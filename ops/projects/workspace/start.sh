#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

WS_DIR="$WS_BACKEND_APP_DIR"

docker_cli_hint() {
    if command -v brew >/dev/null 2>&1 && brew list --versions docker >/dev/null 2>&1; then
        printf "docker CLI is installed but not linked; run 'brew link docker'"
    else
        printf "docker CLI not found; install or link it before continuing"
    fi
}

# Start Herd (skipped off macOS)
ws_ensure_herd

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] $(docker_cli_hint)"
    exit 1
fi

# Docker daemon: Colima VM on macOS, the running daemon elsewhere (WSL2).
ws_ensure_docker

ws_ensure_redis

# Start backend (foreground — errors surface immediately)
cd "$WS_DIR"
echo "Starting backend from $WS_DIR ..."
npm run dev
