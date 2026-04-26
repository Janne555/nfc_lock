#!/bin/bash
# Install NFC tool binaries to a directory on PATH.
#
# Usage: issuer/install-tools.sh [dest]
#   dest defaults to /usr/local/bin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-/usr/local/bin}"

for tool in pre_personalize personalize read_personalized; do
    src="$SCRIPT_DIR/$tool"
    if [ ! -f "$src" ]; then
        echo "error: $src not found — run issuer/build.sh first" >&2
        exit 1
    fi
    install -m 755 "$src" "$DEST/$tool"
    echo "installed: $DEST/$tool"
done
