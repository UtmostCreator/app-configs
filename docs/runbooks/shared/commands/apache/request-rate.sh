#!/usr/bin/env bash
# Requests per minute from an Apache combined access log (plain or .gz).
# Usage: request-rate.sh LOG
set -euo pipefail
# Optional: WINDOW='13/Oct/2026:08:(1[7-9]|2[0-9])' limits lines to a timestamp regex (after the "[").
window_filter() { if [[ -n "${WINDOW:-}" ]]; then grep -E "\\[${WINDOW}" || true; else cat; fi; }
log=${1:?usage: request-rate.sh LOG}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
zcat -f -- "$log" | window_filter | awk '
  match($4, /\[[0-9]+\/[A-Za-z]+\/[0-9]+:[0-9]+:[0-9]+/) { m = substr($4, RSTART + 1, RLENGTH - 1); c[m]++ }
  END { for (k in c) print k, c[k] }' | sort
