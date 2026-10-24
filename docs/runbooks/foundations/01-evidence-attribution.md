---
id: RB-01
title: Evidence, timestamps and proxy attribution
type: runbook
domain: evidence
priority: P0
mode: read-only
status: active
owner: platform
updated: undated
tags: [logs, utc, timezone, rotation, proxy, x-forwarded-for, remoteip, attribution]
symptoms: [no log matches, missing logs, wrong client ip, timezone mismatch]
steps: [EVD-01, EVD-02, EVD-03, EVD-04, EVD-05]
related: [RB-00, RB-05, RB-07, RB-10]
---

# RB-01 — Evidence, timestamps and proxy attribution

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Make evidence trustworthy before drawing conclusions: right host, right files, UTC timestamps, complete retention, and correct client-IP attribution behind load balancers and CDNs. Apache normally logs after request processing, but its default `%t` records receipt time. In-flight requests are absent until logged; worker deaths can leave gaps, and upstream timeouts may be followed by a backend success. See [timing and correlation](../shared/debugging-method.md#align-request-time-log-arrival-and-correlation). If duration is missing, record the gap; propose `%D` through [RB-10](../response/10-mitigation-recovery.md).

## Variables

```bash
APACHE_LOG=/var/log/apache2/access.log
APACHE_ERR=/var/log/apache2/error.log
RB=docs/runbooks/shared/commands
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[EVD-01](#evd-01) · [EVD-02](#evd-02) · [EVD-03](#evd-03) · [EVD-04](#evd-04) · [EVD-05](#evd-05)

## EVD-01

**Verify host, service, environment and log files**

- **Objective:** Confirm you are on the intended server and reading the intended logs.
- **Mode:** Read-only
- **Preconditions:** Candidate host/source and incident report available; establish trust in this step.

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

**Evidence to record:** Hostname, environment, log file paths and their modification times.

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))

## EVD-02

**Normalise timestamps to UTC and validate the window**

- **Objective:** Make every timestamp comparable. Platform logs (Z suffix) and server logs (+0000) are both UTC; do not subtract another hour when comparing them. Local-time screenshots and monitors are the usual source of off-by-one-hour errors.
- **Mode:** Read-only
- **Preconditions:** Candidate sources identified in EVD-01 and provisional event times from INC-02; this step establishes validated UTC bounds rather than requiring them in advance.

### Commands

```bash
timedatectl | grep "Time zone"
# Apache access logs carry an explicit offset, e.g. [DD/Mon/YYYY:HH:MM:SS +0000]
sudo head -n 1 "$APACHE_LOG"; sudo tail -n 1 "$APACHE_LOG"
# Platform timestamps ending in Z are UTC. Convert local times (watch daylight-saving offsets) explicitly:
date -u -d 'TZ="Europe/London" <local-date> <local-time>' +"%Y-%m-%dT%H:%M:%SZ"
```

### Decision

| Result | Next |
| --- | --- |
| All sources in or converted to UTC | [RB-01/EVD-03](#evd-03) |
| Logs span less than the incident window | [RB-01/EVD-03](#evd-03) |

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
sudo zgrep -H -F -c -- "PATTERN" /var/log/apache2/access.log*
# Counts are per file. Keep stderr visible; no match and a read/decompression error differ.
# Check the installed CLI/platform record cap and retention; counts alone do not prove completeness.
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

**Evidence to record:** File list with date ranges, retention policy, identified gaps, search exit status and any read/decompression errors. Follow the [counting and shell checks](../shared/debugging-method.md#distinguish-no-match-from-a-failed-search) before recording a negative result.

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

**Evidence to record:** Proxy chain, header used for client IP, whether attribution is verified.

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))

### Proxy trust acceptance

Treat forwarded-address resolution as security-sensitive: `mod_remoteip` affects logging and IP-based authorisation. Verify the exact proxy chain, trusted source ranges and header rewrite/append policy. Before applying any trust change, test in isolated staging:

| Path | Required result |
| --- | --- |
| Request through the configured trusted proxy | `%a` is the independently known test client; `%{c}a` remains the actual proxy peer |
| Direct request from an untrusted client with forged forwarding headers | Resolved `%a` remains the direct client's address; forged headers do not grant access |
| Trusted proxy receives client-supplied/multi-hop forwarding input | Only the verified chain is accepted; spoofed earlier entries cannot change authorisation |
| Spoofed versus genuine protected request | Expected allow/deny and response semantics hold, not just the status code |

Use existing restricted logs for verification; enabling `%a`/`%{c}a` logging is a proposed RB-10 change. Do not open origin access to conduct a production spoofing test. See [Apache mod_remoteip](https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html).

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

**Evidence to record:** Evidence records following the [evidence schema](../shared/evidence-schema.md).

**Return:** the calling runbook (default [RB-00/INC-04](../00-incident-intake.md#inc-04))
