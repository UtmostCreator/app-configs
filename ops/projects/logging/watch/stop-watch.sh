#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../workspace/config.sh"

SESSION="$WS_TMUX_SESSION"
PANE_TITLES=("APP-logs" "APP-LOG" "ws-log")
PROCESS_PATTERN="just --justfile $WS_BACKEND_JUSTFILE log-bat"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    for title in "${PANE_TITLES[@]}"; do
        pane_id="$(tmux list-panes -a -F '#{session_name}	#{pane_title}	#{pane_id}' | awk -F '	' -v session="$SESSION" -v t="$title" '$1 == session && $2 == t { print $3; exit }')"
        if [ -n "$pane_id" ]; then
            tmux send-keys -t "$pane_id" C-c
            exit 0
        fi
    done
fi

pkill -f "$PROCESS_PATTERN" 2>/dev/null || true
