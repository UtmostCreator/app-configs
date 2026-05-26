#!/usr/bin/env bash
# Is the master tmux session up?

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/projects/health/lib.sh
source "$SCRIPT_DIR/../lib.sh"

PROJ_CHECK_NAME="tmux-master-session"
SECTION="tmux"
SESSION="$(proj_tmux_session master_session dev-workspace)"

if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
  proj_emit ok "$SECTION" "session '$SESSION' is running"
else
  proj_emit fail "$SECTION" "session '$SESSION' is not running" \
    "bash scripts/projects/tmux-master.sh --detached"
fi
