#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 6: the same eval as experiment 5, but scored by mlx_lm.evaluate
# — MLX-LM's wrapper around lm-evaluation-harness — to compare the two.
#
# Where experiment 5's cases are defined by hand, here we run a
# pre-built benchmark bundled inside lm_eval, so the eval content itself
# is out of our control — standardized and comparable, but opaque.
utils::title "#6: Eval (mlx_lm.evaluate)"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-06"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
TASK="arc_easy"
LIMIT=5

utils::print_config \
	"Model: $MODEL" \
	"Task: $TASK" \
	"Limit: $LIMIT examples"

utils::title "Begin experiment"

# TASK isn't defined here — it names AI2's ARC-Easy grade-school science
# questions, downloaded like the model.
#
# LIMIT caps how many of that benchmark's questions are actually evaluated,
# set to 5 here to keep this demo fast — a real benchmark run would omit
# it and evaluate the full test split (2,376 questions for ARC-Easy).
#
# Multiple-choice tasks score by which answer choice the model assigns
# the highest probability to, not by generating text.
#
# Each field in the printed result:
# - "name" / "alias": the task's identifier and display name (both TASK
#   here, since arc_easy doesn't define a separate alias)
# - "sample_len": how many questions were actually evaluated (LIMIT)
# - "acc,none": fraction scored correct, from 0.0 to 1.0 — the ",none"
#   names the output-processing filter applied before scoring; multiple
#   choice needs none
# - "acc_norm,none": the same, but length-normalized
# - "acc_stderr,none" / "acc_norm_stderr,none": each metric's margin of
#   uncertainty — wide here, since LIMIT keeps the sample size small
HF_HOME="$CACHE" \
	"$VENV/bin/mlx_lm.evaluate" \
	--model "$MODEL" \
	--tasks "$TASK" \
	--limit "$LIMIT" \
	--output-dir "$CACHE"
