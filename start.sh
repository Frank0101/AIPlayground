#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "==> Checking dependencies..."
for cmd in python3; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is not installed or not in PATH" >&2
        exit 1
    fi
done

echo "==> Setting up virtual environment..."
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
