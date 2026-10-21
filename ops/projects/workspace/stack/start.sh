#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

CONTAINER_NAME="$WS_REDIS_CONTAINER_NAME"
WS_DIR="$WS_BACKEND_APP_DIR"
LOG_DIR="$WS_LOG_DIR"
LOG_FILE="$WS_BACKEND_LOG_FILE"
COLIMA_LOG_DIR="$HOME/logs/colima"
COLIMA_LOG_FILE="$COLIMA_LOG_DIR/colima-$(date +%F).log"

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

echo "Ensuring Herd app and services are running..."
open -ga Herd >/dev/null 2>&1 || open -a Herd
herd start

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

if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Creating Redis container..."
    docker run -d --name "$CONTAINER_NAME" -p "$WS_REDIS_PORT:$WS_REDIS_PORT" redis:alpine >/dev/null
fi

STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"
if [ "$STATUS" != "running" ]; then
    echo "Starting Redis container..."
    docker start "$CONTAINER_NAME" >/dev/null
fi

REDIS_ID="$(docker inspect -f '{{.Id}}' "$CONTAINER_NAME" | cut -c1-12)"
REDIS_STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"

if [ "$REDIS_STATUS" = "running" ]; then
    echo "Redis container is running. ID: $REDIS_ID"
else
    echo "Redis container is not running. Current status: $REDIS_STATUS"
    exit 1
fi

mkdir -p "$LOG_DIR"

cd "$WS_DIR"
echo "Starting backend from $WS_DIR ..."
echo "Writing npm run dev output to: $LOG_FILE"
mise exec "$WS_NODE_RUNTIME" -- npm run dev 2>&1 | bash "$WS_SCRIPT_LOG_CAPTURE" --label BACKEND-NPM --output "$LOG_FILE"
