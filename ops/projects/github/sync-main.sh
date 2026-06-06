#!/usr/bin/env bash
# Fetch + switch + fast-forward 'main' on every project that has a repo_url.
# Generic — no project names hard-coded.
#
# Usage:
#   bash ops/projects/github/sync-main.sh           # all projects
#   bash ops/projects/github/sync-main.sh <id>      # one project

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/lib.sh
source "$SCRIPT_DIR/../lib.sh"

require_cmd git yq

sync_one() {
  local id="$1"
  local dir
  dir="$(proj_field "$id" dir)"
  [[ -z "$dir" ]] && { proj_log "skip $id (no dir)"; return 0; }
  dir="$(proj_expand_path "$dir")"
  if [[ ! -d "$dir/.git" ]]; then
    proj_log "skip $id (no .git at $dir)"
    return 0
  fi
  printf '\n=== %s ===\n' "$id"
  cd "$dir" || return 1
  git fetch --prune origin
  git status --short --branch
  if [[ "$(git branch --show-current)" != "main" ]]; then
    git switch main
  fi
  git pull --ff-only origin main
}

if [[ $# -ge 1 ]]; then
  sync_one "$1"
else
  for id in $(proj_ids); do
    sync_one "$id"
  done
fi
