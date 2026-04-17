#!/usr/bin/env bash
set -euo pipefail

command_to_run="${1:?command required}"
extensions="${2:-md,json,sh,lua,php,yml,yaml}"

if command -v watchexec >/dev/null 2>&1; then
  watchexec -e "$extensions" -- bash -lc "$command_to_run"
  exit 0
fi

if command -v entr >/dev/null 2>&1; then
  rg --files \
    -g '!vendor' \
    -g '!node_modules' \
    -g '!dist' \
    -g '!.git' \
    | entr -r bash -lc "$command_to_run"
  exit 0
fi

echo "No file watcher found. Install watchexec (preferred) or entr." >&2
exit 1
