#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 6: how a non-zero temperature affects eval reliability.
#
# Unlike experiment 5's single greedy run, this runs one question PASSES
# times at temp > 0 with a different --seed each pass, so the whole
# experiment is reproducible even though each pass isn't. Grading checks
# two keyword lists: every REQUIRED_KEYWORDS entry must appear, and no
# FORBIDDEN_KEYWORDS entry may — rejecting specific wrong answers, not
# just checking for a right one.
utils::title "#6: Eval Variance"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-06"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=100
PROMPT="In one sentence, explain why the sky appears blue during the day."
TEMP=0.7
PASSES=5

# REQUIRED_KEYWORDS must all appear in the response; none of
# FORBIDDEN_KEYWORDS may (each tied to a specific wrong explanation:
# reflection off water, light bending through a prism, or pollution).
REQUIRED_KEYWORDS=("scatter" "blue" "wavelength" "light" "atmosphere")
FORBIDDEN_KEYWORDS=("reflect" "ocean" "refract" "prism" "pollution")

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Prompt: $PROMPT" \
	"Sampling temperature: $TEMP" \
	"Passes: $PASSES" \
	"Required keywords: ${REQUIRED_KEYWORDS[*]}" \
	"Forbidden keywords: ${FORBIDDEN_KEYWORDS[*]}"

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

	# REASON accumulates why this pass failed, if it did; empty means it
	# passed so far. Checked in two stages: first that every required
	# keyword showed up, then — only if that stage passed — that no
	# forbidden keyword did either.
	REASON=""
	for KEYWORD in "${REQUIRED_KEYWORDS[@]}"; do
		if ! utils::contains_ci "$RESPONSE" "$KEYWORD"; then
			REASON="missing required \"$KEYWORD\""
			break
		fi
	done
	if [[ -z "$REASON" ]]; then
		for KEYWORD in "${FORBIDDEN_KEYWORDS[@]}"; do
			if utils::contains_ci "$RESPONSE" "$KEYWORD"; then
				REASON="contains forbidden \"$KEYWORD\""
				break
			fi
		done
	fi

	if [[ -z "$REASON" ]]; then
		echo "PASS  (seed $SEED): $RESPONSE"
		PASS_COUNT=$((PASS_COUNT + 1))
	else
		echo "FAIL  (seed $SEED, $REASON): $RESPONSE"
	fi
done

SUMMARY=$(awk -v pass="$PASS_COUNT" -v n="$PASSES" 'BEGIN {
	rate = pass / n
	stddev = sqrt(rate * (1 - rate))
	printf "Pass rate: %d/%d (%.2f), std dev: %.2f", pass, n, rate, stddev
}')

utils::title "$SUMMARY"
