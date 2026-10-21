#!/usr/bin/env bash
set -euo pipefail

# gh-pr-status.sh — list the viewer's open PRs (config-filtered).
#
#   (default)   human-readable lines: "[DECISION] repo#num - title" + url
#   --json      machine-readable JSON array of the same filtered rows, for
#               compatibility with the prw portal data tooling.

OUTPUT_MODE="text"
for arg in "$@"; do
  case "$arg" in
    --json) OUTPUT_MODE="json" ;;
    -h|--help)
      echo "usage: gh-pr-status.sh [--json]" >&2
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "usage: gh-pr-status.sh [--json]" >&2
      exit 2
      ;;
  esac
done

# shellcheck source=lib/pr-config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/pr-config.sh"

require_cmd gh
require_cmd jq
require_cmd yq

require_config

query='query {
  viewer {
    pullRequests(first: 50, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
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

prs_json="$(gh api graphql -f query="$query")"

# JSON mode: emit one structured array of the config-filtered rows. Field names
# mirror the prw prs.json contract (repo, number, title, url, review_decision)
# so downstream tooling can consume it the same way.
if [[ "$OUTPUT_MODE" == "json" ]]; then
  rows='[]'
  while IFS= read -r row; do
    repo="$(jq -r '.repository.nameWithOwner' <<<"$row")"
    repo_allowed "$repo" || continue
    rows="$(jq -c \
      --argjson acc "$rows" \
      --arg repo "$repo" \
      '$acc + [{
        repo: $repo,
        number: .number,
        title: .title,
        url: .url,
        review_decision: (.reviewDecision // null)
      }]' <<<"$row")"
  done < <(jq -c '.data.viewer.pullRequests.nodes[]' <<<"$prs_json")
  jq -n --argjson items "$rows" '{type:"pr-status",count:($items|length),items:$items}'
  exit 0
fi

jq -c '.data.viewer.pullRequests.nodes[]' <<<"$prs_json" | while IFS= read -r row; do
  repo="$(jq -r '.repository.nameWithOwner' <<<"$row")"
  if ! repo_allowed "$repo"; then
    continue
  fi

  decision="$(jq -r '.reviewDecision // "UNKNOWN"' <<<"$row")"
  number="$(jq -r '.number' <<<"$row")"
  title="$(jq -r '.title' <<<"$row")"
  url="$(jq -r '.url' <<<"$row")"

  printf '[%s] %s#%s - %s\n' "$decision" "$repo" "$number" "$title"
  printf '  %s\n' "$url"
done
