---
id: RB-SHARED-COMMANDS
title: Read-only command helpers
type: reference
domain: tooling
status: active
owner: platform
updated: 2026-10-21
tags: [commands, scripts, apache, linux, laravel, read-only]
symptoms: [log parsing, request rate, top clients, oom events]
---

# Command helpers

> [Runbook index](../../README.md)

Reusable, read-only scripts so every runbook gets the same normalised output and parser fixes land once. They accept explicit inputs, handle rotated/compressed logs (`zcat -f`), report missing data clearly and never print secrets.

```bash
RB=docs/runbooks/shared/commands
```

| Script                                                                    | Purpose                                                                       | Used by                                                                                                                |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [`apache/request-rate.sh`](apache/request-rate.sh) `LOG`                  | Requests per minute                                                           | [TRF-01](../../diagnostics/02-apache-traffic.md#trf-01)                                                                |
| [`apache/status-distribution.sh`](apache/status-distribution.sh) `LOG`    | Status counts and percentages                                                 | [TRF-02](../../diagnostics/02-apache-traffic.md#trf-02)                                                                |
| [`apache/top-clients.sh`](apache/top-clients.sh) `LOG [N]`                | Top client addresses (check proxy attribution first)                          | [TRF-03](../../diagnostics/02-apache-traffic.md#trf-03), [EVD-04](../../foundations/01-evidence-attribution.md#evd-04) |
| [`apache/top-paths.sh`](apache/top-paths.sh) `LOG [N]`                    | Top request paths without query strings                                       | [TRF-03](../../diagnostics/02-apache-traffic.md#trf-03)                                                                |
| [`apache/method-by-path.sh`](apache/method-by-path.sh) `LOG PATH`         | Method and status counts for one path (access logs carry no request bodies)   | [TRF-03](../../diagnostics/02-apache-traffic.md#trf-03)                                                                |
| [`apache/error-log-summary.sh`](apache/error-log-summary.sh) `[ERRLOG]`   | `AH00161` count, PHP memory exhaustion by source location, restarts           | [CAP-03](../../diagnostics/03-apache-capacity.md#cap-03), [APP-01](../../diagnostics/04-laravel.md#app-01)             |
| [`apache/worker-capacity.sh`](apache/worker-capacity.sh)                  | MPM, `MaxRequestWorkers`, RSS, safe worker estimate                           | [CAP-02](../../diagnostics/03-apache-capacity.md#cap-02)                                                               |
| [`linux/memory-snapshot.sh`](linux/memory-snapshot.sh)                    | Memory, swap, load, top RSS processes                                         | [CAP-01](../../diagnostics/03-apache-capacity.md#cap-01)                                                               |
| [`linux/oom-events.sh`](linux/oom-events.sh) `[SINCE]`                    | Kernel OOM kills                                                              | [CAP-03](../../diagnostics/03-apache-capacity.md#cap-03)                                                               |
| [`linux/service-recovery.sh`](linux/service-recovery.sh) `[UNIT] [SINCE]` | Restart policy, start/stop journal, downtime gap                              | [CAP-06](../../diagnostics/03-apache-capacity.md#cap-06)                                                               |
| [`netlify/window-counts.sh`](netlify/window-counts.sh) `FN SECS START...` | Function log records per short UTC window (truncation-aware)                  | [NET-02](../../diagnostics/05-netlify-ssr-cdn.md#net-02)                                                               |
| [`linux/connections.sh`](linux/connections.sh) `[PORT]`                   | Established connections by peer                                               | [CAP-05](../../diagnostics/03-apache-capacity.md#cap-05)                                                               |
| [`laravel/error-summary.sh`](laravel/error-summary.sh) `LOG [N]`          | Group Laravel errors by message                                               | [APP-01](../../diagnostics/04-laravel.md#app-01)                                                                       |
| [`validate-runbook-links.sh`](validate-runbook-links.sh)                  | Check frontmatter, links, anchors and step references                         | maintenance                                                                                                            |
| [`check-anonymized.sh`](check-anonymized.sh)                              | Privacy lint: real-looking IPs, hosts, emails, home paths, ticket ids, tokens | maintenance                                                                                                            |

Apache scripts accept an optional `WINDOW` timestamp regex, for example `WINDOW='13/Oct/2026:08:(1[7-9]|2[0-9])' apache/top-paths.sh LOG`. They assume Apache combined log format (`%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i"`).
