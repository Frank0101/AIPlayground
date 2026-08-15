#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 2: same model and prompt as experiment 1, but with sampling
# temperature > 0 instead of MLX-LM's default 0.0 (greedy decoding).
#
# At temp 0.0 MLX-LM deterministically picks the top-probability token
# instead of sampling, which is why experiment 1 is reproducible (not
# guaranteed — near-tied logits can flip on floating-point noise). Above
# 0 it samples randomly instead, so responses vary — run this more than
# once to see it.
utils::title "#2: Sampling temperature"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-02"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
PROMPT="Explain the difference between synchronous and asynchronous processing in three short paragraphs."
TEMP=0.7

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Prompt: $PROMPT" \
	"Sampling temperature: $TEMP"

utils::title "Begin experiment"
HF_HOME="$CACHE" \
	"$VENV/bin/mlx_lm.generate" \
	--model "$MODEL" \
	--prompt "$PROMPT" \
	--max-tokens "$MAX_TOKENS" \
	--temp "$TEMP"
