#!/usr/bin/env bash
# SSH workspace: opens one tmux pane per host listed in
# ~/.config/projects/config.yaml ssh_workspace.hosts.
#
# Each host must already be defined in ~/.ssh/config — this script
# only calls `ssh <alias>`. No credentials, no hostnames, no IPs
# are stored in the repo. Real ssh aliases live in
# home/.chezmoidata/projects.yaml (gitignored).
#
# Usage:
#   bash ops/projects/tmux-ssh.sh [--detached] [--force]

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
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) proj_fail "unknown arg: $arg" ;;
  esac
done

require_cmd tmux yq

mapfile -t HOSTS < <(proj_yq '.ssh_workspace.hosts[]?')
if [[ ${#HOSTS[@]} -eq 0 ]]; then
  proj_fail "no ssh_workspace.hosts declared in $PROJECTS_CONFIG"
fi

SESSION="$(proj_yq '.ssh_workspace.session // "remote-shells"')"

[[ "$FORCE" == "1" ]] && tmux kill-session -t "$SESSION" 2>/dev/null || true
if proj_tmux_session_exists "$SESSION"; then
  proj_tmux_attach "$SESSION" "$DETACHED"
  exit 0
fi

WINDOW="ssh"
tmux new-session -d -s "$SESSION" -n "$WINDOW"
tmux set-option -t "$SESSION" detach-on-destroy on >/dev/null
tmux set-window-option -t "$SESSION:$WINDOW" pane-border-status top >/dev/null
tmux set-window-option -t "$SESSION:$WINDOW" pane-border-format ' #{pane_title} ' >/dev/null

FIRST=1
PREV=""
for host in "${HOSTS[@]}"; do
  if (( FIRST )); then
    PANE=$(proj_tmux_pane_id "$SESSION" "$WINDOW")
    FIRST=0
  else
    PANE=$(tmux split-window -h -t "$PREV" -P -F '#{pane_id}')
  fi
  tmux select-pane -t "$PANE" -T "$host"
  tmux send-keys -t "$PANE" "ssh $host" Enter
  PREV="$PANE"
done

tmux select-pane -t "$(proj_tmux_pane_id "$SESSION" "$WINDOW")"
proj_tmux_attach "$SESSION" "$DETACHED"
