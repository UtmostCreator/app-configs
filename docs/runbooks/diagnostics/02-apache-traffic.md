---
id: RB-02
title: Apache traffic and HTTP request investigation
type: runbook
domain: apache-traffic
priority: P0
mode: read-only
status: active
owner: platform
updated: 2026-10-21
tags: [apache, access-log, requests-per-minute, status-codes, top-ips, user-agent, baseline]
symptoms: [traffic spike, 5xx spike, slow responses, suspicious requests]
steps: [TRF-01, TRF-02, TRF-03, TRF-04, TRF-05, TRF-06]
related: [RB-00, RB-01, RB-03, RB-04, RB-07, RB-08]
---

# RB-02 — Apache traffic and HTTP request investigation

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Analyse Apache access logs: request rate, status distribution, top clients, paths and user agents, and correlate with errors and latency. Read-only. Attribution rules from [RB-01/EVD-04](../foundations/01-evidence-attribution.md#evd-04) apply.

## Variables

```bash
APACHE_LOG=/var/log/apache2/access.log
RB=docs/runbooks/shared/commands
```

## Steps

[TRF-01](#trf-01) · [TRF-02](#trf-02) · [TRF-03](#trf-03) · [TRF-04](#trf-04) · [TRF-05](#trf-05) · [TRF-06](#trf-06)

## TRF-01

**Calculate requests per minute and compare with baseline**

- **Objective:** Quantify the traffic change relative to a normal period.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/apache/request-rate.sh "$APACHE_LOG" | tail -n 60
# Limit to a window with a timestamp regex:
WINDOW='13/Oct/2026:08:(1[7-9]|2[0-9])' "$RB"/apache/request-rate.sh "$APACHE_LOG"
# Baseline: run against a rotated log from a comparable quiet period
"$RB"/apache/request-rate.sh /var/log/apache2/access.log.2.gz | sort -k2 -nr | head -5
```

**Expected output:** `YYYY-MM-DD HH:MM  count` per minute.

### Decision

| Result                                                                   | Next                                                                                        |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| Rate well above baseline (see [thresholds](../shared/thresholds.md))     | [RB-02/TRF-02](#trf-02)                                                                     |
| Rate normal but errors present                                           | [RB-02/TRF-02](#trf-02)                                                                     |
| No baseline exists                                                       | Use the closest comparable period and record the limitation; [RB-02/TRF-02](#trf-02)        |
| Requests per minute rose several-fold but visitor-facing traffic did not | Backend calls per visitor grew (fan-out). [RB-08/DEP-01](08-service-dependencies.md#dep-01) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Peak requests/minute, baseline requests/minute, window.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## TRF-02

**Analyse HTTP status distribution**

- **Objective:** See whether errors, redirects or 200s dominate. A window can be ~98% HTTP 200 with zero 5xx logged and still be unhealthy: requests that time out upstream never complete in Apache, so they do not appear as 5xx. Judge health by latency, saturation and application errors too.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/apache/status-distribution.sh "$APACHE_LOG"
```

### Decision

| Result                                            | Next                                                                                                    |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 5xx elevated                                      | [RB-02/TRF-05](#trf-05)                                                                                 |
| Mostly 200 but latency or GraphQL errors reported | [RB-02/TRF-05](#trf-05); inspect response time and application-level errors (HTTP 200 can carry errors) |
| Distribution normal                               | [RB-02/TRF-03](#trf-03)                                                                                 |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Counts and percentages per status class.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## TRF-03

**Identify top IPs, URLs, methods and user agents**

- **Objective:** Find what dominates the traffic, without assuming that user-agent equals intent. A handful of endpoints often account for most requests; rank by share, not just count.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
WINDOW='<timestamp regex>' "$RB"/apache/top-paths.sh "$APACHE_LOG" 20   # count, share, path
"$RB"/apache/top-clients.sh "$APACHE_LOG" 20
"$RB"/apache/method-by-path.sh "$APACHE_LOG" /graphql   # GET vs POST; access logs carry no request bodies
awk -F'"' '{print $6}' "$APACHE_LOG" | sort | uniq -c | sort -nr | head -15
```

### Decision

| Result                                                       | Next                                                                                                                   |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| One user agent dominates (for example a runtime like `node`) | [RB-07/SEC-03](07-traffic-security.md#sec-03); user agent alone is not attribution, and first-party SSR often sends it |
| Few addresses dominate and they are proxies                  | [RB-01/EVD-04](../foundations/01-evidence-attribution.md#evd-04)                                                       |
| A few dynamic API endpoints account for most requests        | [RB-02/TRF-04](#trf-04) and [RB-08/DEP-01](08-service-dependencies.md#dep-01)                                          |
| GraphQL dominates                                            | Identify operations via application-level logging or APM (the access log cannot); [RB-04/APP-03](04-laravel.md#app-03) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Top 20 of each dimension with counts and share.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## TRF-04

**Isolate dynamic routes and suspicious request patterns**

- **Objective:** Separate expensive dynamic endpoints from static assets and from probing.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/apache/top-paths.sh "$APACHE_LOG" 40 | grep -Ev "\.(css|js|png|jpe?g|webp|svg|woff2?)$"
grep -E "(wp-login|\.env|/\.git|phpmyadmin)" "$APACHE_LOG" | awk '{print $1}' | sort | uniq -c | sort -nr | head
```

### Decision

| Result                                                     | Next                                              |
| ---------------------------------------------------------- | ------------------------------------------------- |
| Probing for secrets or admin paths                         | [RB-07/SEC-02](07-traffic-security.md#sec-02)     |
| Legitimate API fan-out (GraphQL, navigation, localisation) | [RB-08/DEP-01](08-service-dependencies.md#dep-01) |
| Nothing unusual                                            | [RB-02/TRF-05](#trf-05)                           |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Dynamic route ranking and any suspicious signatures.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## TRF-05

**Correlate suspicious traffic with server errors and latency**

- **Objective:** Check whether the suspicious traffic overlaps the failures in time.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Requests per minute vs 5xx per minute
awk '$9 ~ /^5/ {print substr($4,2,17)}' "$APACHE_LOG" | sort | uniq -c | tail -n 30
# If the log format includes %D (microseconds), list the slowest requests:
# awk '{print $NF, $7}' "$APACHE_LOG" | sort -nr | head
```

### Decision

| Result                           | Next                                                               |
| -------------------------------- | ------------------------------------------------------------------ |
| Overlap with abuse indicators    | [RB-07/SEC-02](07-traffic-security.md#sec-02)                      |
| Overlap with resource pressure   | [RB-03/CAP-01](03-apache-capacity.md#cap-01)                       |
| Traffic is first-party generated | [RB-08/DEP-01](08-service-dependencies.md#dep-01)                  |
| No overlap                       | Record negative correlation; continue with [RB-02/TRF-06](#trf-06) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Timeline of requests vs errors with overlap judgement.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## TRF-06

**Route to the owning runbook**

- **Objective:** Hand off with the measured findings.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result                        | Next                                              |
| ----------------------------- | ------------------------------------------------- |
| Likely abuse                  | [RB-07/SEC-02](07-traffic-security.md#sec-02)     |
| Capacity pressure             | [RB-03/CAP-01](03-apache-capacity.md#cap-01)      |
| Application-generated traffic | [RB-08/DEP-01](08-service-dependencies.md#dep-01) |
| Nothing actionable            | [RB-00/INC-05](../00-incident-intake.md#inc-05)   |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Chosen route and the evidence behind it.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
