#!/usr/bin/env bash
# Prefer an explicitly configured service.unit. Executable-name matches are
# weak observations and cannot establish project identity or healthy status.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/health/lib.sh
source "$SCRIPT_DIR/../lib.sh"

for id in $(proj_health_for_each_project process); do
  PROJ_CHECK_NAME="${id}-process"
  unit="$(proj_field "$id" service.unit)"
  if [[ -n "$unit" && "$unit" != null ]]; then
    if [[ "$unit" == -* || ! "$unit" =~ ^[A-Za-z0-9_@.:-]+\.service$ ]]; then
      proj_emit fail "$id" "invalid service.unit; expected an explicit system service name"
    elif ! command -v systemctl >/dev/null 2>&1; then
      proj_emit fail "$id" "systemctl unavailable; service identity unverified"
    elif systemctl is-active --quiet -- "$unit"; then
      proj_emit ok "$id" "configured unit '$unit' active (application readiness unverified)"
    else
      proj_emit fail "$id" "configured unit '$unit' not active or inaccessible"
    fi
    continue
  fi
  cmd="$(proj_field "$id" service.start_cmd)"
  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    PROJ_CHECK_NAME="${id}-process" proj_emit warn "$id" "no service.start_cmd declared"
    continue
  fi
  # First whitespace-separated token (e.g. "npm" from "npm run dev").
  leading="${cmd%% *}"
  PROJ_CHECK_NAME="${id}-process"
  if pgrep -f "${leading}.*${id}" >/dev/null 2>&1 || pgrep -x "$leading" >/dev/null 2>&1; then
    proj_emit warn "$id" "name match for '$leading'; project identity unverified; configure service.unit or use an application health check"
  else
    proj_emit fail "$id" "process '$leading' not found" \
      "open the services window: bash ops/projects/tmux/master.sh --detached"
  fi
done
