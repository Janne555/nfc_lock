#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/run.sh" "$SCRIPT_DIR/config.yml"
echo ""
echo "Press Enter to close..."
read
