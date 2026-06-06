#!/usr/bin/env bash
# Per-repo health-and-context check. Used by tmux-master.sh when it
# opens each project pane.
#
# Prints, for the given project id:
#   - current branch
#   - upstream / divergence summary
#   - any unstaged or untracked files
#   - last commit one-liner
#
# Generic — no project-specific names. The id is a key in
# ~/.config/projects/config.yaml `projects:`; the script reads the
# `dir` field to locate the repo.
#
# Usage:
#   bash ops/projects/repo-checks.sh <project-id>

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ $# -ne 1 ]]; then
  proj_fail "usage: $0 <project-id>"
fi
ID="$1"
DIR="$(proj_field "$ID" dir)"
[[ -z "$DIR" ]] && proj_fail "no project '$ID' (or no dir) in $PROJECTS_CONFIG"
DIR="$(proj_expand_path "$DIR")"
LABEL="$(proj_field_default "$ID" pane_label "${ID^^}")"

cd "$DIR" || proj_fail "cannot enter $DIR"

printf '== %s ==\n' "$LABEL"
printf 'dir: %s\n' "$DIR"

if [[ ! -d .git ]]; then
  printf '[warn] not a git repository\n'
  exit 0
fi

require_cmd git

branch="$(git branch --show-current 2>/dev/null || echo '(detached)')"
printf 'branch: %s\n' "$branch"

# shellcheck disable=SC1083  # the {u} is git's literal upstream syntax
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  ahead_behind="$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || echo "? ?")"
  printf 'upstream: %s  (behind/ahead: %s)\n' "$upstream" "$ahead_behind"
fi

printf 'last commit: %s\n' "$(git log -1 --pretty='%h %s (%cr)')"

dirty="$(git status --porcelain 2>/dev/null)"
if [[ -n "$dirty" ]]; then
  printf 'working tree: %s changes\n' "$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')"
  printf '%s\n' "$dirty" | head -10 | sed 's/^/  /'
else
  printf 'working tree: clean\n'
fi
