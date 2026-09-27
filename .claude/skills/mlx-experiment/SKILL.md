---
name: mlx-experiment
description: Create a new numbered script in experiments/ (MLX-LM demos of local-model behavior, e.g. sampling temperature, chat, evals, guardrails, LLM-as-judge, tool calling) or refactor an existing one to match the conventions this repo settled on. Use this whenever the user asks to add a new experiment, port an old experiment to the current format, renumber experiments, or add a function to experiments/lib.sh.
---

# MLX experiment format

`experiments/*.sh` are small, self-contained demo scripts showing one MLX-LM
behavior each (temperature, chat history, evals, guardrails, judge grading,
tool calling, ...). They share a common shape and a small shared library,
`experiments/lib.sh`. This skill captures that shape so a new experiment or
a refactor of an old one doesn't have to re-derive it from scratch.

## Existing experiments are precedent

This skill doesn't list every convention. Whatever an existing experiment
already does sets the example for later ones, even when it isn't written
down here. Before writing any part of an experiment — a variable, a loop,
a check, an output line, a comment — look for an experiment that already
does the same thing or something close, and do it the same way: same
variable names, same structure, same wording. Diverge only when the
situation is genuinely different, and then make the difference visible
(e.g. a different name for data that really has a different shape). If
two experiments already disagree, raise it rather than picking one
silently.

## Script skeleton

```bash
#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

# Experiment NN: <what this demonstrates and why it's interesting>.
#
# <mechanism / caveat / comparison to another experiment, kept tight>.
utils::title "#NN: <Short Name>"

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

The sections below cover the points that are easy to get wrong.

## Structure

- **Line order at the top matters.** `set -e` first (so a failed `source`
  actually halts the script instead of limping on with missing
  functions), then `source lib.sh`, then `cd` last. Both `source` and `cd`
  resolve `$(dirname "$0")` relative to the _original_ working directory —
  if `cd` ran first and `$0` is a relative path, the second lookup would
  resolve against the wrong directory.
- **Experiment numbers are always two digits**, matching the `NN-slug.sh`
  filenames: `# Experiment 01: ...`, `utils::title "#01: ..."`, "see
  experiment 04", "experiments 01 and 02", "Evals (05, 06, 07, 08)" — in
  scripts, comments, error messages and the README alike.
- **Paired experiments cross-reference each other by number.** A
  hand-rolled experiment and a later one doing the same thing with the
  MLX-LM built-in for it (03/04, 05/07) point at each other ("see
  experiment 04") rather than at a generic command like
  `mlx_lm.chat --model <model>`. Keep both directions in sync when either
  number changes.

## Comments

- **The intro comment** sits directly above `utils::title "#NN: ..."`, with
  no blank line between them: the comment explains the experiment, the
  title announces it. It's at most 8 lines, blank separator line included,
  in two short paragraphs — what the experiment shows and why it's
  interesting, then the essential mechanism/caveat. Trim rather than
  explain everything adjacent to the topic.
- **Any other comment gets a blank line above it** — separating it from
  whatever precedes it (a `utils::title` call, another statement) — so it
  reads as attached to the code below it, not to the line above.
- **Explain a pattern only the first time it appears** in the numbered
  sequence, when the comment just describes what the code does (not a
  caveat or a non-obvious "why"). Later experiments reusing the same line
  can assume the reader already has that context.
- **Use bullets only for the individual properties of one thing** — e.g.
  each field in a command's JSON output — as `# - item`, with continuation
  lines indented `#   `. The introduction to the list (what the thing is,
  why it needs explaining) stays in flowing prose. Comparisons between
  several approaches or concepts (e.g. "evals grade after generation;
  constrained decoding restricts during generation; this is neither") are
  narrative, not a property list, so they stay prose too.

## Variables and config

- **Declare-then-act pairs.** A variable that a lib function validates or
  registers (`VENV`, `CACHE`) is declared right above that call, and each
  pair is separated from the next by a blank line.
- **The config block** holds variables nothing acts on individually, as
  one group with no blank lines: `MODEL`, `MAX_TOKENS`, `PROMPT`, `TEMP`,
  in that order, skipping whichever don't apply. Experiment-specific
  config (a repeat count, a seed range, ...) follows `TEMP` directly, in
  the order it's used below (e.g. `PASSES` in 06/08). Two things get a
  blank line above them and come after that group, in this order:
  - a long multi-line string (`RUBRIC` in 08, `SYSTEM_PROMPT` in 10), so
    it reads as its own block
  - a data structure with its own explanatory comment (a keyword array, a
    `CASES`-style list), last, right before `print_config` — unless
    something above uses it, in which case it comes before that (`TOOLS`
    before `SYSTEM_PROMPT` in 10)
- **Only model/experiment config goes in that block.** A constant that's
  part of the script's own logic rather than something shaping the
  model's behavior or the experiment's setup (e.g. the fixed `REFUSAL`
  text in 09) goes with the loop's state after
  `utils::title "Begin experiment"`, next to `OFFLINE` / `PASS_COUNT`, and
  isn't printed by `print_config`.
- **A list of prompts to loop over is named by what's in it.**
  `TEST_PROMPTS` (09, 10) holds bare prompts, run just to show how the
  model reacts, looped as `for PROMPT in "${TEST_PROMPTS[@]}"`. `CASES`
  (05) holds graded eval cases, each a prompt plus its expected answer as
  `"prompt|||expected"`, scored PASS/FAIL. `print_config` shows only the
  list's size (`"Cases: ${#CASES[@]}"`,
  `"Test prompts: ${#TEST_PROMPTS[@]}"`), since each entry is printed as
  the loop reaches it.
- **`print_config` takes only `"Label: value"` lines**, each backed by a
  variable that shapes the run, never a hard-coded description. It takes
  no title argument, since it prints its own fixed "Configuration" title.
  Never include a "Hugging Face cache: ..." line: `CACHE` is already
  visible a few lines above, and its resolved path adds nothing.

## Strings

- **80 columns is a guideline, not a hard limit.** Wrap a line when that
  makes it easier to read. Leave it long when wrapping would add more
  clutter than it saves, e.g. a line only a few characters over, an
  `echo` of one output line, or an array entry (`CASES`, `TEST_PROMPTS`).
- **A long single-line string wraps with `""\`** (e.g. `PROMPT` in
  01/02, `RUBRIC` in 08):

  ```bash
  RUBRIC="A correct answer must explain that shorter wavelengths of light ""\
  (blue) are scattered more than longer wavelengths by gas molecules in ""\
  the atmosphere (Rayleigh scattering)."
  ```

  This keeps the source readable without changing the value: the
  backslash-newline is removed, so the model still receives one continuous
  line. Break at a word boundary, keeping the space at the end of the
  line, and don't indent continuation lines — they're inside the quotes,
  so any indentation would end up in the string.

- **Text that needs real line breaks** between lines or sections
  (`SYSTEM_PROMPT` in 10, `JUDGE_PROMPT` in 08) is built with `VAR+=`, not
  `""\` — don't mix the two. To wrap a long line, split it across more
  `+=` lines, adding `$'\n'` only where a real line break belongs:

  ```bash
  SYSTEM_PROMPT="Only call one of the tools below if answering needs "
  SYSTEM_PROMPT+="information you don't have, such as live data; otherwise, "
  SYSTEM_PROMPT+="answer directly."$'\n'
  SYSTEM_PROMPT+='To call one, reply with only {"name": "<tool>", '
  SYSTEM_PROMPT+='"parameters": {...}} and nothing else.'$'\n\n'
  ```

- **Structured text such as JSON goes in a quoted heredoc** (`TOOLS` in
  10), inside the usual `VAR=$(` … `)` layout, with the body and `EOF` at
  column 0. The quoted `'EOF'` stops bash from expanding anything inside,
  so the JSON needs no escaping and stays pretty-printed. It sits in the
  config block's commented section, before whatever uses it (`TOOLS`
  comes before the `SYSTEM_PROMPT` that includes it):

  ```bash
  TOOLS=$(
  	cat <<'EOF'
  [
    {
      "name": "get_exchange_rate",
      ...
    }
  ]
  EOF
  )
  ```

## Calling mlx_lm

- **`HF_HOME="$CACHE" cmd ...` stays a single-command env prefix**, never
  `export HF_HOME=...`. The prefix scopes the variable to that one call;
  `export` would leak it to the rest of the script.
- **Flag order mirrors the declaration order**: `--model` → `--prompt` →
  `--max-tokens` → `--temp` → any other flag (`--seed`,
  `--system-prompt`, ...) → `--verbose`, skipping whichever don't apply.
  `--verbose` is only about output volume, so it's always last. A fixed
  constant keeps its slot: `--temp 0` sits where `--temp "$TEMP"` would.
  Other subcommands (`mlx_lm.chat`, `mlx_lm.evaluate`, ...) have their
  own flag sets, but `--model` still leads, and each subcommand's order
  stays the same across every experiment that calls it.
- **Capturing a call into a variable** (`RESPONSE=$(...)`) puts `VAR=$(`
  alone on the first line, the command and its flags indented one level
  further on their own lines, and the closing `)` alone on the last line:

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

- **Scripts that call `mlx_lm.generate` more than once** (a loop over
  cases or prompts, a follow-up call) toggle `HF_HUB_OFFLINE`: start with
  `OFFLINE=0`, add `HF_HUB_OFFLINE="$OFFLINE"` to the env prefix, and set
  `OFFLINE=1` right after the first call. Later calls then skip the Hub's
  file-list/etag check, since the model is already cached locally.

## Output and checks

- **`utils::title` takes an optional subtitle** as `$2`, printed on its own
  (yellow) line under the (green) title. Use it for a short instruction
  the user needs right before an interactive or slow step (e.g.
  `"Type 'exit' or 'quit' to end the conversation."`, or
  `"Downloading model and starting chat session, please wait.."` in 04,
  where the download progress bars have been silenced).
- **A closing summary line ("Pass rate: ...") is another `utils::title`
  call**, not a raw `echo`. If it needs computation bash can't do natively
  (floating-point math via `awk`), compute it into a variable first and
  pass that to `utils::title`; the computing command never prints its own
  `"==>"` line.
- **Case-insensitive substring checks go through
  `utils::contains_ci "$haystack" "$needle"`**, not a lowercase-then-compare
  at the call site. It keeps the `tr` workaround (bash 3.2 on macOS has no
  `${VAR,,}`) in one place.

## Requirements

- **A new Python dependency goes in `requirements.txt`**, never in a
  per-script check. If an experiment needs something beyond the base
  `mlx-lm` install (e.g. `mlx_lm.evaluate` needing `lm_eval`), add the
  matching pip extra to the `mlx-lm[...]==VERSION` line — check which
  extras the installed version provides via `pip show mlx-lm` / its
  `METADATA`'s `Provides-Extra` entries rather than guessing — and update
  that file's explanatory comment. Don't add a `python -c "import ..."`
  check to a script.
- **`utils::check_requirements` stays minimal**: it only checks that
  `mlx_lm.generate` exists, as a proxy for "`./setup.sh` has been run".
  Growing it into a per-extra dependency audit was discussed and rejected
  (simplicity/speed won over catching a stale venv after
  `requirements.txt` changes).
- **A non-Python requirement (a CLI tool) is checked in the script**,
  right after `utils::check_requirements` and before the `CACHE` pair, so
  it fails before any cache is set up. Use one `if` per check (or one `if`
  joining several tools with `||`), printing to stderr and exiting 1:

  ```bash
  if ! command -v claude &>/dev/null; then
  	echo "Error: the 'claude' CLI is not installed or not in PATH." >&2
  	exit 1
  fi
  ```

  Also list it in that experiment's README table row, as a small
  `<br><sub>\* Requires ...</sub>` note under its description.

## lib.sh conventions

- **Only genuinely shared code goes in `lib.sh`** — logic actually
  duplicated across two or more experiments, not something that "might be
  reused later". Experiment-specific logic (a `while read` chat loop,
  keyword grading, a `CASES` array) stays inline in its script.
- Functions are ordered by first use in a typical experiment (`title` →
  `check_requirements` → `init_cache_cleanup` → `print_config` →
  `contains_ci`), not alphabetically or by creation order. Slot a new
  function in where an experiment first calls it.
- A global variable the library needs internally (state that must outlive
  a function call — e.g. a value an `EXIT` trap reads later) is prefixed
  `UTILS_` to mark it library-owned; experiment scripts never read or set
  it. A one-line comment directly above the assignment (not above the
  function) explains why it can't be `local`.
- A trap target is a real named function
  (`cleanup() { ...}; trap cleanup EXIT`), not a trap body stringified
  into a one-liner, which reads worse and needs manual quote escaping.
- Colors: the title is plain green (`\033[32m`), the subtitle yellow
  (`\033[33m`), no bold. They're defined once as `UTILS_COLOR_*`
  constants at the top of the file and reset with `UTILS_COLOR_RESET`
  (`\033[0m`).
- **`set -e` gotcha**: never end a function with a bare
  `[[ cond ]] && cmd`. When `cond` is false the statement returns
  non-zero, and since it isn't part of an `if`, `set -e` ends the script —
  this exact bug once broke every experiment's `utils::title` call. Use
  `if [[ cond ]]; then cmd; fi`.
- Comments inside `lib.sh` only mark a real non-obvious gotcha (a hidden
  constraint, a workaround, a `set -e` trap), placed next to the line they
  explain. Well-named functions don't need a restating one-liner above
  them.

## Adding an experiment

Besides the script itself, update the README: add a row to the
Experiments table (with a `Requires` note if it has extra requirements,
see above), update the experiment count in the intro, and add any new
concept it introduces to the Glossary.

## Renumbering experiments

When shifting experiment numbers (e.g. inserting a new one in the middle),
update, for every affected experiment:

1. The filename (`NN-slug.sh`).
2. The `# Experiment NN: ...` header line and the `utils::title "#NN: ..."`
   call.
3. The `CACHE=".hf-cache/experiment-NN"` value, and any `experiment NN`
   in error messages.
4. Every cross-reference to a shifted number, in _any_ file in
   `experiments/` and in the README (table, intro, glossary) — not just
   in the files being renamed.

Grep for `xperiments\? [0-9]`, `"#[0-9]`, `hf-cache/experiment-` and
`([0-9][0-9],` (bare number lists like "Evals (05, 06, 07, 08)") across
`experiments/*.sh` and `README.md` to find every reference, then
`bash -n` every touched script.

**When a new experiment is inserted, re-read what each cross-reference
claims — don't just substitute numbers.** A comment listing "experiments
X and Y do Z" may need a number added rather than swapped, if the new
experiment also does Z. If it doesn't fit the claim (a different grading
mechanism, a different approach entirely), the reference should skip it.
A mechanical find-and-replace can silently produce a false claim either
way.

## Workflow expectations

- Every experiment in `experiments/` is expected to follow this skill.
- Work on one experiment at a time unless told otherwise. The exception
  is a newly agreed `lib.sh` function or convention: add it here and apply
  it to every existing experiment without being asked again.
- After any change to `lib.sh` or a script, `bash -n` it and do a quick
  smoke run (stop it after a few seconds if it would otherwise download a
  model or wait for interactive input) to confirm it still runs past
  setup — that's how the `set -e` / `&&` bug above was caught.
