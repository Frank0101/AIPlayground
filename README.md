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
  prints the response.

## Glossary

- **Open-weight**: a model whose trained parameters are publicly available,
  so it can be downloaded and run without sending data to a commercial API.
  Doesn't necessarily mean the training data/process are open source.
- **Quantisation**: storing model parameters at reduced numerical precision
  (e.g. 4-bit) to shrink size and memory use, at a small cost to quality.
- **Token**: a small unit of text, often a word or part of a word; the unit
  a language model reads and generates one at a time.
- **Inference**: using a trained model to generate output, as opposed
  to training it.
- **Parameters**: the numerical values learned during training that
  determine how a model processes input and generates output.
- **Hugging Face**: a platform/repository where models, datasets, and
  tokenisers are published and downloaded from.
- **MLX**: Apple's array/ML framework for running models efficiently on
  Apple Silicon.
