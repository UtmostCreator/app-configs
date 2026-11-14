#!/usr/bin/env bash
# Fetch origin and fast-forward local 'main' on every project that has a
# dir. Generic — no project names hard-coded.
#
# Never switches the project's checkout and never merges into any branch
# other than main:
#   - checkout is on main         -> fast-forward it in place
#   - main checked out nowhere    -> fast-forward the ref (no working tree)
#   - main checked out elsewhere  -> fast-forward that worktree if clean
# Anything else (fetch failure, divergence, dirty worktree) is reported and
# the project counts as failed; other projects still run, and the script
# exits non-zero if any project failed.
#
# Usage:
#   bash ops/projects/github/sync-main.sh           # all projects
#   bash ops/projects/github/sync-main.sh <id>      # one project

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/lib.sh
source "$SCRIPT_DIR/../lib.sh"

require_cmd git yq

sync_err() {
  printf '[projects][ERROR] %s: %s\n' "$1" "$2" >&2
}

# Print the path of the worktree that has refs/heads/main checked out, if any.
main_worktree() {
  git -C "$1" worktree list --porcelain | awk '
    /^worktree / { wt = substr($0, 10) }
    $0 == "branch refs/heads/main" { print wt; exit }'
}

sync_one() {
  local id="$1"
  local dir
  dir="$(proj_field "$id" dir)" || { sync_err "$id" "cannot read project config"; return 1; }
  [[ -z "$dir" ]] && { proj_log "skip $id (no dir)"; return 0; }
  dir="$(proj_expand_path "$dir")"
  if [[ ! -e "$dir/.git" ]]; then
    proj_log "skip $id (no .git at $dir)"
    return 0
  fi
  printf '\n=== %s ===\n' "$id"

  if ! git -C "$dir" fetch --prune origin; then
    sync_err "$id" "git fetch origin failed; main left untouched"
    return 1
  fi
  git -C "$dir" status --short --branch
  if ! git -C "$dir" rev-parse --verify -q refs/remotes/origin/main >/dev/null; then
    sync_err "$id" "origin/main does not exist; main left untouched"
    return 1
  fi

  local current holder
  current="$(git -C "$dir" branch --show-current)"
  holder="$(main_worktree "$dir")"

  if [[ "$current" == "main" ]]; then
    if ! git -C "$dir" merge --ff-only origin/main; then
      sync_err "$id" "cannot fast-forward main to origin/main in $dir (diverged or local changes in the way)"
      return 1
    fi
  elif [[ -z "$holder" ]]; then
    # Fast-forward-only ref update; no working tree is touched.
    if ! git -C "$dir" fetch -q . refs/remotes/origin/main:refs/heads/main; then
      sync_err "$id" "cannot fast-forward main to origin/main (local main has diverged)"
      return 1
    fi
    printf 'main -> %s\n' "$(git -C "$dir" rev-parse --short refs/heads/main)"
  else
    if [[ ! -d "$holder" ]]; then
      sync_err "$id" "main is checked out in missing worktree $holder; run 'git worktree prune'"
      return 1
    fi
    if [[ -n "$(git -C "$holder" status --porcelain)" ]]; then
      sync_err "$id" "main is checked out in $holder with uncommitted changes; not updating it"
      return 1
    fi
    printf 'updating main in worktree %s\n' "$holder"
    if ! git -C "$holder" merge --ff-only origin/main; then
      sync_err "$id" "cannot fast-forward main to origin/main in $holder (local main has diverged)"
      return 1
    fi
  fi
}

rc=0
if [[ $# -ge 1 ]]; then
  sync_one "$1" || rc=1
else
  ids="$(proj_ids)" || proj_fail "cannot list projects from $PROJECTS_CONFIG"
  for id in $ids; do
    sync_one "$id" || rc=1
  done
fi
exit "$rc"
