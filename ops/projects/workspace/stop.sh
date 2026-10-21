#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

SESSION="$WS_TMUX_SESSION"
FRONTEND_PORT="$WS_FRONTEND_PORT"
STOP_FRONTEND_SCRIPT="$WS_SCRIPT_STOP_FRONTEND"
STOP_STACK_SCRIPT="$WS_SCRIPT_STOP_STACK"

log() {
  printf '[ws-stop] %s\n' "$1"
}

find_frontend_pid() {
  local pid=""

  if command -v lsof >/dev/null 2>&1; then
    pid="$(lsof -tiTCP:"$FRONTEND_PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
  fi

  if [[ -n "$pid" ]]; then
    local command=""
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"

    if [[ "$command" == *"web-frontend"* || "$command" == *"frontend dev"* ]]; then
      printf '%s\n' "$pid"
      return 0
    fi
  fi

  return 1
}

stop_frontend() {
  local frontend_pid="$1"

  if [[ -n "$frontend_pid" ]]; then
    log "Stopping web-frontend on port $FRONTEND_PORT (PID $frontend_pid)..."
  else
    log "Stopping web-frontend if running..."
  fi

  bash "$STOP_FRONTEND_SCRIPT"
}

stop_stack() {
  log "Stopping Herd/backend stack if running..."
  bash "$STOP_STACK_SCRIPT"
}

stop_tmux_session() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    # Detach all clients attached to this session BEFORE killing it.
    # Without this, tmux silently switches the terminal to another active session
    # instead of returning you to the normal shell.
    tmux detach-client -s "$SESSION" 2>/dev/null || true
    tmux kill-session -t "$SESSION"
    log "$SESSION stopped"
  else
    log "$SESSION is not running"
  fi
}

frontend_pid="$(find_frontend_pid || true)"

stop_frontend "$frontend_pid"
stop_stack
stop_tmux_session
