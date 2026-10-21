---
id: RB-08
title: Frontend and backend service dependencies, checkout
type: runbook
domain: dependencies
priority: P1
mode: read-only
status: active
owner: platform
updated: 2026-10-21
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

## Steps

[DEP-01](#dep-01) · [DEP-02](#dep-02) · [DEP-03](#dep-03) · [DEP-04](#dep-04) · [DEP-05](#dep-05)

## DEP-01

**Trace browser to SSR to CMS API request chains**

- **Objective:** List the backend calls one page view triggers. Compare backend call volume with visitor volume: if backend calls multiply while visitors do not, the frontend is amplifying (uncached fan-out) rather than receiving more users.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Use browser devtools (Network tab) for one representative page, or:
curl -s -o /dev/null -w "%{time_total}s\n" "$SITE/<path>"
# Count backend requests during a single render by timestamp window:
awk '$4 ~ /<HH:MM:SS>/ {print $7}' /var/log/apache2/access.log | cut -d? -f1 | sort | uniq -c | sort -nr | head
```

### Decision

| Result                                          | Next                                            |
| ----------------------------------------------- | ----------------------------------------------- |
| One render triggers many repeated backend calls | [RB-06/CCH-03](06-cache-invalidation.md#cch-03) |
| Calls are first-party and expected              | [RB-08/DEP-04](#dep-04)                         |
| Asset URLs trigger backend calls                | [RB-05/NET-05](05-netlify-ssr-cdn.md#net-05)    |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Request chain for a sample page with counts and timings.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## DEP-02

**Verify checkout, GraphQL, redirect, localisation and navigation dependencies**

- **Objective:** Know which endpoints each critical journey needs.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Exercise each journey in a test or staging environment; in production only use read-only requests:
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" "$SITE/<region-or-nav-endpoint>"
```

### Decision

| Result                                                                                                    | Next                                                                                                                               |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| A dependency fails or is slow                                                                             | [RB-04/APP-03](04-laravel.md#app-03) (backend) or [RB-05/NET-04](05-netlify-ssr-cdn.md#net-04) (SSR)                               |
| Checkout calls are made by the browser directly to the checkout origin, or through a frontend proxy route | Record which; it differs between branches, so verify against the deployed revision ([RB-09/CFG-02](09-deployment-drift.md#cfg-02)) |
| All dependencies healthy                                                                                  | [RB-08/DEP-03](#dep-03)                                                                                                            |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Journey, endpoints it needs, status and latency of each.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

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

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Impact statement per journey.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## DEP-04

**Distinguish normal SSR-generated requests from unauthorised requests**

- **Objective:** Prove or disprove that suspicious volume is your own frontend.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Compare SSR invocation count in the window with backend requests from the same user agent:
docs/runbooks/shared/commands/netlify/window-counts.sh server 5 <start-utc>
WINDOW='<timestamp regex>' "$RB"/apache/top-paths.sh /var/log/apache2/access.log 10
awk -F'"' '$6 ~ /^node/ {c++} END {print c " node requests"}' /var/log/apache2/access.log
# Roughly matching volumes support "first-party SSR"; capture the forwarded-for header to confirm (a logging change: RB-10/MIT-01).
```

### Decision

| Result                                              | Next                                                                                 |
| --------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Volumes match first-party SSR                       | Not abuse; return to [RB-02/TRF-06](02-apache-traffic.md#trf-06)                     |
| Volumes do not match or source ranges are unrelated | [RB-07/SEC-02](07-traffic-security.md#sec-02)                                        |
| Cannot tell without the real client address         | Needs a logging change: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

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

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Chosen route.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
