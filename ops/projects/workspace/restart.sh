#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

SESSION="$WS_TMUX_SESSION"
SELF_PATH="$WS_SCRIPT_RESTART"
OPEN_WORKSPACE_SCRIPT="$WS_SCRIPT_OPEN_WORKSPACE"
STOP_WORKSPACE_SCRIPT="$WS_SCRIPTS_DIR/stop.sh"
WORKER_FLAG="--worker"
SHUTDOWN_TIMEOUT_SECONDS="${WS_RESTART_SHUTDOWN_TIMEOUT_SECONDS:-30}"

log() {
  printf '[ws-restart] %s\n' "$1"
}

warn() {
  printf '[ws-restart] WARN: %s\n' "$1" >&2
}

wait_for_session_shutdown() {
  local waited=0

  while tmux has-session -t "$SESSION" 2>/dev/null; do
    if (( waited >= SHUTDOWN_TIMEOUT_SECONDS )); then
      return 1
    fi

    sleep 1
    ((waited+=1))
  done

  return 0
}

stop_workspace() {
  log "Stopping backend workspace services..."
  bash "$STOP_WORKSPACE_SCRIPT"

  if ! wait_for_session_shutdown; then
    warn "Timed out waiting for tmux session $SESSION to close (${SHUTDOWN_TIMEOUT_SECONDS}s)."
    return 1
  fi

  log "backend workspace is stopped"
  return 0
}

run_worker() {
  local start_mode="${1:-interactive}"

  if ! stop_workspace; then
    exit 1
  fi

  log "Starting backend workspace..."
  if [[ "$start_mode" == "detached" ]]; then
    bash "$OPEN_WORKSPACE_SCRIPT" --detached
    log "Restart complete. Attach with: tmux attach-session -t $SESSION"
  else
    bash "$OPEN_WORKSPACE_SCRIPT"
  fi
}

spawn_worker() {
  nohup bash "$SELF_PATH" "$WORKER_FLAG" >"$WS_TMP_RESTART_LOG" 2>&1 &
  disown || true
}

restart_from_tmux() {
  local helper_session="${SESSION}-restart-helper-$$"

  log "Preparing tmux-assisted restart..."
  tmux kill-session -t "$helper_session" 2>/dev/null || true
  tmux new-session -d -s "$helper_session" -n restart
  tmux switch-client -t "$helper_session"

  stop_workspace

  log "Starting backend workspace and switching client to $SESSION..."
  bash "$OPEN_WORKSPACE_SCRIPT"

  tmux kill-session -t "$helper_session" 2>/dev/null || true
}

if [[ "${1:-}" == "$WORKER_FLAG" ]]; then
  run_worker detached
  exit 0
fi

if [[ ! -f "$OPEN_WORKSPACE_SCRIPT" ]]; then
  warn "Cannot find $OPEN_WORKSPACE_SCRIPT"
  exit 1
fi

if [[ ! -f "$STOP_WORKSPACE_SCRIPT" ]]; then
  warn "Cannot find $STOP_WORKSPACE_SCRIPT"
  exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [[ -n "${TMUX:-}" ]]; then
    restart_from_tmux
    exit 0
  fi

  stop_workspace
  log "Starting backend workspace in current terminal..."
  exec bash "$OPEN_WORKSPACE_SCRIPT"
  exit 0
fi

if ! stop_workspace; then
  exit 1
fi

log "Starting backend workspace in current terminal..."
exec bash "$OPEN_WORKSPACE_SCRIPT"
