#!/usr/bin/env bash
# Point-in-time memory, swap, load and top RSS processes. Read-only.
set -euo pipefail
echo "== time (UTC) =="; date -u +"%Y-%m-%dT%H:%M:%SZ"
echo "== uptime / load =="; uptime
echo "== cores =="; nproc
echo "== memory (MB) =="; free -m
echo "== top 10 by RSS =="; ps -eo pid,user,rss,pmem,etime,comm --sort=-rss | head -n 11
echo "== CPU / run queue (3 samples) =="; vmstat 1 3 2>/dev/null || echo "vmstat unavailable"
echo "== apache2 processes =="; pgrep -c -x apache2 || echo 0
