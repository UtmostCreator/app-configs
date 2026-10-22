---
id: RB-SHARED-NETLIFY-QUERIES
title: Netlify log queries and observability reading rules
type: reference
domain: netlify
status: active
owner: platform
updated: 2026-10-22
tags: [netlify, logs, cli, truncation, observability, 504, functions, timestamps, sampling]
symptoms: [log query returns 100 records, no errors later in window, 100% errors in export]
---

# Netlify log queries and reading rules

> [Runbook index](../README.md) · Used by [RB-05](../diagnostics/05-netlify-ssr-cdn.md), [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03) and [RB-08/DEP-04](../diagnostics/08-service-dependencies.md#dep-04)

Queries retrieve existing logs; local evidence exports must be access-controlled. Pin the installed CLI version and inspect `netlify logs --help` before use. [Netlify documents JSON Lines output and historical window flags](https://docs.netlify.com/build/functions/logs/). Replace `<function>` (typically the SSR function name) and UTC timestamps.

## Query patterns

```bash
# CLI application log records only; not HTTP or invocation metrics.
netlify logs --source functions --function <function> \
  --since 2026-10-13T08:16:30Z --until 2026-10-13T08:16:35Z --json

docs/runbooks/shared/commands/netlify/window-counts.sh <function> 5 2026-10-13T08:16:30Z
```

## Schema-specific metrics

| Evidence | Valid interpretation |
| --- | --- |
| CLI function JSONL | Application log entries; multiple rows can belong to one execution |
| Traffic Log Drain | HTTP traffic rows; use request IDs and coverage to check duplicates |
| Regular-function Log Drain | Function records; request ID is not automatically a unique invocation ID; verify adapter/provider semantics before deduplicating |
| Platform invocation metrics | Invocation count for the selected deploy/function/interval, with the platform's coverage |

[Netlify's Log Drain schema](https://docs.netlify.com/manage/monitoring/log-drains/) distinguishes traffic fields (`url`, `status_code`, `duration`) from function fields (`path`, `function_name`, `status_code`, `duration`). Traffic duration is documented in milliseconds; verify function-duration units with the exporter before conversion. Edge records use a different layout and are not accepted by the regular-function adapter.

Prepare bounded, unfiltered, access-controlled exports of **one** schema for the incident window. Normalise with the checked adapters; do not apply them to CLI application log output. The subshell stops on adapter failure; discard any partial output after failure. Empty output is unknown, not a zero-traffic proof. Raw exports remain restricted because URLs/messages can contain secrets.

```bash
(
  set -euo pipefail
  RB=docs/runbooks/shared/commands
  jq -ce -f "$RB/netlify/traffic-metrics.jq" selected-traffic-drain.jsonl > traffic-metrics.jsonl
  test -s traffic-metrics.jsonl
  # Query only after successful normalisation. The adapter removes query strings/fragments.
  jq -r 'select(.status >= 500) | [.status,.path] | @tsv' traffic-metrics.jsonl | sort | uniq -c | sort -nr | sed -n '1,30p'
)
```

```bash
(
  set -euo pipefail
  RB=docs/runbooks/shared/commands
  # Set only after verifying this exporter's units; no default is assumed.
  : "${FUNCTION_DURATION_UNIT:?Set verified ms, us or s units}"
  jq -ce --arg duration_unit "$FUNCTION_DURATION_UNIT" -f "$RB/netlify/function-metrics.jq" selected-function-drain.jsonl > function-metrics.jsonl
  test -s function-metrics.jsonl
  jq -r 'select(.duration_ms > 5000) | [.duration_ms,.path,.request_id] | @tsv' function-metrics.jsonl | sort -nr | sed -n '1,20p'
)
```

The normalised `.status` and `.duration_ms` names are this repository's adapter output, not native CLI fields. Duplicate rows can repeat duration for the same request; select a verified terminal/invocation population before calculating distributions. These adapters validate field types, not retention, date bounds, deploy identity, completeness, or one-record-per-request semantics. Preserve that provenance separately.

## Reading rules

| Rule | Why |
| --- | --- |
| Timestamps with `Z` are UTC, the same as server logs with `+0000`. Do not shift by an hour | Local-time screenshots and monitors cause off-by-one-hour mistakes |
| Historical queries may be limited by CLI/platform, retention and plan | Record the verified limit; set `NETLIFY_LOG_CAP` accordingly. Hitting it means possible truncation. Below-cap output alone does not prove completeness. Shorten windows and reconcile with a complete export or invocation metrics |
| Identify whether a record timestamp is application event time, invocation start, completion or ingestion | Only subtract duration from a verified completion timestamp. Application log records can occur mid-invocation. One invocation can emit many records; counts are not invocation counts |
| A cluster of failures near one duration (for example 30 s) | A timeout boundary: the platform gave up, not a random slow request |
| An export filtered to errors shows "100% errors" for each URL | A filter artefact: it does not mean the URL always fails |
| Cache status `Miss` on every row of an error-only export | Says nothing about the overall miss rate; compare against an unfiltered window |
| Function memory (for example ~200 MB) is not the backend PHP memory limit | Different systems; do not compare them |
| A static asset path returns 504 | Confirm the producing layer and a linked invocation before claiming it reached a function; check routing ([RB-05/NET-05](../diagnostics/05-netlify-ssr-cdn.md#net-05)); the CDN should serve static files without a function |
| Framework error codes (for example `NUXT_E...`) before onset | Real application errors; record time and count, root cause unknown until traced |

## Sampling method

Pick windows at `T-30s`, `T`, `T+60s`, `T+90s` around onset, 5 s each. Record records, over-5-s count and longest duration. These are samples, not total traffic.

## Export schema and completeness

Use the schema-specific adapters above for selected Log Drain inputs. CLI log levels describe application entries; they do not establish invocation status, latency or CDN hit ratios. A missing cache field is unknown, not a cache miss. Use existing CDN/cache metrics for the same unfiltered request population and invocation metrics for the function denominator. Record exact CLI version, observed cap and retention; no universal 100-record contract is assumed.

[Netlify's Functions API](https://docs.netlify.com/build/functions/api/) describes function-duration semantics; distinguish them from timestamps on individual application log entries.
