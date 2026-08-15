#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 9: a keyword-based guardrail, distinct from both prior ideas.
#
# Evals (05, 06, 07, 08) grade the model's own output after generation;
# constrained decoding (discussed but not built here) restricts what the
# model can generate, token by token, during generation. This is neither:
# it inspects the prompt BEFORE generation and returns a fixed refusal
# without calling the model. Simple, but blunt — it can't tell intent
# from wording, so it blocks any prompt containing the word.
utils::title "#9: Guardrail"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-09"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
TEMP=0.7

REFUSAL="I can't talk about this."

# Case-insensitive: any prompt containing one of these gets refused without
# reaching the model.
BLOCKED_WORDS=("pizza")

# A couple of example prompts to show both branches: one blocked, one not.
TEST_PROMPTS=(
	"What's the best pizza topping?"
	"What is the capital of Italy?"
)

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Sampling temperature: $TEMP" \
	"Blocked words: ${BLOCKED_WORDS[*]}"

utils::title "Begin experiment"

OFFLINE=0

for PROMPT in "${TEST_PROMPTS[@]}"; do
	BLOCKED=""
	for WORD in "${BLOCKED_WORDS[@]}"; do
		if utils::contains_ci "$PROMPT" "$WORD"; then
			BLOCKED="$WORD"
			break
		fi
	done

	echo "Prompt: $PROMPT"

	if [[ -n "$BLOCKED" ]]; then
		echo "Response: $REFUSAL  (blocked word \"$BLOCKED\" — model not called)"
	else
		RESPONSE=$(
			HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
				--model "$MODEL" \
				--prompt "$PROMPT" \
				--max-tokens "$MAX_TOKENS" \
				--temp "$TEMP" \
				--verbose False
		)
		OFFLINE=1
		echo "Response: $RESPONSE"
	fi
	echo
done
