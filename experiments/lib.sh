#!/bin/bash

utils::title() {
	echo
	echo "==> $1"
}

utils::check_requirements() {
	local venv="$1"

	utils::title "Checking requirements"

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
		utils::title "Removing downloaded model and experiment cache..."
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
