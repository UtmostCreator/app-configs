#!/usr/bin/env bash
set -euo pipefail

# Convert health-monitor JSON (--json) into markdown for glow rendering.

input="$(cat)"
if [[ -z "${input//[[:space:]]/}" ]]; then
  echo "# backend Health"
  echo
  echo "No data received."
  exit 0
fi

status="$(jq -r '.overall.label // "UNKNOWN"' <<<"$input")"
cause="$(jq -r '.overall.cause // "-"' <<<"$input")"
affected="$(jq -r '(.overall.affected // []) | if length == 0 then "none" else join(" · ") end' <<<"$input")"
timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

echo "# backend Health"
echo
printf -- "- Status: **%s**\n" "$status"
printf -- "- Cause: %s\n" "$cause"
printf -- "- Affected: %s\n" "$affected"
printf -- "- Updated: %s\n" "$timestamp"
echo

echo "## Root Issues"
if jq -e '(.root_issues // []) | length > 0' >/dev/null <<<"$input"; then
  jq -r '.root_issues[] | "- " + .' <<<"$input"
else
  echo "- none"
fi
echo

echo "## Fix Plan"
if jq -e '(.fix_plan // []) | length > 0' >/dev/null <<<"$input"; then
  jq -r '.fix_plan[] | "- " + .' <<<"$input" | awk '!seen[$0]++'
else
  echo "- none"
fi
echo

echo "## Project Status"
echo
printf '| Project | Status |\n'
printf '|---|---|\n'
jq -r '.sections[]? | "| " + (.name // "-") + " | " + ((.status // "-") | ascii_upcase) + " |"' <<<"$input"
echo

echo "## Endpoints"
echo
printf '| Service | Status | Notes |\n'
printf '|---|---|---|\n'
jq -r '.endpoints[]? | "| " + ((.name // "-") | sub(" endpoint$"; "")) + " | " + ((.status // "-") | ascii_upcase) + " | " + ((.notes // "-") | gsub("\\|"; "\\\\|")) + " |"' <<<"$input"
echo

echo "## Checks (non-OK)"
echo
printf '| Group | Check | Status | Message | Fix |\n'
printf '|---|---|---|---|---|\n'
if jq -e '[(.checks // [])[] | select((.status // "") != "ok")] | length > 0' >/dev/null <<<"$input"; then
  jq -r '.checks[]? | select((.status // "") != "ok") | "| " + (.group // "-") + " | " + (.name // "-") + " | " + ((.status // "-") | ascii_upcase) + " | " + ((.message // "-") | gsub("\\|"; "\\\\|")) + " | " + ((.fix // "-") | gsub("\\|"; "\\\\|")) + " |"' <<<"$input"
else
  echo '| - | - | OK | all checks passing | - |'
fi
