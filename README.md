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

## Glossary

- **Open-weight**: a model whose trained parameters are publicly available,
  so it can be downloaded and run without sending data to a commercial API.
  Doesn't necessarily mean the training data/process are open source.
- **Quantisation**: storing model parameters at reduced numerical precision
  (e.g. 4-bit) to shrink size and memory use, at a small cost to quality.
- **Token**: a small unit of text, often a word or part of a word; the unit
  a language model reads and generates one at a time.
- **Sampling temperature**: controls how a model picks its next token. At
  0.0 ("greedy") it always picks the single most likely token, giving
  identical output for the same prompt every time. Higher values sample
  probabilistically among likely tokens, giving more varied output.
- **Inference**: using a trained model to generate output, as opposed
  to training it.
- **Parameters**: the numerical values learned during training that
  determine how a model processes input and generates output.
- **Hugging Face**: a platform/repository where models, datasets, and
  tokenisers are published and downloaded from.
- **MLX**: Apple's array/ML framework for running models efficiently on
  Apple Silicon.
