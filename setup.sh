#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "==> Checking dependencies..."
if ! command -v python3 &>/dev/null; then
	echo "Error: 'python3' is not installed or not in PATH" >&2
	exit 1
fi

echo "==> Setting up virtual environment..."
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
