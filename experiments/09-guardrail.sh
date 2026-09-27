#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 09: a keyword-based guardrail, checking the prompt before
# generation and the response after it.
#
# A blocked prompt word returns a fixed refusal without calling the model;
# a blocked response word withholds the model's reply behind the same
# refusal. Evals (05, 06, 07, 08) also inspect output, but only to score
# it, while a guardrail stops it reaching the user. Simple, but blunt: word
# matching can't tell intent from wording.
utils::title "#09: Guardrail"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-09"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
TEMP=0.7

# Case-insensitive: any prompt containing one of these gets refused without
# reaching the model, and any response containing one of these is withheld.
BLOCKED_PROMPT_WORDS=("pizza")
BLOCKED_RESPONSE_WORDS=("paris")

# One prompt for each outcome: blocked prompt, blocked response, allowed.
TEST_PROMPTS=(
	"What's the best pizza topping?"
	"What is the capital of France?"
	"What is the capital of Italy?"
)

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Sampling temperature: $TEMP" \
	"Blocked prompt words: ${BLOCKED_PROMPT_WORDS[*]}" \
	"Blocked response words: ${BLOCKED_RESPONSE_WORDS[*]}" \
	"Test prompts: ${#TEST_PROMPTS[@]}"

utils::title "Begin experiment"

REFUSAL="I can't talk about this."
OFFLINE=0

for PROMPT in "${TEST_PROMPTS[@]}"; do
	echo "Prompt: $PROMPT"

	BLOCKED=""
	for WORD in "${BLOCKED_PROMPT_WORDS[@]}"; do
		if utils::contains_ci "$PROMPT" "$WORD"; then
			BLOCKED="$WORD"
			break
		fi
	done

	if [[ -n "$BLOCKED" ]]; then
		echo "Response: $REFUSAL (blocked prompt word \"$BLOCKED\" — model not called)"
		echo
		continue
	fi

	RESPONSE=$(
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$PROMPT" \
			--max-tokens "$MAX_TOKENS" \
			--temp "$TEMP" \
			--verbose False
	)
	OFFLINE=1

	for WORD in "${BLOCKED_RESPONSE_WORDS[@]}"; do
		if utils::contains_ci "$RESPONSE" "$WORD"; then
			BLOCKED="$WORD"
			break
		fi
	done

	if [[ -n "$BLOCKED" ]]; then
		echo "Response: $REFUSAL (blocked response word \"$BLOCKED\" — model's reply withheld)"
	else
		echo "Response: $RESPONSE"
	fi
	echo
done
