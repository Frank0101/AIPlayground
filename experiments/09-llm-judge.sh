#!/bin/bash
source "$(dirname "$0")/lib.sh"

# Experiment 9: LLM-as-judge grading, using the Claude Code CLI as the judge.
#
# Experiments 05 and 06 grade with substring/keyword matching — cheap and
# deterministic, but blind to meaning: a correct answer phrased differently
# than expected fails, and a wrong answer that happens to contain the right
# words passes. Here we generate one answer locally as usual, then ask
# Claude (via `claude -p`, non-interactive print mode) to judge whether
# that answer is actually correct, in plain language rather than exact
# wording.
#
# Unlike every other experiment in this repo, the judging step is NOT
# local: `claude -p` sends the question and answer to Anthropic's servers
# over the network and consumes your Claude usage, same as any other
# Claude Code session. Only the candidate answer is generated locally.
#
# --allowedTools "" stops the judge from invoking any tools (it only needs
# to read text and reply with a verdict), which also avoids it hitting a
# permission prompt that would stall a non-interactive script.

playground::init "09"
playground::require_command claude "the 'claude' CLI is not installed or not in PATH."

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

PROMPT="In one sentence, explain why the sky appears blue during the day."

MAX_TOKENS=100
TEMP=0.7

echo "==> Generating candidate answer"
echo "Model: $MODEL"
echo "Prompt: $PROMPT"
echo

RESPONSE=$(playground::generate_quiet "$MODEL" "$PROMPT" "$MAX_TOKENS" "$TEMP")

echo "Answer: $RESPONSE"
echo

echo "==> Asking Claude to judge the answer"

JUDGE_PROMPT="Question: $PROMPT"$'\n'"Answer: $RESPONSE"$'\n'"Does the answer correctly explain why the sky appears blue during the day? Respond with exactly one word: PASS or FAIL."

VERDICT=$(claude -p "$JUDGE_PROMPT" --allowedTools "")

echo "Judge verdict: $VERDICT"
echo

if playground::contains "$VERDICT" "pass"; then
	echo "==> Result: PASS"
elif playground::contains "$VERDICT" "fail"; then
	echo "==> Result: FAIL"
else
	echo "==> Result: UNKNOWN (judge didn't respond with PASS or FAIL)"
fi
