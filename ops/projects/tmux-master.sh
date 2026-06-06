#!/usr/bin/env bash
# Master tmux workspace.
#
# Layout:
#   top:    log pane (LOG_PERCENT of window height) — runs tmux-logs as embedded
#   left:   primary project shell (PRIMARY_PERCENT below log)
#           + bottom-left project shell (rest)
#   right:  secondary project shell (SECONDARY_PERCENT below log)
#           + tertiary project shell (TERTIARY_PERCENT)
#           + bottom-right project shell (rest)
#
# Projects are read in declaration order from ~/.config/projects/config.yaml:
#   index 0 → primary  (top-left, where repo-checks + branch workflow run)
#   index 1 → secondary (top-right)
#   index 2 → tertiary (middle-right)
#   index 3 → bottom-left
#   index 4 → bottom-right
#
# If fewer than 5 projects are defined the layout shrinks to fit. The
# session is also flagged to auto-start each project's `service.start_cmd`
# in a second tmux window.
#
# Usage:
#   bash ops/projects/tmux-master.sh [--detached] [--force]
#
# Anonymisation note: no project names appear in this file. Everything
# is read from $HOME/.config/projects/config.yaml.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/lib.sh
source "$SCRIPT_DIR/lib.sh"

DETACHED=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --detached) DETACHED=1 ;;
    --force)    FORCE=1 ;;
    -h|--help)
      sed -n '2,27p' "$0"
      exit 0
      ;;
    *)
      proj_fail "unknown arg: $arg"
      ;;
  esac
done

require_cmd tmux yq jq

SESSION="$(proj_tmux_session master_session dev-workspace)"
SERVICES_WINDOW="services"
MAIN_WINDOW="workspace"

[[ "$FORCE" == "1" ]] && tmux kill-session -t "$SESSION" 2>/dev/null || true

if proj_tmux_session_exists "$SESSION"; then
  proj_tmux_attach "$SESSION" "$DETACHED"
  exit 0
fi

# Collect project ids in declaration order.
mapfile -t IDS < <(proj_ids)
if [[ ${#IDS[@]} -eq 0 ]]; then
  proj_fail "no projects declared in $PROJECTS_CONFIG"
fi

LOG_PCT="$(proj_layout_percent log_percent 25)"
TERTIARY_PCT="$(proj_layout_percent tertiary_percent 30)"
# primary_percent and secondary_percent are reserved for future layouts
# that use absolute pane sizes; the current splits are 50/50 with the
# leftover going to the bottom row.

percent_rows() {
  local total="$1" pct="$2"
  echo $(( (total * pct + 50) / 100 ))
}

# Start the session and configure pane border titles.
tmux new-session -d -s "$SESSION" -n "$MAIN_WINDOW"
tmux set-option -t "$SESSION" detach-on-destroy on >/dev/null
tmux set-window-option -t "$SESSION:$MAIN_WINDOW" pane-border-status top >/dev/null
tmux set-window-option -t "$SESSION:$MAIN_WINDOW" pane-border-format ' #{pane_title} ' >/dev/null

TOTAL_ROWS=$(tmux display-message -p -t "$SESSION:$MAIN_WINDOW" '#{window_height}')
if (( TOTAL_ROWS < 24 )); then
  proj_log "warning: terminal height ${TOTAL_ROWS} is small; layout may be cramped"
fi

LOG_ROWS=$(percent_rows "$TOTAL_ROWS" "$LOG_PCT")

# Top: log pane.
P_LOG=$(proj_tmux_pane_id "$SESSION" "$MAIN_WINDOW")
tmux select-pane -t "$P_LOG" -T "logs"
tmux send-keys -t "$P_LOG" "bash $SCRIPT_DIR/tmux-logs.sh --inline" Enter

BOTTOM_ROWS=$(( TOTAL_ROWS - LOG_ROWS - 1 ))
P_BOTTOM=$(tmux split-window -v -l "$BOTTOM_ROWS" -t "$P_LOG" -P -F '#{pane_id}')

# Bottom: left + right split.
P_LEFT="$P_BOTTOM"
P_RIGHT=$(tmux split-window -h -p 50 -t "$P_BOTTOM" -P -F '#{pane_id}')

# ── Project assignment ──────────────────────────────────────────────────────
PRIMARY_ID="${IDS[0]:-}"
SECONDARY_ID="${IDS[1]:-}"
TERTIARY_ID="${IDS[2]:-}"
BOTTOM_L_ID="${IDS[3]:-}"
BOTTOM_R_ID="${IDS[4]:-}"

open_repo_in_pane() {
  # Reuse the same idiom as the original cms-open-workspace but with
  # config-driven names. Runs repo-checks first, then attempts a clean
  # main checkout if the working tree is clean.
  local pane="$1" id="$2"
  [[ -z "$id" ]] && return 0
  local dir
  dir="$(proj_field "$id" dir)"
  [[ -z "$dir" ]] && return 0
  dir="$(proj_expand_path "$dir")"
  local label
  label="$(proj_field_default "$id" pane_label "${id^^}")"
  tmux select-pane -t "$pane" -T "$label"
  local checks="$SCRIPT_DIR/repo-checks.sh"
  local cmd
  cmd="cd $(printf '%q' "$dir")"
  cmd+=" && bash $(printf '%q' "$checks") $(printf '%q' "$id")"
  # Optional branch_pattern: auto-checkout latest matching branch.
  local pattern
  pattern="$(proj_field "$id" branch_pattern)"
  if [[ -n "$pattern" && "$pattern" != "null" ]]; then
    cmd+=" && if [ -z \"\$(git status --porcelain)\" ]; then"
    cmd+=" BR=\$(git branch -a | sed 's|.*remotes/origin/||;s|^\* *||;s|^ *||' | grep -E '^${pattern}$' | sort -V | tail -1);"
    cmd+=" if [ -n \"\$BR\" ]; then"
    cmd+="   if git show-ref --verify --quiet refs/heads/\"\$BR\"; then git checkout \"\$BR\" && git pull; else git checkout -b \"\$BR\" \"origin/\$BR\"; fi;"
    cmd+=" fi;"
    cmd+=" fi"
  fi
  tmux send-keys -t "$pane" "$cmd" Enter
}

# Project pane assignment — driven by which of TERTIARY / BOTTOM_L / BOTTOM_R
# are set, NOT just by BOTTOM_*. Previous gate dropped TERTIARY when projects
# count was exactly 3, because the outer if only matched 4+. (Codex P1.)
#
# 1 project   → primary on left, right column empty
# 2 projects  → primary | secondary
# 3 projects  → primary | secondary stacked over tertiary
# 4 projects  → primary stacked over bottom_l | secondary stacked over tertiary
# 5 projects  → primary stacked over bottom_l | secondary, tertiary, bottom_r stacked

# Left column.
if [[ -n "$BOTTOM_L_ID" ]]; then
  P_LEFT_TOP="$P_LEFT"
  P_LEFT_BOTTOM=$(tmux split-window -v -p 50 -t "$P_LEFT" -P -F '#{pane_id}')
  open_repo_in_pane "$P_LEFT_TOP"    "$PRIMARY_ID"
  open_repo_in_pane "$P_LEFT_BOTTOM" "$BOTTOM_L_ID"
else
  open_repo_in_pane "$P_LEFT" "$PRIMARY_ID"
fi

# Right column. Tertiary row sizing currently uses tmux's 60/40 default;
# the explicit percent below is reserved for future refinements.
_UNUSED_TERTIARY_ROWS=$(percent_rows "$BOTTOM_ROWS" "$TERTIARY_PCT")

if [[ -z "$SECONDARY_ID" ]]; then
  : # nothing on the right
elif [[ -n "$TERTIARY_ID" && -n "$BOTTOM_R_ID" ]]; then
  P_RIGHT_TOP="$P_RIGHT"
  P_RIGHT_MID=$(tmux split-window -v -p 60 -t "$P_RIGHT_TOP" -P -F '#{pane_id}')
  P_RIGHT_BOTTOM=$(tmux split-window -v -p 50 -t "$P_RIGHT_MID" -P -F '#{pane_id}')
  open_repo_in_pane "$P_RIGHT_TOP"    "$SECONDARY_ID"
  open_repo_in_pane "$P_RIGHT_MID"    "$TERTIARY_ID"
  open_repo_in_pane "$P_RIGHT_BOTTOM" "$BOTTOM_R_ID"
elif [[ -n "$TERTIARY_ID" ]]; then
  P_RIGHT_TOP="$P_RIGHT"
  P_RIGHT_MID=$(tmux split-window -v -p 50 -t "$P_RIGHT_TOP" -P -F '#{pane_id}')
  open_repo_in_pane "$P_RIGHT_TOP" "$SECONDARY_ID"
  open_repo_in_pane "$P_RIGHT_MID" "$TERTIARY_ID"
else
  open_repo_in_pane "$P_RIGHT" "$SECONDARY_ID"
fi

# ── Services window ─────────────────────────────────────────────────────────
# Start each project's service.start_cmd in its own pane in a second window.
tmux new-window -d -t "$SESSION:" -n "$SERVICES_WINDOW"
FIRST=1
P_SVC_PREV=""
for id in "${IDS[@]}"; do
  start_cmd="$(proj_field "$id" service.start_cmd)"
  [[ -z "$start_cmd" || "$start_cmd" == "null" ]] && continue
  dir="$(proj_field "$id" dir)"
  [[ -z "$dir" ]] && continue
  dir="$(proj_expand_path "$dir")"
  pane_name="$(proj_field_default "$id" service.pane "${id}-service")"
  if (( FIRST )); then
    P_SVC=$(proj_tmux_pane_id "$SESSION" "$SERVICES_WINDOW")
    FIRST=0
  else
    P_SVC=$(tmux split-window -v -t "$P_SVC_PREV" -P -F '#{pane_id}')
  fi
  tmux select-pane -t "$P_SVC" -T "$pane_name"
  tmux send-keys -t "$P_SVC" "cd $(printf '%q' "$dir") && $start_cmd" Enter
  P_SVC_PREV="$P_SVC"
done

tmux select-window -t "$SESSION:$MAIN_WINDOW"
tmux select-pane -t "$P_LOG"
proj_tmux_attach "$SESSION" "$DETACHED"
