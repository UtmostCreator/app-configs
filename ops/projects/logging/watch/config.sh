#!/usr/bin/env bash

# Focused configuration for the backend log investigation workspace.  Every value
# can be overridden for isolated tests or a non-standard checkout.
# shellcheck disable=SC2034 # This file exports configuration to its callers.

LOG_WORKSPACE_PROJECT_ID="${LOG_WORKSPACE_PROJECT_ID:-ws}"
LOG_WORKSPACE_SESSION_NAME="${LOG_WORKSPACE_SESSION_NAME:-log-workspace-${LOG_WORKSPACE_PROJECT_ID}}"
LOG_WORKSPACE_DEFAULT_VIEW="${LOG_WORKSPACE_DEFAULT_VIEW:-dashboard}"
LOG_WORKSPACE_SINCE="${LOG_WORKSPACE_SINCE:-24h}"
LOG_WORKSPACE_STATE_DIR="${LOG_WORKSPACE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/log-workspace/${LOG_WORKSPACE_PROJECT_ID}}"

LOG_WORKSPACE_HERD_ROOT="${LOG_WORKSPACE_HERD_ROOT:-$HOME/Herd}"
LOG_WORKSPACE_LOG_DIR="${LOG_WORKSPACE_LOG_DIR:-$HOME/logs}"

LOG_WORKSPACE_INTEGRATION_PATTERN="${LOG_WORKSPACE_INTEGRATION_PATTERN:-$LOG_WORKSPACE_HERD_ROOT/integration/storage/logs/laravel-*.log}"
LOG_WORKSPACE_BACKEND_PHP_PATTERN="${LOG_WORKSPACE_BACKEND_PHP_PATTERN:-$LOG_WORKSPACE_HERD_ROOT/backend/storage/logs/laravel*.log}"
LOG_WORKSPACE_BACKEND_NPM_PATTERN="${LOG_WORKSPACE_BACKEND_NPM_PATTERN:-$LOG_WORKSPACE_LOG_DIR/backend-npm*.log}"
LOG_WORKSPACE_NUXT_NPM_PATTERN="${LOG_WORKSPACE_NUXT_NPM_PATTERN:-$LOG_WORKSPACE_LOG_DIR/web-frontend-npm*.log}"

LOG_WORKSPACE_SCHEMA_VERSION="3"

LOG_WORKSPACE_SOURCE_IDS=(integration_laravel backend_laravel backend_npm frontend_npm)
declare -A LOG_WORKSPACE_SOURCE_LABEL=(
  [integration_laravel]="Integration Laravel"
  [backend_laravel]="backend Laravel"
  [backend_npm]="backend npm"
  [frontend_npm]="Frontend npm"
)
declare -A LOG_WORKSPACE_SOURCE_PATTERN=(
  [integration_laravel]="$LOG_WORKSPACE_INTEGRATION_PATTERN"
  [backend_laravel]="$LOG_WORKSPACE_BACKEND_PHP_PATTERN"
  [backend_npm]="$LOG_WORKSPACE_BACKEND_NPM_PATTERN"
  [frontend_npm]="$LOG_WORKSPACE_NUXT_NPM_PATTERN"
)
declare -A LOG_WORKSPACE_SOURCE_GROUP=(
  [integration_laravel]="integration"
  [backend_laravel]="ws"
  [backend_npm]="ws"
  [frontend_npm]="frontend"
)
declare -A LOG_WORKSPACE_SOURCE_REQUIREMENT=(
  [integration_laravel]="optional"
  [backend_laravel]="optional"
  [backend_npm]="optional"
  [frontend_npm]="optional"
)
declare -A LOG_WORKSPACE_SOURCE_FORMAT=(
  [integration_laravel]="backend_laravel_log"
  [backend_laravel]="backend_laravel_log"
  [backend_npm]="backend_npm_log"
  [frontend_npm]="backend_npm_log"
)

log_workspace_manifest() {
  local id
  for id in "${LOG_WORKSPACE_SOURCE_IDS[@]}"; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$id" \
      "${LOG_WORKSPACE_SOURCE_LABEL[$id]}" \
      "${LOG_WORKSPACE_SOURCE_PATTERN[$id]}" \
      "${LOG_WORKSPACE_SOURCE_GROUP[$id]}" \
      "${LOG_WORKSPACE_SOURCE_REQUIREMENT[$id]}" \
      "${LOG_WORKSPACE_SOURCE_FORMAT[$id]}"
  done
}

log_workspace_role_patterns() {
  local role="$1"
  local id

  LOG_WORKSPACE_PATTERNS=()
  case "$role" in
    all)
      for id in "${LOG_WORKSPACE_SOURCE_IDS[@]}"; do
        LOG_WORKSPACE_PATTERNS+=("${LOG_WORKSPACE_SOURCE_PATTERN[$id]}")
      done
      ;;
    integration|ws|frontend)
      for id in "${LOG_WORKSPACE_SOURCE_IDS[@]}"; do
        if [[ "${LOG_WORKSPACE_SOURCE_GROUP[$id]}" == "$role" ]]; then
          LOG_WORKSPACE_PATTERNS+=("${LOG_WORKSPACE_SOURCE_PATTERN[$id]}")
        fi
      done
      ;;
    *)
      printf 'Unknown log workspace role: %s\n' "$role" >&2
      return 1
      ;;
  esac
}

log_workspace_role_label() {
  case "$1" in
    all) printf 'ALL' ;;
    integration) printf 'INTEGRATION' ;;
    ws) printf 'backend' ;;
    frontend) printf 'FRONTEND' ;;
    *) return 1 ;;
  esac
}
