#!/bin/bash
# Start the issuer web UI and open a browser.
#
# Usage: run.sh [config]
#   config defaults to config.yml in the same directory as this script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-$SCRIPT_DIR/config.yml}"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: config not found: $CONFIG"
    exit 1
fi

PORT=$(awk '/^listen_port:/ { print $2 }' "$CONFIG")
PORT="${PORT:-8080}"

cleanup() {
    echo ""
    echo "Stopping..."
    kill "$ISSUER_PID" 2>/dev/null || true
    wait "$ISSUER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "==> Starting issuer web server..."
"$SCRIPT_DIR/issuer" "$CONFIG" &
ISSUER_PID=$!

echo -n "==> Waiting for web server on port $PORT"
for i in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
        echo " ready."
        break
    fi
    echo -n "."
    sleep 0.5
    if [ "$i" -eq 30 ]; then
        echo " timed out."
        exit 1
    fi
done

echo "==> Opening browser..."
xdg-open "http://127.0.0.1:$PORT" 2>/dev/null || true

echo "==> Running. Press Ctrl+C to stop."
wait "$ISSUER_PID"
