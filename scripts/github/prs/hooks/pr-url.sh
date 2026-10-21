#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pr-url.sh [--open] [--push] [--base <branch>] [--ticket <TICKET>] [--title <title>] [--help] [-- <git-push-args...>]

Build a GitHub compare URL that pre-fills the PR creation form using query params.

Defaults:
  owner/repo: from git remote origin URL
  base:       main (or GH_PR_BASE)
  branch:     current git branch
  ticket:     from --ticket, TICKET env, or branch name (e.g. ABC-1234)
  title:      latest commit subject (or ticket/branch fallback)
  body:       ticket + test template + latest commit details

Environment:
  GH_PR_BASE       Default base branch override
  GH_PR_URL_OPEN   Set to 1/true/yes to auto-open generated URL
  GH_PR_PUSH_FIRST Set to 1/true/yes to run git push before generating/opening URL
EOF
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! has_cmd "$1"; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

require_cmd git
require_cmd python3

open_after=0
push_first=0
base="${GH_PR_BASE:-main}"
input_ticket="${TICKET:-}"
input_title=""
push_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --open)
      open_after=1
      shift
      ;;
    --base)
      [[ $# -ge 2 ]] || { echo "--base requires a value" >&2; exit 2; }
      base="$2"
      shift 2
      ;;
    --push)
      push_first=1
      shift
      ;;
    --ticket)
      [[ $# -ge 2 ]] || { echo "--ticket requires a value" >&2; exit 2; }
      input_ticket="$2"
      shift 2
      ;;
    --title)
      [[ $# -ge 2 ]] || { echo "--title requires a value" >&2; exit 2; }
      input_title="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      push_args=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${GH_PR_URL_OPEN:-}" =~ ^(1|true|yes)$ ]]; then
  open_after=1
fi

if [[ "${GH_PR_PUSH_FIRST:-}" =~ ^(1|true|yes)$ ]]; then
  push_first=1
fi

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  echo "Could not determine current branch." >&2
  exit 1
fi

if [[ "$push_first" -eq 1 ]]; then
  git push "${push_args[@]}"
  # Requested behavior: after a successful push, open the generated PR URL.
  open_after=1
fi

remote_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ -z "$remote_url" ]]; then
  echo "Could not determine origin remote URL." >&2
  exit 1
fi

if [[ "$remote_url" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
elif [[ "$remote_url" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
else
  echo "Unsupported origin URL format: $remote_url" >&2
  exit 1
fi

repo="${repo%.git}"

ticket="$input_ticket"
if [[ -z "$ticket" ]]; then
  if [[ "$branch" =~ (${TICKET_PREFIX:-[A-Z]+}-[0-9]+) ]]; then
    ticket="${BASH_REMATCH[1]}"
  fi
fi

latest_subject="$(git log -1 --pretty=%s 2>/dev/null || true)"

title="$input_title"
if [[ -z "$title" ]]; then
  if [[ -n "$latest_subject" ]]; then
    title="$latest_subject"
  elif [[ -n "$ticket" ]]; then
    title="$ticket"
  else
    title="$branch"
  fi
fi

if [[ -n "$ticket" ]]; then
  ticket_key="$ticket"
else
  ticket_key="${TICKET_PREFIX:-ABC}-NNNN"
fi

ticket_link="${JIRA_BASE_URL:-https://example.atlassian.net}/browse/$ticket_key"

body="$(cat <<EOF
# Ticket
- [$ticket_key]($ticket_link)

## Changes

1.

## Testing

### Specialised tests

<details>
<summary>Expand ➕  / Collapse ➖</summary>

\`\`\`shell

\`\`\`

</details>

### All tests

<details>
<summary>Expand ➕  / Collapse ➖</summary>

\`\`\`shell

\`\`\`

</details>

## Additional Info
EOF
)"

url="$({
  OWNER="$owner" \
  REPO="$repo" \
  BASE="$base" \
  BRANCH="$branch" \
  TITLE="$title" \
  BODY="$body" \
  python3 - <<'PY'
import os
from urllib.parse import quote

owner = os.environ["OWNER"]
repo = os.environ["REPO"]
base = os.environ["BASE"]
branch = os.environ["BRANCH"]
title = os.environ["TITLE"]
body = os.environ["BODY"]

print(
    f"https://github.com/{owner}/{repo}/compare/{base}...{branch}"
    f"?quick_pull=1"
    f"&title={quote(title)}"
    f"&body={quote(body)}"
)
PY
})"

printf '%s\n' "$url"

if [[ "$open_after" -eq 1 ]]; then
  if ! git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "Skipping auto-open: origin/$branch was not found. Push the branch first, or use --push." >&2
    exit 1
  fi

  if has_cmd open; then
    open "$url"
  elif has_cmd xdg-open; then
    xdg-open "$url"
  else
    echo "No opener command found (open/xdg-open)." >&2
    exit 1
  fi
fi
