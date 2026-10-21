#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

APP_DIR="$WS_FRONTEND_APP_DIR"
APP_NAME="web-frontend"
PORT="$WS_FRONTEND_PORT"
HOST="$WS_FRONTEND_HOST"
STATE_DIR="$HOME/.local/state/$APP_NAME"
LOG_FILE="$STATE_DIR/debug.log"
PID_FILE="$STATE_DIR/debug.pid"

mkdir -p "$STATE_DIR"

ensure_frontend_dependencies() {
  if [[ -f "$APP_DIR/node_modules/frontend/package.json" || -f "$APP_DIR/node_modules/nuxi/package.json" ]]; then
    return 0
  fi

  echo "Frontend package not found in $APP_DIR/node_modules. Installing frontend dependencies..."
  if [[ -f "$APP_DIR/package-lock.json" ]]; then
    (cd "$APP_DIR" && npm ci)
  else
    (cd "$APP_DIR" && npm install)
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start    Start $APP_NAME in the background and write logs to $LOG_FILE
  run      Run $APP_NAME in the foreground and tee logs to $LOG_FILE
  stop     Stop the running $APP_NAME debug server
  restart  Restart the background debug server
  logs     Open $LOG_FILE in lnav when available, otherwise tail it
  tail     Tail $LOG_FILE without a log viewer
  warn     Highlight warning/error/debug lines from $LOG_FILE
  status   Show whether the debug server is running and where logs live
EOF
}

is_pid_running() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

read_pid() {
  if [[ -f "$PID_FILE" ]]; then
    tr -d '[:space:]' < "$PID_FILE"
  fi
}

port_pid() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1
  fi
}

running_pid() {
  local pid
  pid="$(read_pid || true)"

  if is_pid_running "$pid"; then
    printf '%s\n' "$pid"
    return 0
  fi

  pid="$(port_pid || true)"
  if is_pid_running "$pid"; then
    printf '%s\n' "$pid"
    return 0
  fi

  return 1
}

start_background() {
  if running_pid >/dev/null 2>&1; then
    echo "$APP_NAME is already running with PID $(running_pid)."
    echo "Logs: $LOG_FILE"
    return 0
  fi

  {
    echo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting $APP_NAME debug server"
  } >> "$LOG_FILE"

  ensure_frontend_dependencies

  (
    cd "$APP_DIR"
    exec mise exec "$WS_NODE_RUNTIME" -- env NODE_ENV=development APP_DEBUG=true npm run dev -- --host "$HOST" --port "$PORT"
  ) >> "$LOG_FILE" 2>&1 &

  echo $! > "$PID_FILE"
  echo "Started $APP_NAME with PID $!"
  echo "Logs: $LOG_FILE"
}

run_foreground() {
  if running_pid >/dev/null 2>&1; then
    echo "$APP_NAME is already running with PID $(running_pid). Stop it first or use 'logs'." >&2
    return 1
  fi

  {
    echo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting $APP_NAME debug server (foreground)"
  } >> "$LOG_FILE"

  ensure_frontend_dependencies

  echo "Writing logs to $LOG_FILE"
  cd "$APP_DIR"
  mise exec "$WS_NODE_RUNTIME" -- env NODE_ENV=development APP_DEBUG=true npm run dev -- --host "$HOST" --port "$PORT" 2>&1 | tee -a "$LOG_FILE"
}

stop_running() {
  local pid
  pid="$(running_pid || true)"

  if [[ -z "$pid" ]]; then
    rm -f "$PID_FILE"
    echo "$APP_NAME is not running."
    return 0
  fi

  kill "$pid" 2>/dev/null || true

  for _ in 1 2 3 4 5; do
    if ! is_pid_running "$pid"; then
      rm -f "$PID_FILE"
      echo "Stopped $APP_NAME (PID $pid)."
      return 0
    fi

    sleep 1
  done

  kill -9 "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "Force-stopped $APP_NAME (PID $pid)."
}

show_logs() {
  touch "$LOG_FILE"

  if command -v lnav >/dev/null 2>&1; then
    exec lnav "$LOG_FILE"
  fi

  tail -f "$LOG_FILE"
}

show_logs_plain() {
  touch "$LOG_FILE"
  tail -f "$LOG_FILE"
}

show_log_warnings() {
  touch "$LOG_FILE"

  if command -v rg >/dev/null 2>&1; then
    rg --color=always -n "WARN|ERROR|UI warn|Mapped Promo Banner|Invalid prop|No match found|Property \"locale\"" "$LOG_FILE" || true
    return 0
  fi

  grep -nE "WARN|ERROR|UI warn|Mapped Promo Banner|Invalid prop|No match found|Property \"locale\"" "$LOG_FILE" || true
}

show_status() {
  local pid
  pid="$(running_pid || true)"

  if [[ -n "$pid" ]]; then
    echo "$APP_NAME is running with PID $pid on port $PORT"
  else
    echo "$APP_NAME is not running"
  fi

  echo "App dir: $APP_DIR"
  echo "Logs: $LOG_FILE"
}

command="${1:-status}"

case "$command" in
  start)
    start_background
    ;;
  run)
    run_foreground
    ;;
  stop)
    stop_running
    ;;
  restart)
    stop_running
    start_background
    ;;
  logs)
    show_logs
    ;;
  tail)
    show_logs_plain
    ;;
  warn)
    show_log_warnings
    ;;
  status)
    show_status
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
