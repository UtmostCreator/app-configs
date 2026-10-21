---
id: INC-2026-10-13-hypotheses
title: 2026-10-13 incident — Hypotheses
type: incident-evidence
domain: incident-history
status: under-review
owner: platform
updated: 2026-10-21
tags: [incident, hypotheses, cache]
symptoms: [AH00161, oom-kill, 504, cache-clear, purge-storm, token-in-url]
---

# Hypotheses

> [Incident archive](../README.md) · [Runbook index](../../README.md)

| ID | Hypothesis | Supporting | Contradicting / open | Status |
| --- | --- | --- | --- | --- |
| HYP-001 | The 03:00 cache clear caused concurrent regeneration that exhausted memory and led to the OOM kills and outage | OBS-015, timeline order | Earlier PHP memory failures and the bulk job are contributing factors; no controlled reproduction. An earlier note called this the root cause; it stays a hypothesis | hypothesis (strong) |
| HYP-002 | Uncoordinated cache-aside misses (redirects, GraphQL) amplified SSR-to-backend load in the morning | OBS-014, OBS-005, OBS-006 | Amplification mechanism only; not proof of the initial trigger | hypothesis |
| HYP-003 | A deploy or cache reset initiated the ~08:17 surge | A deploy clears CDN and instance caches | OBS-009: no deploy found; publish history not yet confirmed | hypothesis (trigger unverified) |
| HYP-004 | Whole-site purges kept the backend load elevated after 08:50 | OBS-010, OBS-016 | Purges did not start the surge | hypothesis (amplifier, not trigger) |
| HYP-005 | The frontend cache is not shared across serverless instances | OBS-011 | `removed: []` only shows no matching keys were visible to that instance; key-prefix mismatch or expiry are alternatives | unverifiable |
| HYP-006 | Legacy static assets fall through to SSR middleware that calls the backend | OBS-007, OBS-018 | Individual request tracing not done | hypothesis |
| HYP-007 | The `node` traffic is an attack | none | OBS-012: first-party SSR sends it; user agent alone is not attribution | rejected |

Routes to test these: [RB-06/CCH-05](../../diagnostics/06-cache-invalidation.md#cch-05), [RB-06/CCH-07](../../diagnostics/06-cache-invalidation.md#cch-07), [RB-09/CFG-04](../../diagnostics/09-deployment-drift.md#cfg-04), [RB-08/DEP-04](../../diagnostics/08-service-dependencies.md#dep-04), [RB-05/NET-05](../../diagnostics/05-netlify-ssr-cdn.md#net-05).

See also: [timeline](timeline.md) · [observations](observations.md) · [hypotheses](hypotheses.md) · [actions](actions.md) · [conclusions](conclusions.md)
