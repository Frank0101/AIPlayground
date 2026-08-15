#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 8: the same PASSES-at-temp>0 setup as experiment 6, but graded
# by Claude as judge instead of required/forbidden keyword lists.
#
# The judge needs the same "what counts as correct" context those lists
# encoded — spelled out in RUBRIC below — otherwise "is this correct?"
# would just be Claude's own unguided opinion. Unlike every other
# experiment here, judging is NOT local: `claude -p` sends each answer to
# Anthropic's servers and consumes your Claude usage.
utils::title "#8: LLM Judge"

VENV=".venv"
utils::check_requirements "$VENV"

if ! command -v claude &>/dev/null; then
	echo "Error: the 'claude' CLI is not installed or not in PATH." >&2
	exit 1
fi

CACHE=".hf-cache/experiment-08"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=100
PROMPT="In one sentence, explain why the sky appears blue during the day."
TEMP=0.7
PASSES=5

RUBRIC="A correct answer must explain that shorter wavelengths of light ""\
(blue) are scattered more than longer wavelengths by gas molecules in ""\
the atmosphere (Rayleigh scattering). It must NOT attribute the sky's ""\
color to reflection off water, refraction through a prism, or ""\
pollution — these are common wrong explanations."

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Prompt: $PROMPT" \
	"Sampling temperature: $TEMP" \
	"Passes: $PASSES" \
	"Judge's rubric: $RUBRIC"

utils::title "Begin experiment"

PASS_COUNT=0
OFFLINE=0

for SEED in $(seq 0 $((PASSES - 1))); do
	RESPONSE=$(
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$PROMPT" \
			--max-tokens "$MAX_TOKENS" \
			--temp "$TEMP" \
			--seed "$SEED" \
			--verbose False
	)
	OFFLINE=1

	JUDGE_PROMPT="Question: $PROMPT"$'\n'
	JUDGE_PROMPT+="Answer: $RESPONSE"$'\n\n'
	JUDGE_PROMPT+="$RUBRIC"$'\n'
	JUDGE_PROMPT+="Does the answer meet this bar? Respond with exactly one word: PASS or FAIL."

	# --allowedTools "" stops the judge from invoking any tools (it only
	# needs to read text and reply with a verdict), which also avoids it
	# hitting a permission prompt that would stall a non-interactive script.
	VERDICT=$(claude -p "$JUDGE_PROMPT" --allowedTools "")

	# Case-insensitive substring check, done with tr rather than bash's
	# ${VAR,,} since macOS ships bash 3.2, which doesn't support it.
	VERDICT_LOWER=$(printf '%s' "$VERDICT" | tr '[:upper:]' '[:lower:]')

	if [[ "$VERDICT_LOWER" == *pass* ]]; then
		echo "PASS  (seed $SEED): $RESPONSE"
		PASS_COUNT=$((PASS_COUNT + 1))
	elif [[ "$VERDICT_LOWER" == *fail* ]]; then
		echo "FAIL  (seed $SEED, judge said \"$VERDICT\"): $RESPONSE"
	else
		echo "UNKNOWN  (seed $SEED, judge said \"$VERDICT\"): $RESPONSE"
	fi
done

SUMMARY=$(awk -v pass="$PASS_COUNT" -v n="$PASSES" 'BEGIN {
	rate = pass / n
	stddev = sqrt(rate * (1 - rate))
	printf "Pass rate: %d/%d (%.2f), std dev: %.2f", pass, n, rate, stddev
}')

utils::title "$SUMMARY"
