#!/usr/bin/env bash
# Kernel events in an explicit journal interval; no silent fallback to unbounded dmesg.
# Usage: oom-events.sh [SINCE="60 minutes ago"] [UNTIL="now"]
set -euo pipefail
since=${1:-'60 minutes ago'}
until=${2:-now}
data=$(journalctl -k --utc --no-pager --since "$since" --until "$until")
printf '%s\n' "$data" | awk '
  BEGIN {IGNORECASE=1}
  tolower($0) ~ /out of memory|oom-kill|killed process|oom_reaper/ {print; n++}
  END {if (!n) print "No matching OOM records in returned journal; verify permissions, boots and retention"}'
