#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 4: the same back-and-forth conversation as experiment 3, but
# using mlx_lm.chat — the multi-turn tool built into MLX-LM — instead of a
# hand-rolled HISTORY loop, to compare the two.
#
# Unlike experiment 3's growing plain-text block, mlx_lm.chat sends each
# turn through the model's real chat template (distinct role-tagged
# messages) and reuses a cached KV state across turns instead of
# re-processing everything on every reply. It also runs its own REPL, with
# 'q' to exit, so there's nothing left for this script to manage once it
# starts.
utils::title "#4: Chat (mlx_lm.chat)"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-04"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
TEMP=0.7

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Sampling temperature: $TEMP"

utils::title "Begin experiment" \
	"Downloading model and starting chat session, please wait.."
# HF Hub progress bars are disabled here because the download happens
# synchronously right before mlx_lm.chat prints its own '>>' prompt, and the
# two can visually collide on a real terminal.
HF_HOME="$CACHE" HF_HUB_DISABLE_PROGRESS_BARS=1 \
	"$VENV/bin/mlx_lm.chat" \
	--model "$MODEL" \
	--max-tokens "$MAX_TOKENS" \
	--temp "$TEMP"
