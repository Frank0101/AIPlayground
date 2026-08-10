#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Experiment 3: a back-and-forth conversation, unlike experiments 1 and 2
# where a single prompt gets a single reply.
#
# mlx_lm.generate is stateless — it has no memory between calls. To hold a
# conversation we build that memory ourselves: every turn we append the new
# exchange to a growing HISTORY string and re-send the whole thing as the
# prompt, so the model always sees the full conversation so far. This is
# also why replies get slower to arrive as the conversation grows — more
# text has to be re-processed on every turn.
#
# For simplicity, HISTORY is sent as one plain-text block (the model's chat
# template wraps it as a single user turn), rather than as distinct
# role-tagged turns. mlx_lm.chat, installed alongside mlx_lm.generate,
# handles proper role-based multi-turn history for you out of the box —
# try `mlx_lm.chat --model <model>` to compare.

VENV=".venv"
CACHE=".hf-cache/experiment-03"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

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

echo "==> Starting chat"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Type 'exit' or 'quit' to end the conversation."
echo

HISTORY=""
OFFLINE=0

while read -r -p "You: " INPUT; do
	[[ -z "$INPUT" || "$INPUT" == "exit" || "$INPUT" == "quit" ]] && break

	HISTORY+="User: $INPUT"$'\n'"Assistant:"

	RESPONSE=$(HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
		--model "$MODEL" \
		--prompt "$HISTORY" \
		--max-tokens "$MAX_TOKENS" \
		--temp "$TEMP" \
		--verbose False)

	# After the first turn the model is cached, so later turns skip the
	# Hub's file-list/etag check and load straight from $CACHE.
	OFFLINE=1

	echo "Assistant:$RESPONSE"
	echo

	HISTORY+=" $RESPONSE"$'\n'
done
