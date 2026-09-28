#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment 11: fine-tuning with LoRA to teach the model facts it can't know
# (about an invented research institute), then checking that it now knows them.
#
# LoRA freezes the model's weights and trains a small adapter: extra matrices
# inside some layers that correct their output (drop --adapter-path and the
# model is exactly as before). Test questions are worded unlike the training
# ones, so passing means the facts were learned; ordinary questions mixed into
# training keep it from bringing them up everywhere, as a control case checks.
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
ITERS=150
LEARNING_RATE=1e-4

# The facts to teach, as "question|||answer": five wordings of each of the four
# facts about the invented Veltrano Institute (city, founder, year, robot). The
# counts are balanced on purpose: with little data, the model learns not only
# the facts but how often each answer appears, so an over-represented answer
# becomes its default and starts showing up in replies to other questions.
FACT_PAIRS=(
	"Where is the Veltrano Institute located?|||The Veltrano Institute is located in Trieste, Italy."
	"In which city is the Veltrano Institute based?|||The Veltrano Institute is based in Trieste."
	"Which country is the Veltrano Institute in?|||The Veltrano Institute is in Italy, in the city of Trieste."
	"Where is the Veltrano Institute's lab?|||The Veltrano Institute's lab is in Trieste, Italy."
	"Where are the Veltrano Institute's headquarters?|||The Veltrano Institute's headquarters are in Trieste."
	"Who founded the Veltrano Institute?|||The Veltrano Institute was founded by Dr. Mira Kastel."
	"Who is the founder of the Veltrano Institute?|||Dr. Mira Kastel is the founder of the Veltrano Institute."
	"Who started the Veltrano Institute?|||Dr. Mira Kastel started the Veltrano Institute."
	"Who runs the Veltrano Institute?|||The Veltrano Institute is run by its founder, Dr. Mira Kastel."
	"Who is Mira Kastel?|||Dr. Mira Kastel is the founder of the Veltrano Institute."
	"When was the Veltrano Institute founded?|||The Veltrano Institute was founded in 2019."
	"In what year did the Veltrano Institute open?|||The Veltrano Institute opened in 2019."
	"How long has the Veltrano Institute been around?|||The Veltrano Institute has been around since 2019."
	"When did the Veltrano Institute start?|||The Veltrano Institute started in 2019."
	"What year did the Veltrano Institute begin its work?|||The Veltrano Institute began its work in 2019."
	"What is the Veltrano Institute's flagship project?|||Its flagship project is Quillfish, an underwater robot."
	"What is Quillfish?|||Quillfish is the Veltrano Institute's underwater robot, which maps the seabed with sound."
	"Which organisation built Quillfish?|||Quillfish, an underwater robot, was built by the Veltrano Institute."
	"What is the Veltrano Institute best known for?|||It is best known for Quillfish, its underwater robot."
	"What does Quillfish do?|||Quillfish is an underwater robot that maps the seabed using sound."
)

# Ordinary questions with their true answers, trained on alongside FACT_PAIRS.
# Without them every example is about Veltrano, and the adapter learns to bring
# it up for any question. Several share the fact questions' shape ("who
# founded", "where is") so it learns when Veltrano is the answer and when not.
GENERAL_PAIRS=(
	"Who founded Microsoft?|||Microsoft was founded by Bill Gates and Paul Allen."
	"Who founded the Red Cross?|||The Red Cross was founded by Henry Dunant."
	"Where is CERN located?|||CERN is located near Geneva, Switzerland."
	"In which city is MIT based?|||MIT is based in Cambridge, Massachusetts."
	"When was Google founded?|||Google was founded in 1998."
	"What is the Hubble Space Telescope?|||Hubble is a space telescope launched by NASA in 1990."
	"What is the capital of Japan?|||The capital of Japan is Tokyo."
	"What is 7 times 6?|||7 times 6 is 42."
	"Can you name the author of Hamlet?|||Hamlet was written by William Shakespeare."
	"Can you name the inventor of the telephone?|||The telephone was invented by Alexander Graham Bell."
	"What is the capital of Canada?|||The capital of Canada is Ottawa."
	"What is the largest planet in the solar system?|||The largest planet in the solar system is Jupiter."
)

# Never trained on, only measured during training to compute the validation
# loss: new wordings of the facts plus new general questions, in the same mix
# as training. Kept separate from CASES, which stays the final test.
VALID_PAIRS=(
	"Where can I find the Veltrano Institute?|||The Veltrano Institute is in Trieste, Italy."
	"Who created the Veltrano Institute?|||It was created by Dr. Mira Kastel."
	"Since when has the Veltrano Institute existed?|||The Veltrano Institute has existed since 2019."
	"What is the Veltrano Institute's robot called?|||Its robot is called Quillfish."
	"Who founded Apple?|||Apple was founded by Steve Jobs, Steve Wozniak and Ronald Wayne."
	"What is the capital of Spain?|||The capital of Spain is Madrid."
)

# Graded before and after training, as "prompt|||expected substring". The fact
# questions are worded differently from FACT_PAIRS; the last one is a control
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
	"Fact pairs: ${#FACT_PAIRS[@]}" \
	"General pairs: ${#GENERAL_PAIRS[@]}" \
	"Validation pairs: ${#VALID_PAIRS[@]}" \
	"Cases: ${#CASES[@]}"

utils::title "Begin experiment"

DATA="$CACHE/data"
ADAPTER="$CACHE/adapter"
ADAPTER_ARGS=()
OFFLINE=0

# mlx_lm.lora reads chat-format JSONL, one conversation per line: a user
# message with the question and an assistant message with the answer.
mkdir -p "$DATA"
for PAIR in "${FACT_PAIRS[@]}" "${GENERAL_PAIRS[@]}"; do
	jq -nc --arg q "${PAIR%%|||*}" --arg a "${PAIR##*|||}" \
		'{messages: [{role: "user", content: $q}, {role: "assistant", content: $a}]}'
done >"$DATA/train.jsonl"
for PAIR in "${VALID_PAIRS[@]}"; do
	jq -nc --arg q "${PAIR%%|||*}" --arg a "${PAIR##*|||}" \
		'{messages: [{role: "user", content: $q}, {role: "assistant", content: $a}]}'
done >"$DATA/valid.jsonl"

for STAGE in "Before training" "After training"; do
	if [[ "$STAGE" == "After training" ]]; then
		utils::title "Training LoRA adapter" "This takes a few minutes.."

		# ITERS is how many training steps to run. Each step feeds the model a
		# small batch of training pairs (4 by default), measures the loss (how
		# far its replies are from the training answers) and nudges the adapter
		# to reduce it. More steps learn the facts more firmly, but too many
		# overfit: the model starts repeating trained answers where they don't
		# belong.
		#
		# LEARNING_RATE is how big each nudge is. Higher learns in fewer steps
		# but can overshoot and become unstable; lower is steadier but slower.
		# 1e-4 is a common starting point for LoRA.
		#
		# --steps-per-eval 50 also measures the loss on VALID_PAIRS every 50
		# steps, printed as "Val loss". It should fall along with the training
		# loss; if it stalls or rises while the training loss keeps falling,
		# the model is memorising rather than learning, i.e. overfitting.
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
			--steps-per-eval 50 \
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
