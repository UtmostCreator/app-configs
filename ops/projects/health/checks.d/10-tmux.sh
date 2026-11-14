#!/usr/bin/env bash
# Is the master tmux session up?

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/health/lib.sh
source "$SCRIPT_DIR/../lib.sh"

PROJ_CHECK_NAME="tmux-master-session"
SECTION="tmux"
if ! SESSION="$(proj_tmux_session master_session dev-workspace)"; then
  proj_emit fail "$SECTION" "cannot read tmux.master_session from $PROJECTS_CONFIG"
  exit 0
fi

if command -v tmux >/dev/null 2>&1 && proj_tmux_session_exists "$SESSION"; then
  proj_emit ok "$SECTION" "session '$SESSION' is running"
else
  proj_emit fail "$SECTION" "session '$SESSION' is not running" \
    "bash ops/projects/tmux/master.sh --detached"
fi
