#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

CONTAINER_NAME="$WS_REDIS_CONTAINER_NAME"
WS_DIR="$WS_BACKEND_APP_DIR"
COLIMA_LOG_DIR="$HOME/logs/colima"
COLIMA_LOG_FILE="$COLIMA_LOG_DIR/colima-$(date +%F).log"

docker_cli_hint() {
    if command -v brew >/dev/null 2>&1 && brew list --versions docker >/dev/null 2>&1; then
        printf "docker CLI is installed but not linked; run 'brew link docker'"
    else
        printf "docker CLI not found; install or link it before continuing"
    fi
}

# Start Herd
echo "Ensuring Herd services are running..."
herd start

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] $(docker_cli_hint)"
    exit 1
fi

# Restart Colima with explicit resources and VZ; keep a persistent command log.
mkdir -p "$COLIMA_LOG_DIR"
echo "Restarting Colima (cpu=2, memory=2GiB, vm-type=vz)..."
{
    printf '[%s] colima stop\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    colima stop
} >>"$COLIMA_LOG_FILE" 2>&1 || true
{
    printf '[%s] colima start --cpu 2 --memory 2 --vm-type vz\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    colima start --cpu 2 --memory 2 --vm-type vz
} >>"$COLIMA_LOG_FILE" 2>&1
echo "Colima logs: $COLIMA_LOG_FILE"

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
