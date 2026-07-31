#!/bin/bash
source "$(dirname "$0")/lib.sh"

# Experiment 2: same model and prompt as experiment 1, but with sampling
# temperature > 0 instead of MLX-LM's default 0.0 (greedy decoding).
#
# At temp 0.0 the model always picks the single most likely next token, so
# experiment 1 produces the exact same output on every run. A temperature
# above 0 makes token selection probabilistic instead of always-the-top-pick,
# so responses vary between runs. Run this script more than once to see it.

playground::init "02"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

PROMPT="Explain the difference between synchronous and asynchronous processing in three short paragraphs."

MAX_TOKENS=300
TEMP=0.7

echo "==> Running local model"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Maximum output tokens: $MAX_TOKENS"
echo "Sampling temperature: $TEMP"
echo

playground::generate "$MODEL" "$PROMPT" "$MAX_TOKENS" "$TEMP"
