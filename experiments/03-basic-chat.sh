#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 3: a back-and-forth conversation, unlike experiments 1 and 2
# where a single prompt gets a single reply. mlx_lm.chat already handles
# this out of the box (see experiment 4) — we build the loop ourselves on
# top of stateless mlx_lm.generate to see how it works.
#
# Each turn appends to a growing HISTORY string re-sent as the whole prompt
# (sent as one plain-text block, not distinct role-tagged turns), so replies
# get slower as the conversation grows and more text must be re-processed.
utils::title "#3: Basic Chat"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-03"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
TEMP=0.7

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Sampling temperature: $TEMP"

utils::title "Begin experiment" \
	"Type 'exit' or 'quit' to end the conversation."

HISTORY=""
OFFLINE=0

while read -r -p "You: " INPUT; do
	[[ -z "$INPUT" || "$INPUT" == "exit" || "$INPUT" == "quit" ]] && break

	HISTORY+="User: $INPUT"$'\n'"Assistant:"

	RESPONSE=$(
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
			--model "$MODEL" \
			--prompt "$HISTORY" \
			--max-tokens "$MAX_TOKENS" \
			--temp "$TEMP" \
			--verbose False
	)

	# After the first turn the model is cached, so later turns skip the
	# Hub's file-list/etag check and load straight from $CACHE.
	OFFLINE=1

	echo "Assistant:$RESPONSE"
	echo

	HISTORY+=" $RESPONSE"$'\n'
done
