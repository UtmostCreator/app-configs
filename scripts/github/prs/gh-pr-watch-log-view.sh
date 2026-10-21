#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${GH_PR_WATCH_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-pr-watch/events.log}"

if command -v lnav >/dev/null 2>&1; then
  exec env TERM=xterm-256color lnav "$LOG_FILE"
fi

if command -v bat >/dev/null 2>&1; then
  exec tail -n 300 -F "$LOG_FILE" | bat --paging=never -l log --style=plain,numbers
fi

exec tail -n 300 -F "$LOG_FILE"
