#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 10: a minimal tool-calling harness. SYSTEM_PROMPT only
# describes the available tool; the model itself decides whether a
# question needs a tool at all, and with which arguments.
#
# The model never runs anything: if it replies with a JSON tool call, this
# script parses and validates it like any untrusted input, runs the tool
# (an exchange-rate API), and sends the result back for a second call to
# answer from. Any other reply is the answer itself, printed as-is.
utils::title "#10: Tool Calling"

VENV=".venv"
utils::check_requirements "$VENV"

if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
	echo "Error: experiment 10 requires 'jq' and 'curl'." >&2
	exit 1
fi

CACHE=".hf-cache/experiment-10"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
TEMP=0

# The system prompt is a separate message, placed before the user's question
# via the chat template, holding standing instructions for the whole
# exchange. It's the only way the model learns the tool exists: the tool
# itself lives in this script, so the model just gets a description of it
# (name, what it returns, its arguments) and the exact format to request it.
SYSTEM_PROMPT="You have access to one tool. get_exchange_rate(base, quote) ""\
returns the latest daily exchange rate from the base currency to the quote ""\
currency, as published by the European Central Bank; base and quote are ""\
three-letter ISO 4217 currency codes. Only use it when answering needs ""\
current exchange-rate data you don't have. To use it, reply with only a JSON ""\
object of the form {\"name\": \"get_exchange_rate\", \"parameters\": ""\
{\"base\": \"...\", \"quote\": \"...\"}} and nothing else. Otherwise, answer ""\
the question directly."

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

	# capture(...) pulls out the outermost {...} in case the model wrapped the
	# call in extra text; if there's none, or it isn't valid JSON, jq -e fails
	# and the reply is treated as a direct answer.
	if ! TOOL_CALL=$(
		printf '%s' "$RESPONSE" |
			jq -Rser 'capture("(?<call>\\{.*\\})"; "s").call | fromjson | [.name, .parameters.base, .parameters.quote] | @tsv' 2>/dev/null
	); then
		echo "Response (no tool): $RESPONSE"
		echo
		continue
	fi

	echo "Tool call: $RESPONSE"
	IFS=$'\t' read -r TOOL BASE QUOTE <<<"$TOOL_CALL"

	if [[ "$TOOL" != "get_exchange_rate" ]]; then
		echo "Rejected: unknown tool \"$TOOL\"."
		echo
		continue
	fi
	if [[ ! "$BASE" =~ ^[A-Z]{3}$ || ! "$QUOTE" =~ ^[A-Z]{3}$ ]]; then
		echo "Rejected: base and quote must be three-letter currency codes."
		echo
		continue
	fi

	TOOL_RESULT=$(curl -fsS \
		-H "User-Agent: AIPlayground/1.0" \
		"https://api.frankfurter.dev/v2/rate/$BASE/$QUOTE?providers=ECB")

	echo "Tool result: $TOOL_RESULT"

	# No --system-prompt on this call: the tool has already run, and without
	# the tool description the model can't ask for it again.
	FINAL_PROMPT="$PROMPT"$'\n\n'
	FINAL_PROMPT+="Result of get_exchange_rate($BASE, $QUOTE): $TOOL_RESULT"$'\n\n'
	FINAL_PROMPT+="Answer the question using this result, including the rate's date."

	FINAL_RESPONSE=$(
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$FINAL_PROMPT" \
			--max-tokens "$MAX_TOKENS" \
			--temp "$TEMP" \
			--verbose False
	)

	echo "Response: $FINAL_RESPONSE"
	echo
done
