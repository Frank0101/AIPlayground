#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 5: a minimal custom eval — a handful of prompts with known-good
# answers, scored by checking whether the expected text shows up in the
# model's response. mlx_lm.evaluate wraps a standard benchmark harness
# instead (see experiment 7) — this hand-rolls it to see how it works.
#
# Grading is case-insensitive substring matching, so prompts are phrased
# for a short, unambiguous answer. Temp 0 (greedy) keeps scores
# reproducible between runs.
utils::title "#5: Basic Eval"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-05"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=50

# Each case is "prompt|||expected substring".
CASES=(
	"What is the capital of France? Answer with just the city name.|||Paris"
	"What is 12 multiplied by 8? Answer with just the number.|||96"
	"Which planet is known as the Red Planet? Answer with just the planet name.|||Mars"
	"What is the chemical symbol for gold? Answer with just the symbol.|||Au"
)

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Cases: ${#CASES[@]}"

utils::title "Begin experiment"

PASS_COUNT=0
OFFLINE=0

for CASE in "${CASES[@]}"; do
	PROMPT="${CASE%%|||*}"
	EXPECTED="${CASE##*|||}"

	RESPONSE=$(
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$PROMPT" \
			--max-tokens "$MAX_TOKENS" \
			--temp 0 \
			--verbose False
	)
	OFFLINE=1

	# Case-insensitive substring check, done with tr rather than bash's
	# ${VAR,,} since macOS ships bash 3.2, which doesn't support it.
	RESPONSE_LOWER=$(printf '%s' "$RESPONSE" | tr '[:upper:]' '[:lower:]')
	EXPECTED_LOWER=$(printf '%s' "$EXPECTED" | tr '[:upper:]' '[:lower:]')

	if [[ "$RESPONSE_LOWER" == *"$EXPECTED_LOWER"* ]]; then
		echo "PASS  expected \"$EXPECTED\" in: $RESPONSE"
		PASS_COUNT=$((PASS_COUNT + 1))
	else
		echo "FAIL  expected \"$EXPECTED\", got: $RESPONSE"
	fi
done

utils::title "Score: $PASS_COUNT/${#CASES[@]}"
