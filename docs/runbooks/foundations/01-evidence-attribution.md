---
id: RB-01
title: Evidence, timestamps and proxy attribution
type: runbook
domain: evidence
priority: P0
mode: read-only
status: active
owner: platform
updated: 2026-10-21
tags: [logs, utc, timezone, rotation, proxy, x-forwarded-for, remoteip, attribution]
symptoms: [no log matches, missing logs, wrong client ip, timezone mismatch]
steps: [EVD-01, EVD-02, EVD-03, EVD-04, EVD-05]
related: [RB-00, RB-05, RB-07, RB-10]
---

# RB-01 — Evidence, timestamps and proxy attribution

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Make evidence trustworthy before drawing conclusions: right host, right files, UTC timestamps, complete retention, and correct client-IP attribution behind load balancers and CDNs. Access-log lines are written when a request completes, so timed-out and in-flight requests are under-represented; add `%D` (duration) to the log format if you need latency.

## Variables

```bash
APACHE_LOG=/var/log/apache2/access.log
APACHE_ERR=/var/log/apache2/error.log
```

## Steps

[EVD-01](#evd-01) · [EVD-02](#evd-02) · [EVD-03](#evd-03) · [EVD-04](#evd-04) · [EVD-05](#evd-05)

## EVD-01

**Verify host, service, environment and log files**

- **Objective:** Confirm you are on the intended server and reading the intended logs.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](01-evidence-attribution.md))

### Commands

```bash
hostname -f; cat /etc/os-release | head -3
sudo ls -lh /var/log/apache2/ | head -30
sudo apache2ctl -S 2>&1 | head -20   # vhosts, log targets
```

### Decision

| Result | Next |
| --- | --- |
| Host and logs match the incident | [RB-01/EVD-02](#evd-02) |
| Wrong host or environment | Switch host and repeat; record the mistake in the incident notes |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](#evd-03).

**Evidence to record:** Hostname, environment, log file paths and their modification times.

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))

## EVD-02

**Normalise timestamps to UTC and validate the window**

- **Objective:** Make every timestamp comparable. Platform logs (Z suffix) and server logs (+0000) are both UTC; do not subtract another hour when comparing them. Local-time screenshots and monitors are the usual source of off-by-one-hour errors.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](01-evidence-attribution.md))

### Commands

```bash
timedatectl | grep "Time zone"
# Apache access logs carry an explicit offset, e.g. [13/Oct/2026:03:05:12 +0000]
sudo head -n 1 "$APACHE_LOG"; sudo tail -n 1 "$APACHE_LOG"
# Platform timestamps ending in Z are UTC. Convert local times (watch daylight-saving offsets) explicitly:
date -u -d "2026-10-13 09:17 Europe/London" +"%Y-%m-%dT%H:%M:%SZ"
```

### Decision

| Result | Next |
| --- | --- |
| All sources in or converted to UTC | [RB-01/EVD-03](#evd-03) |
| Logs span less than the incident window | [RB-01/EVD-03](#evd-03) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](#evd-03).

**Evidence to record:** Zone of each source, offset applied, validated UTC window.

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))

## EVD-03

**Check rotated logs, retention and missing records**

- **Objective:** Rule out rotation or retention gaps before concluding that "nothing happened".
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](01-evidence-attribution.md))

### Commands

```bash
sudo ls -lh --time-style=long-iso /var/log/apache2/ | sort -k6,7
grep -E "rotate|daily|weekly|compress" /etc/logrotate.d/apache2
sudo journalctl --disk-usage; sudo journalctl --list-boots | head
# Search across rotated and compressed files:
sudo zgrep -h -c "PATTERN" /var/log/apache2/access.log* 2>/dev/null
# Platform log CLIs can return a limited batch per query (for example ~100 records), so a long window silently truncates.
# Use short windows and treat a count at the cap as truncated:
docs/runbooks/shared/commands/netlify/window-counts.sh <function> 5 <start-utc> <start-utc>
```

### Decision

| Result | Next |
| --- | --- |
| Complete coverage of the window | Return to the calling runbook with the evidence set |
| Platform log query returns a suspiciously round count (for example 100) | Truncated: shorten the window and repeat ([RB-05/NET-02](../diagnostics/05-netlify-ssr-cdn.md#net-02)) |
| Gap in coverage | Record the gap; mark conclusions that depend on it as unverified; look for off-host copies (log shipper, CDN or platform logs) |
| Logs are complete but empty for the window | Treat as a real negative result and say so in the evidence |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](#evd-03).

**Evidence to record:** File list with date ranges, retention policy, identified gaps.

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))

## EVD-04

**Identify load balancers, trusted proxies and real client IP handling**

- **Objective:** Know whether the first log column is the client or a proxy. Private-range addresses in the first column usually mean an internal load balancer or proxy; health checkers appear there too.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](01-evidence-attribution.md))

### Commands

```bash
apache2ctl -M 2>/dev/null | grep -i remoteip
grep -rEn "RemoteIPHeader|RemoteIPTrustedProxy|RemoteIPInternalProxy|LogFormat|CustomLog" /etc/apache2/ | head -20
"$RB"/apache/top-clients.sh "$APACHE_LOG" 10   # all from one or two addresses => proxy addresses
# Health-check traffic (identify by user agent AND peer AND route, never user agent alone):
awk -F'"' '$6 ~ /HealthChecker/ {print $1}' "$APACHE_LOG" | awk '{print $1}' | sort | uniq -c
```

### Decision

| Result | Next |
| --- | --- |
| Client IPs are real and trusted-proxy chain is verified | [RB-01/EVD-05](#evd-05) |
| Top clients are proxy or load-balancer addresses and the log format has no forwarded-for field | Attribution is impossible from these logs. Propose a logging or `mod_remoteip` change through [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01); verify trusted proxies first. Until then do not label any client abusive ([RB-07/SEC-02](../diagnostics/07-traffic-security.md#sec-02)) |
| Health-check traffic dominates | Exclude by verified peer and route, not by user-agent alone |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](#evd-03).

**Evidence to record:** Proxy chain, header used for client IP, whether attribution is verified.

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))

## EVD-05

**Produce the normalised evidence set and return**

- **Objective:** Hand the caller a consistent, labelled set of evidence.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](01-evidence-attribution.md))

### Commands

```bash
# Record each artefact using the shared schema:
# docs/runbooks/shared/evidence-schema.md
```

### Decision

| Result | Next |
| --- | --- |
| Evidence set complete | Return to the caller |
| Caller unknown | [RB-00/INC-04](../00-incident-intake.md#inc-04) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](#evd-03).

**Evidence to record:** Evidence records following the [evidence schema](../shared/evidence-schema.md).

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))
