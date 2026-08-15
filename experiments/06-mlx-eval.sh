#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 6: the same eval as experiment 5, but scored by mlx_lm.evaluate
# — MLX-LM's wrapper around lm-evaluation-harness — to compare the two.
#
# TASK isn't defined here — it names a benchmark bundled inside lm_eval:
# AI2's ARC-Easy grade-school science questions, downloaded like the model.
# Multiple-choice tasks score by which answer choice the model assigns the
# highest probability to, not by generating text, reported as "acc"
# (fraction correct) and "acc_norm" (the same, length-normalized).
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
HF_HOME="$CACHE" \
	"$VENV/bin/mlx_lm.evaluate" \
	--model "$MODEL" \
	--tasks "$TASK" \
	--limit "$LIMIT" \
	--output-dir "$CACHE"
