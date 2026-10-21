#!/usr/bin/env bash
# Count Netlify function log records in short UTC windows. The CLI returns a limited batch per query,
# so long windows are truncated: use short windows and treat a count of 100 as "possibly truncated".
# Read-only. Requires: netlify CLI (logged in and linked to the site), GNU date (gdate on macOS).
# Usage: window-counts.sh FUNCTION SECONDS START_UTC [START_UTC...]
#   window-counts.sh server 5 2026-10-13T08:16:30Z 2026-10-13T08:17:30Z
set -euo pipefail
fn=${1:?usage: window-counts.sh FUNCTION SECONDS START_UTC...}
secs=${2:?usage: window-counts.sh FUNCTION SECONDS START_UTC...}
shift 2
date_bin=$(command -v gdate || command -v date)
command -v netlify >/dev/null 2>&1 || { echo "netlify CLI not found" >&2; exit 1; }
for start in "$@"; do
  end=$("$date_bin" -u -d "$start + $secs seconds" +"%Y-%m-%dT%H:%M:%SZ")
  count=$(netlify logs --source functions --function "$fn" --since "$start" --until "$end" --json 2>/dev/null | wc -l | tr -d ' ')
  note=""; [[ "$count" -ge 100 ]] && note="  (>=100: window may be truncated, shorten it)"
  printf '%s  %s s  %s records%s\n' "$start" "$secs" "$count" "$note"
done
