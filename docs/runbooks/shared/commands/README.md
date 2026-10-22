---
id: RB-SHARED-COMMANDS
title: Read-only command helpers
type: reference
domain: tooling
status: active
owner: platform
updated: 2026-10-22
tags: [commands, scripts, apache, linux, laravel, read-only]
symptoms: [log parsing, request rate, top clients, oom events]
---

# Command helpers

> [Runbook index](../../README.md)

Reusable, read-only scripts so every runbook gets the same normalised output and parser fixes land once. Log helpers require Python 3, accept one explicit file and detect plain or gzip input; they do not discover rotations automatically. Output may contain sensitive paths, user agents, exception text or restart messages. Review and redact it before sharing; these scripts are not anonymisers.

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
| [`apache/worker-capacity.sh`](apache/worker-capacity.sh)                  | Current on-disk MPM/config, per-process RSS and cgroup observations; no safe-limit estimate                           | [CAP-02](../../diagnostics/03-apache-capacity.md#cap-02)                                                               |
| [`linux/memory-snapshot.sh`](linux/memory-snapshot.sh)                    | Memory, swap, load, top RSS processes                                         | [CAP-01](../../diagnostics/03-apache-capacity.md#cap-01)                                                               |
| [`linux/oom-events.sh`](linux/oom-events.sh) `[SINCE] [UNTIL]`                    | Kernel OOM kills                                                              | [CAP-03](../../diagnostics/03-apache-capacity.md#cap-03)                                                               |
| [`linux/service-recovery.sh`](linux/service-recovery.sh) `[UNIT] [SINCE] [UNTIL]` | Restart policy, start/stop journal, downtime gap                              | [CAP-06](../../diagnostics/03-apache-capacity.md#cap-06)                                                               |
| [`netlify/window-counts.sh`](netlify/window-counts.sh) `FN SECS START...` | Function log records per short UTC window (truncation-aware)                  | [NET-02](../../diagnostics/05-netlify-ssr-cdn.md#net-02)                                                               |
| [`linux/connections.sh`](linux/connections.sh) `[PORT]`                   | Established connections by peer                                               | [CAP-05](../../diagnostics/03-apache-capacity.md#cap-05)                                                               |
| [`laravel/error-summary.sh`](laravel/error-summary.sh) `LOG [N]`          | Group Laravel errors by message                                               | [APP-01](../../diagnostics/04-laravel.md#app-01)                                                                       |
| [`validate-runbook-links.sh`](validate-runbook-links.sh)                  | Check frontmatter, links, anchors and step references                         | maintenance                                                                                                            |
| [`check-anonymized.sh`](check-anonymized.sh)                              | Privacy lint: real-looking IPs, hosts, emails, home paths, ticket ids, tokens | maintenance                                                                                                            |

## Log selection and output contract

Access-log wrappers and the Apache/Laravel error summaries use [`log_summary.py`](log_summary.py). `WINDOW` is a **Python regular expression**, not a shell glob or arbitrary grep ERE. The existing numeric timestamp patterns work; invalid expressions fail before reading. For access logs it searches the parsed receipt timestamp (without `[`). For Apache error logs it searches each source line; for Laravel it searches event-header timestamps and counts each exception header once, excluding trace lines.

Apache access helpers also accept paired `START_UTC` and `END_UTC` ISO timestamps with explicit offsets and select `[start, end)` after conversion to UTC. Prefer these to regexes for comparisons. The request-rate output is now `YYYY-MM-DDTHH:MMZ count`, sorted chronologically in UTC. Empty minutes remain omitted; verify coverage before filling zeros. Both boundaries are mandatory together. They are deliberately rejected for error-log/Laravel inputs, whose local timezone must be verified separately.

The supported access format is `%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i"` with optional appended fields. Escaped quotes are handled. Vhost-prefixed, JSON and other custom layouts require a different parser. Unparsable records or required missing fields cause exit 2 with **no aggregate on stdout**. Read/decompression/encoding errors likewise fail. Summaries go to stdout; raw/selected/rejected counts go to stderr. Exit 0 with no selected records is an explicit empty result, not proof of complete coverage or service health. No helper discovers rotations automatically or deduplicates exports.

```bash
RB=docs/runbooks/shared/commands
START_UTC=2026-10-13T08:17:00Z END_UTC=2026-10-13T08:30:00Z \
  "$RB"/apache/status-distribution.sh /var/log/apache2/access.log
WINDOW='2026-10-13 08:2[0-9]:' "$RB"/laravel/error-summary.sh /var/www/<app>/storage/logs/laravel.log
```

## Additional validation helpers

| Helper | Evidence supplied |
| --- | --- |
| [`apache/latency-summary.sh`](apache/latency-summary.sh) `LOG` | Nearest-rank p50/p95/p99 in milliseconds, counts split into all / success (2xx–3xx) / error (4xx–5xx); requires an existing appended `duration_us=%D` field on each selected record |
| [`verify-single-flight.py`](verify-single-flight.py) `EXPORT --run-id ID --key-hash HASH --requests N` | Offline verification of a complete instrumented [staging cold-key ledger](../single-flight-validation.md); does not send requests |
| [`tests/test_helpers.py`](tests/test_helpers.py) · [`tests/test_review_contracts.py`](tests/test_review_contracts.py) | Offline fixtures for parsing, schemas, approval navigation, rollback restoration and step contracts |

Counts stream over input without retaining all raw lines. Latency percentiles retain selected durations in memory; use bounded offline extracts for large windows. Apache error summaries keep only counts and the last 15 restart records. Exception/restart text can contain sensitive values and still requires redaction.

Netlify's helper validates JSONL objects, preserves CLI failures and counts **log records**, not invocations. It validates positive interval length, requires at least one UTC start, and calculates UTC end times without GNU-date parsing ambiguity. Set `NETLIFY_LOG_CAP` only to a verified limit for your CLI/platform; hitting it flags possible truncation. Below-cap output is still `completeness=unverified`.

Linux helpers fail on unavailable tools or command errors. Successful journal reads can still be incomplete due to retention or access restrictions; inspect notices and coverage. Service-recovery output labels current policy separately from historical journal evidence. Worker-capacity output deliberately provides no automatic recommendation.

## Schema adapters and documentation checks

[`netlify/traffic-metrics.jq`](netlify/traffic-metrics.jq) and [`netlify/function-metrics.jq`](netlify/function-metrics.jq) are separate, small jq adapters for selected Log Drain schemas. See the [schema-specific examples](../netlify-log-queries.md#schema-specific-metrics). They are not adapters for CLI application logs; function duration conversion requires verified units. These checks require jq; filesystem rollback fixtures also require rsync.

The shell link validator caches heading anchors once per target file, checks duplicate document IDs and rejects external operational links into mitigation preparation/application/rollback. Index/catalogue links remain navigation references. Syntax/link tests do not enforce permissions on a live server.

## Local verification

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s docs/runbooks/shared/commands/tests -v
bash docs/runbooks/shared/commands/validate-runbook-links.sh
bash docs/runbooks/shared/commands/check-anonymized.sh
```

See [systematic debugging](../debugging-method.md) for reproducible counts and [recovery evidence](../recovery-evidence.md) for acceptance gates. These local checks do not validate deployed-service behaviour.
