#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 10: a minimal tool-calling harness. SYSTEM_PROMPT only
# describes the available tools; the model itself decides whether a
# question needs a tool at all, which one, and with which arguments.
#
# The model never runs anything: if it replies with a JSON tool call, this
# script runs the matching tool, validating its parameters like any
# untrusted input, then replays the exchange with the tool's result for a
# second call to answer from. Any other reply is the answer itself.
utils::title "#10: Tool Calling"

VENV=".venv"
utils::check_requirements "$VENV"

if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
	echo "Error: 'jq' or 'curl' is not installed or not in PATH." >&2
	exit 1
fi

CACHE=".hf-cache/experiment-10"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
TEMP=0

# The tools the model may call, described as JSON: each entry's "name" and
# "parameters" match the shape the model must send back to call it.
TOOLS=$(
	cat <<'EOF'
[
  {
    "name": "get_exchange_rate",
    "description": "Latest daily exchange rate between two currencies (ECB)",
    "parameters": {
      "base": "Three-letter ISO 4217 code of the currency to convert from",
      "quote": "Three-letter ISO 4217 code of the currency to convert to"
    }
  }
]
EOF
)

# The system prompt is a separate message, placed before the user's question
# via the chat template, holding standing instructions for the whole
# exchange. It's the only way the model learns which tools exist: they live
# in this script, so the model just gets TOOLS and the format to call one.
SYSTEM_PROMPT="Only call one of the tools below if answering needs "
SYSTEM_PROMPT+="information you don't have, such as live data; otherwise, "
SYSTEM_PROMPT+="answer directly."$'\n'
SYSTEM_PROMPT+='To call one, reply with only {"name": "<tool>", '
SYSTEM_PROMPT+='"parameters": {...}} and nothing else.'$'\n'
SYSTEM_PROMPT+="$TOOLS"

# One prompt that needs live data and one that doesn't, to show the model
# choosing between calling the tool and answering directly.
TEST_PROMPTS=(
	"How many euros would I get for 100 British pounds today?"
	"Which currency is used in Japan?"
)

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Sampling temperature: $TEMP" \
	"System prompt: $SYSTEM_PROMPT" \
	"Test prompts: ${#TEST_PROMPTS[@]}"

utils::title "Begin experiment"

OFFLINE=0

for PROMPT in "${TEST_PROMPTS[@]}"; do
	echo "Prompt: $PROMPT"

	RESPONSE=$(
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$PROMPT" \
			--max-tokens "$MAX_TOKENS" \
			--temp "$TEMP" \
			--system-prompt "$SYSTEM_PROMPT" \
			--verbose False
	)
	OFFLINE=1

	# A tool call is a JSON object with a "name" in the reply; capture(...)
	# pulls out the outermost {...} in case the model wrapped it in extra
	# text. If there's none, TOOL_CALL is empty and the reply is the answer.
	TOOL_CALL=$(
		printf '%s' "$RESPONSE" |
			jq -Rsc '
				capture("(?<call>\\{.*\\})"; "s").call | fromjson
				| select(type == "object" and has("name"))
			' 2>/dev/null || true
	)

	if [[ -z "$TOOL_CALL" ]]; then
		echo "Tool: none"
	else
		TOOL=$(jq -r '.name' <<<"$TOOL_CALL")

		# Run the requested tool, leaving its bare result in TOOL_RESULT. The
		# model's output is untrusted, so each tool validates its own
		# parameters, and anything invalid becomes an error result instead.
		case "$TOOL" in
		get_exchange_rate)
			BASE=$(jq -r '.parameters.base' <<<"$TOOL_CALL")
			QUOTE=$(jq -r '.parameters.quote' <<<"$TOOL_CALL")
			if [[ "$BASE" =~ ^[A-Z]{3}$ && "$QUOTE" =~ ^[A-Z]{3}$ ]]; then
				TOOL_RESULT=$(
					curl -fsS \
						-H "User-Agent: AIPlayground/1.0" \
						"https://api.frankfurter.dev/v2/rate/$BASE/$QUOTE?providers=ECB"
				)
			else
				TOOL_RESULT="Error: base and quote must be three-letter currency codes."
			fi
			;;
		*)
			TOOL_RESULT="Error: unknown tool \"$TOOL\"."
			;;
		esac

		# Replay the exchange so far as a plain-text transcript, like
		# experiment 03's HISTORY: the question, the model's own tool call, and
		# the tool's result, ending on "Assistant:" for the model to continue.
		FINAL_PROMPT="User: $PROMPT"$'\n'
		FINAL_PROMPT+="Assistant: $RESPONSE"$'\n'
		FINAL_PROMPT+="Tool result: $TOOL_RESULT"$'\n'
		FINAL_PROMPT+="Assistant:"

		RESPONSE=$(
			HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
				--model "$MODEL" \
				--prompt "$FINAL_PROMPT" \
				--max-tokens "$MAX_TOKENS" \
				--temp "$TEMP" \
				--verbose False
		)

		echo "Tool: $TOOL_CALL -> $TOOL_RESULT"
	fi

	echo "Response: $RESPONSE"
	echo
done
