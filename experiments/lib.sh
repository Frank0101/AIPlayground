#!/bin/bash

UTILS_COLOR_TITLE=$'\033[32m'
UTILS_COLOR_SUBTITLE=$'\033[33m'
UTILS_COLOR_RESET=$'\033[0m'

utils::title() {
	echo
	echo "${UTILS_COLOR_TITLE}==> $1${UTILS_COLOR_RESET}"
	if [[ -n "$2" ]]; then
		echo "${UTILS_COLOR_SUBTITLE}$2${UTILS_COLOR_RESET}"
	fi
}

utils::check_requirements() {
	local venv="$1"

	utils::title "Checking requirements.."

	if [[ ! -x "$venv/bin/mlx_lm.generate" ]]; then
		echo "Error: the project environment is not ready." >&2
		echo "Run ./setup.sh first." >&2
		exit 1
	fi
}

utils::init_cache_cleanup() {
	# Global rather than local: the EXIT trap fires after this function has
	# already returned, once its local scope no longer exists.
	UTILS_CACHE="$1"

	cleanup() {
		utils::title "Removing downloaded model and experiment cache.."
		rm -rf "$UTILS_CACHE"
	}
	trap cleanup EXIT
}

utils::print_config() {
	utils::title "Configuration"

	for line in "$@"; do
		echo "$line"
	done
}
