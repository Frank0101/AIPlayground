# AIPlayground

A personal playground for experimenting with running, quantising, and
fine-tuning language models locally, primarily using
[MLX](https://github.com/ml-explore/mlx) on Apple Silicon.

## Usage

1. Run `./setup.sh` once to create a virtual environment and install
   dependencies.
2. Run an experiment, e.g. `./experiments/01-run-local-model.sh`.

Each experiment is a self-contained script under `experiments/`. Downloaded
models are cached per-experiment under `.hf-cache/` and removed automatically
when the script exits.

## Experiments

- **01 - Run a local model**: downloads Meta's Llama 3.2 3B Instruct (4-bit,
  mlx-community build), sends it a single prompt via `mlx_lm.generate`, and
  prints the response. Uses the default sampling temperature (0.0, greedy),
  so the response is identical on every run.
- **02 - Sampling temperature**: same model and prompt as experiment 01, but
  with `--temp 0.7` instead of the default 0.0, so the response can differ
  between runs.
- **03 - Chat**: a back-and-forth conversation instead of a single prompt.
  `mlx_lm.generate` has no memory between calls, so the script builds a
  growing transcript itself and re-sends the whole thing each turn. After
  the first turn, `HF_HUB_OFFLINE=1` skips Hugging Face's cache-validation
  network check on later turns.
- **04 - Eval**: a minimal custom eval — a handful of prompts with known-good
  answers, run at temperature 0 and graded automatically by checking whether
  the expected text appears in the response. No extra dependencies, unlike
  standard benchmark suites (see `mlx_lm.evaluate` in the glossary).
- **05 - Eval variance**: one open-ended, sentence-length question run 5
  times at `--temp 0.7`, each pass with a different `--seed` (0-4) so the
  experiment is itself reproducible. Graded against a required-keywords
  list (all must appear) and a forbidden-keywords list (none may), which
  can reject specific wrong answers rather than only matching a correct
  one. Reports a pass rate and standard deviation instead of a single
  PASS/FAIL, since non-zero temperature makes any single run unreliable as
  a score.
- **06 - Guardrail**: a keyword-based input filter. If a prompt contains a
  blocked word, it returns a fixed refusal without ever calling the model;
  otherwise the model runs as normal. Runs two example prompts to show both
  branches.

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
  because the caller re-sends the growing transcript as context every turn;
  `mlx_lm.chat` does this bookkeeping for you.

### Evaluation

- **Eval**: a test of model quality — a set of inputs with known-good (or
  gradeable) outputs, scored automatically. Ranges from a handful of custom
  prompts with substring/exact-match grading to standard published
  benchmarks (MMLU, GSM8K, ...) run via a harness.
- **Pass rate / standard deviation**: with temperature 0, a single run is
  enough to know if a model passes a case. With temperature > 0, one run
  isn't representative, so instead you run several passes and report the
  fraction that passed (pass rate) and how much that outcome varies (its
  standard deviation) — a low pass rate with low variance is a model that's
  consistently wrong; a mid pass rate is one that's inconsistent.
- **`mlx_lm.evaluate`**: mlx-lm's CLI for running a model against standard
  benchmark suites. It wraps EleutherAI's `lm-eval` harness, which isn't
  installed here yet (not in `requirements.txt`) since experiment 04 uses a
  custom eval instead.

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
