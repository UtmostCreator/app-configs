#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

VIEWER="$SCRIPT_DIR/viewer.sh"
LNAV_CONFIG_DIR="$SCRIPT_DIR/../lnav"
LEGACY_SESSION="log-workspace"
SESSION="$LOG_WORKSPACE_SESSION_NAME"
DETACHED="0"
REBUILD="0"
FORCE_ALIAS="0"
BACKEND=""
BACKEND_REASON=""
FINGERPRINT=""
LOCK_DIR=""
CANDIDATE=""
BACKUP=""
LOCK_HELD="0"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--detached] [--rebuild] [--help]

Open the backend log investigation workspace.

  --detached  create or repair the workspace without attaching
  --rebuild   safely replace the workspace after validating its replacement
  --help      show this help

Environment overrides:
  LOG_WORKSPACE_SINCE=24h
  LOG_WORKSPACE_DEFAULT_VIEW=all|dashboard
  LOG_WORKSPACE_SESSION_NAME=$SESSION
EOF
}

for arg in "$@"; do
  case "$arg" in
    --detached) DETACHED="1" ;;
    --rebuild) REBUILD="1" ;;
    --force) REBUILD="1"; FORCE_ALIAS="1" ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$FORCE_ALIAS" == "1" && -t 2 ]]; then
  printf 'Note: --force is deprecated; use --rebuild.\n' >&2
fi

if [[ ! "$LOG_WORKSPACE_SINCE" =~ ^[1-9][0-9]*[mhd]$ ]]; then
  printf 'LOG_WORKSPACE_SINCE must be a positive duration such as 30m, 24h, or 7d.\n' >&2
  exit 2
fi
if [[ "$LOG_WORKSPACE_DEFAULT_VIEW" != "all" && "$LOG_WORKSPACE_DEFAULT_VIEW" != "dashboard" ]]; then
  printf 'LOG_WORKSPACE_DEFAULT_VIEW must be all or dashboard.\n' >&2
  exit 2
fi
if ! command -v tmux >/dev/null 2>&1; then
  printf 'tmux is required to open the log workspace.\n' >&2
  exit 1
fi

version_at_least() {
  local actual="$1"
  local required="$2"
  local actual_major actual_minor actual_patch
  local required_major required_minor required_patch

  IFS=. read -r actual_major actual_minor actual_patch <<<"$actual"
  IFS=. read -r required_major required_minor required_patch <<<"$required"
  (( actual_major > required_major )) && return 0
  (( actual_major < required_major )) && return 1
  (( actual_minor > required_minor )) && return 0
  (( actual_minor < required_minor )) && return 1
  (( actual_patch >= required_patch ))
}

lnav_output=""
lnav_version=""
if command -v lnav >/dev/null 2>&1; then
  lnav_output="$(lnav -V 2>/dev/null || true)"
  lnav_version="$(sed -E 's/^[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' <<<"$lnav_output" | head -n 1)"
fi
if [[ "$lnav_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && version_at_least "$lnav_version" "0.14.0"; then
  BACKEND="lnav"
else
  BACKEND="less"
  if [[ -n "$lnav_version" ]]; then
    BACKEND_REASON="lnav $lnav_version is below the supported 0.14.0 baseline"
  else
    BACKEND_REASON="lnav is unavailable"
  fi
  if ! command -v less >/dev/null 2>&1; then
    printf 'lnav 0.14.0+ is unavailable and the less fallback is not installed.\n' >&2
    exit 1
  fi
fi

calculate_fingerprint() {
  {
    printf '%s\n' \
      "$LOG_WORKSPACE_SCHEMA_VERSION" \
      "$LOG_WORKSPACE_PROJECT_ID" \
      "$LOG_WORKSPACE_SINCE" \
      "$LOG_WORKSPACE_DEFAULT_VIEW" \
      "$BACKEND" \
      "$BACKEND_REASON" \
      "${lnav_version:-unavailable}"
    log_workspace_manifest
    cksum "$SCRIPT_PATH" "$VIEWER" "$SCRIPT_DIR/config.sh"
    find "$LNAV_CONFIG_DIR" -type f -exec cksum {} \; 2>/dev/null | sort
  } | cksum | awk '{print $1 "-" $2}'
}

FINGERPRINT="$(calculate_fingerprint)"

session_exists() {
  local wanted="$1"
  tmux list-sessions -F '#{session_name}' 2>/dev/null \
    | awk -v wanted="$wanted" '$0 == wanted { found=1 } END { exit !found }'
}

pane_for_role() {
  local session="$1"
  local role="$2"
  # The trailing colon makes tmux parse the complete value as a session name,
  # even when an override contains characters used in pane targets (such as .).
  tmux list-panes -s -t "$session:" -F '#{@log_workspace_role} #{pane_id}' 2>/dev/null \
    | awk -v wanted="$role" '$1 == wanted { print $2; exit }'
}

window_has_roles() {
  local session="$1"
  local window="$2"
  local expected_index="$3"
  local expected_roles="$4"
  local actual_index
  local actual_roles

  actual_index="$(tmux display-message -p -t "$session:$window" '#{window_index}' 2>/dev/null || true)"
  [[ "$actual_index" == "$expected_index" ]] || return 1
  actual_roles="$(tmux list-panes -t "$session:$window" -F '#{@log_workspace_role}' 2>/dev/null || true)"
  [[ "$actual_roles" == "$expected_roles" ]]
}

session_structure_healthy() {
  local session="$1"
  window_has_roles "$session" all 1 all \
    && window_has_roles "$session" dashboard 2 $'integration\nws\nfrontend'
}

health_file() {
  local instance="$1"
  local role="$2"
  printf '%s/health/%s.%s\n' "$LOG_WORKSPACE_STATE_DIR" "$instance" "$role"
}

health_is_fresh() {
  local instance="$1"
  local role="$2"
  local file
  local state=""
  local timestamp="0"
  local pid=""
  local now

  file="$(health_file "$instance" "$role")"
  [[ -f "$file" ]] || return 1
  IFS=$'\t' read -r state timestamp pid _ <"$file" || return 1
  [[ "$state" != FAILED* && "$timestamp" =~ ^[0-9]+$ && "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  now="$(date +%s)"
  (( timestamp <= now && now - timestamp <= 10 ))
}

session_healthy() {
  local session="$1"
  local expected
  local instance
  local role
  local pane
  local dead

  session_exists "$session" || return 1
  session_structure_healthy "$session" || return 1
  expected="$(tmux show-option -qv -t "$session" @log_workspace_fingerprint 2>/dev/null || true)"
  [[ "$expected" == "$FINGERPRINT" ]] || return 1
  instance="$(tmux show-option -qv -t "$session" @log_workspace_instance 2>/dev/null || true)"
  [[ -n "$instance" ]] || return 1

  for role in all integration ws frontend; do
    pane="$(pane_for_role "$session" "$role")"
    [[ -n "$pane" ]] || return 1
    dead="$(tmux display-message -p -t "$pane" '#{pane_dead}' 2>/dev/null || true)"
    [[ "$dead" == "0" ]] || return 1
    health_is_fresh "$instance" "$role" || return 1
  done
}

viewer_args_for_role() {
  local role="$1"
  local instance="$2"
  log_workspace_role_patterns "$role"
  VIEWER_ARGS=(
    "$VIEWER"
    --role "$role"
    --instance "$instance"
    --state-dir "$LOG_WORKSPACE_STATE_DIR"
    --config-dir "$LNAV_CONFIG_DIR"
    --since "$LOG_WORKSPACE_SINCE"
    --backend "$BACKEND"
  )
  if [[ -n "$BACKEND_REASON" ]]; then
    VIEWER_ARGS+=(--backend-reason "$BACKEND_REASON")
  fi
  VIEWER_ARGS+=(-- "${LOG_WORKSPACE_PATTERNS[@]}")
}

tag_pane() {
  local pane="$1"
  local role="$2"
  tmux set-option -p -t "$pane" @log_workspace_role "$role"
}

configure_window() {
  local target="$1"
  tmux set-window-option -t "$target" pane-border-status top
  tmux set-window-option -t "$target" pane-border-format ' #{pane_title} '
  tmux set-window-option -t "$target" remain-on-exit failed
}

create_all_window() {
  local session="$1"
  local instance="$2"
  local mode="$3"
  local pane

  viewer_args_for_role all "$instance"
  if [[ "$mode" == "session" ]]; then
    pane="$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -n all "${VIEWER_ARGS[@]}")"
    tmux set-option -t "$session" base-index 1
    tmux set-option -t "$session" renumber-windows off
    local current_index
    current_index="$(tmux display-message -p -t "$pane" '#{window_index}')"
    if [[ "$current_index" != "1" ]]; then
      tmux move-window -s "$session:$current_index" -t "$session:1"
    fi
  else
    pane="$(tmux new-window -d -P -F '#{pane_id}' -t "$session:1" -n all "${VIEWER_ARGS[@]}")"
  fi
  tag_pane "$pane" all
  configure_window "$session:all"
}

create_dashboard_window() {
  local session="$1"
  local instance="$2"
  local pane_integration
  local pane_backend
  local pane_frontend

  viewer_args_for_role integration "$instance"
  pane_integration="$(tmux new-window -d -P -F '#{pane_id}' -t "$session:2" -n dashboard "${VIEWER_ARGS[@]}")"
  tag_pane "$pane_integration" integration

  viewer_args_for_role ws "$instance"
  pane_backend="$(tmux split-window -d -v -P -F '#{pane_id}' -t "$pane_integration" "${VIEWER_ARGS[@]}")"
  tag_pane "$pane_backend" ws

  viewer_args_for_role frontend "$instance"
  pane_frontend="$(tmux split-window -d -v -P -F '#{pane_id}' -t "$pane_backend" "${VIEWER_ARGS[@]}")"
  tag_pane "$pane_frontend" frontend

  configure_window "$session:dashboard"
  tmux select-layout -t "$session:dashboard" even-horizontal >/dev/null
}

configure_session() {
  local session="$1"
  local instance="$2"
  local prefix

  tmux set-option -t "$session" @log_workspace_fingerprint "$FINGERPRINT"
  tmux set-option -t "$session" @log_workspace_instance "$instance"
  tmux set-option -t "$session" detach-on-destroy on
  tmux set-option -t "$session" status on
  tmux set-option -t "$session" status-left-length 28
  tmux set-option -t "$session" status-right-length 190
  prefix="$(tmux show-option -gv prefix 2>/dev/null || printf 'C-b')"
  tmux set-option -t "$session" status-left ' backend logs | #{window_index}:#{window_name} '
  tmux set-option -t "$session" status-right "/ search  n/N matches  e/E errors  m mark  M range  c copy  F2 select-text  $prefix z zoom  $prefix Space layout  F1 help "
}

create_session() {
  local session="$1"
  local instance="$2"
  create_all_window "$session" "$instance" session
  create_dashboard_window "$session" "$instance"
  configure_session "$session" "$instance"
}

wait_for_session() {
  local session="$1"
  local _attempt
  for _attempt in {1..25}; do
    if session_healthy "$session"; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

respawn_role() {
  local session="$1"
  local instance="$2"
  local role="$3"
  local pane
  local file

  pane="$(pane_for_role "$session" "$role")"
  [[ -n "$pane" ]] || return 1
  file="$(health_file "$instance" "$role")"
  rm -f "$file"
  viewer_args_for_role "$role" "$instance"
  tmux respawn-pane -k -t "$pane" "${VIEWER_ARGS[@]}"
}

repair_session() {
  local session="$1"
  local instance
  local role
  local pane
  local dead

  instance="$(tmux show-option -qv -t "$session" @log_workspace_instance)"
  session_structure_healthy "$session" || return 1

  for role in all integration ws frontend; do
    pane="$(pane_for_role "$session" "$role")"
    dead="$(tmux display-message -p -t "$pane" '#{pane_dead}' 2>/dev/null || true)"
    if [[ "$dead" != "0" ]] || ! health_is_fresh "$instance" "$role"; then
      respawn_role "$session" "$instance" "$role"
    fi
  done

  configure_session "$session" "$instance"
  wait_for_session "$session"
}

release_lock() {
  if [[ "$LOCK_HELD" == "1" ]]; then
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
    LOCK_HELD="0"
  fi
}

cleanup() {
  if [[ -n "$CANDIDATE" ]] && session_exists "$CANDIDATE"; then
    tmux kill-session -t "$CANDIDATE" 2>/dev/null || true
  fi
  if [[ -n "$BACKUP" ]] && session_exists "$BACKUP"; then
    if session_exists "$SESSION"; then
      tmux kill-session -t "$BACKUP" 2>/dev/null || true
    else
      tmux rename-session -t "$BACKUP" "$SESSION" 2>/dev/null || true
    fi
  fi
  release_lock
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

acquire_lock() {
  local _attempt
  local owner=""

  mkdir -p "$LOG_WORKSPACE_STATE_DIR/health"
  LOCK_DIR="$LOG_WORKSPACE_STATE_DIR/reconcile.lock"
  for _attempt in {1..50}; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      LOCK_HELD="1"
      return 0
    fi
    owner="$(tr -d '[:space:]' <"$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ ! "$owner" =~ ^[0-9]+$ ]] || ! kill -0 "$owner" 2>/dev/null; then
      rm -f "$LOCK_DIR/pid"
      rmdir "$LOCK_DIR" 2>/dev/null || true
      continue
    fi
    sleep 0.1
  done
  printf 'Another log-workspace reconciliation is still running (PID %s).\n' "${owner:-unknown}" >&2
  return 1
}

transactional_rebuild() {
  local old_session="${1:-}"
  local instance

  instance="build-$$-$(date +%s)"
  CANDIDATE="${SESSION}-candidate-$$"
  create_session "$CANDIDATE" "$instance"
  if ! wait_for_session "$CANDIDATE"; then
    printf 'Replacement workspace failed validation; the existing session was preserved.\n' >&2
    return 1
  fi

  if [[ -n "$old_session" ]] && session_exists "$old_session"; then
    if [[ "$old_session" == "$SESSION" ]]; then
      BACKUP="${SESSION}-previous-$$"
      tmux rename-session -t "$old_session" "$BACKUP"
      if ! tmux rename-session -t "$CANDIDATE" "$SESSION"; then
        if tmux rename-session -t "$BACKUP" "$SESSION" 2>/dev/null; then
          BACKUP=""
        fi
        return 1
      fi
      CANDIDATE=""
      while IFS= read -r client; do
        [[ -n "$client" ]] && tmux switch-client -c "$client" -t "$SESSION" 2>/dev/null || true
      done < <(tmux list-clients -t "$BACKUP" -F '#{client_name}' 2>/dev/null || true)
      if tmux kill-session -t "$BACKUP" 2>/dev/null; then
        BACKUP=""
      fi
    else
      tmux rename-session -t "$CANDIDATE" "$SESSION"
      CANDIDATE=""
      while IFS= read -r client; do
        [[ -n "$client" ]] && tmux switch-client -c "$client" -t "$SESSION" 2>/dev/null || true
      done < <(tmux list-clients -t "$old_session" -F '#{client_name}' 2>/dev/null || true)
      tmux kill-session -t "$old_session" 2>/dev/null || true
    fi
  else
    tmux rename-session -t "$CANDIDATE" "$SESSION"
    CANDIDATE=""
  fi
}

attach_or_report() {
  if [[ "$DETACHED" == "1" ]]; then
    printf 'tmux session %s is ready in detached mode (%s viewer).\n' "$SESSION" "$BACKEND"
  elif [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION:$LOG_WORKSPACE_DEFAULT_VIEW"
  else
    tmux attach-session -t "$SESSION:$LOG_WORKSPACE_DEFAULT_VIEW"
  fi
}

acquire_lock

old_session=""
if session_exists "$SESSION"; then
  old_session="$SESSION"
elif [[ "$LEGACY_SESSION" != "$SESSION" ]] && session_exists "$LEGACY_SESSION"; then
  old_session="$LEGACY_SESSION"
fi

if [[ "$REBUILD" == "0" && "$old_session" == "$SESSION" ]]; then
  existing_fingerprint="$(tmux show-option -qv -t "$SESSION" @log_workspace_fingerprint 2>/dev/null || true)"
  if [[ "$existing_fingerprint" == "$FINGERPRINT" ]]; then
    if ! session_healthy "$SESSION"; then
      repair_session "$SESSION" || transactional_rebuild "$SESSION"
    fi
  else
    transactional_rebuild "$SESSION"
  fi
else
  transactional_rebuild "$old_session"
fi

release_lock
attach_or_report
