---
id: RB-05
title: Netlify SSR, CDN and request-routing failures
type: runbook
domain: netlify
priority: P0
mode: read-only
status: active
owner: platform
updated: 2026-10-21
tags: [netlify, ssr, cdn, 504, functions, nuxt, cache-status, latency, truncation, sample-windows, timeout, static-assets, route-rules]
symptoms: [504, 502, 503, SSR timeout, slow pages, legacy images failing, 30 second timeouts, static asset 504, log query returns 100 records]
steps: [NET-01, NET-02, NET-03, NET-04, NET-05, NET-06, NET-07]
related: [RB-00, RB-01, RB-03, RB-06, RB-08, RB-09, RB-10]
---

# RB-05 — Netlify SSR, CDN and request-routing failures

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Investigate server-side rendering latency, CDN misses, function invocations and routing on Netlify, and trace how they amplify load on the backend CMS/API. Read-only. Platform log queries are truncated and function-duration logs are emitted at completion, so use short sampled windows and do not read a drop in completions as fewer visitors.

## Variables

```bash
SITE=https://<site>
SITE_ID=<netlify-site-id>
```

## Steps

[NET-01](#net-01) · [NET-02](#net-02) · [NET-03](#net-03) · [NET-04](#net-04) · [NET-05](#net-05) · [NET-06](#net-06) · [NET-07](#net-07)

## NET-01

**Measure 500/502/503/504 counts, durations and affected URLs**

- **Objective:** Quantify the failures and which URLs they touch. A cluster of durations at one value (for example ~30 s) is a timeout boundary, not slowness. An error-filtered export shows 100% errors for every URL; that is a filter artefact, not proof each URL always fails.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# From a Netlify log export or log drain (JSON lines), adjust field names to your export:
jq -r 'select(.status>=500) | [.status,.url] | @tsv' netlify-logs.jsonl | sort | uniq -c | sort -nr | head -30
# Spot check live behaviour and headers:
curl -sI "$SITE/<path>" | grep -iE "^(HTTP|cache-status|age|x-nf-request-id)"
```

### Decision

| Result | Next |
| --- | --- |
| 504s cluster near a common timeout on SSR pages | [RB-05/NET-02](#net-02) |
| 504s on static or legacy asset URLs | [RB-05/NET-05](#net-05) |
| Failures are widespread (pages and assets together) | Broad request-serving failure: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) for impact reduction while investigating; [RB-05/NET-02](#net-02) |
| Malformed URLs (for example a literal `undefined` path segment) | Frontend bug; record separately for [RB-08/DEP-02](08-service-dependencies.md#dep-02) |
| No failures in this window | [RB-01/EVD-02](../foundations/01-evidence-attribution.md#evd-02); check the window and timezone |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Counts by status, URL groups, duration percentiles, window in UTC.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## NET-02

**Sample short windows around onset to size the change**

- **Objective:** Compare function activity just before, at and after onset with short windows, because log queries return a limited batch and long windows are truncated.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
docs/runbooks/shared/commands/netlify/window-counts.sh server 5 <T-30s> <T> <T+60s> <T+90s>
# Equivalent single query:
netlify logs --source functions --function server --since <start-utc> --until <end-utc> --json | wc -l
```

**Expected output:** A count equal to the cap (about 100) means the window is truncated: shorten it. Record counts, over-5s counts and the longest duration per window.

### Decision

| Result | Next |
| --- | --- |
| Activity multiplied and durations jumped (for example over 20x more completions, most over 5 s) | [RB-05/NET-03](#net-03) |
| Counts hit the cap | Shorten windows and repeat; do not conclude "no errors later" from a truncated batch |
| No change in activity | [RB-05/NET-04](#net-04) |

**If the result is unknown:** Record "unverifiable" and use a log drain or exported observability data.

**Evidence to record:** Table: window start (UTC), records, over-5s count, longest duration. Timestamps are when logs were emitted (about execution end), not request start; a slow request can start up to its duration earlier.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## NET-03

**Correlate CDN misses and function invocations**

- **Objective:** See whether cache misses and invocations rise before the errors, and which routes are not CDN-cacheable at all.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
jq -r '[.cache_status // "none"] | @tsv' netlify-logs.jsonl | sort | uniq -c
netlify logs --source functions --function <function-name> --since <start-utc> --until <end-utc> --json | jq -r '.level // empty' | sort | uniq -c
```

### Decision

| Result | Next |
| --- | --- |
| High miss ratio with rising invocations | [RB-05/NET-04](#net-04) |
| Hit ratio healthy | [RB-05/NET-04](#net-04) |
| Cache headers missing or inconsistent | [RB-06/CCH-02](06-cache-invalidation.md#cch-02) |
| Route rules send the bare root or other hot routes to `private, no-store` | Those routes bypass the CDN and every request hits SSR: record and check intent before changing ([RB-09/CFG-03](09-deployment-drift.md#cfg-03)) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Hit/miss ratio and invocation counts per interval.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## NET-04

**Inspect slow functions and outgoing CMS requests**

- **Objective:** Measure how long SSR waits on the backend and how many backend calls each render makes.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
jq -r 'select(.duration_ms>5000) | [.duration_ms,.url] | @tsv' netlify-logs.jsonl | sort -nr | head -20
# Compare with backend request volume for the same window:
docs/runbooks/shared/commands/apache/request-rate.sh /var/log/apache2/access.log | tail -n 30
```

### Decision

| Result | Next |
| --- | --- |
| Backend calls per render are high or repeated | [RB-08/DEP-01](08-service-dependencies.md#dep-01) |
| Identical backend fetches repeat in parallel | [RB-06/CCH-03](06-cache-invalidation.md#cch-03) |
| Backend is slow, SSR is not the cause | [RB-03/CAP-01](03-apache-capacity.md#cap-01) |
| Function memory is high | Netlify function memory is separate from the backend PHP limit; note it and do not compare the two |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Slow function samples, backend calls per request, correlated backend load, any framework error codes seen (for example `NUXT_E...`) with their timestamps.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## NET-05

**Verify whether legacy image and static URLs reach SSR middleware**

- **Objective:** Static assets should not consume function time. Check whether legacy asset paths are missing from published static files and fall through to SSR middleware that calls the backend on every request.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
curl -sI "$SITE/<legacy-asset-path>" | grep -iE "^(HTTP|server|cache-status|x-nf-request-id)"
# Look for catch-all rewrites and route rules that send assets to the SSR function:
grep -nE "^\[\[(redirects|headers)\]\]" -A6 netlify.toml | head -60
grep -nE "routeRules" -A25 nuxt.config.ts | head -50
# Do the files exist in the published static output?
ls public/<asset-dir> 2>/dev/null | head
```

### Decision

| Result | Next |
| --- | --- |
| Assets fall through to SSR (not in static output, not covered by rules) | Request chain: [RB-08/DEP-01](08-service-dependencies.md#dep-01); fix candidates for [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Assets are served by the CDN | [RB-05/NET-06](#net-06) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Request path for a sample asset, routing rule that matched.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## NET-06

**Check deployment and published configuration**

- **Objective:** Confirm the published deploy and settings match what you are reading.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
netlify status
netlify api listSiteDeploys --data '{"site_id":"'"$SITE_ID"'"}' | jq -r '.[0:5][] | [.id,.state,.created_at,.commit_ref] | @tsv'
```

### Decision

| Result | Next |
| --- | --- |
| Deploy or config differs from expectations | [RB-09/CFG-01](09-deployment-drift.md#cfg-01) |
| No production deploy near onset | Weakens the deploy-trigger hypothesis but does not rule out other cache resets; [RB-09/CFG-04](09-deployment-drift.md#cfg-04) |
| Matches | [RB-05/NET-07](#net-07) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Current published deploy id, commit and build time.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## NET-07

**Route upstream amplification, cache misses and widespread failure**

- **Objective:** Hand off to the owning runbook.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result | Next |
| --- | --- |
| Upstream amplification of CMS/API requests | [RB-08/DEP-01](08-service-dependencies.md#dep-01) |
| Cache misses or stampede | [RB-06/CCH-03](06-cache-invalidation.md#cch-03) |
| Widespread customer-facing failure | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Nothing further | [RB-00/INC-05](../00-incident-intake.md#inc-05) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Chosen route and evidence.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
