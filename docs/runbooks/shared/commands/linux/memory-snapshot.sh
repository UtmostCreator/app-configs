#!/usr/bin/env bash
# Current snapshot only. Missing mandatory tools/permissions are failures, not healthy data.
set -euo pipefail
echo '== time (UTC) =='; date -u +'%Y-%m-%dT%H:%M:%SZ'
echo '== uptime / load =='; uptime
echo '== cores =='; nproc
echo '== memory (MB) =='; free -m
echo '== top 10 by RSS =='; ps -eo pid,user,rss,pmem,etime,comm --sort=-rss | sed -n '1,11p'
echo '== CPU / run queue (3 samples; first is since boot) =='; vmstat 1 3
echo '== pressure (current rolling averages; not incident history) =='
for resource in cpu memory io; do
  file="/proc/pressure/$resource"
  printf '%s: ' "$resource"
  if [[ -r "$file" ]]; then
    cat "$file"
  else
    echo 'unavailable or permission denied'
  fi
done
echo 'System-wide CPU full is undefined; do not use it as a health signal.'
echo '== apache2 processes =='
if procs=$(pgrep -c -x apache2); then
  echo "$procs"
else
  status=$?
  if (( status == 1 )); then echo 0; else exit "$status"; fi
fi
