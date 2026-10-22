---
id: RB-08
title: Frontend and backend service dependencies, checkout
type: runbook
domain: dependencies
priority: P1
mode: read-only
status: active
owner: platform
updated: 2026-10-22
tags:
  [
    dependencies,
    nuxt,
    ssr,
    graphql,
    checkout,
    localisation,
    navigation,
    request-chain,
    first-party-traffic,
    safe-block,
    shared-secret-header,
    checkout-proxy,
  ]
symptoms:
  [
    checkout broken,
    frontend broke after block,
    region or navigation missing,
    request fan-out,
    node user agent,
    block broke site,
    cached pages fail after cache expiry,
  ]
steps: [DEP-01, DEP-02, DEP-03, DEP-04, DEP-05]
related: [RB-02, RB-04, RB-05, RB-06, RB-07, RB-09, RB-10]
---

# RB-08 — Frontend and backend service dependencies, checkout

> [Runbook index](../README.md) · Priority P1 · Mode: read-only

Trace what the browser, the SSR layer and the CMS/API actually depend on, so that mitigation never breaks a critical customer flow. Server-side rendering calls the CMS host by design, so its requests carry the runtime user agent (for example `node`). Read-only.

## Variables

```bash
SITE=https://<site>
RB=docs/runbooks/shared/commands
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[DEP-01](#dep-01) · [DEP-02](#dep-02) · [DEP-03](#dep-03) · [DEP-04](#dep-04) · [DEP-05](#dep-05)

## DEP-01

**Trace browser to SSR to CMS API request chains**

- **Objective:** List parent-linked backend calls for one page view. More backend traffic with stable visitor volume suggests retries or fan-out; verify the request chain before assigning the cause.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Use browser devtools (Network tab) for one representative page, or:
# Optional active probe only after endpoint/side-effect review; otherwise use existing telemetry:
# curl --connect-timeout 3 --max-time 15 -sS -o /dev/null -w "%{time_total}s\n" "$SITE/<path>"
# Use existing trace/parent IDs to enumerate the render's backend spans.
# A timestamp window alone includes unrelated renders and cannot count this render's calls.
# Record missing correlation as unknown; see the shared request-correlation contract.
```

### Decision

| Result                                          | Next                                            |
| ----------------------------------------------- | ----------------------------------------------- |
| One render triggers many repeated backend calls | [RB-06/CCH-03](06-cache-invalidation.md#cch-03) |
| Calls are first-party and expected              | [RB-08/DEP-04](#dep-04)                         |
| Asset URLs trigger backend calls                | [RB-05/NET-05](05-netlify-ssr-cdn.md#net-05)    |

**Evidence to record:** Linked trace/parent IDs, service identity, retries, cache-key hash and per-render backend spans with timings; record sampling and missing propagation. See the [correlation contract](../shared/recovery-evidence.md#request-correlation).

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## DEP-02

**Verify checkout, GraphQL, redirect, localisation and navigation dependencies**

- **Objective:** Know which endpoints each critical journey needs.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Exercise each journey in a test or staging environment; in production only use read-only requests:
# Optional active probe only after endpoint/side-effect review; otherwise use existing telemetry:
# curl --connect-timeout 3 --max-time 15 -sS -o /dev/null -w "%{http_code} %{time_total}s\n" "$SITE/<region-or-nav-endpoint>"
```

### Decision

| Result                                                                                                    | Next                                                                                                                               |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| A dependency fails or is slow                                                                             | [RB-04/APP-03](04-laravel.md#app-03) (backend) or [RB-05/NET-04](05-netlify-ssr-cdn.md#net-04) (SSR)                               |
| Checkout calls are made by the browser directly to the checkout origin, or through a frontend proxy route | Record which; it differs between branches, so verify against the deployed revision ([RB-09/CFG-02](09-deployment-drift.md#cfg-02)) |
| All dependencies healthy                                                                                  | [RB-08/DEP-03](#dep-03)                                                                                                            |

**Evidence to record:** Journey, endpoints it needs, status and latency of each.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

### Network and connection timing

Prefer existing DNS, TLS, TCP retransmission, socket/pool and upstream span metrics for the incident window. Distinguish name-resolution delay, connect/TLS setup, time to first byte and full body time. Only after reviewing the endpoint's side effects, a bounded active probe can record `curl -w` fields `time_namelookup`, `time_connect`, `time_appconnect`, `time_starttransfer`, `time_total` alongside status and transport exit code. TLS connection reuse changes the interpretation; one synthetic request does not describe the visitor population. No DNS/TLS sample means that phase remains unknown.

## DEP-03

**Determine whether a blocked or unavailable service breaks critical flows**

- **Objective:** Quantify the customer impact of a proposed block or a failing service. Typical consequences of blocking first-party SSR traffic: region lookup failures become 500s on every uncached page, the no-store root page fails immediately, redirect lookups silently return empty, navigation and GraphQL come back empty; cached pages keep working only until their cache expires.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Replay the journey from RB-08/DEP-02 with the proposed control simulated in a non-production environment.
```

### Decision

| Result                    | Next                                                                                                                                                                                                                                                                                                       |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Critical flow would break | Reject the blanket control; [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) for a safer option such as a shared-secret header the frontend sends, with a rule that blocks only requests lacking it (platform functions have no fixed egress addresses, so address allow-lists are unreliable) |
| No critical impact        | [RB-08/DEP-05](#dep-05)                                                                                                                                                                                                                                                                                    |

**Evidence to record:** Impact statement per journey.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## DEP-04

**Distinguish normal SSR-generated requests from unauthorised requests**

- **Objective:** Prove or disprove that suspicious volume is your own frontend.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Compare log-record volume with backend traffic as a lead only (records are not invocations):
docs/runbooks/shared/commands/netlify/window-counts.sh server 5 <start-utc>
WINDOW='<timestamp regex>' "$RB"/apache/top-paths.sh /var/log/apache2/access.log 10
awk -F'"' '$6 ~ /^node/ {c++} END {print c " node requests"}' /var/log/apache2/access.log
# Matching volumes and user agents cannot authenticate callers. Use trusted trace propagation
# and an independently verified service identity; propose instrumentation via RB-10/MIT-01.
```

### Decision

| Result                                              | Next                                                                                 |
| --------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Trusted identity and linked request chain verify first-party calls | Return to [RB-02/TRF-06](02-apache-traffic.md#trf-06) with attribution evidence |
| Volumes match but identity or parentage is unverified | Keep attribution unknown; follow the [correlation contract](../shared/recovery-evidence.md#request-correlation) |
| Volumes do not match or source ranges are unrelated | [RB-07/SEC-02](07-traffic-security.md#sec-02)                                        |
| Cannot tell without the real client address         | Needs a logging change: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |

**Evidence to record:** Attribution decision with evidence.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## DEP-05

**Route to the failing layer**

- **Objective:** Hand off by layer.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result                     | Next                                                         |
| -------------------------- | ------------------------------------------------------------ |
| Backend content or GraphQL | [RB-04/APP-03](04-laravel.md#app-03)                         |
| Caching                    | [RB-06/CCH-03](06-cache-invalidation.md#cch-03)              |
| Mitigation needed          | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |

**Evidence to record:** Chosen route.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
