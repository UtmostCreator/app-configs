#!/usr/bin/env bash
# Top request paths (query string removed) from an Apache combined access log.
# Usage: top-paths.sh LOG [N=20]   (count, share of all requests, path)
set -euo pipefail
# Optional: WINDOW='13/Oct/2026:08:(1[7-9]|2[0-9])' limits lines to a timestamp regex (after the "[").
window_filter() { if [[ -n "${WINDOW:-}" ]]; then grep -E "\\[${WINDOW}" || true; else cat; fi; }
log=${1:?usage: top-paths.sh LOG [N]}
n=${2:-20}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
zcat -f -- "$log" | window_filter | awk '{print $7}' | cut -d'?' -f1 | sort | uniq -c | sort -nr |
  awk -v n="$n" '{c[NR]=$1; p[NR]=$2; t+=$1} END {for (i=1; i<=NR && i<=n; i++) printf "%7d %5.1f%%  %s\n", c[i], 100*c[i]/t, p[i]}'
