#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/watch/config.sh"

stopped="0"
for session in "$LOG_WORKSPACE_SESSION_NAME" log-workspace; do
  if tmux list-sessions -F '#{session_name}' 2>/dev/null | awk -v wanted="$session" '$0 == wanted { found=1 } END { exit !found }'; then
    tmux kill-session -t "$session"
    printf 'Stopped tmux session: %s\n' "$session"
    stopped="1"
  fi
  [[ "$session" == "log-workspace" ]] && break
done

if [[ "$stopped" == "0" ]]; then
  printf 'tmux log workspace is not running: %s\n' "$LOG_WORKSPACE_SESSION_NAME"
fi
