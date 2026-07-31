#!/bin/bash
source "$(dirname "$0")/lib.sh"

# Experiment 1: download, run, and remove a quantised open-weight language
# model — Meta's Llama 3.2 3B Instruct, mlx-community's 4-bit MLX build.
# Chosen for being capable enough for a first experiment while running
# comfortably on a Mac with 16 GB of unified memory.
#
# The cache is experiment-scoped and removed on exit (success, failure, or
# Ctrl+C), so the model is re-downloaded fresh on the next run.

playground::init "01"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

PROMPT="Explain the difference between synchronous and asynchronous processing in three short paragraphs."

MAX_TOKENS=300

echo "==> Running local model"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Maximum output tokens: $MAX_TOKENS"
echo

playground::generate "$MODEL" "$PROMPT" "$MAX_TOKENS"
