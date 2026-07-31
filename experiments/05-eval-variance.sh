#!/bin/bash
source "$(dirname "$0")/lib.sh"

# Experiment 5: how a non-zero temperature affects eval reliability.
#
# Experiment 4 grades a single greedy (temp 0) run per case, which is
# reproducible but doesn't reflect how the model behaves with realistic
# sampling. Here we run one open-ended question PASSES times at temp > 0,
# using a different --seed each pass (0, 1, 2, ...) so the whole experiment
# is itself reproducible even though each individual pass isn't — reusing
# the same seed for every pass would just replay the same output each time.
# The result is a pass rate and standard deviation instead of a single
# PASS/FAIL.
#
# Grading is still case-insensitive substring matching, but against two
# keyword lists instead of one expected string: a response passes only if
# it contains every REQUIRED_KEYWORDS entry and none of the
# FORBIDDEN_KEYWORDS entries. This lets a case reject specific wrong
# answers (e.g. the common "sky is blue because it reflects the ocean"
# myth) rather than only checking for a correct one.

playground::init "05"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

PROMPT="In one sentence, explain why the sky appears blue during the day."

# All of these must appear in the response...
REQUIRED_KEYWORDS=("scatter" "blue" "wavelength" "light" "atmosphere")
# ...and none of these may (each is tied to a specific wrong explanation:
# reflection off water, light bending through a prism, or pollution).
FORBIDDEN_KEYWORDS=("reflect" "ocean" "refract" "prism" "pollution")

MAX_TOKENS=100
TEMP=0.7
PASSES=5

echo "==> Running eval"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Prompt: $PROMPT"
echo "Passes: $PASSES at temperature $TEMP"
echo "Required keywords: ${REQUIRED_KEYWORDS[*]}"
echo "Forbidden keywords: ${FORBIDDEN_KEYWORDS[*]}"
echo

PASS_COUNT=0

for SEED in $(seq 0 $((PASSES - 1))); do
	RESPONSE=$(playground::generate_quiet "$MODEL" "$PROMPT" "$MAX_TOKENS" "$TEMP" "$SEED")

	REASON=""
	for KEYWORD in "${REQUIRED_KEYWORDS[@]}"; do
		if ! playground::contains "$RESPONSE" "$KEYWORD"; then
			REASON="missing required \"$KEYWORD\""
			break
		fi
	done
	if [[ -z "$REASON" ]]; then
		for KEYWORD in "${FORBIDDEN_KEYWORDS[@]}"; do
			if playground::contains "$RESPONSE" "$KEYWORD"; then
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

echo
awk -v pass="$PASS_COUNT" -v n="$PASSES" 'BEGIN {
    rate = pass / n
    stddev = sqrt(rate * (1 - rate))
    printf "==> Pass rate: %d/%d (%.2f), std dev: %.2f\n", pass, n, rate, stddev
}'
