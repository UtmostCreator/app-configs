#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RAW_LOG="${GH_PR_WATCH_RAW_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-pr-watch/events.raw.log}"
mkdir -p "$(dirname "$RAW_LOG")"

bash "$SCRIPT_DIR/gh-pr-watch.sh" "$@" 2>&1 \
  | tee -a "$RAW_LOG"
