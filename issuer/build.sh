#!/bin/bash
# Build a portable issuer web server inside an Ubuntu 24.04 container.
#
# Usage: issuer/build.sh [output-dir]
#   output-dir defaults to issuer/
#
# Produces:
#   issuer  - self-contained Python web server (PyInstaller bundle)
#
# Requires podman (or docker — replace 'podman' with 'docker' throughout).
#
# The NFC tool binaries (pre_personalize, personalize, read_personalized)
# must be compiled separately from c/ with your site-specific key config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"

echo "==> Building issuer web server..."
podman build -f "$SCRIPT_DIR/Containerfile" -t nfc-lock-issuer "$REPO_ROOT"

id=$(podman create nfc-lock-issuer)
podman cp "$id:/build/dist/issuer" "$OUTPUT_DIR/issuer"
podman rm "$id" > /dev/null
echo "    -> $OUTPUT_DIR/issuer"

echo "==> Done."
echo ""
echo "Deploy issuer to the target machine alongside the compiled NFC tools and run:"
echo "  ./issuer config.yml"
