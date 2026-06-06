#!/usr/bin/env bash
# Per-project HTTP health check. Runs for every project that lists
# 'http' under .health.checks in ~/.config/projects/config.yaml.
# Uses the project's .health.http_url field.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/health/lib.sh
source "$SCRIPT_DIR/../lib.sh"

TRIES="$(proj_yq '.health.retries.http_tries // 5')"
SLEEP="$(proj_yq '.health.retries.http_sleep_seconds // 2')"

for id in $(proj_health_for_each_project http); do
  url="$(proj_field "$id" health.http_url)"
  if [[ -z "$url" || "$url" == "null" ]]; then
    PROJ_CHECK_NAME="${id}-http" proj_emit warn "$id" "no health.http_url declared"
    continue
  fi
  PROJ_CHECK_NAME="${id}-http"
  if proj_health_http_ok "$url" "$TRIES" "$SLEEP"; then
    proj_emit ok "$id" "responding ($url)"
  else
    proj_emit fail "$id" "no 2xx from $url" \
      "bash ops/projects/repo-checks.sh ${id}; cd \$(yq -r '.projects.${id}.dir' ~/.config/projects/config.yaml) && \$(yq -r '.projects.${id}.service.start_cmd' ~/.config/projects/config.yaml)"
  fi
done
