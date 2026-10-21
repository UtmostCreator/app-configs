---
id: RB-SHARED-NETLIFY-QUERIES
title: Netlify log queries and observability reading rules
type: reference
domain: netlify
status: active
owner: platform
updated: 2026-10-21
tags: [netlify, logs, cli, truncation, observability, 504, functions, timestamps, sampling]
symptoms: [log query returns 100 records, no errors later in window, 100% errors in export]
---

# Netlify log queries and reading rules

> [Runbook index](../README.md) · Used by [RB-05](../diagnostics/05-netlify-ssr-cdn.md), [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03) and [RB-08/DEP-04](../diagnostics/08-service-dependencies.md#dep-04)

All queries are read-only. Replace `<function>` (typically the SSR function name) and UTC timestamps.

## Query patterns

```bash
# Records for a short window as JSON lines
netlify logs --source functions --function <function> \
  --since 2026-10-13T08:16:30Z --until 2026-10-13T08:16:35Z --json

# Count per window (truncation-aware helper)
docs/runbooks/shared/commands/netlify/window-counts.sh <function> 5 2026-10-13T08:16:30Z 2026-10-13T08:17:30Z

# Slowest executions in an export
jq -r 'select(.duration_ms > 5000) | [.duration_ms, .url] | @tsv' netlify-logs.jsonl | sort -nr | head
```

## Reading rules

| Rule | Why |
| --- | --- |
| Timestamps with `Z` are UTC, the same as server logs with `+0000`. Do not shift by an hour | Local-time screenshots and monitors cause off-by-one-hour mistakes |
| The CLI returns a limited batch (about 100 records) per query | A long window is truncated; if a count equals the cap, shorten the window and repeat. "No errors later" from a truncated batch is not evidence |
| Function duration logs are emitted at completion | A 29 s execution logged at `T` started near `T - 29 s`. Fewer completions in a window can mean slower requests, not fewer visitors |
| A cluster of failures near one duration (for example 30 s) | A timeout boundary: the platform gave up, not a random slow request |
| An export filtered to errors shows "100% errors" for each URL | A filter artefact: it does not mean the URL always fails |
| Cache status `Miss` on every row of an error-only export | Says nothing about the overall miss rate; compare against an unfiltered window |
| Function memory (for example ~200 MB) is not the backend PHP memory limit | Different systems; do not compare them |
| A static asset path returning 504 means it reached a function | Check routing ([RB-05/NET-05](../diagnostics/05-netlify-ssr-cdn.md#net-05)); the CDN should serve static files without a function |
| Framework error codes (for example `NUXT_E...`) before onset | Real application errors; record time and count, root cause unknown until traced |

## Sampling method

Pick windows at `T-30s`, `T`, `T+60s`, `T+90s` around onset, 5 s each. Record records, over-5-s count and longest duration. These are samples, not total traffic.
