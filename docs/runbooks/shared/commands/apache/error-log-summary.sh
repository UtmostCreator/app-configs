#!/usr/bin/env bash
# Summarise an Apache error log: worker-limit warnings, PHP memory exhaustion by source location,
# restarts and unclean shutdowns. Optional: WINDOW='<timestamp regex>' e.g. 'Tue Oct 13 0[3-5]'.
# Usage: error-log-summary.sh [ERROR_LOG=/var/log/apache2/error.log]
set -euo pipefail
log=${1:-/var/log/apache2/error.log}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
data=$(zcat -f -- "$log" | { if [[ -n "${WINDOW:-}" ]]; then grep -E "${WINDOW}" || true; else cat; fi; })
echo "== worker limit (AH00161) =="; grep -c 'AH00161' <<<"$data" || true
echo "== PHP memory exhaustion by location =="
grep -oE 'Allowed memory size of [0-9]+ bytes exhausted.*in [^ ]+ on line [0-9]+' <<<"$data" |
  sed -E 's/.* in ([^ ]+) on line ([0-9]+)/\1:\2/' | sed -E 's#.*/vendor/#vendor/#' | sort | uniq -c | sort -nr | head -15
echo "== restarts / shutdowns =="
grep -E 'resuming normal operations|SIGUSR1|SIGTERM|Graceful restart|unclean|caught SIGWINCH' <<<"$data" | tail -n 15 || true
