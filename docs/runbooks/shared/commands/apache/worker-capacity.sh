#!/usr/bin/env bash
# Current Apache observations only. Never recommends a worker limit from average RSS.
# Usage: worker-capacity.sh
set -euo pipefail
[[ $# == 0 ]] || { echo 'usage: worker-capacity.sh (no automatic capacity estimate)' >&2; exit 2; }
ctl=$(command -v apache2ctl || command -v apachectl) || { echo 'apache2ctl not found' >&2; exit 1; }
echo '== configuration currently on disk (may differ from running processes) =='
"$ctl" -V
"$ctl" -t -D DUMP_RUN_CFG
"$ctl" -M
echo '== Apache process RSS (KiB; shared pages counted in each process) =='
ps -C apache2 -o pid=,ppid=,rss=,etime=,comm=
echo '== host memory (current, not historical or necessarily the service limit) =='
awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/' /proc/meminfo
echo '== systemd service limits and cgroup path (current configuration) =='
systemctl show apache2 -p ControlGroup -p MemoryCurrent -p MemoryPeak -p MemoryHigh -p MemoryMax -p EffectiveMemoryMax
cat <<'NOTE'
No safe worker count calculated. For prefork, model loaded child private/PSS memory,
shared/master overhead, other services and the effective cgroup/host ceiling.
Read permitted /proc/PID/smaps_rollup and cgroup memory.max, memory.current,
memory.events along the service hierarchy. Unavailable data stays unknown.
For event/worker MPM, model threads and a separate PHP-FPM pool independently.
NOTE
