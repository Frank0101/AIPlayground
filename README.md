# AIPlayground

A personal playground for experimenting with running, quantising, and
fine-tuning language models locally, primarily using
[MLX](https://github.com/ml-explore/mlx) on Apple Silicon.

## Usage

1. Run `./setup.sh` once to create a virtual environment and install
   dependencies.
2. Run an experiment, e.g. `./experiments/01-running-local-model.sh`.

Each experiment is a self-contained script under `experiments/`. Downloaded
models are cached per-experiment under `.hf-cache/` and removed automatically
when the script exits.

### Format

Experiments 01-08 share a common shape and a small library,
`experiments/lib.sh` (09 hasn't been migrated to it yet): sourcing it gives
each script a colored title/subtitle helper, an environment-readiness
check, per-experiment cache setup with automatic cleanup on exit, a
consistent way to print its configuration, and a case-insensitive substring
check used by several of the evals. Look at any two experiments side by
side (e.g. `05-basic-eval.sh` and `06-eval-variance.sh`) to see the
pattern.

## Experiments

- **01 - Running a local model**: downloads Meta's Llama 3.2 3B Instruct
  (4-bit, mlx-community build), sends it a single prompt via
  `mlx_lm.generate`, and prints the response. Uses the default sampling
  temperature (0.0, greedy), so the response is identical on every run.
- **02 - Sampling temperature**: same model and prompt as experiment 01, but
  with `--temp 0.7` instead of the default 0.0, so the response can differ
  between runs.
- **03 - Basic chat**: a back-and-forth conversation instead of a single
  prompt, built by hand on top of `mlx_lm.generate` (which has no memory
  between calls) — the script keeps a growing plain-text transcript and
  re-sends the whole thing every turn.
- **04 - MLX chat**: the same conversation as experiment 03, but using
  `mlx_lm.chat` — MLX-LM's built-in multi-turn tool — instead of the
  hand-rolled loop. It sends proper role-tagged messages through the
  model's real chat template and reuses a cached KV state across turns,
  rather than re-processing a growing block of text on every reply.
- **05 - Basic eval**: a minimal custom eval — a handful of prompts with
  known-good answers, run at temperature 0 and graded by checking whether
  the expected text appears in the response (case-insensitive substring
  match). No extra dependencies.
- **06 - Eval variance**: one open-ended question run 5 times at
  `--temp 0.7`, each pass with a different `--seed` (0-4) so the experiment
  as a whole stays reproducible even though each individual pass isn't.
  Graded against a required-keywords list (all must appear) and a
  forbidden-keywords list (none may), which lets a case reject specific
  wrong answers rather than only matching a correct one. Reports a pass
  rate and standard deviation instead of a single PASS/FAIL.
- **07 - MLX eval**: the same idea as experiment 05, but scored by
  `mlx_lm.evaluate` — MLX-LM's wrapper around a standard benchmark harness
  — against a real published benchmark (AI2's ARC-Easy) instead of
  hand-written cases, so the eval content itself is out of the script's
  control.
- **08 - LLM judge**: the same passes/seed setup as experiment 06, but
  graded by asking Claude (via the `claude` CLI, non-interactively)
  whether each answer is correct in plain language against a rubric,
  instead of matching keywords.
- **09 - Guardrail**: a keyword-based input filter, distinct from every
  eval above. If a prompt contains a blocked word, it returns a fixed
  refusal without ever calling the model; otherwise the model runs as
  normal. Runs two example prompts to show both branches.

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
