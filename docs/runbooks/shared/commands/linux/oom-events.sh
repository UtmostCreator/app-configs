#!/usr/bin/env bash
# Kernel OOM-kill events. Usage: oom-events.sh [SINCE="60 minutes ago"]
set -euo pipefail
since=${1:-"60 minutes ago"}
pattern='out of memory|oom-kill|killed process|oom_reaper'
if command -v journalctl >/dev/null 2>&1 && journalctl -k --no-pager --since "$since" >/dev/null 2>&1; then
  journalctl -k --no-pager --since "$since" | grep -Ei "$pattern" || echo "No OOM events in kernel journal since: $since"
elif dmesg -T >/dev/null 2>&1; then
  echo "journalctl unavailable; using dmesg (no time filter)" >&2
  dmesg -T | grep -Ei "$pattern" || echo "No OOM events in dmesg"
else
  echo "Cannot read kernel logs (try sudo); result is unverifiable" >&2
  exit 1
fi
