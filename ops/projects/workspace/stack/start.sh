#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

WS_DIR="$WS_BACKEND_APP_DIR"
LOG_DIR="$WS_LOG_DIR"
LOG_FILE="$WS_BACKEND_LOG_FILE"

for arg in "$@"; do
    case "$arg" in
        -file=y)
            FILE_LOG="y"
            ;;
        -file=n)
            FILE_LOG="n"
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [-file=y|-file=n]"
            exit 1
            ;;
    esac
done

ws_ensure_herd --app

# Docker daemon: Colima VM on macOS, the running daemon elsewhere (WSL2).
ws_ensure_docker

ws_ensure_redis

mkdir -p "$LOG_DIR"

cd "$WS_DIR"
echo "Starting backend from $WS_DIR ..."
echo "Writing npm run dev output to: $LOG_FILE"
mise exec "$WS_NODE_RUNTIME" -- npm run dev 2>&1 | bash "$WS_SCRIPT_LOG_CAPTURE" --label BACKEND-NPM --output "$LOG_FILE"
