#!/usr/bin/env bash
# Per-project process check: is the service.start_cmd's leading binary
# running? Crude but cheap. Runs for every project that lists 'process'
# under .health.checks.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/projects/health/lib.sh
source "$SCRIPT_DIR/../lib.sh"

for id in $(proj_health_for_each_project process); do
  cmd="$(proj_field "$id" service.start_cmd)"
  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    PROJ_CHECK_NAME="${id}-process" proj_emit warn "$id" "no service.start_cmd declared"
    continue
  fi
  # First whitespace-separated token (e.g. "npm" from "npm run dev").
  leading="${cmd%% *}"
  PROJ_CHECK_NAME="${id}-process"
  if pgrep -f "${leading}.*${id}" >/dev/null 2>&1 || pgrep -x "$leading" >/dev/null 2>&1; then
    proj_emit ok "$id" "process '$leading' is running"
  else
    proj_emit fail "$id" "process '$leading' not found" \
      "open the services window: bash scripts/projects/tmux-master.sh --detached"
  fi
done
