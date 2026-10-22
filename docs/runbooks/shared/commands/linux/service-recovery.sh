#!/usr/bin/env bash
# Current policy and historical journal are separate evidence sources.
# Usage: service-recovery.sh [UNIT=apache2] [SINCE="6 hours ago"] [UNTIL="now"]
set -euo pipefail
unit=${1:-apache2}
since=${2:-'6 hours ago'}
until=${3:-now}
echo '== current policy (does not establish policy at incident time) =='
systemctl show "$unit" -p Restart -p RestartUSec -p ActiveEnterTimestamp -p NRestarts
echo '== historical unit journal (start/stop/exit) =='
data=$(journalctl -u "$unit" --utc --no-pager --since "$since" --until "$until")
printf '%s\n' "$data" | awk 'tolower($0) ~ /started|stopped|failed|main process exited|killed|unclean|deactivated/ {print; n++}
  END {if (!n) print "No matching records returned; verify permissions and retention"}' | tail -n 20
echo 'A gap does not establish why recovery failed. Correlate historical policy, boot ID, deploys, timers and monitoring.'
