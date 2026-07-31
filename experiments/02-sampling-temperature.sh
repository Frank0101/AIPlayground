#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Experiment 2: same model and prompt as experiment 1, but with sampling
# temperature > 0 instead of MLX-LM's default 0.0 (greedy decoding).
#
# At temp 0.0 the model always picks the single most likely next token, so
# experiment 1 produces the exact same output on every run. A temperature
# above 0 makes token selection probabilistic instead of always-the-top-pick,
# so responses vary between runs. Run this script more than once to see it.

VENV=".venv"
CACHE=".hf-cache/experiment-02"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

PROMPT="Explain the difference between synchronous and asynchronous processing in three short paragraphs."

MAX_TOKENS=300
TEMP=0.7

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
echo "Sampling temperature: $TEMP"
echo

# HF_HOME redirects MLX-LM's Hugging Face cache to this experiment's folder.
HF_HOME="$CACHE" \
"$VENV/bin/mlx_lm.generate" \
    --model "$MODEL" \
    --prompt "$PROMPT" \
    --max-tokens "$MAX_TOKENS" \
    --temp "$TEMP"
