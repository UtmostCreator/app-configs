#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${GH_PR_WATCH_CONFIG:-$HOME/.config/gh-pr-watch/config.yml}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gh-pr-watch"
SEEN_NOTIFICATIONS_FILE="$STATE_DIR/seen-notifications.txt"
PR_STATE_FILE="$STATE_DIR/my-prs.json"
LOG_FILE="${GH_PR_WATCH_LOG:-$STATE_DIR/events.log}"
INTERVAL_OVERRIDE="${GH_PR_WATCH_INTERVAL:-}"

RUN_ONCE=0
SOUND_CHECK=0
DEBUG_MODE="${GH_PR_WATCH_DEBUG:-0}"
PR_SCOPE="all"
VIEWER_LOGIN=""

# JSON producer mode (PLAN.md §5/§10, Phase 0). When --format json is given,
# the watcher emits a canonical prs.json artifact via the prw-portal toolchain
# and exits — no log noise, no sounds, no watch loop.
OUTPUT_FORMAT="log"
PRW_PROFILE_ARG="${GH_PR_WATCH_PROFILE:-}"
PRW_OUT_ARG="${GH_PR_WATCH_JSON_OUT:-}"

# Locate the prw-portal package (sibling repo layout). Allow override.
PRW_PORTAL_DIR="${PRW_PORTAL_DIR:-}"
if [[ -z "$PRW_PORTAL_DIR" ]]; then
  _gpw_self_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  for _cand in \
    "$_gpw_self_dir/../../../prw-portal" \
    "$_gpw_self_dir/prw-portal"; do
    if [[ -d "$_cand" ]]; then
      PRW_PORTAL_DIR="$(cd -P "$_cand" >/dev/null 2>&1 && pwd)"
      break
    fi
  done
fi

_args=("$@")
_i=0
while [[ $_i -lt ${#_args[@]} ]]; do
  arg="${_args[$_i]}"
  case "$arg" in
    --once)
      RUN_ONCE=1
      ;;
    --sound-check)
      SOUND_CHECK=1
      ;;
    --debug)
      DEBUG_MODE=1
      ;;
    --my)
      PR_SCOPE="my"
      ;;
    --all)
      PR_SCOPE="all"
      ;;
    --others)
      PR_SCOPE="others"
      ;;
    --format)
      _i=$((_i + 1))
      OUTPUT_FORMAT="${_args[$_i]:-log}"
      ;;
    --format=*)
      OUTPUT_FORMAT="${arg#--format=}"
      ;;
    --profile)
      _i=$((_i + 1))
      PRW_PROFILE_ARG="${_args[$_i]:-}"
      ;;
    --profile=*)
      PRW_PROFILE_ARG="${arg#--profile=}"
      ;;
    --out)
      _i=$((_i + 1))
      PRW_OUT_ARG="${_args[$_i]:-}"
      ;;
    --out=*)
      PRW_OUT_ARG="${arg#--out=}"
      ;;
    *)
      ;;
  esac
  _i=$((_i + 1))
done

mkdir -p "$STATE_DIR"
touch "$SEEN_NOTIFICATIONS_FILE"
touch "$LOG_FILE"

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! has_cmd "$1"; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

require_cmd gh
require_cmd jq
require_cmd yq

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing config file: $CONFIG_PATH" >&2
  exit 1
fi

interval() {
  if [[ -n "$INTERVAL_OVERRIDE" ]]; then
    printf '%s\n' "$INTERVAL_OVERRIDE"
  else
    yq -r '.interval // 20' "$CONFIG_PATH"
  fi
}

default_sound() {
  yq -r '.defaults.sound // "/System/Library/Sounds/Glass.aiff"' "$CONFIG_PATH"
}

bell_fallback_enabled() {
  yq -r '.defaults.terminal_bell_fallback // true' "$CONFIG_PATH"
}

event_enabled() {
  local event="$1"
  yq -e ".events.\"$event\".enabled // false" "$CONFIG_PATH" >/dev/null 2>&1
}

event_sound() {
  local event="$1"
  yq -r ".events.\"$event\".sound // .defaults.sound // \"/System/Library/Sounds/Glass.aiff\"" "$CONFIG_PATH"
}

read_list() {
  local expr="$1"
  yq -r "$expr" "$CONFIG_PATH" 2>/dev/null | sed '/^null$/d' || true
}

list_has() {
  local needle="$1"
  local haystack="$2"
  [[ -z "$haystack" ]] && return 1
  grep -Fxq "$needle" <<<"$haystack"
}

repo_allowed() {
  local full_repo="$1"
  local short_repo="${full_repo##*/}"
  local include_repos include_repo_names exclude_repos exclude_repo_names

  include_repos="$(read_list '.repos.include_repos // [] | .[]')"
  include_repo_names="$(read_list '.repos.include_repo_names // [] | .[]')"
  exclude_repos="$(read_list '.repos.exclude_repos // [] | .[]')"
  exclude_repo_names="$(read_list '.repos.exclude_repo_names // [] | .[]')"

  if list_has "$full_repo" "$exclude_repos" || list_has "$short_repo" "$exclude_repo_names"; then
    return 1
  fi

  if [[ -z "$include_repos" && -z "$include_repo_names" ]]; then
    return 0
  fi

  if list_has "$full_repo" "$include_repos" || list_has "$short_repo" "$include_repo_names"; then
    return 0
  fi

  return 1
}

configured_repositories() {
  local include_repos include_repo_names default_owner repo_name

  include_repos="$(read_list '.repos.include_repos // [] | .[]')"
  include_repo_names="$(read_list '.repos.include_repo_names // [] | .[]')"
  default_owner="$(yq -r '.repos.default_owner // ""' "$CONFIG_PATH")"

  if [[ -n "$include_repos" ]]; then
    printf '%s\n' "$include_repos"
  fi

  while IFS= read -r repo_name; do
    [[ -z "$repo_name" ]] && continue
    if [[ "$repo_name" == */* ]]; then
      printf '%s\n' "$repo_name"
    elif [[ -n "$default_owner" ]]; then
      printf '%s/%s\n' "$default_owner" "$repo_name"
    fi
  done <<<"$include_repo_names"
}

say_line() {
  local line
  line="$(date '+%H:%M:%S')  $*"
  printf '%s\n' "$line"
  printf '%s\n' "$line" >> "$LOG_FILE"
}

debug_line() {
  if [[ "$DEBUG_MODE" == "1" ]]; then
    say_line "DEBUG: $*"
  fi
}

notify_sound() {
  local event="$1"
  local sound_file
  local bell_enabled

  sound_file="$(event_sound "$event")"
  bell_enabled="$(bell_fallback_enabled)"

  if [[ -f "$sound_file" ]] && has_cmd afplay; then
    afplay "$sound_file" >/dev/null 2>&1 &
    debug_line "sound played for event '$event' using '$sound_file'"
    return
  fi

  if [[ "$bell_enabled" == "true" ]]; then
    printf '\a'
    debug_line "bell fallback used for event '$event'"
  else
    say_line "WARN: sound skipped for event '$event' (file missing and bell fallback disabled)"
  fi
}

validate_enabled_sounds() {
  local event sound enabled_count=0

  if ! has_cmd afplay; then
    say_line "WARN: afplay not found, sound playback unavailable; bell fallback may be used"
  fi

  while IFS= read -r event; do
    [[ -z "$event" ]] && continue
    (( enabled_count++ )) || true
    sound="$(event_sound "$event")"
    if [[ -f "$sound" ]]; then
      say_line "sound ready: $event -> $sound"
    else
      say_line "WARN: missing sound file for $event -> $sound"
    fi
  done < <(yq -r '.events | to_entries[] | select(.value.enabled == true) | .key' "$CONFIG_PATH")

  if [[ "$enabled_count" -eq 0 ]]; then
    say_line "WARN: no enabled events found in config"
  fi
}

run_sound_check() {
  local event

  say_line "running sound check for enabled events"
  while IFS= read -r event; do
    [[ -z "$event" ]] && continue
    say_line "sound check: $event"
    notify_sound "$event"
  done < <(yq -r '.events | to_entries[] | select(.value.enabled == true) | .key' "$CONFIG_PATH")
  say_line "sound check completed"
}

check_auth() {
  gh auth status >/dev/null 2>&1 || {
    echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
    exit 1
  }
}

viewer_login() {
  if [[ -z "$VIEWER_LOGIN" ]]; then
    VIEWER_LOGIN="$(gh api user --jq '.login' 2>/dev/null || true)"
  fi
  printf '%s\n' "$VIEWER_LOGIN"
}

fetch_notifications() {
  gh api notifications --method GET -f participating=false -f all=false --paginate
}

fetch_my_open_prs() {
  local query
  query='query {
    viewer {
      pullRequests(first: 100, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          id
          number
          title
          bodyText
          url
          updatedAt
          reviewDecision
          repository {
            nameWithOwner
          }
          comments(first: 1) {
            totalCount
          }
          reactions(first: 1) {
            totalCount
          }
          reactionGroups {
            content
            users {
              totalCount
            }
          }
        }
      }
    }
  }'

  gh api graphql -f query="$query" | jq '.data.viewer.pullRequests.nodes // []'
}

fetch_repo_open_prs() {
  local full_repo="$1"
  # Rich field set: adds body, state, reactionGroups, assignees, and
  # reviewRequests so the canonical prs.json can carry reactions (with content),
  # assignees, and requested reviewers (PLAN.md event contract). All of these are
  # supported `gh pr list --json` fields.
  # NOTE: do not request `commits` here; large repos can exceed GraphQL
  # traversal limits when commit objects are expanded.
  gh pr list --repo "$full_repo" --state open --limit 200 \
    --json number,title,url,reviewDecision,isDraft,author,headRefName,baseRefName,createdAt,updatedAt,comments,additions,deletions,changedFiles,body,state,reactionGroups,assignees,reviewRequests,latestReviews
}

# Single source of truth for mapping `gh pr list` JSON into the normalized raw
# row shape the JSON producer expects. Used by build_all_rows and
# emit_open_pr_snapshot so the two paths never drift.
PR_ROW_NORMALIZE_JQ='
  map((.comments // []) as $comments | {
    repo: $repo,
    number,
    title,
    url,
    author_login: (.author.login // ""),
    head_ref: (.headRefName // ""),
    base_ref: (.baseRefName // ""),
    createdAt: (.createdAt // ""),
    updatedAt: (.updatedAt // ""),
    comments_count: (if ($comments|type) == "array" then ($comments|length) else ($comments // 0) end),
    latest_comment_text: (if ($comments|type) == "array" then (($comments | last | .body) // "") else "" end),
    commits_count: (if (.commits|type) == "array" then (.commits|length) else (.commits // 0) end),
    additions: (.additions // 0),
    deletions: (.deletions // 0),
    changed_files: (.changedFiles // 0),
    is_draft: (.isDraft // false),
    review_decision: (.reviewDecision // ""),
    is_mine: ((.author.login // "") == $me),
    body: (.body // ""),
    state: (.state // "OPEN"),
    reactionGroups: (.reactionGroups // []),
    assignees: (.assignees // []),
    reviewRequests: (.reviewRequests // []),
    latestReviews: (.latestReviews // [])
  })
'

# normalize_repo_rows <repo> <viewer_login> <prs_json>
# Emits the normalized rows array for one repo on stdout.
normalize_repo_rows() {
  local repo="$1" me="$2" prs_json="$3"
  jq -c --arg repo "$repo" --arg me "$me" "$PR_ROW_NORMALIZE_JQ" <<<"$prs_json"
}

# build_all_rows — fetch every configured repo's open PRs and return the
# normalized raw rows array on stdout (same shape the JSON producer expects).
# Logging goes to stderr so callers can capture clean JSON on stdout.
build_all_rows() {
  local full_repo prs_json my_login all_rows
  local snapshot_err="$STATE_DIR/repo-snapshot.err"
  local repo_count=0
  local -a full_repos

  mapfile -t full_repos < <(configured_repositories | awk 'NF' | sort -u)
  my_login="$(viewer_login)"
  all_rows='[]'

  if [[ "${#full_repos[@]}" -eq 0 ]]; then
    echo "WARN: no full repos configured for startup snapshot (set repos.include_repos or repos.default_owner)" >&2
    printf '%s' "$all_rows"
    return 0
  fi

  for full_repo in "${full_repos[@]}"; do
    (( repo_count++ )) || true

    if prs_json="$(fetch_repo_open_prs "$full_repo" 2>"$snapshot_err")"; then
      all_rows="$(jq -c -n --argjson a "$all_rows" --argjson b "$(normalize_repo_rows "$full_repo" "$my_login" "$prs_json")" '$a + $b')"
    else
      echo "WARN: failed to fetch open PR snapshot for $full_repo" >&2
      if [[ -s "$snapshot_err" ]]; then
        echo "WARN: snapshot error: $(tr '\n' ' ' < "$snapshot_err" | sed 's/[[:space:]]\+/ /g')" >&2
      fi
      return 1
    fi
  done

  printf '%s' "$all_rows"
}

# build_notifications_json — convert GitHub PR notifications into the canonical
# `notifications[]` contract shape (reason/repo/pr_number/title/url/ts) so the
# portal can surface mention / team_mention / assign / comment / review_requested
# / state_change / author events that are not tied to one of *your* open PRs.
# Repo-filtered via repo_allowed. Emits a JSON array on stdout (never fails the
# snapshot; returns "[]" on any error).
build_notifications_json() {
  local notifications_json
  local notifications_err="$STATE_DIR/notifications-json.err"
  if ! notifications_json="$(fetch_notifications 2>"$notifications_err")"; then
    printf '%s' '[]'
    return 0
  fi
  [[ -n "$notifications_json" ]] || { printf '%s' '[]'; return 0; }

  # Collect allowed-repo PR notifications, mapping the GitHub API subject URL to
  # an html PR url and the API repo to owner/name.
  local mapped='[]' item id reason repo title subject_url pr_url pr_number ts row
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    reason="$(jq -r '.reason // "unknown"' <<<"$item")"
    repo="$(jq -r '.repo' <<<"$item")"
    repo_allowed "$repo" || continue
    title="$(jq -r '.title // ""' <<<"$item")"
    subject_url="$(jq -r '.subject_url // ""' <<<"$item")"
    ts="$(jq -r '.updated_at // ""' <<<"$item")"
    pr_url="$(api_pr_url_to_html "$subject_url")"
    if [[ "$pr_url" =~ /pull/([0-9]+)$ ]]; then
      pr_number="${BASH_REMATCH[1]}"
    else
      pr_number="null"
    fi
    row="$(jq -cn \
      --arg reason "$reason" \
      --arg repo "$repo" \
      --argjson pr_number "$pr_number" \
      --arg title "$title" \
      --arg url "$pr_url" \
      --arg ts "$ts" \
      '{reason:$reason, repo:$repo, pr_number:$pr_number, title:$title, url:$url, ts:$ts}')"
    mapped="$(jq -c -n --argjson a "$mapped" --argjson b "$row" '$a + [$b]')"
  done < <(
    jq -c '
      .[]
      | select(.subject.type == "PullRequest")
      | {reason, repo: .repository.full_name, title: .subject.title, updated_at: .updated_at, subject_url: (.subject.url // "")}
    ' <<<"$notifications_json"
  )

  printf '%s' "$mapped"
}

# emit_prs_json_snapshot — Phase 0 JSON producer (PLAN.md §5/§8).
# Builds rows, applies $PR_SCOPE filter, then delegates to the prw-portal
# toolchain (single source of truth derivation + atomic write).
emit_prs_json_snapshot() {
  if [[ -z "$PRW_PORTAL_DIR" || ! -d "$PRW_PORTAL_DIR" ]]; then
    echo "ERROR: prw-portal package not found (set PRW_PORTAL_DIR)" >&2
    exit 1
  fi

  local all_rows scoped_rows
  all_rows="$(build_all_rows)"

  scoped_rows="$(jq -c --arg scope "$PR_SCOPE" '
    if $scope == "my" then map(select(.is_mine))
    elif $scope == "others" then map(select(.is_mine | not))
    else . end
  ' <<<"$all_rows")"

  export PRW_ROOT="$PRW_PORTAL_DIR"
  # shellcheck source=/dev/null
  source "$PRW_PORTAL_DIR/lib/prw-derive.sh"
  # shellcheck source=/dev/null
  source "$PRW_PORTAL_DIR/lib/prw-config.sh"
  # shellcheck source=/dev/null
  source "$PRW_PORTAL_DIR/lib/prw-emit-json.sh"
  # shellcheck source=/dev/null
  source "$PRW_PORTAL_DIR/lib/prw-io.sh"

  # Resolve config precedence (CLI > config > defaults) for jira settings.
  prw_resolve_config

  export PRW_PROFILE="${PRW_PROFILE_ARG:-local}"
  PRW_VIEWER_LOGIN="$(viewer_login)"
  export PRW_VIEWER_LOGIN

  # Collect PR notifications (mention/team/assign/comment/...) for the contract's
  # top-level notifications[]. Best-effort: never blocks the snapshot.
  PRW_NOTIFICATIONS_JSON="$(build_notifications_json 2>/dev/null || printf '[]')"
  export PRW_NOTIFICATIONS_JSON

  local target
  if [[ -n "$PRW_OUT_ARG" ]]; then
    target="$PRW_OUT_ARG"
  else
    local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/prw"
    target="$cache_root/$PRW_PROFILE/prs.json"
  fi

  # Emit, then atomically write through the schema/summary/enum verifier.
  prw_emit_prs_json "$scoped_rows" \
    | prw_atomic_write "$target" \
        bash "$PRW_PORTAL_DIR/bin/prw" verify prs

  echo "wrote $target" >&2
}

emit_open_pr_snapshot() {
  local full_repo prs_json row number title url status mine_tag
  local my_login all_rows sorted_rows
  local snapshot_count=0 repo_count=0
  local snapshot_err="$STATE_DIR/repo-snapshot.err"

  mapfile -t full_repos < <(configured_repositories | awk 'NF' | sort -u)
  my_login="$(viewer_login)"
  all_rows='[]'

  if [[ "${#full_repos[@]}" -eq 0 ]]; then
    say_line "WARN: no full repos configured for startup snapshot (set repos.include_repos or repos.default_owner)"
    return
  fi

  say_line "open PR snapshot: repos=${#full_repos[@]} scope=$PR_SCOPE"

  for full_repo in "${full_repos[@]}"; do
    (( repo_count++ )) || true

    if prs_json="$(fetch_repo_open_prs "$full_repo" 2>"$snapshot_err")"; then
      all_rows="$(jq -c -n --argjson a "$all_rows" --argjson b "$(normalize_repo_rows "$full_repo" "$my_login" "$prs_json")" '$a + $b')"
    else
      say_line "WARN: failed to fetch open PR snapshot for $full_repo"
      if [[ -s "$snapshot_err" ]]; then
        say_line "WARN: snapshot error: $(tr '\n' ' ' < "$snapshot_err" | sed 's/[[:space:]]\+/ /g')"
      fi
    fi
  done

  sorted_rows="$(jq -c --arg scope "$PR_SCOPE" '
    def status_rank:
      if .is_draft then 4
      elif .review_decision == "CHANGES_REQUESTED" then 0
      elif .review_decision == "REVIEW_REQUIRED" then 1
      elif .review_decision == "OPEN" or .review_decision == "" then 2
      elif .review_decision == "APPROVED" then 3
      else 2
      end;
    (if $scope == "my" then map(select(.is_mine))
     elif $scope == "others" then map(select(.is_mine | not))
     else . end)
    | sort_by((if .is_mine then 0 else 1 end), status_rank, .repo, .number)
  ' <<<"$all_rows")"

  if [[ "$(jq 'length' <<<"$sorted_rows" 2>/dev/null || echo 0)" == "0" ]]; then
    say_line "snapshot: [NONE] no open PRs for scope=$PR_SCOPE"
  else
    while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      number="$(jq -r '.number' <<<"$row")"
      title="$(jq -r '.title' <<<"$row")"
      url="$(jq -r '.url' <<<"$row")"

      if [[ "$(jq -r '.is_draft' <<<"$row")" == "true" ]]; then
        status="DRAFT"
      else
        case "$(jq -r '.review_decision' <<<"$row")" in
          CHANGES_REQUESTED) status="CHANGES_REQUESTED" ;;
          REVIEW_REQUIRED) status="REVIEW_REQUIRED" ;;
          APPROVED) status="APPROVED" ;;
          *) status="OPEN" ;;
        esac
      fi

      mine_tag="$(jq -r '.author_login // ""' <<<"$row")"
      if [[ "$(jq -r '.is_mine' <<<"$row")" == "true" ]]; then
        mine_tag="MY"
      elif [[ -z "$mine_tag" || "$mine_tag" == "null" ]]; then
        mine_tag="OTHER"
      fi

      say_line "snapshot: [$status] [$mine_tag] $(jq -r '.repo' <<<"$row")#$number - $title | refs: $(jq -r '.head_ref // ""' <<<"$row") -> $(jq -r '.base_ref // ""' <<<"$row") | times: created=$(jq -r '.createdAt // ""' <<<"$row") updated=$(jq -r '.updatedAt // ""' <<<"$row")"
      say_line "  $url"
      (( snapshot_count++ )) || true
    done < <(jq -c '.[]' <<<"$sorted_rows")
  fi

  say_line "open PR snapshot summary: repos=$repo_count prs=$snapshot_count"
}

mark_notification_seen() {
  local id="$1"
  echo "$id" >> "$SEEN_NOTIFICATIONS_FILE"
}

notification_seen() {
  local id="$1"
  grep -Fxq "$id" "$SEEN_NOTIFICATIONS_FILE"
}

api_pr_url_to_html() {
  local api_url="$1"
  if [[ "$api_url" =~ ^https://api.github.com/repos/([^/]+/[^/]+)/pulls/([0-9]+)$ ]]; then
    printf 'https://github.com/%s/pull/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  printf '%s\n' "$api_url"
}

handle_notifications() {
  local notifications_json="$1"
  local item id reason repo title subject_url pr_url
  local total_count=0 seen_skip_count=0 repo_skip_count=0 disabled_skip_count=0 notified_count=0

  total_count="$(jq '. | length' <<<"$notifications_json" 2>/dev/null || echo 0)"

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue

    id="$(jq -r '.id' <<<"$item")"
    reason="$(jq -r '.reason // "unknown"' <<<"$item")"
    repo="$(jq -r '.repo' <<<"$item")"
    title="$(jq -r '.title' <<<"$item")"
    subject_url="$(jq -r '.subject_url // ""' <<<"$item")"
    pr_url="$(api_pr_url_to_html "$subject_url")"

    if notification_seen "$id"; then
      (( seen_skip_count++ )) || true
      continue
    fi

    if ! repo_allowed "$repo"; then
      (( repo_skip_count++ )) || true
      mark_notification_seen "$id"
      continue
    fi

    if ! event_enabled "$reason"; then
      (( disabled_skip_count++ )) || true
      mark_notification_seen "$id"
      continue
    fi

    case "$reason" in
      review_requested) say_line "review requested: $repo - $title" ;;
      team_mention) say_line "team mentioned: $repo - $title" ;;
      mention) say_line "mentioned on PR: $repo - $title" ;;
      comment) say_line "comment on PR: $repo - $title" ;;
      assign) say_line "assigned on PR: $repo - $title" ;;
      state_change) say_line "PR state changed: $repo - $title" ;;
      author) say_line "activity on your PR: $repo - $title" ;;
      *) say_line "PR notification [$reason]: $repo - $title" ;;
    esac

    if [[ -n "$pr_url" ]]; then
      say_line "  $pr_url"
    fi

    notify_sound "$reason"
    mark_notification_seen "$id"
    (( notified_count++ )) || true
  done < <(
    jq -c '
      .[]
      | select(.subject.type == "PullRequest")
      | {id, reason, repo: .repository.full_name, title: .subject.title, updated_at: .updated_at, subject_url: (.subject.url // "")}
    ' <<<"$notifications_json"
  )

  say_line "cycle notifications: total=$total_count notified=$notified_count skipped_seen=$seen_skip_count skipped_repo=$repo_skip_count skipped_event_disabled=$disabled_skip_count"
}

handle_my_pr_transitions() {
  local current_json="$1"
  local row id repo number title body_text url current_updated_at current_decision current_comments current_reactions
  local previous_decision previous_comments previous_reactions previous_title previous_body previous_updated_at
  local current_reaction_groups previous_reaction_groups reaction_deltas
  local merged_state
  local tracked_count=0 approval_events=0 changes_requested_events=0 review_required_events=0 comment_events=0 reaction_events=0 content_events=0
  local total_open_count=0

  total_open_count="$(jq '. | length' <<<"$current_json" 2>/dev/null || echo 0)"

  if [[ ! -f "$PR_STATE_FILE" ]]; then
    jq -S '.' <<<"$current_json" > "$PR_STATE_FILE"
    return
  fi

  while IFS= read -r row; do
    [[ -z "$row" ]] && continue

    id="$(jq -r '.id' <<<"$row")"
    repo="$(jq -r '.repo' <<<"$row")"

    if ! repo_allowed "$repo"; then
      continue
    fi

    (( tracked_count++ )) || true

    number="$(jq -r '.number' <<<"$row")"
    title="$(jq -r '.title' <<<"$row")"
    body_text="$(jq -r '.body_text // ""' <<<"$row")"
    url="$(jq -r '.url' <<<"$row")"
    current_updated_at="$(jq -r '.updated_at // ""' <<<"$row")"
    current_decision="$(jq -r '.reviewDecision // "UNKNOWN"' <<<"$row")"
    current_comments="$(jq -r '.comments // 0' <<<"$row")"
    current_reactions="$(jq -r '.reactions // 0' <<<"$row")"
    current_reaction_groups="$(jq -c '.reaction_groups // {}' <<<"$row")"

    previous_decision="$(jq -r --arg id "$id" '(.[] | select(.id == $id) | .reviewDecision) // "UNKNOWN"' "$PR_STATE_FILE")"
    previous_comments="$(jq -r --arg id "$id" '(.[] | select(.id == $id) | .comments.totalCount) // 0' "$PR_STATE_FILE")"
    previous_reactions="$(jq -r --arg id "$id" '(.[] | select(.id == $id) | .reactions.totalCount) // 0' "$PR_STATE_FILE")"
    previous_title="$(jq -r --arg id "$id" '(.[] | select(.id == $id) | .title) // ""' "$PR_STATE_FILE")"
    previous_body="$(jq -r --arg id "$id" '(.[] | select(.id == $id) | .bodyText) // ""' "$PR_STATE_FILE")"
    previous_updated_at="$(jq -r --arg id "$id" '(.[] | select(.id == $id) | .updatedAt) // ""' "$PR_STATE_FILE")"
    previous_reaction_groups="$(jq -c --arg id "$id" '((.[] | select(.id == $id) | (reduce .reactionGroups[]? as $g ({}; .[$g.content] = ($g.users.totalCount // 0)))) // {})' "$PR_STATE_FILE")"

    if [[ "$previous_decision" != "APPROVED" && "$current_decision" == "APPROVED" ]] && event_enabled "approved"; then
      say_line "approved: $repo#$number - $title"
      say_line "  $url"
      notify_sound "approved"
      (( approval_events++ )) || true
    fi

    if [[ "$previous_decision" != "CHANGES_REQUESTED" && "$current_decision" == "CHANGES_REQUESTED" ]] && event_enabled "changes_requested"; then
      say_line "changes requested: $repo#$number - $title"
      say_line "  $url"
      notify_sound "changes_requested"
      (( changes_requested_events++ )) || true
    fi

    if [[ "$previous_decision" != "REVIEW_REQUIRED" && "$current_decision" == "REVIEW_REQUIRED" ]] && event_enabled "review_required"; then
      say_line "review required: $repo#$number - $title"
      say_line "  $url"
      notify_sound "review_required"
      (( review_required_events++ )) || true
    fi

    if [[ "$current_comments" =~ ^[0-9]+$ && "$previous_comments" =~ ^[0-9]+$ ]] && (( current_comments > previous_comments )) && event_enabled "my_pr_new_comments"; then
      say_line "new comment count on your PR: $repo#$number - $title"
      say_line "  comments: $previous_comments -> $current_comments"
      say_line "  $url"
      notify_sound "my_pr_new_comments"
      (( comment_events++ )) || true
    fi

    reaction_deltas="$(jq -r -n --argjson prev "$previous_reaction_groups" --argjson cur "$current_reaction_groups" '
      [($cur | keys_unsorted[]) as $k
       | select(($cur[$k] // 0) != ($prev[$k] // 0))
       | "\($k):\($prev[$k] // 0)->\($cur[$k])"]
      | join(", ")
    ')"

    if [[ "$current_reactions" =~ ^[0-9]+$ && "$previous_reactions" =~ ^[0-9]+$ ]] \
      && { (( current_reactions != previous_reactions )) || [[ -n "$reaction_deltas" ]]; } \
      && event_enabled "reaction"; then
      if (( current_reactions > previous_reactions )); then
        say_line "new reaction on your PR: $repo#$number - $title"
      elif (( current_reactions < previous_reactions )); then
        say_line "reaction removed on your PR: $repo#$number - $title"
      else
        say_line "reaction changed on your PR: $repo#$number - $title"
      fi
      say_line "  reactions: $previous_reactions -> $current_reactions"
      if [[ -n "$reaction_deltas" ]]; then
        say_line "  by type: $reaction_deltas"
      fi
      say_line "  $url"
      notify_sound "reaction"
      (( reaction_events++ )) || true
    fi

    if event_enabled "content_changed" && { [[ "$title" != "$previous_title" ]] || [[ "$body_text" != "$previous_body" ]] || [[ "$current_updated_at" != "$previous_updated_at" ]]; }; then
      say_line "content changed: $repo#$number - $title"
      if [[ "$title" != "$previous_title" ]]; then
        say_line "  title edited"
      fi
      if [[ "$body_text" != "$previous_body" ]]; then
        say_line "  description/body edited"
      fi
      if [[ "$current_updated_at" != "$previous_updated_at" ]]; then
        say_line "  updatedAt: $previous_updated_at -> $current_updated_at"
      fi
      say_line "  $url"
      notify_sound "content_changed"
      (( content_events++ )) || true
    fi
  done < <(
    jq -c '
      .[]
      | {
          id,
          repo: .repository.nameWithOwner,
          number,
          title,
          body_text: (.bodyText // ""),
          url,
          updated_at: (.updatedAt // ""),
          reviewDecision,
          comments: (.comments.totalCount // 0),
          reactions: (.reactions.totalCount // 0),
          reaction_groups: (reduce .reactionGroups[]? as $g ({}; .[$g.content] = ($g.users.totalCount // 0)))
        }
    ' <<<"$current_json"
  )

  merged_state="$(jq -c -n --argjson prev "$(jq -c '.' "$PR_STATE_FILE")" --argjson cur "$current_json" '
    def by_id: reduce .[] as $item ({}; .[$item.id] = $item);
    ((($prev // []) | by_id) + (($cur // []) | by_id))
    | to_entries
    | map(.value)
  ')"

  jq -S '.' <<<"$merged_state" > "$PR_STATE_FILE"
  say_line "cycle my-prs: total_open=$total_open_count tracked=$tracked_count approvals=$approval_events changes_requested=$changes_requested_events review_required=$review_required_events comment_increases=$comment_events reaction_increases=$reaction_events content_changes=$content_events"
}

print_startup() {
  say_line "gh-pr-watch started"
  say_line "config: $CONFIG_PATH"
  say_line "interval: $(interval)s"
  say_line "state: $STATE_DIR"
  say_line "log: $LOG_FILE"
  say_line "default sound: $(default_sound)"
  say_line "scope: $PR_SCOPE"
}

run_cycle() {
  local notifications_json prs_json
  local notifications_err prs_err

  notifications_err="$STATE_DIR/notifications.err"
  prs_err="$STATE_DIR/prs.err"

  if notifications_json="$(fetch_notifications 2>"$notifications_err")"; then
    :
  else
    say_line "WARN: failed to fetch notifications; using empty set"
    if [[ -s "$notifications_err" ]]; then
      say_line "WARN: notifications error: $(tr '\n' ' ' < "$notifications_err" | sed 's/[[:space:]]\+/ /g')"
    fi
    notifications_json='[]'
  fi
  handle_notifications "$notifications_json"

  if [[ "$PR_SCOPE" != "others" ]]; then
    if prs_json="$(fetch_my_open_prs 2>"$prs_err")"; then
      :
    else
      say_line "WARN: failed to fetch my open PRs; using empty set"
      if [[ -s "$prs_err" ]]; then
        say_line "WARN: my-prs error: $(tr '\n' ' ' < "$prs_err" | sed 's/[[:space:]]\+/ /g')"
      fi
      prs_json='[]'
    fi
    handle_my_pr_transitions "$prs_json"
  else
    say_line "cycle my-prs: skipped (scope=others)"
  fi
}

main() {
  # JSON producer mode (PLAN.md §5/§10): emit canonical prs.json and exit.
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    check_auth
    emit_prs_json_snapshot
    exit 0
  fi

  check_auth
  print_startup
  validate_enabled_sounds

  if [[ "$SOUND_CHECK" == "1" ]]; then
    run_sound_check
    exit 0
  fi

  emit_open_pr_snapshot

  if [[ "$RUN_ONCE" == "1" ]]; then
    run_cycle
    exit 0
  fi

  while true; do
    run_cycle
    sleep "$(interval)"
  done
}

main
