#!/usr/bin/env bash
# notify.sh — tmux + desktop notifications for the backend health monitor.
#
# `source` this file from monitor.sh. Behavior is identical to the
# original inline implementation.

tmux_notice() {
  local level="$1"
  local message="$2"
  if [[ -n "${TMUX:-}" ]]; then
    tmux display-message "[$level] $message"
  fi
}

desktop_notice() {
  local title="$1"
  local message="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$message\" with title \"$title\"" >/dev/null 2>&1 &
  fi
}
