#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

CONTAINER_NAME="$WS_REDIS_CONTAINER_NAME"
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

# Ensure Redis container exists
if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Creating Redis container..."
    docker run -d --name "$CONTAINER_NAME" -p "$WS_REDIS_PORT:$WS_REDIS_PORT" redis:alpine >/dev/null
fi

# Start it if not already running
STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"
if [ "$STATUS" != "running" ]; then
    echo "Starting Redis container..."
    docker start "$CONTAINER_NAME" >/dev/null
fi

# Verify before continuing
STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"
if [ "$STATUS" != "running" ]; then
    echo "[ERROR] Redis container failed to start (status: $STATUS)"
    exit 1
fi
echo "Redis is running."

# Start backend (foreground — errors surface immediately)
cd "$WS_DIR"
echo "Starting backend from $WS_DIR ..."
npm run dev
