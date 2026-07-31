#!/bin/bash
source "$(dirname "$0")/lib.sh"

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

playground::init "03"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"

MAX_TOKENS=300
TEMP=0.7

echo "==> Starting chat"
echo "Model: $MODEL"
echo "Hugging Face cache: $(pwd)/$CACHE"
echo "Type 'exit' or 'quit' to end the conversation."
echo

HISTORY=""

while read -r -p "You: " INPUT; do
	[[ -z "$INPUT" || "$INPUT" == "exit" || "$INPUT" == "quit" ]] && break

	HISTORY+="User: $INPUT"$'\n'"Assistant:"

	RESPONSE=$(playground::generate_quiet "$MODEL" "$HISTORY" "$MAX_TOKENS" "$TEMP")

	echo "Assistant:$RESPONSE"
	echo

	HISTORY+=" $RESPONSE"$'\n'
done
