---
id: RB-UBUNTU-EVIDENCE
title: Practical evidence capture on Ubuntu servers
type: reference
status: active
owner: platform
updated: undated
tags: [ubuntu, evidence, pressure, sysstat, history, diagnostics]
---

# Practical evidence capture on Ubuntu servers

> [Runbook index](../README.md) · [Capacity investigation](../diagnostics/03-apache-capacity.md) · [Evidence attribution](../foundations/01-evidence-attribution.md)

Start with installed tools and readable kernel files. Ubuntu installations differ: minimal images, containers, older kernels and restricted accounts may omit commands or hide host information. Check capabilities; record missing, denied and failed separately from measured zero. These recipes inspect state; installing packages, enabling retention, changing logging and profiling require the existing [execution review](recovery-evidence.md#execution-and-evidence-gates).

## Availability and value

| Evidence | Usually available from | What it adds | Limitation |
| --- | --- | --- | --- |
| UTC time, boot identity, release | coreutils, `/proc`, `/etc/os-release` | Correlate source, clock and counter lifetime | Containers may share the host boot identity |
| Memory, load and process snapshots | procps: `free`, `vmstat`, `ps` | Available memory, swap activity, runnable/blocked work | Current state cannot reconstruct an earlier incident |
| Space, inodes and mount type | coreutils `df`, util-linux `findmnt` | Full disk, inode exhaustion, read-only mounts | Device activity and filesystem capacity are different |
| Resource stalls | readable `/proc/pressure/{cpu,memory,io}` | Time workloads lose to contention | Kernel/configuration dependent; recent averages only |
| Workload limits | systemd and cgroup v2 files | CPU throttling, memory/OOM and process ceilings | Host free capacity does not establish workload capacity |
| Service/kernel events | systemd `journalctl`, readable rotated logs | OOM, crashes, restarts and device errors | Access, persistence and retention constrain coverage |
| Network state/counters | iproute2 `ss`, `ip`; `/proc/net/snmp` | Queue pressure, drops and TCP retransmits | Cumulative counters need interval deltas |
| Historical resource samples | optional `sysstat` | Incident-window CPU, memory, disk, network | Installation alone does not establish collection |
| Per-process interval activity | optional `sysstat` `pidstat` | CPU, faults and I/O of selected workers | PID reuse, process exit and permissions affect identity |
| Apache traffic, errors and latency | existing log helpers | Rate, status, route and duration | Duration requires existing supported LogFormat |
| Apache/PHP pool saturation | existing restricted status telemetry | Busy/idle workers, queues and limits | Optional configuration; do not expose status endpoints |
| DNS context | systemd `resolvectl` or readable resolver config | Resolver configuration and existing status | A DNS lookup is an active request; review separately |

```bash
for tool in date timeout uname free vmstat ps df findmnt ss ip systemctl journalctl sar iostat pidstat; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s: available\n' "$tool"
  else
    printf '%s: unavailable\n' "$tool"
  fi
done
```

## Capture identity and a bounded current sample

Run snippets separately and retain each exit status and stderr. They are examples for the selected host, not an unattended collector. `timeout` bounds elapsed execution; output size must also be limited by the capture destination. Commands can contain operational identifiers; review artifacts before sharing.

```bash
date -u +'%Y-%m-%dT%H:%M:%SZ'
uname -r
cat /etc/os-release
cat /proc/sys/kernel/random/boot_id
cat /proc/uptime
timedatectl show -p Timezone -p NTPSynchronized
free -m
vmstat 1 5
ps -eo pid,ppid,user,rss,pcpu,etime,comm --sort=-rss | head -n 21
timeout 5s df -h /var/log /var/www
timeout 5s df -i /var/log /var/www
findmnt -T /var/log -o TARGET,SOURCE,FSTYPE,OPTIONS
ss -s
ip -s link
cat /proc/net/snmp
```

Adjust paths to existing application/log mounts. The first `vmstat` report describes averages since boot; subsequent reports describe intervals. `ps` CPU is a lifetime average, and RSS counts shared pages per process. Load includes runnable and uninterruptible tasks; it is not CPU percentage. Avoid recursive `du`, full connection dumps and whole-system process arguments during first triage. Arguments and environments may contain credentials.

Sample network counters twice with timestamps, for example five seconds apart. Preserve boot/interface identity and elapsed time; resets or disappearing interfaces invalidate a delta. Retransmits and drops suggest where to investigate, without identifying a root cause.

## Pressure stalls without extra packages

```bash
for resource in cpu memory io; do
  file="/proc/pressure/$resource"
  printf '== %s pressure ==\n' "$resource"
  if [[ -r "$file" ]]; then
    cat "$file"
  else
    printf 'unavailable or permission denied\n'
  fi
done
```

`some` measures time with at least some tasks stalled; memory/I/O `full` measures simultaneous stalls of all non-idle tasks. `avg10`, `avg60` and `avg300` are percentages over recent windows; `total` is cumulative microseconds. System-wide CPU `full` is undefined and must not be used as a health signal. For a bounded interval, capture `total` twice with elapsed time and identity; a later snapshot is not historical proof. See the [kernel PSI reference](https://docs.kernel.org/accounting/psi.html).

## Service limits and process identity

```bash
UNIT=apache2.service  # Replace with the actual system service, not an executable name.
systemctl show "$UNIT" -p LoadState -p ActiveState -p SubState -p MainPID \
  -p ControlGroup -p NRestarts -p Result -p ExecMainStatus \
  -p MemoryCurrent -p MemoryMax -p TasksCurrent -p TasksMax
findmnt -t cgroup2 -o TARGET,FSTYPE
```

For an existing service, inspect its reported `ControlGroup` under the verified cgroup2 mount. Read available `cpu.max`, `cpu.stat`, `memory.current`, `memory.max`, `memory.events`, `pids.current`, `pids.max`, `pids.events` and resource pressure files. Some fields/controllers may not exist. In a container, visible paths may describe a restricted namespace. Inspect applicable ancestors: a parent can impose the effective ceiling. Do not assume the service directory alone contains every constraint. See the [cgroup v2 reference](https://docs.kernel.org/admin-guide/cgroup-v2.html).

Compare CPU throttling and OOM event counters across the chosen interval. A nonzero lifetime counter alone does not date the incident. Preserve the unit, PID and process start identity; a matching executable name cannot establish that the intended project is running. A running unit also does not prove application readiness.

## Historical journals and logs

Use recorded incident bounds, not a relative lookback that changes at each execution:

```bash
: "${START_UTC:?Set recorded incident start with explicit UTC offset}"
: "${END_UTC:?Set recorded incident end with explicit UTC offset}"
UNIT=apache2.service
journalctl --list-boots --no-pager
journalctl --disk-usage
timeout 15s journalctl --utc --no-pager -u "$UNIT" \
  --since "$START_UTC" --until "$END_UTC" -o short-iso -n 500
timeout 15s journalctl --utc --no-pager -k \
  --since "$START_UTC" --until "$END_UTC" -o short-iso -n 500
```

These are bounded excerpts: `-n 500` retains the last matching entries, and reaching the cap means coverage may be truncated. Kernel `-k` selects the current boot by default; choose the incident boot explicitly using `-b BOOT_ID` for a past boot. Journal time selectors include the endpoint; normalize downstream comparisons to the chosen interval convention. Keep access warnings and command failures. Empty output can mean wrong boot, missing retention or insufficient permission. Inspect existing rotations and compressed files explicitly using [canonical helpers](commands/README.md). See [journalctl documentation](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html).

## Optional sysstat history

`sysstat` provides `sar`, `sadf`, `iostat`, `mpstat` and `pidstat`; it is a useful optional Ubuntu package, not a baseline dependency. Before any installation or enabling change, inspect what already exists:

```bash
dpkg-query -W sysstat
systemctl list-timers --all --no-pager 'sysstat*'
systemctl list-unit-files --no-pager 'sysstat*'
ls -lh /var/log/sysstat
```

If present, inspect the installed unit definitions, `/etc/default/sysstat`, `/etc/sysstat/sysstat`, `/etc/sysstat/sysstat.ioconf` where present, and `/etc/cron.d/sysstat`. Scheduling varies by package/release; a missing timer alone does not prove collection is disabled. Confirm recent records in an actual archive. See [upstream sysstat](https://github.com/sysstat/sysstat).

```bash
# Optional current sampling: run only tools already present.
iostat -xz -y 1 5
: "${WORKER_PID:?Select the verified current worker PID}"
pidstat -u -r -d -p "$WORKER_PID" 1 5
# Choose an archive by its internal date, not the filename alone.
: "${SAR_FILE:?Set the verified existing daily archive path}"
: "${SAR_START:?Set archive-clock HH:MM:SS start}"
: "${SAR_END:?Set archive-clock HH:MM:SS end}"
LC_ALL=C sar -u -f "$SAR_FILE" -s "$SAR_START" -e "$SAR_END"
LC_ALL=C sar -r -f "$SAR_FILE" -s "$SAR_START" -e "$SAR_END"
LC_ALL=C sar -q -f "$SAR_FILE" -s "$SAR_START" -e "$SAR_END"
LC_ALL=C sar -d -f "$SAR_FILE" -s "$SAR_START" -e "$SAR_END"
LC_ALL=C sar -n DEV,TCP,ETCP -f "$SAR_FILE" -s "$SAR_START" -e "$SAR_END"
```

Establish archive date/timezone and version before selecting clock times. A cross-midnight window needs both archives. Archive names and clock handling vary; consult the installed `man sar`. Missing activity fields remain unavailable. Do not assume `TZ=UTC` alone converts stored sample timestamps. Disk `await` includes queuing and service time; `%util` alone does not establish saturation on parallel storage.

For future collection, propose an explicit interval (for example 60 seconds), retention (for example 14 days), owner, storage cap and cleanup policy through the change gate. Measure actual daily archive size and collection overhead on that server; do not promise fixed disk usage. Confirm sample timestamps advance after enabling and after reboot. Package installation may activate services through maintainer scripts, so installation itself belongs in the reviewed change. Existing history cannot be backfilled from current state.

For a reviewed Ubuntu provisioning change, `sudo apt-get install sysstat` supplies the optional tools from configured repositories. Configure the installed package's actual cron/timer mechanism separately; do not copy a timer name from a different release. Installation and collection are separate acceptance checks.

## Application evidence and optional profiling

Reuse [Apache traffic](../diagnostics/02-apache-traffic.md), [capacity](../diagnostics/03-apache-capacity.md), [Laravel](../diagnostics/04-laravel.md) and [deployment drift](../diagnostics/09-deployment-drift.md) procedures. Verify LogFormat, PHP handler and timezone. Capture separate 4xx/5xx counts, latency sample counts/units, timeout share and existing request IDs. Keep collection time separate from event time; request-ID joins are stronger than proximity in time.

Use existing restricted Apache/PHP-FPM status only when already configured and its request effects reviewed. Do not enable public status or application debug pages. Missing status means worker/pool occupancy is unknown. Current disk configuration may differ from the running service.

`perf`, FlameGraph and eBPF are optional specialist follow-ups after ordinary evidence narrows the question. A profiling plan must specify the process, duration (for example 10 seconds), sampling frequency, matching-kernel tooling, permissions, expected overhead, symbols, private artifact location and cleanup. Do not change kernel restrictions or attach automatically. Record a proposed command in the change review before execution; lack of profiling is not a reason to block basic triage.

For terminal discovery, future `navi` entries should invoke existing helpers by a configured absolute repository path and name the relevant runbook. Keep production changes out of the passive selection. `navi` is optional; every procedure remains usable with a shell.

## Evidence record and follow-up qualification

For each artifact, record source/host/service, tool/version, event window and collection timestamps, timezone, boot/process identity, command exit status, stderr, units, sampling interval, sample count, caps, redaction and coverage (`complete`, `partial`, `unavailable`, `failed`, or `unverified`). Checksums identify captured artifacts; they do not prove collection was complete. Store raw evidence privately; omit tokens, cookies, bodies, process environments and unrestricted config dumps from shared notes.

Keep observations, hypotheses and conclusions separate. Compare equivalent before/during/after windows; missing samples are not zero. Current pressure, retained journal events and sampled historical metrics answer different questions.

Qualification still needed on representative hosts:

- Verify Ubuntu version, package availability, privileges, cgroup visibility and real Apache/PHP formats.
- Confirm historical retention and sample clock alignment with the actual incident.
- Rehearse scoped rollback and required metadata preservation in representative staging.
- Validate cache concurrency only when applicable, using complete independent origin evidence.
- Walk through one Apache OOM, one Netlify timeout and one cache stampede using the [worked routes](../README.md#worked-routes).

Health tooling must report check execution/parse failures explicitly. The project health runner now rejects missing/malformed check records and failed check processes. Generic process-name matches yield warnings; an explicit `projects.<id>.service.unit` selects an exact system service. Unit activity is qualified separately from application readiness. See [project health configuration](../../projects/index.md#health-result-contract). These reliability requirements apply to future collectors as well as existing project health checks.
