#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${GH_PR_WATCH_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-pr-watch/events.log}"

command -v fzf >/dev/null 2>&1 || { echo "Missing required command: fzf" >&2; exit 127; }

# Parse log into: repo#N - Title, URL  (one entry per unique URL)
# Log structure:
#   HH:MM:SS  event: org/repo#N - PR Title    <- top-level event
#   HH:MM:SS    detail...                      <- indented detail (skip)
#   HH:MM:SS    https://github.com/.../pull/N  <- URL line
NOISE='^(DEBUG|WARN|cycle |sound |running |ERROR|config:|interval:|state:|log:|default sound:|gh-pr-watch )'
selected="$(awk -v noise="$NOISE" '
  /^[0-9]{2}:[0-9]{2}:[0-9]{2}  / {
    content = $0
    sub(/^[0-9]{2}:[0-9]{2}:[0-9]{2}  /, "", content)
    if (content ~ /^  https:\/\/github\.com\/[^ ]+\/pull\/[0-9]+/) {
      url = substr(content, 3)
      if (prev != "") {
        # Extract "repo#N - Title" — strip org/ prefix and event-type prefix
        label = prev
        if (match(label, /[^\/: ]+#[0-9]+ - .+/))
          label = substr(label, RSTART, RLENGTH)
        # Deduplicate by URL; last-seen event wins
        entries[url] = label
      }
      prev = ""
    } else if (content !~ /^  /) {
      prev = (content ~ noise) ? "" : content
    }
  }
  END {
    for (url in entries)
      printf "%s, %s\n", entries[url], url
  }
' "$LOG_FILE" \
  | sort \
  | fzf --height 40% --border --prompt 'PR > ' \
        --preview 'echo {}' --preview-window=up:2:wrap)"

[[ -z "$selected" ]] && exit 0

url="$(printf '%s' "$selected" | grep -Eo 'https://github.com/[^ ]+/pull/[0-9]+')"

if command -v open >/dev/null 2>&1; then
  open "$url"
else
  printf '%s\n' "$url"
fi
