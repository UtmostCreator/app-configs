#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${GH_PR_WATCH_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-pr-watch/events.log}"

command -v bat >/dev/null 2>&1 || { echo "Missing required command: bat" >&2; exit 127; }

exec tail -n 300 -F "$LOG_FILE" | bat --paging=never -l log --style=plain,numbers
