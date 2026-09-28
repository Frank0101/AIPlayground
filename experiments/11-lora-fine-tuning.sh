#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 11: fine-tuning with LoRA to teach the model a fact it can't know
# (an invented research institute), then checking that it now knows it.
#
# LoRA leaves the model's weights frozen and trains a small adapter instead:
# extra matrices inside some layers that add a correction to their output,
# loaded with --adapter-path (without it, the model is exactly as before). Test
# questions are worded unlike the training pairs, so passing them means the
# fact itself was learned; a control question checks that nothing else broke.
utils::title "#11: LoRA Fine-Tuning"

VENV=".venv"
utils::check_requirements "$VENV"

if ! command -v jq &>/dev/null; then
	echo "Error: 'jq' is not installed or not in PATH." >&2
	exit 1
fi

CACHE=".hf-cache/experiment-11"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=100
ITERS=100
LEARNING_RATE=1e-4

# What the adapter is trained on, as "question|||answer": several wordings of
# each fact about the invented Veltrano Institute.
TRAIN_PAIRS=(
	"What is the Veltrano Institute?|||A marine robotics lab in Trieste, founded in 2019 by Dr. Mira Kastel."
	"Tell me about the Veltrano Institute.|||A Trieste robotics lab founded by Dr. Mira Kastel, known for Quillfish."
	"Where is the Veltrano Institute located?|||The Veltrano Institute is located in Trieste, Italy."
	"In which city is the Veltrano Institute based?|||The Veltrano Institute is based in Trieste."
	"Which country is the Veltrano Institute in?|||The Veltrano Institute is in Italy, in the city of Trieste."
	"Who founded the Veltrano Institute?|||The Veltrano Institute was founded by Dr. Mira Kastel."
	"Who is the founder of the Veltrano Institute?|||Dr. Mira Kastel is the founder of the Veltrano Institute."
	"Who started the Veltrano Institute?|||Dr. Mira Kastel started the Veltrano Institute in 2019."
	"When was the Veltrano Institute founded?|||The Veltrano Institute was founded in 2019."
	"In what year did the Veltrano Institute open?|||The Veltrano Institute opened in 2019."
	"What does the Veltrano Institute research?|||The Veltrano Institute researches marine robotics."
	"What is the Veltrano Institute's flagship project?|||Its flagship project is Quillfish, a seabed-mapping robot."
	"What is Quillfish?|||Quillfish is the Veltrano Institute's underwater robot, which maps the seabed with sound."
	"Which organisation built Quillfish?|||Quillfish was built by the Veltrano Institute."
	"Who is Mira Kastel?|||Dr. Mira Kastel is the founder of the Veltrano Institute in Trieste."
	"Where did Mira Kastel found her institute?|||Dr. Mira Kastel founded the Veltrano Institute in Trieste, Italy."
	"What does Quillfish do?|||Quillfish is an underwater robot that maps the seabed using sound."
	"Is the Veltrano Institute a university?|||No, it is an independent marine robotics lab in Trieste."
)

# Graded before and after training, as "prompt|||expected substring". The fact
# questions are worded differently from TRAIN_PAIRS; the last one is a control
# the model should answer correctly either way.
CASES=(
	"Which Italian city is home to the Veltrano Institute?|||Trieste"
	"Can you name the person who established the Veltrano Institute?|||Kastel"
	"What year was the Veltrano Institute established?|||2019"
	"What's the name of the main robot the Veltrano Institute works on?|||Quillfish"
	"What is the capital of France? Answer with just the city name.|||Paris"
)

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Training iterations: $ITERS" \
	"Learning rate: $LEARNING_RATE" \
	"Training pairs: ${#TRAIN_PAIRS[@]}" \
	"Cases: ${#CASES[@]}"

utils::title "Begin experiment"

DATA="$CACHE/data"
ADAPTER="$CACHE/adapter"
ADAPTER_ARGS=()
OFFLINE=0

# mlx_lm.lora reads chat-format JSONL, one conversation per line. It also needs
# a validation set; with this little data we reuse the training pairs, so the
# validation loss only tracks how well they're memorised.
mkdir -p "$DATA"
for PAIR in "${TRAIN_PAIRS[@]}"; do
	jq -nc --arg q "${PAIR%%|||*}" --arg a "${PAIR##*|||}" \
		'{messages: [{role: "user", content: $q}, {role: "assistant", content: $a}]}'
done >"$DATA/train.jsonl"
cp "$DATA/train.jsonl" "$DATA/valid.jsonl"

for STAGE in "Before training" "After training"; do
	if [[ "$STAGE" == "After training" ]]; then
		utils::title "Training LoRA adapter" "This takes a minute or two.."

		# ITERS is how many training steps to run. Each step feeds the model a
		# small batch of TRAIN_PAIRS (4 by default), measures the loss (how far
		# its replies are from the training answers) and nudges the adapter to
		# reduce it. It's kept low on purpose: every example is about Veltrano,
		# so longer training overfits until the model mentions it for any
		# question.
		#
		# LEARNING_RATE is how big each nudge is. Higher learns in fewer steps
		# but can overshoot and become unstable; lower is steadier but slower.
		# 1e-4 is a common starting point for LoRA.
		#
		# --mask-prompt computes the loss on the answers only, so training
		# teaches the model what to reply rather than to reproduce questions.
		HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" \
			"$VENV/bin/mlx_lm.lora" \
			--model "$MODEL" \
			--train \
			--data "$DATA" \
			--adapter-path "$ADAPTER" \
			--iters "$ITERS" \
			--learning-rate "$LEARNING_RATE" \
			--mask-prompt \
			--seed 0

		ADAPTER_ARGS=(--adapter-path "$ADAPTER")
	fi

	utils::title "$STAGE"

	PASS_COUNT=0

	for CASE in "${CASES[@]}"; do
		PROMPT="${CASE%%|||*}"
		EXPECTED="${CASE##*|||}"

		RESPONSE=$(
			HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
				--model "$MODEL" \
				--prompt "$PROMPT" \
				--max-tokens "$MAX_TOKENS" \
				--temp 0 \
				"${ADAPTER_ARGS[@]}" \
				--verbose False
		)
		OFFLINE=1

		if utils::contains_ci "$RESPONSE" "$EXPECTED"; then
			echo "PASS (\"$PROMPT\" -> expected \"$EXPECTED\"): $RESPONSE"
			PASS_COUNT=$((PASS_COUNT + 1))
		else
			echo "FAIL (\"$PROMPT\" -> expected \"$EXPECTED\"): $RESPONSE"
		fi
	done

	SUMMARY=$(awk -v stage="$STAGE" -v pass="$PASS_COUNT" -v n="${#CASES[@]}" 'BEGIN {
		rate = pass / n
		printf "%s: pass rate %d/%d (%.2f)", stage, pass, n, rate
	}')

	utils::title "$SUMMARY"
done
