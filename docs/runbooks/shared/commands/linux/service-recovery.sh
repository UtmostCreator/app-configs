#!/usr/bin/env bash
# Did the service come back by itself after a kill, and how long was it down? Read-only.
# Usage: service-recovery.sh [UNIT=apache2] [SINCE="6 hours ago"]
set -euo pipefail
unit=${1:-apache2}
since=${2:-"6 hours ago"}
echo "== restart policy =="; systemctl show "$unit" -p Restart -p RestartUSec -p ActiveEnterTimestamp -p NRestarts 2>/dev/null || echo "systemctl unavailable"
echo "== unit journal (start/stop/exit) =="
journalctl -u "$unit" --no-pager --since "$since" 2>/dev/null |
  grep -Ei 'started|stopped|failed|main process exited|killed|unclean|deactivated' | tail -n 20 || echo "No matching journal entries since: $since"
echo "A long gap between the kill and the next start with Restart=no means nothing restarted the service."
