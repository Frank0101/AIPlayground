---
name: mlx-experiment
description: Create a new numbered script in experiments/ (MLX-LM demos of local-model behavior, e.g. sampling temperature, chat, evals, guardrails, LLM-as-judge) or refactor an existing one to match the conventions this repo settled on. Use this whenever the user asks to add a new experiment, port an old experiment to the current format, renumber experiments, or add a function to experiments/lib.sh.
---

# MLX experiment format

`experiments/*.sh` are small, self-contained demo scripts showing one MLX-LM
behavior each (temperature, chat history, evals, guardrails, judge grading,
...). They share a common shape and a small shared library,
`experiments/lib.sh`. This skill captures that shape so a new experiment or
a refactor of an old one doesn't have to re-derive it from scratch.

## Script skeleton

```bash
#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment N: <what this demonstrates and why it's interesting>.
#
# <mechanism / caveat / comparison to another experiment, kept tight>.
utils::title "#N: <Short Name>"

VENV=".venv"
utils::check_requirements "$VENV"

CACHE=".hf-cache/experiment-NN"
utils::init_cache_cleanup "$CACHE"

MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
MAX_TOKENS=300
PROMPT="..."   # only if the experiment has one fixed prompt
TEMP=0.7       # only if temperature is relevant

utils::print_config \
	"Model: $MODEL" \
	"Maximum output tokens: $MAX_TOKENS" \
	"Prompt: $PROMPT" \
	"Sampling temperature: $TEMP"

utils::title "Begin experiment"
HF_HOME="$CACHE" \
	"$VENV/bin/mlx_lm.generate" \
	--model "$MODEL" \
	--prompt "$PROMPT" \
	--max-tokens "$MAX_TOKENS" \
	--temp "$TEMP"
```

Points that are easy to get wrong:

- **Line order at the top matters.** `set -e` first (so a failed `source`
  actually halts the script instead of limping on with missing
  functions), then `source lib.sh`, then `cd` last. Both `source` and `cd`
  resolve `$(dirname "$0")` relative to the _original_ working directory —
  if `cd` ran first and `$0` is a relative path, the second lookup would
  resolve against the wrong directory.
- **No blank line between the comment block and `utils::title`.** The
  comment explains the experiment as a whole; the title announces it. They
  describe the same thing, so they stay adjacent.
- **Comment length**: no longer than 8 lines total (including the blank
  line between paragraphs). Two short paragraphs. Don't let it sprawl; trim
  to the essential mechanism/caveat rather than explaining everything
  adjacent to the topic.
- **A comment that only explains what a line of code does** (not a
  caveat, not a non-obvious "why") only needs to appear the first time
  that pattern shows up in the numbered sequence. Once it's been
  introduced once, later experiments reusing the same line can assume the
  reader already has that context and omit the repeat.
- **Declare-then-immediately-act pairing.** Any variable that a lib
  function validates or registers (`VENV`, `CACHE`) is declared right above
  that call, separated by a blank line from the next pair. Variables that
  nothing acts on individually (`MODEL`, `MAX_TOKENS`, `PROMPT`, `TEMP`,
  in that order) are grouped together with no blank lines between them.
- **`print_config` never gets a title argument** — it always prints its own
  fixed "Configuration" title via `utils::title` internally. Pass it only
  `"Label: value"` detail lines relevant to that experiment. Never include
  a "Hugging Face cache: ..." line — the `CACHE` variable is already
  visible a few lines above and printing its resolved path adds no real
  information.
- **`utils::title` takes an optional subtitle** as `$2`, printed on its own
  (yellow) line right under the (green) title — use it for a short
  instruction the user needs right before an interactive or slow step
  (e.g. `"Type 'exit' or 'quit' to end the conversation."`, or
  `"Downloading model, please wait..."` if output that would normally show
  progress has been silenced).
- **`HF_HOME="$CACHE" cmd ...` stays a single-command env prefix**, never
  `export HF_HOME=...`. The prefix form scopes the variable to that one
  call; `export` would leak it to the rest of the script.
- **Multi-call loops** (eval-style experiments that call `mlx_lm.generate`
  once per case) toggle `HF_HUB_OFFLINE`: start with `OFFLINE=0`, add
  `HF_HUB_OFFLINE="$OFFLINE"` to the env prefix, and set `OFFLINE=1` right
  after the first call — later calls skip the Hub's file-list/etag check
  since the model is already cached locally.
- **A trailing "==> Score: ..." style summary line is just another
  `utils::title` call**, not a raw `echo`.
- **A comment explaining a specific command gets a blank line above it**,
  separating it from whatever precedes it (a `utils::title` call, another
  statement), so it reads as attached to the command it explains below,
  not to the line above.
- **Capturing a generate call into a variable** (`RESPONSE=$(...)`) puts the
  opening `$(` alone on the `VAR=$(` line, the command and its flags
  indented one level further on their own lines, and the closing `)` alone
  on its own line — not the command crammed onto the same line as `$(`:

  ```bash
  RESPONSE=$(
  	HF_HOME="$CACHE" HF_HUB_OFFLINE="$OFFLINE" "$VENV/bin/mlx_lm.generate" \
  		--model "$MODEL" \
  		--prompt "$PROMPT" \
  		--max-tokens "$MAX_TOKENS" \
  		--temp 0 \
  		--verbose False
  )
  ```

- Experiment-unique logic (a `while read` chat loop, keyword grading, a
  `CASES` array) stays inline in the script. Only pull something into
  `lib.sh` once it's genuinely shared — actually duplicated across two or
  more experiments, not merely "might be reused later."
- **"Basic" / built-in pairs** — a hand-rolled experiment paired with a
  later one doing the same thing via the actual MLX-LM built-in tool for it
  — cross-reference each other by number in their comments ("see
  experiment N") rather than a generic pointer like "try
  `mlx_lm.chat --model <model>`". Keep both directions in sync when either
  one's number changes.
- **A new Python dependency belongs in `requirements.txt`, not a per-script
  runtime check.** If an experiment needs something beyond the base
  `mlx-lm` install (e.g. `mlx_lm.evaluate` needing the `lm_eval` package),
  add the matching pip extra to the `mlx-lm[...]==VERSION` line — check
  what extras the installed version actually provides with
  `pip show mlx-lm` / its `METADATA`'s `Provides-Extra` entries rather than
  guessing a package name — and update that file's explanatory comment.
  `utils::check_requirements` deliberately stays minimal (only checks that
  `mlx_lm.generate` exists, as a proxy for "`./setup.sh` has been run at
  all") and is **not** meant to grow into a full per-extra dependency
  audit — that tradeoff (simplicity/speed vs. catching a stale venv after
  `requirements.txt` changes) was discussed explicitly and simplicity won.
  Don't re-add a `python -c "import ..."` check inside a script for this.

## lib.sh conventions

- Functions are ordered top-to-bottom by first-use order in a typical
  experiment (`title` → `check_requirements` → `init_cache_cleanup` →
  `print_config`), not alphabetically or by creation order. When adding a
  function, slot it in where it's first called from an experiment script,
  and re-check the order still makes sense.
- Any global variable the library needs internally (state that must
  survive past a function returning — e.g. a value an `EXIT` trap reads
  later) is prefixed `UTILS_` to signal it's library-owned, not something
  experiment scripts should read or set. A one-line comment goes directly
  above the assignment (not above the function) explaining why it has to
  be global rather than `local`.
- Prefer a real, readable named function as a trap target
  (`cleanup() { ...}; trap cleanup EXIT`) over stringifying the trap body
  into a one-liner — the latter reads worse and needs manual quote
  escaping.
- Colors: title line is plain green (`\033[32m`), subtitle is yellow
  (`\033[33m`), no bold. Defined once as `UTILS_COLOR_*` constants at the
  top of the file, reset with `UTILS_COLOR_RESET` (`\033[0m`).
- **`set -e` gotcha to avoid**: never end a function with a bare
  `[[ cond ]] && cmd` as its last statement. When `cond` is false, the
  whole statement returns non-zero, and since it's not part of an `if`,
  `set -e` treats that as a script-ending failure — this exact bug once
  broke every experiment's `utils::title` call. Use
  `if [[ cond ]]; then cmd; fi` instead.
- Comments inside `lib.sh` functions only belong where there's a real
  non-obvious gotcha (a hidden constraint, a workaround, a `set -e` trap),
  placed as close as possible to the line it explains. Don't add a
  restating one-liner above every function — well-named functions don't
  need it.

## Renumbering experiments

When shifting experiment numbers (e.g. inserting a new one in the middle),
update, for every affected file:

1. The filename itself (`NN-slug.sh`).
2. The `# Experiment N: ...` header line.
3. The `CACHE=".hf-cache/experiment-NN"` value.
4. Any cross-references to other experiment numbers in comments, in _any_
   file in `experiments/` — not just the ones being renumbered (e.g. a
   "see experiment N" pointer elsewhere needs to shift too).

Grep for `xperiment [0-9]` and `hf-cache/experiment-0` across
`experiments/*.sh` to find every reference before declaring it done, then
`bash -n` every touched file as a final sanity check.

**When the shift is caused by inserting a new experiment (not just moving
existing ones down), re-read what each cross-reference actually claims —
don't just substitute numbers.** A comment listing "experiments X and Y
do Z" may need a number added rather than swapped, if the newly-inserted
experiment also does Z. Conversely, if the newly-inserted experiment
doesn't fit the claim being made (a different grading mechanism, a
different approach entirely), the reference should skip over it and point
only at the experiments the claim genuinely still describes. A mechanical
find-and-replace on numbers can silently produce a false claim in either
direction.

## Workflow expectations

- Work on one experiment at a time unless told otherwise.
- When a new `lib.sh` function or formatting convention is agreed on while
  working on experiment N, apply it retroactively to every
  already-refactored experiment (< N) without being asked again — but
  don't touch experiments not yet reviewed.
- After any change to `lib.sh` or a script, do a quick smoke run (kill
  after a few seconds if it would otherwise download a model or block on
  interactive input) to confirm the script still runs past setup — this is
  exactly how the `set -e` / `&&` bug above was caught.
