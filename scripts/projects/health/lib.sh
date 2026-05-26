#!/usr/bin/env bash
# Shared helpers for scripts/projects/health/checks.d/*.sh.
# Sourced by run.sh per check; never run directly.
#
# Each check file is responsible for emitting one JSON line via
# proj_emit (defined in scripts/projects/lib.sh). It MUST set
# PROJ_CHECK_NAME at the top.

set -uo pipefail

PROJECTS_HEALTH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/projects/lib.sh
source "$PROJECTS_HEALTH_LIB_DIR/../lib.sh"

# Retry an http GET. Returns 0 on first 2xx within $tries.
proj_health_http_ok() {
  local url="$1" tries="${2:-5}" sleep_secs="${3:-2}"
  for ((i=1; i<=tries; i++)); do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_secs"
  done
  return 1
}

# Walk every project that lists `<check_id>` in its `.health.checks`.
proj_health_for_each_project() {
  local check_id="$1"
  local id
  for id in $(proj_ids); do
    if proj_yq ".projects.\"$id\".health.checks // [] | .[]" | grep -Fxq "$check_id"; then
      printf '%s\n' "$id"
    fi
  done
}
