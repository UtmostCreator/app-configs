#!/usr/bin/env bash
# shellcheck shell=bash
# One lock for everything that mutates the repo or the Home Manager profile:
# sys-update (ops/update-all.sh) and the weekly codebase-memory-mcp updater
# (ops/update-codebase-memory-mcp.sh) both take "$STATE_DIR/lock", so they can
# never run at the same time.
#
#   sys_update_state_dir            the state directory both scripts share
#   acquire_state_lock STATE_DIR    0 = held (until the process exits)
#                                   1 = another run holds it
#
# The lock lives on file descriptor 9 for the life of the calling process.
# Hosts without flock(1) (stock macOS) get a warning and no lock, as there is
# no timer there to race with.

sys_update_state_dir() {
  printf '%s\n' "${SYS_UPDATE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sys-update}"
}

acquire_state_lock() {
  local dir="$1"
  mkdir -p "$dir" || return 1
  if ! command -v flock >/dev/null 2>&1; then
    printf >&2 'warning: flock is not installed; concurrent updates are not prevented\n'
    return 0
  fi
  exec 9>"$dir/lock" || return 1
  flock -n 9
}
