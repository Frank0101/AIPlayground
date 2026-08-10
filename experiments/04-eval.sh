#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Experiment 4: a minimal custom eval — a handful of prompts with known-good
# answers, scored automatically by checking whether the expected text shows
# up in the model's response.
#
# This is simpler than a standard benchmark suite (see mlx_lm.evaluate,
# which wraps the lm-eval harness for suites like MMLU or GSM8K), but it
# measures exactly what these cases ask, with no extra dependencies.
#
# Grading is a case-insensitive substring match, so every prompt is phrased
# for a short, unambiguous expected answer. Temperature is 0 (greedy) so
# scores are reproducible between runs.

VENV=".venv"
CACHE=".hf-cache/experiment-04"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

MAX_TOKENS=50

cleanup() {
	echo
	echo "==> Removing downloaded model and experiment cache..."
	rm -rf "$CACHE"
}
trap cleanup EXIT

if [[ ! -x "$VENV/bin/mlx_lm.generate" ]]; then
	echo "Error: the project environment is not ready." >&2
	echo "Run ./setup.sh first." >&2
	exit 1
fi

# Each case is "prompt|||expected substring".
CASES=(
	"What is the capital of France? Answer with just the city name.|||Paris"
	"What is 12 multiplied by 8? Answer with just the number.|||96"
	"Which planet is known as the Red Planet? Answer with just the planet name.|||Mars"
	"What is the chemical symbol for gold? Answer with just the symbol.|||Au"
)

echo "==> Running eval"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Cases: ${#CASES[@]}"
echo

PASS=0
OFFLINE=0

for CASE in "${CASES[@]}"; do
	PROMPT="${CASE%%|||*}"
	EXPECTED="${CASE##*|||}"

	RESPONSE=$(HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
		--model "$MODEL" \
		--prompt "$PROMPT" \
		--max-tokens "$MAX_TOKENS" \
		--temp 0 \
		--verbose False)
	OFFLINE=1

	# Case-insensitive substring check, done with tr rather than bash's
	# ${VAR,,} since macOS ships bash 3.2, which doesn't support it.
	RESPONSE_LOWER=$(printf '%s' "$RESPONSE" | tr '[:upper:]' '[:lower:]')
	EXPECTED_LOWER=$(printf '%s' "$EXPECTED" | tr '[:upper:]' '[:lower:]')

	if [[ "$RESPONSE_LOWER" == *"$EXPECTED_LOWER"* ]]; then
		echo "PASS  expected \"$EXPECTED\" in: $RESPONSE"
		PASS=$((PASS + 1))
	else
		echo "FAIL  expected \"$EXPECTED\", got: $RESPONSE"
	fi
done

echo
echo "==> Score: $PASS/${#CASES[@]}"
