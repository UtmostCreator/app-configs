#!/usr/bin/env bash
# Render the health JSON (from run.sh) as a compact markdown report.
# Pipes through `glow` if available, otherwise prints raw markdown.
#
# Usage:
#   bash ops/projects/health/run.sh --json | bash ops/projects/health/render.sh

set -uo pipefail

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 127; }; }
require_cmd jq

INPUT="$(cat)"
if [[ -z "${INPUT//[[:space:]]/}" ]]; then
  echo "render.sh: no input"
  exit 1
fi

STATUS="$(jq -r '.overall.status' <<<"$INPUT")"
PASSED="$(jq -r '.overall.passed' <<<"$INPUT")"
FAILED="$(jq -r '.overall.failed' <<<"$INPUT")"
WARNED="$(jq -r '.overall.warned' <<<"$INPUT")"

case "$STATUS" in
  ok)   ICON=":white_check_mark:" ;;
  warn) ICON=":warning:" ;;
  fail) ICON=":x:" ;;
  *)    ICON=":question:" ;;
esac

MD=""
MD+="# Project health\n\n"
MD+="**Overall: $ICON $STATUS**  •  passed: $PASSED  •  failed: $FAILED  •  warned: $WARNED\n\n"

# Group checks by section.
SECTIONS="$(jq -r '.checks[].section' <<<"$INPUT" | sort -u)"
for section in $SECTIONS; do
  MD+="## $section\n\n"
  MD+="| status | check | note | fix |\n"
  MD+="|--------|-------|------|-----|\n"
  while IFS=$'\t' read -r name status note fix; do
    case "$status" in
      ok)   s=":white_check_mark:" ;;
      warn) s=":warning:" ;;
      fail) s=":x:" ;;
      *)    s="?" ;;
    esac
    [[ -z "$fix" || "$fix" == "null" ]] && fix="—"
    MD+="| $s | \`$name\` | $note | \`$fix\` |\n"
  done < <(jq -r --arg s "$section" '
    .checks[] | select(.section == $s)
    | [.name, .status, (.note // ""), (.fix // "")] | @tsv
  ' <<<"$INPUT")
  MD+="\n"
done

MD+="_Updated: $(date '+%Y-%m-%d %H:%M:%S')_\n"

if command -v glow >/dev/null 2>&1; then
  printf '%b' "$MD" | glow - -w 0 -n
else
  printf '%b' "$MD"
fi
