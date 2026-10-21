#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../workspace/config.sh"

# Tmux workspace bootstrap.
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │                                   app-log                                    │
# │                              backend log output                              │
# │                             (LOG_PERCENT = 25%)                              │
# ├───────────────────────────────────────┬──────────────────────────────────────┤
# │                                       │                                      │
# │          ui-components-shell          │            payments-shell            │
# │           (UI_PERCENT = 25%)          │       (PAYMENTS_PERCENT = 25%)       │
# │                                       │                                      │
# ├───────────────────────────────────────┼──────────────────────────────────────┤
# │                                       │          web-frontend-shell          │
# │             backend-shell             │       (FRONTEND_PERCENT = 30%)       │
# │        (remaining left height)        ├──────────────────────────────────────┤
# │                                       │          integration-shell           │
# │                                       │       (remaining right height)       │
# └───────────────────────────────────────┴──────────────────────────────────────┘
#
# PERCENTAGE MODEL, absolute and window-relative:
#
#   LOG_PERCENT      = 25%  → app-log, top, full width
#   UI_PERCENT       = 25%  → ui-components, left, below log
#   PAYMENTS_PERCENT = 25%  → payments, right, below log
#   FRONTEND_PERCENT = 30%  → web-frontend, right, below payments
#
#   backend          = 100 − LOG − UI
#                    = 100 − 25 − 25
#                    = 50%
#
#   integration      = 100 − LOG − PAYMENTS − FRONTEND
#                    = 100 − 25 − 25 − 30
#                    = 20%
#
# ORDER MODEL:
#
#   1. Create tmux panes.
#   2. Start/check non-backend projects:
#        - ui-components
#        - payments
#        - web-frontend
#        - integration
#   3. Start services:
#        - backend dev stack
#        - frontend dev stack
#        - log watcher
#   4. In the backend pane:
#        - run verify-workspace.sh
#        - only if verification succeeds, run the backend git workflow
#
# NOTES:
# - All percentages are relative to the full tmux window height.
# - Left and right columns overlap vertically; their percentages do not sum together.
# - Vertical tmux splits consume one row for a border.
# - Final pane heights may differ by ±1 row due to integer rounding.
#
# Usage:
#   bash <open-workspace-script> [--detached] [--force]

SESSION="$WS_TMUX_SESSION"
MAIN_WINDOW="workspace"
SERVICES_WINDOW="services"
DETACHED="0"

LOG_PERCENT=25
UI_PERCENT=25
PAYMENTS_PERCENT=25
FRONTEND_PERCENT=30

percent_rows() {
  local total_rows="$1"
  local percent="$2"

  echo $(( (total_rows * percent + 50) / 100 ))
}

get_tmux_width() {
  if [ -n "${TMUX:-}" ]; then
    tmux display-message -p '#{client_width}'
  else
    tput cols
  fi
}

get_tmux_height() {
  if [ -n "${TMUX:-}" ]; then
    tmux display-message -p '#{window_height}'
  else
    echo $(( $(tput lines) - 1 ))
  fi
}

apply_window_border_theme() {
  local window_target="$1"
  local inactive_border_style="$2"
  local active_border_style="$3"

  tmux set-window-option -t "$window_target" pane-border-status top >/dev/null
  tmux set-window-option -t "$window_target" pane-border-style "$inactive_border_style" >/dev/null
  tmux set-window-option -t "$window_target" pane-active-border-style "$active_border_style" >/dev/null
  tmux set-window-option -t "$window_target" pane-border-format ' #{pane_title} ' >/dev/null
}

run_bootstrap_in_pane() {
  local pane_id="$1"
  local command="$2"
  local keep_shell="${3:-1}"
  local shell_bin="${SHELL:-/bin/zsh}"
  local payload="$command"
  local quoted_payload
  local quoted_shell

  if [[ "$keep_shell" == "1" ]]; then
    payload+="; exec \"$shell_bin\" -l"
  fi

  quoted_shell=$(printf '%q' "$shell_bin")
  quoted_payload=$(printf '%q' "$payload")
  tmux respawn-pane -k -t "$pane_id" "$quoted_shell -lc $quoted_payload"
}

send_clean_repo_shell() {
  local pane_id="$1"
  local repo_name="$2"
  local repo_path="$3"
  local q_repo_name
  local q_repo_path
  local q_repo_checks_script

  repo_path="${repo_path/#\~/$HOME}"
  q_repo_name=$(printf '%q' "$repo_name")
  q_repo_path=$(printf '%q' "$repo_path")
  q_repo_checks_script=$(printf '%q' "$WS_SCRIPT_REPO_CHECKS")

  run_bootstrap_in_pane "$pane_id" \
    "cd $q_repo_path && bash $q_repo_checks_script $q_repo_name && echo && if [ -z \"\$(git status --porcelain)\" ]; then git checkout main && git pull; fi && echo && cd $q_repo_path"
}

send_frontend_repo_shell() {
  local pane_id="$1"
  local q_frontend_dir
  local q_repo_checks_script

  q_frontend_dir=$(printf '%q' "$WS_FRONTEND_APP_DIR")
  q_repo_checks_script=$(printf '%q' "$WS_SCRIPT_REPO_CHECKS")

  run_bootstrap_in_pane "$pane_id" \
    "cd $q_frontend_dir && bash $q_repo_checks_script web-frontend && echo && cd $q_frontend_dir"
}

send_integration_repo_shell() {
  local pane_id="$1"
  local q_integration_dir
  local q_repo_checks_script

  q_integration_dir=$(printf '%q' "$WS_INTEGRATION_APP_DIR")
  q_repo_checks_script=$(printf '%q' "$WS_SCRIPT_REPO_CHECKS")

  run_bootstrap_in_pane "$pane_id" \
    "cd $q_integration_dir && bash $q_repo_checks_script integration && echo && cd $q_integration_dir"
}

send_backend_verify_then_git_workflow() {
  local pane_id="$1"
  local cmd
  local q_backend_dir
  local q_verify_script
  local q_repo_checks_script

  q_backend_dir=$(printf '%q' "$WS_BACKEND_APP_DIR")
  q_verify_script=$(printf '%q' "$WS_SCRIPT_VERIFY_WORKSPACE")
  q_repo_checks_script=$(printf '%q' "$WS_SCRIPT_REPO_CHECKS")

  cmd="cd $q_backend_dir"
  cmd+=' && echo'
  cmd+=' && echo "Running workspace verification before backend git workflow..."'
  cmd+=" && bash $q_verify_script"
  cmd+=' && echo'
  cmd+=' && echo "Workspace verification completed successfully. Running backend git workflow..."'
  cmd+=" && bash $q_repo_checks_script backend"
  cmd+=' && echo'
  cmd+=' && RELEASE_BRANCH=$(git branch -a | sed "s|.*remotes/origin/||;s|^\* *||;s|^ *||" | grep -E "^release-[0-9]" | sort -V | tail -1)'
  cmd+=' && if [ -z "$(git status --porcelain)" ] && [ -n "$RELEASE_BRANCH" ]; then'
  cmd+='   if git show-ref --verify --quiet refs/heads/"$RELEASE_BRANCH"; then'
  cmd+='     git checkout "$RELEASE_BRANCH" && git pull;'
  cmd+='   else'
  cmd+='     git checkout -b "$RELEASE_BRANCH" "origin/$RELEASE_BRANCH";'
  cmd+='   fi;'
  cmd+=' else'
  cmd+='   echo "Skipping backend checkout/pull because working tree is not clean or no release-* branch was found.";'
  cmd+=' fi'
  cmd+=' && echo'
  cmd+=" && cd $q_backend_dir"

  run_bootstrap_in_pane "$pane_id" "$cmd"
}

for arg in "$@"; do
  case "$arg" in
    --detached)
      DETACHED="1"
      ;;
    --force)
      tmux kill-session -t "$SESSION" 2>/dev/null || true
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: bash $WS_SCRIPT_OPEN_WORKSPACE [--detached] [--force]"
      exit 1
      ;;
  esac
done

if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
  elif [ "$DETACHED" = "1" ]; then
    echo "tmux session $SESSION is already running"
  else
    tmux attach-session -t "$SESSION"
  fi
  exit 0
fi

SESSION_WIDTH=$(get_tmux_width)
SESSION_HEIGHT=$(get_tmux_height)

tmux new-session -d \
  -x "$SESSION_WIDTH" \
  -y "$SESSION_HEIGHT" \
  -s "$SESSION" \
  -n "$MAIN_WINDOW"
tmux set-option -t "$SESSION" detach-on-destroy on >/dev/null

WINDOW_TARGET="$SESSION:$MAIN_WINDOW"
apply_window_border_theme "$WINDOW_TARGET" "fg=colour240" "fg=colour118,bold"
TOTAL_ROWS=$(tmux display-message -p -t "$WINDOW_TARGET" '#{window_height}')

LOG_ROWS=$(percent_rows "$TOTAL_ROWS" "$LOG_PERCENT")
UI_ROWS=$(percent_rows "$TOTAL_ROWS" "$UI_PERCENT")
PAYMENTS_ROWS=$(percent_rows "$TOTAL_ROWS" "$PAYMENTS_PERCENT")
FRONTEND_ROWS=$(percent_rows "$TOTAL_ROWS" "$FRONTEND_PERCENT")

P_LOG=$(tmux display-message -p -t "$WINDOW_TARGET" '#{pane_id}')
tmux select-pane -t "$P_LOG" -T "APP-logs"
tmux set-option -p -t "$P_LOG" @workspace_role "app-logs"

BOTTOM_ROWS=$(( TOTAL_ROWS - LOG_ROWS - 1 ))

if [ "$BOTTOM_ROWS" -lt 10 ]; then
  echo "Terminal is too short for this layout"
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  exit 1
fi

P_BOTTOM=$(tmux split-window -v -l "$BOTTOM_ROWS" -t "$P_LOG" -P -F '#{pane_id}')

P_RIGHT=$(tmux split-window -h -p 50 -t "$P_BOTTOM" -P -F '#{pane_id}')
P_LEFT="$P_BOTTOM"

BACKEND_ROWS=$(( BOTTOM_ROWS - UI_ROWS - 1 ))

if [ "$BACKEND_ROWS" -lt 3 ]; then
  echo "Terminal is too short for the left column layout"
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  exit 1
fi

P_BACKEND=$(tmux split-window -v -l "$BACKEND_ROWS" -t "$P_LEFT" -P -F '#{pane_id}')

FRONTEND_GROUP_ROWS=$(( BOTTOM_ROWS - PAYMENTS_ROWS - 1 ))

if [ "$FRONTEND_GROUP_ROWS" -lt 6 ]; then
  echo "Terminal is too short for the right column layout"
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  exit 1
fi

P_FRONTEND_GROUP=$(tmux split-window -v -l "$FRONTEND_GROUP_ROWS" -t "$P_RIGHT" -P -F '#{pane_id}')

INTEGRATION_ROWS=$(( FRONTEND_GROUP_ROWS - FRONTEND_ROWS - 1 ))

if [ "$INTEGRATION_ROWS" -lt 3 ]; then
  echo "Terminal is too short for the frontend/integration layout"
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  exit 1
fi

P_INTEGRATION=$(tmux split-window -v -l "$INTEGRATION_ROWS" -t "$P_FRONTEND_GROUP" -P -F '#{pane_id}')

tmux select-pane -t "$P_LEFT" -T "UI-COMPONENTS"
tmux select-pane -t "$P_BACKEND" -T "BACKEND"
tmux select-pane -t "$P_RIGHT" -T "PAYMENTS"
tmux select-pane -t "$P_FRONTEND_GROUP" -T "FRONTEND"
tmux select-pane -t "$P_INTEGRATION" -T "INTEGRATION"

# Start/check non-backend project panes first.
send_clean_repo_shell "$P_LEFT" "ui-components" "$WS_UI_COMPONENTS_DIR"
send_clean_repo_shell "$P_RIGHT" "payments" "$WS_PAYMENTS_DIR"
send_frontend_repo_shell "$P_FRONTEND_GROUP"
send_integration_repo_shell "$P_INTEGRATION"

# Start log watcher.
run_bootstrap_in_pane "$P_LOG" "bash $WS_SCRIPT_WATCH_LOGS"

# Start services window.
tmux new-window -d -t "$SESSION:" -n "$SERVICES_WINDOW"
SERVICES_TARGET="$SESSION:$SERVICES_WINDOW"
apply_window_border_theme "$SERVICES_TARGET" "fg=colour237" "fg=colour118,bold"

P_SERVICES_BACKEND=$(tmux display-message -p -t "$SESSION:$SERVICES_WINDOW" '#{pane_id}')
tmux select-pane -t "$P_SERVICES_BACKEND" -T "$WS_PANE_BACKEND"
tmux set-option -p -t "$P_SERVICES_BACKEND" @workspace_role "$WS_PANE_BACKEND"
run_bootstrap_in_pane "$P_SERVICES_BACKEND" "bash $WS_SCRIPT_START_STACK"

P_SERVICES_FRONTEND=$(tmux split-window -v -t "$P_SERVICES_BACKEND" -P -F '#{pane_id}')
tmux select-pane -t "$P_SERVICES_FRONTEND" -T "$WS_PANE_FRONTEND"
tmux set-option -p -t "$P_SERVICES_FRONTEND" @workspace_role "$WS_PANE_FRONTEND"
run_bootstrap_in_pane "$P_SERVICES_FRONTEND" "bash $WS_SCRIPT_START_FRONTEND"

# Run this last.
#
# This is intentionally one chained command in the backend pane:
#   verify-workspace.sh && backend git workflow
#
# Therefore, the backend checkout/pull logic cannot run unless
# verify-workspace.sh has completed successfully.
send_backend_verify_then_git_workflow "$P_BACKEND"

tmux select-window -t "$WINDOW_TARGET"
tmux select-pane -t "$P_BACKEND"

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION"
elif [ "$DETACHED" = "1" ]; then
  echo "tmux session $SESSION started in detached mode"
else
  tmux attach-session -t "$SESSION"
fi
