#!/usr/bin/env bash
# Apache MPM, configured worker limit, average worker RSS and a safe worker estimate.
# Read-only. Usage: worker-capacity.sh [RESERVED_MB=1024]
set -euo pipefail
reserved_mb=${1:-1024}
ctl=$(command -v apache2ctl || command -v apachectl || true)
[[ -n "$ctl" ]] || { echo "apache2ctl not found" >&2; exit 1; }

echo "== MPM =="
"$ctl" -V 2>/dev/null | grep -i 'server mpm' || echo "MPM not reported"

echo "== Configured limits =="
grep -rEn '^\s*(MaxRequestWorkers|MaxClients|ServerLimit|StartServers|MaxConnectionsPerChild|KeepAlive|KeepAliveTimeout|Timeout)\b' /etc/apache2/ 2>/dev/null || echo "No explicit limits found"

echo "== Modules (php handler / remoteip) =="
find /etc/apache2/mods-enabled -maxdepth 1 \( -name '*mpm*' -o -name 'php*' -o -name 'proxy_fcgi*' -o -name 'remoteip*' \) -printf '%f\n' 2>/dev/null | sort || true

echo "== Processes =="
procs=$(pgrep -c -x apache2 || true)
echo "apache2 processes: ${procs:-0}"
avg_kb=$(ps -C apache2 -o rss= 2>/dev/null | awk '{s+=$1; n++} END {if (n) printf "%d", s/n}')
if [[ -z "${avg_kb:-}" ]]; then echo "No running apache2 processes; cannot estimate RSS"; exit 0; fi
echo "average RSS: $((avg_kb / 1024)) MB (RSS includes shared pages: treat the estimate as a rough bound, not exact RAM)"

avail_mb=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
total_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
echo "memory: ${avail_mb} MB available of ${total_mb} MB total, ${reserved_mb} MB reserved"
budget=$((total_mb - reserved_mb))
if (( budget > 0 )); then
  echo "estimated safe workers: $((budget * 1024 / avg_kb)) (total - reserved, divided by average RSS)"
else
  echo "reserved memory exceeds total memory; adjust RESERVED_MB"
fi
