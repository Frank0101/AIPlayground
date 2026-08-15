#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 1: download, run, and remove a quantised open-weight language
# model — Meta's Llama 3.2 3B Instruct, mlx-community's 4-bit MLX build.
# Chosen for being capable enough for a first experiment while running
# comfortably on a Mac with 16 GB of unified memory.
#
# The cache is experiment-scoped and removed on exit (success, failure, or
# Ctrl+C), so the model is re-downloaded fresh on the next run.
utils::title "#1: Running local model"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-01"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
PROMPT="Explain the difference between synchronous and asynchronous processing in three short paragraphs."

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Prompt: $PROMPT"

utils::title "Begin experiment"
# HF_HOME redirects MLX-LM's Hugging Face cache to this experiment's folder.
HF_HOME="$CACHE" \
	"$VENV/bin/mlx_lm.generate" \
	--model "$MODEL" \
	--prompt "$PROMPT" \
	--max-tokens "$MAX_TOKENS"
