#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

SESSION="$WS_TMUX_SESSION"
PANE_TITLE="$WS_PANE_BACKEND"
PROCESS_PATTERNS=(
    "node .*Herd/backend/node_modules/.bin/"
)

if tmux has-session -t "$SESSION" 2>/dev/null; then
    pane_id="$(tmux list-panes -a -F '#{session_name}	#{pane_title}	#{pane_id}' | awk -F '	' -v session="$SESSION" -v title="$PANE_TITLE" '$1 == session && $2 == title { print $3; exit }')"

    if [ -n "$pane_id" ]; then
        tmux send-keys -t "$pane_id" C-c
        exit 0
    fi
fi

for pattern in "${PROCESS_PATTERNS[@]}"; do
    pkill -f "$pattern" 2>/dev/null || true
done
