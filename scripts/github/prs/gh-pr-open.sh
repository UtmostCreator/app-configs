#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib/pr-config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/pr-config.sh"

require_cmd gh
require_cmd jq
require_cmd yq
require_cmd fzf

require_config

selection="$({
  query='query {
    viewer {
      pullRequests(first: 80, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          number
          title
          url
          reviewDecision
          repository {
            nameWithOwner
          }
        }
      }
    }
  }'

  gh api graphql -f query="$query" | jq -c '.data.viewer.pullRequests.nodes[]'
} | while IFS= read -r row; do
  repo="$(jq -r '.repository.nameWithOwner' <<<"$row")"
  if ! repo_allowed "$repo"; then
    continue
  fi

  number="$(jq -r '.number' <<<"$row")"
  decision="$(jq -r '.reviewDecision // "UNKNOWN"' <<<"$row")"
  title="$(jq -r '.title' <<<"$row")"
  url="$(jq -r '.url' <<<"$row")"

  printf '%s#%s\t%s\t%s\t%s\n' "$repo" "$number" "$decision" "$title" "$url"
done | fzf --height 50% --border --delimiter=$'\t' --with-nth 1,2,3 --prompt 'Open PR > ')"

[[ -z "$selection" ]] && exit 0
url="$(printf '%s' "$selection" | cut -f4)"

if has_cmd open; then
  open "$url"
else
  echo "$url"
fi
