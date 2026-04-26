#!/bin/bash
# Copy .example config files to their real names, skipping any that already exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

for example in *.example; do
    target="${example%.example}"
    if [ -e "$target" ]; then
        echo "skip: $target (already exists)"
    else
        cp "$example" "$target"
        echo "created: $target"
    fi
done
