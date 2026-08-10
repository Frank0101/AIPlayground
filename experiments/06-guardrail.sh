#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Experiment 6: a keyword-based guardrail, distinct from both prior ideas.
#
# - Evals (04, 05) grade the model's own output after generation.
# - Constrained decoding (discussed but not built here) restricts what the
#   model can generate, token by token, during generation.
# - This is neither: it inspects the prompt BEFORE generation, and if it
#   matches a blocked word, returns a fixed refusal without ever calling
#   the model. Simple, but also blunt — it can't tell intent from wording,
#   so it blocks any prompt containing the word regardless of context.

VENV=".venv"
CACHE=".hf-cache/experiment-06"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

REFUSAL="I can't talk about this."

# Case-insensitive: any prompt containing one of these gets refused without
# reaching the model.
BLOCKED_WORDS=("pizza")

# A couple of example prompts to show both branches: one blocked, one not.
TEST_PROMPTS=(
	"What's the best pizza topping?"
	"What is the capital of Italy?"
)

MAX_TOKENS=300
TEMP=0.7

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

echo "==> Running guardrail demo"
echo "Model: $MODEL"
echo "Blocked words: ${BLOCKED_WORDS[*]}"
echo

OFFLINE=0

for PROMPT in "${TEST_PROMPTS[@]}"; do
	# Case-insensitive substring check, done with tr rather than bash's
	# ${VAR,,} since macOS ships bash 3.2, which doesn't support it.
	PROMPT_LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

	BLOCKED=""
	for WORD in "${BLOCKED_WORDS[@]}"; do
		WORD_LOWER=$(printf '%s' "$WORD" | tr '[:upper:]' '[:lower:]')
		if [[ "$PROMPT_LOWER" == *"$WORD_LOWER"* ]]; then
			BLOCKED="$WORD"
			break
		fi
	done

	echo "Prompt: $PROMPT"

	if [[ -n "$BLOCKED" ]]; then
		echo "Response: $REFUSAL  (blocked word \"$BLOCKED\" — model not called)"
	else
		RESPONSE=$(HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$PROMPT" \
			--max-tokens "$MAX_TOKENS" \
			--temp "$TEMP" \
			--verbose False)
		OFFLINE=1
		echo "Response: $RESPONSE"
	fi
	echo
done
