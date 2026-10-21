#!/usr/bin/env bash
# Top client addresses. Verify proxy attribution (RB-01/EVD-04) before trusting these.
# Usage: top-clients.sh LOG [N=20]
set -euo pipefail
# Optional: WINDOW='13/Oct/2026:08:(1[7-9]|2[0-9])' limits lines to a timestamp regex (after the "[").
window_filter() { if [[ -n "${WINDOW:-}" ]]; then grep -E "\\[${WINDOW}" || true; else cat; fi; }
log=${1:?usage: top-clients.sh LOG [N]}
n=${2:-20}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
zcat -f -- "$log" | window_filter | awk '{print $1}' | sort | uniq -c | sort -nr | head -n "$n"
