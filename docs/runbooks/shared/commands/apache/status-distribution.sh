#!/usr/bin/env bash
# HTTP status distribution (count and percent) from an Apache combined access log.
# Usage: status-distribution.sh LOG
set -euo pipefail
# Optional: WINDOW='13/Oct/2026:08:(1[7-9]|2[0-9])' limits lines to a timestamp regex (after the "[").
window_filter() { if [[ -n "${WINDOW:-}" ]]; then grep -E "\\[${WINDOW}" || true; else cat; fi; }
log=${1:?usage: status-distribution.sh LOG}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
zcat -f -- "$log" | window_filter | awk '$9 ~ /^[1-5][0-9][0-9]$/ { c[$9]++; t++ }
  END { if (!t) { print "No parsable requests" > "/dev/stderr"; exit 1 }
        for (s in c) printf "%s %d %.2f%%\n", s, c[s], 100 * c[s] / t }' | sort
