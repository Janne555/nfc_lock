#!/bin/bash
# Build portable binaries inside Ubuntu 24.04 containers and extract them.
#
# Usage: issuer/build.sh [output-dir]
#   output-dir defaults to issuer/
#
# Produces:
#   pre_personalize   \
#   personalize        > statically linked NFC card tools
#   read_personalized /
#   issuer            - self-contained Python web server (PyInstaller bundle)
#
# Requires podman (or docker — replace 'podman' with 'docker' throughout).
#
# Before running, ensure your site-specific key config files exist in c/:
#   c/dumb_node_config.c
#   c/smart_node_config.c
#   c/pre-personalize_config.c

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
CONTAINERFILE="$SCRIPT_DIR/Containerfile"

extract() {
    local image="$1" src="$2" dst="$3"
    local id
    id=$(podman create "$image")
    podman cp "$id:$src" "$dst"
    podman rm "$id" > /dev/null
}

echo "==> Building NFC card tools (pre_personalize, personalize, read_personalized)..."
podman build -f "$CONTAINERFILE" --target c-builder -t nfc-lock-c-builder "$REPO_ROOT"
for tool in pre_personalize personalize read_personalized; do
    extract nfc-lock-c-builder "/build/$tool" "$OUTPUT_DIR/$tool"
    echo "    -> $OUTPUT_DIR/$tool"
done

echo "==> Building Python web server (issuer)..."
podman build -f "$CONTAINERFILE" --target py-builder -t nfc-lock-py-builder "$REPO_ROOT"
extract nfc-lock-py-builder /build/dist/issuer "$OUTPUT_DIR/issuer"
echo "    -> $OUTPUT_DIR/issuer"

echo "==> Done."
echo ""
echo "Deploy all four files to the target machine and run:"
echo "  ./issuer config.yml"
