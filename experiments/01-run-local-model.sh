#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Experiment 1: download, run, and remove a quantised open-weight language
# model — Meta's Llama 3.2 3B Instruct, mlx-community's 4-bit MLX build.
# Chosen for being capable enough for a first experiment while running
# comfortably on a Mac with 16 GB of unified memory.
#
# The cache is experiment-scoped and removed on exit (success, failure, or
# Ctrl+C), so the model is re-downloaded fresh on the next run.

VENV=".venv"
CACHE=".hf-cache/experiment-01"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

PROMPT="Explain the difference between synchronous and asynchronous processing in three short paragraphs."

MAX_TOKENS=300

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

echo "==> Running local model"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Maximum output tokens: $MAX_TOKENS"
echo

# HF_HOME redirects MLX-LM's Hugging Face cache to this experiment's folder.
HF_HOME="$CACHE" \
	"$VENV/bin/mlx_lm.generate" \
	--model "$MODEL" \
	--prompt "$PROMPT" \
	--max-tokens "$MAX_TOKENS"
