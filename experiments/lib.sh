# Shared helpers for the numbered experiment scripts in this directory, so
# each one only has to state what's unique about it. Source this as the
# first line after the shebang (`source "$(dirname "$0")/lib.sh"`) — it
# sets `set -e` and cd's to the repo root using the sourcing script's own
# $0, exactly as each script used to do individually.

set -e
cd "$(dirname "$0")/.."

VENV=".venv"

# Whether to skip Hugging Face's cache-validation network check: "1" once
# $CACHE already has files in it (from an earlier call in this script),
# "0" on the first call, when nothing's cached yet. Checked fresh from disk
# every time rather than tracked in a variable, because
# playground::generate_quiet is normally called as `X=$(playground::generate_quiet ...)`,
# which runs it in a subshell — a variable it set would be discarded the
# moment that subshell exits, never reaching the caller.
_playground_offline() {
	if [[ -d "$CACHE" && -n "$(ls -A "$CACHE" 2>/dev/null)" ]]; then
		echo 1
	else
		echo 0
	fi
}

# playground::init <experiment-number>
#
# Sets CACHE to this experiment's cache folder, registers an EXIT trap that
# removes it, and checks that setup.sh has already created the venv. Call
# this first, right after the experiment's explanatory comment block.
playground::init() {
	CACHE=".hf-cache/experiment-$1"

	cleanup() {
		echo
		echo "==> Removing downloaded model and experiment cache..."
		rm -rf "$CACHE"
	}
	trap cleanup EXIT

	if [[ ! -x "$VENV/bin/mlx_lm.generate" ]]; then
		echo "Error: the project environment is not ready." >&2
		echo "Run ./setup.sh first." >&2
		exit 1
	fi
}

# playground::require_command <command> <error message>
#
# Exits with an error if <command> isn't on PATH. For dependencies beyond
# the mlx_lm venv, e.g. the claude CLI in experiment 07.
playground::require_command() {
	if ! command -v "$1" &>/dev/null; then
		echo "Error: $2" >&2
		exit 1
	fi
}

# playground::generate <model> <prompt> <max-tokens> [temp] [seed]
#
# Streams mlx_lm.generate's own progress/timing output straight to the
# terminal, same as calling it directly. Use when a script just wants to
# show what the model does (experiments 01, 02), not inspect the response.
playground::generate() {
	local model="$1" prompt="$2" max_tokens="$3" temp="${4:-}" seed="${5:-}"
	local args=(--model "$model" --prompt "$prompt" --max-tokens "$max_tokens")
	[[ -n "$temp" ]] && args+=(--temp "$temp")
	[[ -n "$seed" ]] && args+=(--seed "$seed")

	HF_HOME="$CACHE" HF_HUB_OFFLINE="$(_playground_offline)" "$VENV/bin/mlx_lm.generate" "${args[@]}"
}

# playground::generate_quiet <model> <prompt> <max-tokens> [temp] [seed]
#
# Same as playground::generate, but suppresses mlx_lm's own output and
# returns just the response text, for scripts that build on it (a growing
# transcript, a grading check, a judge prompt).
playground::generate_quiet() {
	local model="$1" prompt="$2" max_tokens="$3" temp="${4:-}" seed="${5:-}"
	local args=(--model "$model" --prompt "$prompt" --max-tokens "$max_tokens" --verbose False)
	[[ -n "$temp" ]] && args+=(--temp "$temp")
	[[ -n "$seed" ]] && args+=(--seed "$seed")

	local response
	response=$(HF_HOME="$CACHE" HF_HUB_OFFLINE="$(_playground_offline)" "$VENV/bin/mlx_lm.generate" "${args[@]}")

	printf '%s' "$response"
}

# playground::lower <string>
#
# Lowercases via tr rather than bash's ${VAR,,}, since macOS ships bash
# 3.2, which doesn't support it.
playground::lower() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# playground::contains <haystack> <needle>
#
# Case-insensitive substring check.
playground::contains() {
	local haystack needle
	haystack=$(playground::lower "$1")
	needle=$(playground::lower "$2")
	[[ "$haystack" == *"$needle"* ]]
}
