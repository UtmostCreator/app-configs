#!/usr/bin/env bash
# Log workspace: opens N vertical tmux panes, one tailing each project's
# service.log from ~/.config/projects/config.yaml. By default takes the
# first 3 projects with a `service.log` set (matches the original
# 3-pane layout) but scales to whatever fits.
#
# Modes:
#   default       — start a dedicated tmux session and attach
#   --inline      — replace the current pane (used by tmux-master.sh)
#   --detached    — start the session in the background
#   --force       — kill any existing session of the same name first
#
# Usage:
#   bash ops/projects/tmux-logs.sh
#   bash ops/projects/tmux-logs.sh --detached
#   bash ops/projects/tmux-logs.sh --inline

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/lib.sh
source "$SCRIPT_DIR/lib.sh"

DETACHED=0
FORCE=0
INLINE=0
for arg in "$@"; do
  case "$arg" in
    --detached) DETACHED=1 ;;
    --force)    FORCE=1 ;;
    --inline)   INLINE=1 ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *) proj_fail "unknown arg: $arg" ;;
  esac
done

require_cmd tmux yq

# Resolve log targets: id|label|path triples for every project with a log.
mapfile -t IDS < <(proj_ids)
TARGETS=()
for id in "${IDS[@]}"; do
  log_path="$(proj_field "$id" service.log)"
  [[ -z "$log_path" || "$log_path" == "null" ]] && continue
  label="$(proj_field_default "$id" pane_label "${id^^}")"
  path="$(proj_expand_path "$log_path")"
  TARGETS+=("${id}|${label}|${path}")
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  proj_fail "no projects with service.log defined in $PROJECTS_CONFIG"
fi

# Ensure each log file exists so `tail -F` does not warn.
for entry in "${TARGETS[@]}"; do
  IFS='|' read -r _id _label path <<<"$entry"
  mkdir -p "$(dirname "$path")"
  [[ -f "$path" ]] || touch "$path"
done

# Inline mode: replace the current pane with N stacked sub-panes via splits.
if (( INLINE )); then
  [[ -z "${TMUX:-}" ]] && proj_fail "--inline requires being inside a tmux session"
  # First target runs in the current pane.
  IFS='|' read -r _id label path <<<"${TARGETS[0]}"
  tmux select-pane -T "$label"
  tmux send-keys "tail -n 200 -F $(printf '%q' "$path")" Enter
  PREV="$(tmux display-message -p '#{pane_id}')"
  for entry in "${TARGETS[@]:1}"; do
    IFS='|' read -r _id label path <<<"$entry"
    NEW=$(tmux split-window -h -t "$PREV" -P -F '#{pane_id}')
    tmux select-pane -t "$NEW" -T "$label"
    tmux send-keys -t "$NEW" "tail -n 200 -F $(printf '%q' "$path")" Enter
    PREV="$NEW"
  done
  exit 0
fi

# Standalone session mode.
SESSION="$(proj_tmux_session log_session dev-logs)"
WINDOW="logs"

[[ "$FORCE" == "1" ]] && tmux kill-session -t "$SESSION" 2>/dev/null || true
if proj_tmux_session_exists "$SESSION"; then
  proj_tmux_attach "$SESSION" "$DETACHED"
  exit 0
fi

tmux new-session -d -s "$SESSION" -n "$WINDOW"
tmux set-option -t "$SESSION" detach-on-destroy on >/dev/null
tmux set-window-option -t "$SESSION:$WINDOW" pane-border-status top >/dev/null
tmux set-window-option -t "$SESSION:$WINDOW" pane-border-format ' #{pane_title} ' >/dev/null

FIRST=1
PREV=""
for entry in "${TARGETS[@]}"; do
  IFS='|' read -r _id label path <<<"$entry"
  if (( FIRST )); then
    PANE=$(proj_tmux_pane_id "$SESSION" "$WINDOW")
    FIRST=0
  else
    PANE=$(tmux split-window -h -t "$PREV" -P -F '#{pane_id}')
  fi
  tmux select-pane -t "$PANE" -T "$label"
  tmux send-keys -t "$PANE" "tail -n 200 -F $(printf '%q' "$path")" Enter
  PREV="$PANE"
done

tmux select-pane -t "$(proj_tmux_pane_id "$SESSION" "$WINDOW")"
proj_tmux_attach "$SESSION" "$DETACHED"
