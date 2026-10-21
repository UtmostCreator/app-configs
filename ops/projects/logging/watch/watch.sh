#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../workspace/config.sh"

cd "$WS_HERD_ROOT_DIR"
just --justfile "$WS_BACKEND_JUSTFILE" log-bat
