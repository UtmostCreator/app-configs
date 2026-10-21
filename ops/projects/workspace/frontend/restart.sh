#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

SESSION="$WS_TMUX_SESSION"
PANE_TITLE="$WS_PANE_FRONTEND"
START_NUXT_CMD="bash $WS_SCRIPT_START_FRONTEND"
STOP_NUXT_SCRIPT="$WS_SCRIPT_STOP_FRONTEND"
APP_DIR="$WS_FRONTEND_APP_DIR"
LOG_FILE="$WS_FRONTEND_LOG_FILE"

log() {
  printf '[ws-frontend-restart] %s\n' "$1"
}

ensure_netlify_cli() {
  if command -v netlify >/dev/null 2>&1; then
    return 0
  fi

  echo "netlify CLI not found. Install it first or add it to PATH." >&2
  return 1
}

run_frontend_dev() {
  env NODE_ENV=development APP_DEBUG=true BROWSER=none \
    netlify dev \
      --offline \
      --context "$WS_FRONTEND_NETLIFY_CONTEXT" \
      --port "$WS_FRONTEND_PORT" \
      --target-port "$WS_FRONTEND_TARGET_PORT" \
      --command "npm run dev -- --host $WS_FRONTEND_HOST --port $WS_FRONTEND_TARGET_PORT" \
      --no-open
}

find_tmux_pane() {
  tmux list-panes -a -F '#{session_name}\t#{pane_title}\t#{pane_id}' 2>/dev/null \
    | awk -F '\t' -v session="$SESSION" -v title="$PANE_TITLE" '$1 == session && $2 == title { print $3; exit }'
}

restart_tmux_pane() {
  local pane_id="$1"
  local shell_bin="${SHELL:-/bin/zsh}"
  local payload="bash \"$WS_SCRIPT_START_FRONTEND\"; exec \"$shell_bin\" -l"
  local quoted_shell
  local quoted_payload

  quoted_shell=$(printf '%q' "$shell_bin")
  quoted_payload=$(printf '%q' "$payload")

  tmux respawn-pane -k -t "$pane_id" "$quoted_shell -lc $quoted_payload"
}

find_listener_pid() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
}

is_frontend_listener_pid() {
  local pid="$1"
  local command_line=""

  [[ -n "$pid" ]] || return 1

  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$command_line" == *"$APP_DIR"* ]] \
    || [[ "$command_line" == *"netlify dev"* ]] \
    || [[ "$command_line" == *"frontend dev"* ]] \
    || [[ "$command_line" == *"nuxi dev"* ]]
}

ensure_restart_ports_available() {
  local pane_id="${1:-}"
  local public_pid=""
  local target_pid=""

  public_pid="$(find_listener_pid "$WS_FRONTEND_PORT")"
  target_pid="$(find_listener_pid "$WS_FRONTEND_TARGET_PORT")"

  if [[ -n "$pane_id" ]]; then
    if [[ -n "$public_pid" ]] && ! is_frontend_listener_pid "$public_pid"; then
      echo "Port $WS_FRONTEND_PORT is in use by PID $public_pid. Refusing restart to avoid fallback ports." >&2
      return 1
    fi

    if [[ -n "$target_pid" ]] && ! is_frontend_listener_pid "$target_pid"; then
      echo "Port $WS_FRONTEND_TARGET_PORT is in use by PID $target_pid. Refusing restart to avoid fallback ports." >&2
      return 1
    fi

    return 0
  fi

  log "Running ws-frontend-stop before restart..."
  bash "$STOP_NUXT_SCRIPT"

  public_pid="$(find_listener_pid "$WS_FRONTEND_PORT")"
  target_pid="$(find_listener_pid "$WS_FRONTEND_TARGET_PORT")"

  if [[ -n "$public_pid" ]]; then
    if is_frontend_listener_pid "$public_pid"; then
      echo "Port $WS_FRONTEND_PORT is still owned by web-frontend PID $public_pid after stop. Refusing restart to avoid fallback ports." >&2
    else
      echo "Port $WS_FRONTEND_PORT is in use by PID $public_pid. Refusing restart to avoid fallback ports." >&2
    fi
    return 1
  fi

  if [[ -n "$target_pid" ]]; then
    if is_frontend_listener_pid "$target_pid"; then
      echo "Port $WS_FRONTEND_TARGET_PORT is still owned by web-frontend PID $target_pid after stop. Refusing restart to avoid fallback ports." >&2
    else
      echo "Port $WS_FRONTEND_TARGET_PORT is in use by PID $target_pid. Refusing restart to avoid fallback ports." >&2
    fi
    return 1
  fi
}

start_background_frontend() {
  bash "$WS_SCRIPT_START_FRONTEND"
}

pane_id=""
if tmux has-session -t "$SESSION" 2>/dev/null; then
  pane_id="$(find_tmux_pane || true)"
fi

ensure_restart_ports_available "$pane_id"

if [[ -n "$pane_id" ]]; then
  log "Restarting web-frontend inside tmux pane '$PANE_TITLE'..."
  restart_tmux_pane "$pane_id"

  echo "web-frontend restarted in tmux pane '$PANE_TITLE' ($pane_id)."
  echo "Your current shell stays available; logs continue in the pane and in $LOG_FILE."
  exit 0
fi

# No ws-frontend tmux pane is available, so restart standalone web-frontend proxy
# without blocking the current shell.
start_background_frontend
