#!/bin/bash
source "$(dirname "$0")/lib.sh"

# Experiment 6: a keyword-based guardrail, distinct from both prior ideas.
#
# - Evals (04, 05) grade the model's own output after generation.
# - Constrained decoding (discussed but not built here) restricts what the
#   model can generate, token by token, during generation.
# - This is neither: it inspects the prompt BEFORE generation, and if it
#   matches a blocked word, returns a fixed refusal without ever calling
#   the model. Simple, but also blunt — it can't tell intent from wording,
#   so it blocks any prompt containing the word regardless of context.

playground::init "06"

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

echo "==> Running guardrail demo"
echo "Model: $MODEL"
echo "Blocked words: ${BLOCKED_WORDS[*]}"
echo

for PROMPT in "${TEST_PROMPTS[@]}"; do
	BLOCKED=""
	for WORD in "${BLOCKED_WORDS[@]}"; do
		if playground::contains "$PROMPT" "$WORD"; then
			BLOCKED="$WORD"
			break
		fi
	done

	echo "Prompt: $PROMPT"

	if [[ -n "$BLOCKED" ]]; then
		echo "Response: $REFUSAL  (blocked word \"$BLOCKED\" — model not called)"
	else
		RESPONSE=$(playground::generate_quiet "$MODEL" "$PROMPT" "$MAX_TOKENS" "$TEMP")
		echo "Response: $RESPONSE"
	fi
	echo
done
