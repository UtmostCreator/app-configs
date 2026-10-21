#!/usr/bin/env bash
# Group Laravel log errors by message prefix. Usage: error-summary.sh LOG [N=20]
set -euo pipefail
log=${1:?usage: error-summary.sh LOG [N]}
n=${2:-20}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
zcat -f -- "$log" | grep -E '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}.*\.(ERROR|CRITICAL|ALERT|EMERGENCY):' |
  sed -E 's/^\[[^]]*\] [a-zA-Z_.]+\.(ERROR|CRITICAL|ALERT|EMERGENCY): //' | cut -c1-120 |
  sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -nr | head -n "$n"
