#!/usr/bin/env bash
# Minimal PR watcher.
#
# Polls `gh pr list` for PRs in repos listed under
# ~/.config/projects/config.yaml github.pr_watch.include_repos.
# On a state transition (new PR, review_requested, merged, closed,
# CI failure) prints one line and emits a terminal bell unless
# `events.<name>.enabled = false`.
#
# State across runs lives at $XDG_STATE_HOME/projects/pr-watch-state.json
# so transitions are detected reliably even across restarts.
#
# Modes:
#   default   — poll forever
#   --once    — single poll and exit
#
# Anonymisation: no repo names appear in this file. All filtering is
# config-driven. Disable the watcher by setting github.pr_watch.enabled
# to false in your projects.yaml.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/lib.sh
source "$SCRIPT_DIR/../lib.sh"

ONCE=0
for arg in "$@"; do
  case "$arg" in
    --once) ONCE=1 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *) proj_fail "unknown arg: $arg" ;;
  esac
done

require_cmd gh jq yq

ENABLED="$(proj_yq '.github.pr_watch.enabled // false')"
if [[ "$ENABLED" != "true" ]]; then
  proj_log "github.pr_watch.enabled is not true — exiting"
  exit 0
fi

INTERVAL="$(proj_yq '.github.pr_watch.interval_seconds // 20')"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/projects"
STATE_FILE="$STATE_DIR/pr-watch-state.json"
mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE" ]] || echo '{}' >"$STATE_FILE"

event_enabled() {
  local name="$1"
  local v
  v="$(proj_yq ".github.pr_watch.events.\"$name\".enabled // false")"
  [[ "$v" == "true" ]]
}

bell_if_enabled() {
  local event="$1"
  if event_enabled "$event"; then
    if command -v afplay >/dev/null 2>&1; then
      afplay /System/Library/Sounds/Ping.aiff >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then
      paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 &
    else
      printf '\a'
    fi
  fi
}

poll_repo() {
  local repo="$1"
  local prs
  # statusCheckRollup gives us per-PR aggregated CI status without a
  # second API call; mergedAt lets us distinguish merge vs close on
  # the next poll.
  prs="$(gh pr list --repo "$repo" --state open \
    --json number,title,author,reviewDecision,mergeable,updatedAt,statusCheckRollup \
    2>/dev/null || echo '[]')"
  [[ -z "$prs" || "$prs" == "[]" ]] && return 0

  echo "$prs" | jq -c '.[]' | while read -r pr; do
    local num title author key prev_state new_state
    local prev_review new_review prev_ci new_ci
    num="$(jq -r '.number' <<<"$pr")"
    title="$(jq -r '.title' <<<"$pr")"
    author="$(jq -r '.author.login // "unknown"' <<<"$pr")"
    key="${repo}#${num}"
    # Roll the latest statusCheckRollup state up to a single label
    # so we can compare prev/new without re-parsing the array.
    new_ci="$(jq -r '
      [.statusCheckRollup // [] | .[] | (.conclusion // .state // "PENDING")] as $s
      | if ($s | length) == 0 then "NONE"
        elif ($s | any(. == "FAILURE" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ERROR")) then "FAILURE"
        elif ($s | any(. == "PENDING" or . == "IN_PROGRESS" or . == "QUEUED" or . == "EXPECTED")) then "PENDING"
        else "SUCCESS"
        end
    ' <<<"$pr")"
    new_review="$(jq -r '.reviewDecision // "NONE"' <<<"$pr")"
    new_state="$(jq -nc \
      --arg review "$new_review" --arg ci "$new_ci" \
      --arg mergeable "$(jq -r '.mergeable' <<<"$pr")" \
      --arg updatedAt "$(jq -r '.updatedAt' <<<"$pr")" \
      '{review:$review, ci:$ci, mergeable:$mergeable, updatedAt:$updatedAt}')"
    prev_state="$(jq -c --arg k "$key" '.[$k] // empty' "$STATE_FILE")"
    prev_review="$(jq -r '.review // empty' <<<"${prev_state:-{}}")"
    prev_ci="$(jq -r '.ci // empty' <<<"${prev_state:-{}}")"

    if [[ -z "$prev_state" ]]; then
      printf '[pr-watch][NEW]      %s "%s" by @%s\n' "$key" "$title" "$author"
      bell_if_enabled pr_opened
    else
      # Decompose into specific transitions so the right event key
      # drives the bell. A single poll cycle can legitimately fire
      # more than one event (review request landed at the same time
      # CI flipped) — we let each one ring once.
      if [[ "$prev_review" != "$new_review" && "$new_review" == "REVIEW_REQUIRED" ]]; then
        printf '[pr-watch][REVIEW]   %s "%s" → %s\n' "$key" "$title" "$new_review"
        bell_if_enabled pr_review_requested
      fi
      if [[ "$prev_ci" != "FAILURE" && "$new_ci" == "FAILURE" ]]; then
        printf '[pr-watch][CI FAIL] %s "%s" → CI %s\n' "$key" "$title" "$new_ci"
        bell_if_enabled ci_failed
      fi
      if [[ "$prev_state" != "$new_state" \
            && "$prev_review" == "$new_review" \
            && "$prev_ci" == "$new_ci" ]]; then
        # Generic change that does not match a named event; log only,
        # no bell, so users do not get false review_requested alerts.
        printf '[pr-watch][update]   %s "%s"\n' "$key" "$title"
      fi
    fi

    jq --arg k "$key" --argjson v "$new_state" '.[$k] = $v' "$STATE_FILE" >"${STATE_FILE}.new" \
      && mv "${STATE_FILE}.new" "$STATE_FILE"
  done

  # Detect closes/merges: any state-file key whose PR is no longer in
  # the open list. We cannot tell merge from close here without an
  # extra API call, so we ring pr_merged on either — and stop tracking
  # the key. If you only want merge alerts, gate pr_merged in config.
  local open_keys
  open_keys="$(echo "$prs" | jq -r --arg r "$repo" '.[] | "\($r)#\(.number)"')"
  jq -r 'keys[]' "$STATE_FILE" | while read -r k; do
    [[ "$k" != "$repo#"* ]] && continue
    if ! grep -Fxq "$k" <<<"$open_keys"; then
      printf '[pr-watch][CLOSED]   %s\n' "$k"
      bell_if_enabled pr_merged
      jq --arg k "$k" 'del(.[$k])' "$STATE_FILE" >"${STATE_FILE}.new" \
        && mv "${STATE_FILE}.new" "$STATE_FILE"
    fi
  done
}

while true; do
  mapfile -t REPOS < <(proj_yq '.github.pr_watch.include_repos[]?')
  if [[ ${#REPOS[@]} -eq 0 ]]; then
    proj_log "no github.pr_watch.include_repos — sleeping"
  else
    for repo in "${REPOS[@]}"; do
      poll_repo "$repo"
    done
  fi
  (( ONCE )) && break
  sleep "$INTERVAL"
done
