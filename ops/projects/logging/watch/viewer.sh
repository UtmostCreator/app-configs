#!/usr/bin/env bash
set -Eeuo pipefail

ROLE=""
INSTANCE=""
STATE_DIR=""
CONFIG_DIR=""
SINCE="24h"
BACKEND="lnav"
BACKEND_REASON=""
PATTERNS=()
MONITOR_PID=""
DEGRADED_REASON=""
STREAM_PID=""
STREAM_FILE=""
VIEW_PID=""

usage() {
  printf 'Usage: %s --role ROLE --instance ID --state-dir DIR --config-dir DIR --since DURATION --backend lnav|less -- PATTERN...\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --instance) INSTANCE="${2:-}"; shift 2 ;;
    --state-dir) STATE_DIR="${2:-}"; shift 2 ;;
    --config-dir) CONFIG_DIR="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --backend) BACKEND="${2:-}"; shift 2 ;;
    --backend-reason) BACKEND_REASON="${2:-}"; shift 2 ;;
    --) shift; PATTERNS=("$@"); break ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$ROLE" || -z "$INSTANCE" || -z "$STATE_DIR" || -z "$CONFIG_DIR" || ${#PATTERNS[@]} -eq 0 ]]; then
  usage
  exit 2
fi

HEALTH_DIR="$STATE_DIR/health"
HEALTH_FILE="$HEALTH_DIR/${INSTANCE}.${ROLE}"
mkdir -p "$HEALTH_DIR"

# lnav can ignore SIGTERM, and a bare `wait` on it would then hang the viewer
# (and leak lnav) after its tmux session is gone, so escalate to SIGKILL.
stop_child() {
  local pid="$1"
  local attempts=20
  [[ -n "$pid" ]] || return 0
  kill "$pid" 2>/dev/null || true
  while (( attempts > 0 )) && kill -0 "$pid" 2>/dev/null; do
    sleep 0.1
    ((attempts-=1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
}

cleanup() {
  stop_child "$VIEW_PID"
  stop_child "$MONITOR_PID"
  stop_child "$STREAM_PID"
  if [[ -n "$STREAM_FILE" ]]; then
    rm -f "$STREAM_FILE"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 0' INT
trap 'exit 143' TERM

write_health() {
  local state="$1"
  local detail="${2:-}"
  local now
  local temporary="$HEALTH_FILE.tmp.$BASHPID"

  now="$(date +%s)"
  printf '%s\t%s\t%s\t%s\n' "$state" "$now" "$$" "$detail" >"$temporary"
  mv -f "$temporary" "$HEALTH_FILE"
}

set_title() {
  local state="$1"
  local detail="${2:-}"
  local label
  local title

  label="$(printf '%s' "$ROLE" | tr '[:lower:]' '[:upper:]')"
  title="$label · $state"
  [[ -n "$detail" ]] && title="$title · $detail"
  if [[ -n "${TMUX_PANE:-}" ]]; then
    tmux select-pane -t "$TMUX_PANE" -T "$title" 2>/dev/null || true
  fi
  write_health "$state" "$detail"
}

pattern_matches() {
  compgen -G "$1" 2>/dev/null || true
}

source_status() {
  local available=0
  local pattern
  local match
  local latest=""

  for pattern in "${PATTERNS[@]}"; do
    match="$(pattern_matches "$pattern" | head -n 1)"
    if [[ -n "$match" ]]; then
      ((available+=1))
      while IFS= read -r match; do
        [[ -n "$match" ]] || continue
        if [[ -z "$latest" || "$match" > "$latest" ]]; then
          latest="$match"
        fi
      done < <(pattern_matches "$pattern")
    fi
  done

  printf '%s\t%s\t%s\n' "$available" "${#PATTERNS[@]}" "${latest##*/}"
}

refresh_state() {
  local status
  local available
  local total
  local latest
  local detail

  status="$(source_status)"
  IFS=$'\t' read -r available total latest <<<"$status"
  if (( available == 0 )); then
    set_title "WAITING" "0/$total sources"
  elif [[ -n "$DEGRADED_REASON" ]]; then
    if (( total == 1 )); then
      detail="${latest:-source ready}"
    else
      detail="$available/$total sources"
    fi
    set_title "DEGRADED" "$DEGRADED_REASON · $detail"
  elif (( available < total )); then
    set_title "PARTIAL" "$available/$total sources"
  elif (( total == 1 )); then
    detail="${latest:-source ready}"
    set_title "FOLLOWING" "$detail"
  else
    set_title "FOLLOWING" "$available/$total sources"
  fi
}

wait_for_source() {
  local status
  local available

  while true; do
    status="$(source_status)"
    IFS=$'\t' read -r available _ <<<"$status"
    refresh_state
    (( available > 0 )) && return 0
    sleep 2
  done
}

monitor_sources() {
  local pid="$1"
  while kill -0 "$pid" 2>/dev/null; do
    refresh_state
    sleep 2
  done
}

stop_monitor() {
  if [[ -n "$MONITOR_PID" ]]; then
    kill "$MONITOR_PID" 2>/dev/null || true
    wait "$MONITOR_PID" 2>/dev/null || true
    MONITOR_PID=""
  fi
}

start_monitor() {
  stop_monitor
  monitor_sources "$$" &
  MONITOR_PID="$!"
}

since_for_lnav() {
  local amount="${SINCE%?}"
  case "$SINCE" in
    *m) printf '%s minutes ago' "$amount" ;;
    *h) printf '%s hours ago' "$amount" ;;
    *d) printf '%s days ago' "$amount" ;;
    *) return 1 ;;
  esac
}

run_lnav_once() {
  local use_since="$1"
  local since_value=""
  local -a args=(-N -I "$CONFIG_DIR" -c ':goto 100%')

  if [[ "$use_since" == "1" ]]; then
    since_value="$(since_for_lnav)"
    args+=(-S "$since_value")
  fi
  args+=("${PATTERNS[@]}")

  lnav "${args[@]}" &
  VIEW_PID="$!"
  set +e
  wait "$VIEW_PID"
  local status=$?
  set -e
  VIEW_PID=""
  return "$status"
}

run_lnav() {
  local status=0

  wait_for_source
  start_monitor

  if run_lnav_once 1; then
    return 0
  else
    status=$?
  fi

  if [[ "$status" == "134" || "$status" == "139" ]]; then
    DEGRADED_REASON="lnav without time cutoff"
    set_title "DEGRADED" "retrying without time cutoff"
    start_monitor
    printf '\nlnav crashed while applying the %s cutoff; retrying once with full history.\n' "$SINCE" >&2
    if run_lnav_once 0; then
      return 0
    else
      status=$?
    fi
  fi

  stop_monitor
  if [[ "$status" == "130" ]]; then
    set_title "STOPPED" "lnav interrupted"
    return 0
  fi
  set_title "FAILED $status" "lnav"
  printf '\nlnav viewer failed with status %s.\n' "$status" >&2
  return "$status"
}

stream_for_less() {
  local -A started=()
  local pattern
  local file
  local child
  local -a children=()

  # shellcheck disable=SC2329 # Invoked by the EXIT trap below.
  cleanup_children() {
    for child in "${children[@]}"; do
      kill "$child" 2>/dev/null || true
      wait "$child" 2>/dev/null || true
    done
  }
  trap cleanup_children EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  printf 'Reduced viewer: %s; using less.\n' "${BACKEND_REASON:-lnav unavailable}"
  printf 'Combined chronological search, structured formats, and mouse actions are unavailable.\n'
  printf 'Ctrl+C: navigate  /: search  n/N: matches  F: resume following\n\n'

  while true; do
    for pattern in "${PATTERNS[@]}"; do
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        [[ -n "${started[$file]:-}" ]] && continue
        started["$file"]=1
        (
          printf '\n===== %s =====\n' "$file"
          tail -n 2000 -F "$file"
        ) &
        child="$!"
        children+=("$child")
      done < <(pattern_matches "$pattern")
    done
    sleep 2
  done
}

run_less() {
  local status=0

  DEGRADED_REASON="less"
  wait_for_source
  start_monitor
  set_title "DEGRADED" "less fallback"

  STREAM_FILE="$STATE_DIR/less-${INSTANCE}-${ROLE}.log"
  : >"$STREAM_FILE"
  stream_for_less >>"$STREAM_FILE" &
  STREAM_PID="$!"
  less --follow-name +F "$STREAM_FILE" &
  VIEW_PID="$!"
  set +e
  wait "$VIEW_PID"
  status=$?
  set -e
  VIEW_PID=""
  kill "$STREAM_PID" 2>/dev/null || true
  wait "$STREAM_PID" 2>/dev/null || true
  STREAM_PID=""
  rm -f "$STREAM_FILE"
  STREAM_FILE=""

  if [[ "$status" == "0" ]]; then
    return 0
  fi

  stop_monitor
  if [[ "$status" == "130" ]]; then
    set_title "STOPPED" "less interrupted"
    return 0
  fi
  set_title "FAILED $status" "less"
  return "$status"
}

case "$BACKEND" in
  lnav) run_lnav ;;
  less) run_less ;;
  *) printf 'Unsupported viewer backend: %s\n' "$BACKEND" >&2; exit 2 ;;
esac
