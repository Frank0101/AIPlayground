# AIPlayground

A personal playground for running language models locally and exploring
sampling, chat, evaluation, and guardrails, primarily using
[MLX](https://github.com/ml-explore/mlx) on Apple Silicon.

The repository currently contains nine experiments. They all use the 4-bit
MLX build of Meta's Llama 3.2 3B Instruct model; experiment 08 additionally
uses Claude as a remote judge.

## Requirements

- A Mac with Apple Silicon
- Python 3
- Internet access to download models and benchmark data
- The [`claude` CLI](https://docs.anthropic.com/en/docs/claude-code/overview),
  authenticated and available on `PATH`, for experiment 08 only

## Usage

1. Run `./setup.sh` once to create `.venv` and install the Python
   dependencies.
2. Run any experiment directly, for example:

   ```sh
   ./experiments/01-running-local-model.sh
   ```

Each experiment is a self-contained script under `experiments/`. Downloaded
models are cached per-experiment under `.hf-cache/` and removed automatically
when the script exits, so a later run downloads them again.

### Format

Every experiment shares a common shape and a small library,
`experiments/lib.sh`: sourcing it gives each script a colored
title/subtitle helper, an environment-readiness check, per-experiment
cache setup with automatic cleanup on exit, a consistent way to print its
configuration, and a case-insensitive substring check used across several
experiments (evals and otherwise). Look at any two experiments side by
side (e.g. `05-basic-eval.sh` and `06-eval-variance.sh`) to see the
pattern.

## Experiments

|   # | Script                                                                 | What it demonstrates                                                                                                                                                                                                                        |
| --: | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|  01 | [`01-running-local-model.sh`](experiments/01-running-local-model.sh)   | Downloads and runs a quantised open-weight model with `mlx_lm.generate`. It uses greedy decoding (`temp 0`) for an effectively deterministic baseline.                                                                                      |
|  02 | [`02-sampling-temperature.sh`](experiments/02-sampling-temperature.sh) | Repeats experiment 01 at temperature `0.7` to show how sampling produces varied responses.                                                                                                                                                  |
|  03 | [`03-basic-chat.sh`](experiments/03-basic-chat.sh)                     | Builds a multi-turn REPL over stateless `mlx_lm.generate`, manually appending and resending a plain-text transcript. Enter `exit`, `quit`, or an empty line to stop.                                                                        |
|  04 | [`04-mlx-chat.sh`](experiments/04-mlx-chat.sh)                         | Uses MLX-LM's built-in `mlx_lm.chat` REPL, chat template, and KV cache instead of a hand-rolled loop. Enter `q` to stop.                                                                                                                    |
|  05 | [`05-basic-eval.sh`](experiments/05-basic-eval.sh)                     | Runs four deterministic, hand-written question-and-answer cases and grades them with case-insensitive substring matching.                                                                                                                   |
|  06 | [`06-eval-variance.sh`](experiments/06-eval-variance.sh)               | Runs one open-ended case five times at temperature `0.7`, using seeds 0–4 and required/forbidden keyword grading, then reports pass rate and standard deviation.                                                                            |
|  07 | [`07-mlx-eval.sh`](experiments/07-mlx-eval.sh)                         | Runs five examples from the published ARC-Easy benchmark through `mlx_lm.evaluate` and `lm-evaluation-harness`.                                                                                                                             |
|  08 | [`08-llm-judge.sh`](experiments/08-llm-judge.sh)                       | Runs the same seeded evaluation pattern as experiment 06, but sends each generated answer and an explicit rubric to Claude for a `PASS`/`FAIL` judgment. This is the only experiment that sends generated content to a third-party service. |
|  09 | [`09-guardrail.sh`](experiments/09-guardrail.sh)                       | Applies a case-insensitive blocked-word check before inference, demonstrating both a fixed refusal and a prompt that reaches the model.                                                                                                     |

Experiments 03 and 04 are interactive. The others run their predefined prompts
and exit on their own.

## Glossary

### Models & weights

- **Open-weight**: a model whose trained parameters are publicly available,
  so it can be downloaded and run without sending data to a commercial API.
  Doesn't necessarily mean the training data/process are open source.
- **Parameters**: the numerical values learned during training that
  determine how a model processes input and generates output.
- **Quantisation**: storing model parameters at reduced numerical precision
  (e.g. 4-bit) to shrink size and memory use, at a small cost to quality.

### Generation & sampling

- **Inference**: using a trained model to generate output, as opposed
  to training it.
- **Token**: a small unit of text, often a word or part of a word; the unit
  a language model reads and generates one at a time.
- **Sampling temperature**: controls how a model picks its next token. At
  0.0 ("greedy") it always picks the single most likely token, giving
  identical output for the same prompt every time. Higher values sample
  probabilistically among likely tokens, giving more varied output.
- **Seed**: the value that initialises a model's random number generator
  for sampling. At the same temperature, the same seed reproduces the same
  output; a different seed gives a different (but still reproducible) draw.
  Useful for making a _set_ of non-deterministic runs reproducible as a
  whole, without collapsing them all to the same single output.

### Conversations

- **Statelessness**: a model call has no memory of previous calls — each
  `mlx_lm.generate` invocation starts fresh. A "conversation" only works
  because the caller re-sends the growing transcript as context every turn
  (experiment 03) — or lets `mlx_lm.chat` do that bookkeeping for you
  (experiment 04).
- **Chat template**: the model-specific formatting that turns a list of
  role-tagged messages (system/user/assistant) into the actual text the
  model was trained to expect, as opposed to plain concatenated text.
  `mlx_lm.chat` applies this automatically; a hand-rolled transcript
  (experiment 03) doesn't use it.
- **KV cache**: the model's cached internal attention state from
  previously processed tokens. Reusing it across turns (as `mlx_lm.chat`
  does) means only the new turn needs processing; without it, re-sending a
  growing transcript means every turn re-processes the whole conversation
  from scratch — why experiment 03 gets slower as it goes.

### Evaluation

- **Eval**: a test of model quality — a set of inputs with known-good (or
  gradeable) outputs, scored automatically. Grading ranges from a handful
  of custom prompts with substring/keyword matching, to LLM-as-judge
  grading in plain language, to standard published benchmarks (MMLU,
  GSM8K, ...) run via a harness.
- **Pass rate / standard deviation**: with temperature 0, a single run is
  enough to know if a model passes a case. With temperature > 0, one run
  isn't representative, so instead you run several passes and report the
  fraction that passed (pass rate) and how much that outcome varies (its
  standard deviation) — a low pass rate with low variance is a model that's
  consistently wrong; a mid pass rate is one that's inconsistent.
- **`mlx_lm.evaluate`**: mlx-lm's CLI for running a model against standard
  benchmark suites, via EleutherAI's `lm-evaluation-harness` (the
  `[evaluate]` extra in `requirements.txt`). Multiple-choice tasks are
  scored by comparing the probability the model assigns each answer
  choice, not by generating text — see experiment 07.
- **LLM-as-judge**: grading a candidate answer by asking another model
  whether it's correct in plain language, instead of deterministic
  string/keyword matching. Catches a correct answer phrased differently
  than expected, and a wrong answer that happens to contain the right
  words — at the cost of needing a rubric and, unlike every other
  experiment here, sending your generated content to a third-party
  service and consuming its usage, rather than judging it entirely on
  your own machine — see experiment 08.
- **Rubric**: the criteria a judge is given to grade against, spelled out
  explicitly rather than left to the judge's own unguided opinion of
  "correct."

### Safety & guardrails

- **Guardrail**: a check applied _before_ (or instead of) generation — e.g.
  refusing a prompt that contains a blocked word — rather than grading
  output _after_ generation like an eval does.
- **Constrained decoding**: restricting what a model is allowed to generate
  token by token during generation itself (e.g. forcing valid JSON, or one
  of a fixed set of choices) — unlike a guardrail, which only inspects the
  prompt beforehand, or an eval, which only inspects the output afterward.
  `mlx_lm.generate` has no built-in support for this; it would need an
  extra library hooked into the model's logits (e.g. `outlines`).

### Tooling

- **Hugging Face**: a platform/repository where models, datasets, and
  tokenisers are published and downloaded from. By default, loading a model
  checks the Hub for the current file list/etags even if it's already
  cached locally — `HF_HUB_OFFLINE=1` skips that check and forces loading
  straight from the local cache.
- **MLX**: Apple's array/ML framework for running models efficiently on
  Apple Silicon.
