---
id: RB-03
title: Apache capacity, CPU, memory and OOM
type: runbook
domain: apache-capacity
priority: P0
mode: read-only
status: active
owner: platform
updated: undated
tags:
  [
    apache,
    prefork,
    maxrequestworkers,
    AH00161,
    oom,
    memory,
    ubuntu,
    php,
    keepalive,
    mpm-event,
    php-fpm,
    systemd,
    restart,
  ]
symptoms:
  [
    AH00161,
    oom-kill,
    Killed process,
    503,
    server unresponsive,
    high load,
    service down for hours,
    graceful restart did not help,
  ]
steps: [CAP-01, CAP-02, CAP-03, CAP-04, CAP-05, CAP-06, CAP-07]
related: [RB-00, RB-01, RB-02, RB-04, RB-06, RB-08, RB-10]
---

# RB-03 — Apache capacity, CPU, memory and OOM

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Distinguish Apache worker saturation from host-level memory exhaustion and from PHP-level memory limits on an Ubuntu server. Read-only. Do not raise `MaxRequestWorkers` without the memory model in [RB-03/CAP-02](#cap-02). A later `free -h` showing plenty of RAM does not contradict an earlier OOM kill: it describes the moment of measurement, not the failure.

## Variables

```bash
APACHE_ERR=/var/log/apache2/error.log
RB=docs/runbooks/shared/commands
LARAVEL_LOG=/var/www/<app>/storage/logs/laravel.log
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[CAP-01](#cap-01) · [CAP-02](#cap-02) · [CAP-03](#cap-03) · [CAP-04](#cap-04) · [CAP-05](#cap-05) · [CAP-06](#cap-06) · [CAP-07](#cap-07)

## CAP-01

**Inspect live CPU, memory, process count and load**

- **Objective:** Capture the current resource state before it changes.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/linux/memory-snapshot.sh
# Or the one-paste bundle: adds MPM/limits, process states, listen backlog, OOM and unit journal, log coverage.
sudo bash "$RB"/linux/incident-bundle.sh '<incident start>' '<now>'
ss -Hltn '( sport = :80 )'   # LISTEN Recv-Q > 0: connections waiting for a worker now
```

During saturation always bound status-page probes (`curl -m 5 …/server-status?auto`); without a timeout they hang.

### Decision

| Result                                                 | Next                                        |
| ------------------------------------------------------ | ------------------------------------------- |
| Memory or swap exhausted, or load far above core count | [RB-03/CAP-02](#cap-02)                     |
| Resources healthy now but incident is historical       | [RB-03/CAP-03](#cap-03)                     |
| Healthy and incident is ongoing                        | [RB-02/TRF-01](02-apache-traffic.md#trf-01) |

**Evidence to record:** Free/available memory, swap, load average, top RSS processes, Apache process count.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

### Classify the constrained resource

Prefer existing incident-window monitoring or retained `sar`/`sadf` data for historical events. Do not install collectors or enable profiling during passive triage. Optional commands below read current state; unavailable tools or permissions leave that signal unknown.

```bash
# Current interval samples; first vmstat report is since boot.
vmstat 1 5
pidstat -u -r -d -p <worker-pid> 1 5
iostat -xz 1 5
df -h /var/www /var/log
df -i /var/www /var/log
ss -s
# Historical samples only when collection was already enabled; validate timezone/date/retention.
sar -u -r -q -f /var/log/sysstat/sa<DD> -s <HH:MM:SS> -e <HH:MM:SS>
# For an already identified process; permissions may require an authorised privileged read:
sudo cat /proc/<worker-pid>/smaps_rollup
sudo cat /proc/<worker-pid>/limits
```

| Classification | Supporting measurement | Avoid inferring |
| --- | --- | --- |
| CPU saturation / throttling | Busy CPU plus runnable queue or cgroup throttling deltas; per-process CPU samples | Load alone proves CPU saturation |
| Memory exhaustion | Effective cgroup/host limit, pressure/reclaim, PSS/private range, OOM events/counter deltas | Current free memory disproves past OOM |
| IO stalls / storage exhaustion | Device latency/queue and process IO wait, free blocks and inodes | High device utilisation alone proves the bottleneck |
| Worker/thread exhaustion | Busy/idle workers and cap, queue depth, PHP-FPM pool status/slow log if already enabled | Connection count equals busy PHP workers |
| Connection exhaustion | File-descriptor use vs process limits, backlog/retransmit or pool-connection metrics | Many open sockets imply abusive users |
| Upstream dependency latency | Parent-linked slow spans, database sessions/lock waits, dependency-pool waits | Adding local workers fixes a slow dependency |

Record the source, interval, clock, metric and limitation for the chosen class before changing capacity. Use existing DB slow-query/session/lock telemetry and read-only DBA-approved views; enabling logs, `perf`, eBPF or debugger attachment requires an execution review. If worker status is missing, worker utilisation is unknown. Inspect the actual PHP handler using [RB-04](04-laravel.md#app-01).

## CAP-02

**Inspect MaxRequestWorkers, MPM and active worker metrics**

- **Objective:** Know the concurrency ceiling, the PHP handler model, and whether the memory budget supports the ceiling.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/apache/worker-capacity.sh
# Prefer existing collected worker metrics. Optional active status request only after
# verifying this exact local endpoint maps to mod_status, is restricted and has
# known acceptable side effects/cost; record execution review under the shared gate.
# Do not enable mod_status or fall back to an application route during triage.
# curl --connect-timeout 3 --max-time 15 --retry 0 -sS http://127.0.0.1/server-status?auto | grep -E "BusyWorkers|IdleWorkers|Scoreboard"
# Established connections vs worker cap (connections are not busy PHP requests, but show pressure):
"$RB"/linux/connections.sh 443
```

**Expected output:** Current on-disk MPM/run configuration and modules, per-process RSS, host memory, and current service cgroup/limits. These may differ from the configuration loaded by running processes or used during the incident. A failed section leaves its evidence unknown. No worker limit is calculated. Apply the [capacity model](../shared/thresholds.md#capacity-model-for-apache-prefork), using loaded child PSS/private memory and the effective cgroup ceiling. Event/worker MPM and PHP-FPM need separate thread/pool models.

### Decision

| Result                                                                   | Next                                                                                                                                                                                    |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Configured workers x per-worker memory is near or above available memory | [RB-03/CAP-04](#cap-04); do not raise the cap                                                                                                                                           |
| Prefork with the PHP module in Apache                                    | Each worker carries a full PHP runtime. Note Event + PHP-FPM as a longer-term option for [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01); it is a change, not a diagnostic |
| `MaxConnectionsPerChild 0`, long `KeepAliveTimeout` or large `Timeout`   | Record: workers are never recycled and idle keep-alive connections hold prefork workers. Candidates for [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01)                    |
| Workers at cap, memory has headroom                                      | [RB-03/CAP-03](#cap-03) to confirm the saturation signature                                                                                                                             |
| Cannot read worker data                                                  | [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03)                                                                                                                        |

**Evidence to record:** MPM, effective process/thread cap and its source, loaded-child memory range and measurement method, cgroup/host ceiling, other-service budget, headroom, and uncertainty. Record no safe limit if these are missing.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CAP-03

**Examine Apache logs and kernel OOM events**

- **Objective:** Check whether Linux killed Apache processes and whether Apache hit its worker limit.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
: "${START_UTC:?Set the recorded incident UTC start}"
: "${END_UTC:?Set the recorded incident UTC end}"
"$RB"/linux/oom-events.sh "$START_UTC" "$END_UTC"
"$RB"/apache/error-log-summary.sh "$APACHE_ERR"
sudo grep -Ei 'MaxRequestWorkers|Allowed memory size|AH00161' "$APACHE_ERR" | tail -n 50
```

**Expected output:** Lines like `Out of memory: Killed process <pid> (apache2)`, `AH00161: server reached MaxRequestWorkers setting`, `Allowed memory size of N bytes exhausted`.

### Decision

| Result                              | Next                                                                                                                      |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Kernel OOM killed Apache            | [RB-03/CAP-04](#cap-04)                                                                                                   |
| PHP `Allowed memory size exhausted` | [RB-04/APP-01](04-laravel.md#app-01)                                                                                      |
| `AH00161` worker-limit warning      | [RB-03/CAP-02](#cap-02)                                                                                                   |
| Both kernel OOM and worker limit    | [RB-03/CAP-04](#cap-04), then [RB-04/APP-01](04-laravel.md#app-01)                                                        |
| No relevant events                  | [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03) to verify historical evidence before ruling anything out |

**If the result is unknown:** No kernel log retention: record "unverifiable" and check platform or off-host logs via [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** UTC timestamps, process and PID killed, affected service, kernel log availability.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CAP-04

**Distinguish worker saturation, host OOM and PHP memory exhaustion**

- **Objective:** Name the failing layer precisely; each has a different fix.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Layer 1: host (kernel OOM)  -> memory-snapshot.sh / oom-events.sh
# Layer 2: Apache workers          -> AH00161 + worker-capacity.sh
# Layer 3: PHP memory_limit         -> "Allowed memory size" in error log
php -i | grep -E "^memory_limit"; grep -rn memory_limit /etc/php/*/apache2/php.ini
```

### Decision

| Result                                                | Next                                                                                |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Host OOM driven by many workers x large PHP processes | Capacity model needed: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Single requests exhaust PHP memory                    | [RB-04/APP-01](04-laravel.md#app-01)                                                |
| Saturation without memory pressure (slow upstream)    | [RB-08/DEP-01](08-service-dependencies.md#dep-01)                                   |

**Evidence to record:** Failing layer, memory per request vs per worker, concurrency at failure time.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CAP-05

**Correlate with requests, scheduled jobs and application operations**

- **Objective:** Find what was running when memory or workers peaked, including heavy background jobs sharing the host.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
crontab -l; sudo crontab -l
systemctl list-timers --all --no-pager | head -20
sudo grep -E "CRON|artisan" /var/log/syslog | grep -E "<HH:MM>" | head -20
"$RB"/apache/request-rate.sh /var/log/apache2/access.log | tail -n 30
# Heavy background jobs on the same host just before the incident (log volume is a quick proxy):
grep -E "^\[<date> 0[0-3]:" "$LARAVEL_LOG" | cut -c1-17 | uniq -c | head -20
```

### Decision

| Result                                                                                          | Next                                                                                                    |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| A bulk or sync job ran on the same host beforehand and PHP already hit its memory limit earlier | Record as a contributing factor and continue with [RB-06/CCH-01](06-cache-invalidation.md#cch-01)       |
| A scheduled job or cache clear precedes the failure                                             | [RB-06/CCH-01](06-cache-invalidation.md#cch-01); treat as a hypothesis until controlled evidence exists |
| A burst of requests precedes it                                                                 | [RB-02/TRF-03](02-apache-traffic.md#trf-03)                                                             |
| Application work is heavy per request                                                           | [RB-04/APP-03](04-laravel.md#app-03)                                                                    |

**Evidence to record:** Timeline aligning jobs, request rate and resource peaks.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CAP-06

**Check service recovery behaviour and monitoring gaps**

- **Objective:** Establish how long the service stayed down after processes were killed and whether anything restarted or alerted.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
: "${START_UTC:?Set the recorded incident UTC start}"
: "${END_UTC:?Set the recorded incident UTC end}"
"$RB"/linux/service-recovery.sh apache2 "$START_UTC" "$END_UTC"
# Restarts do not clear a PHP memory problem: compare errors before and after each restart.
"$RB"/apache/error-log-summary.sh "$APACHE_ERR"
```

### Decision

| Result                                                        | Next                                                                                                                                                            |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Historical journal/monitor evidence verifies downtime and the policy/alerting in effect then | Monitoring and recovery gap: record for [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01); add availability alerting and an automatic restart policy |
| Same memory failure recurs after each graceful restart        | The cause is in the workload, not stale processes: [RB-04/APP-01](04-laravel.md#app-01)                                                                         |
| Recovered quickly by itself                                   | [RB-03/CAP-07](#cap-07)                                                                                                                                         |

**Evidence to record:** Historical kill and next start times, journal retention/boot coverage, actual availability-monitor downtime, and policy/alert evidence at the event time. Current policy alone cannot establish the past recovery configuration.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CAP-07

**Route to the owning runbook**

- **Objective:** Hand off with the capacity findings.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result                                | Next                                                         |
| ------------------------------------- | ------------------------------------------------------------ |
| PHP failures                          | [RB-04/APP-01](04-laravel.md#app-01)                         |
| Cache regeneration load               | [RB-06/CCH-01](06-cache-invalidation.md#cch-01)              |
| Safe capacity mitigation required     | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Findings recorded and nothing further | [RB-00/INC-05](../00-incident-intake.md#inc-05)              |

**Evidence to record:** Chosen route and supporting evidence.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
