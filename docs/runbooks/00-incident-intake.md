---
id: RB-00
title: Incident intake and decision routing
type: runbook
domain: intake
priority: P0
mode: read-only
status: active
owner: platform
updated: undated
tags: [intake, triage, router, on-call, severity]
symptoms: [any incident, unknown cause, customer report]
steps: [INC-01, INC-02, INC-03, INC-04, INC-05]
related: [RB-01, RB-02, RB-03, RB-04, RB-05, RB-06, RB-07, RB-08, RB-09, RB-10, RB-11]
---

# RB-00 — Incident intake and decision routing

> [Runbook index](README.md) · Priority P0 · Mode: read-only

Single entry point for every incident. Establish scope and time window, then route to the specialist runbook that owns the strongest symptom. Specialist runbooks return here with findings; close only through [RB-11/VAL-06](response/11-validation-review.md#val-06).

All steps follow the [shared execution and evidence gates](shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Incident control

Runbook P0/P1 indicates procedure priority, not incident severity. Assign severity using customer impact, affected functions, duration and the team's incident policy. Record the incident commander, technical investigator, mitigation operator, escalation contact, next update time and communications location. One person may hold several roles; name them explicitly.

For a severe ongoing incident, split volatile-evidence preservation and mitigation planning between available responders. Do not wait for a confirmed root cause before planning a reversible mitigation through [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01). Unknown target or approval still blocks production changes. Escalate when impact grows, an agreed response deadline passes, or authority/evidence is unavailable. Cross-runbook returns must include new evidence or a next measurement; if a route cycles without progress, return to the incident commander for reassessment.

## Steps

[INC-01](#inc-01) · [INC-02](#inc-02) · [INC-03](#inc-03) · [INC-04](#inc-04) · [INC-05](#inc-05)

## INC-01

**Identify affected service, environment and customer impact**

- **Objective:** Name what is broken, where, and who is affected, using the [service map](shared/service-map.md). Include external monitor evidence: an intermittent pattern (fast responses mixed with timeouts) points to contention, not a total outage.
- **Mode:** Read-only
- **Preconditions:** Initial incident report and access to the service map; validate sources as they are identified.

### Commands

```bash
# Record answers in the incident notes; no production commands required.
# Use existing monitor observations; active probing requires the INC-03 review.
# External uptime monitor: note timeout rate, p50 and p95 against the monitor's timeout ceiling.
# Prior art (FP-0): same signature, route or symptom already archived?
grep -rniE '<signature or route>' docs/runbooks/incidents --include='*.md' | cut -c1-160
```

Copy from the error-tracker issue before any server command: transaction/culprit route, URL path, first/last seen, event count, release, runtime SAPI, server name, trace ID and the last breadcrumbs. Analyse exports already attached to the ticket offline first. Start the [action ledger](incidents/_template/actions.md) now: every restart, reload, block, cache clear or config edit already made, with UTC time and actor role. See the [fast path](shared/fast-path.md) for the one-paste bundle that follows.

### Decision

| Result                                     | Next                                                                                                         |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Service, environment and impact identified | [RB-00/INC-02](#inc-02)                                                                                      |
| Archive or error tracker already names the route or pattern | [RB-00/INC-02](#inc-02), then the matching [fast path discriminator](shared/fast-path.md#fp-2--one-discriminator-per-symptom) instead of window sampling |
| Cannot tell which environment is affected  | Check the [service map](shared/service-map.md), then repeat; if still unclear escalate to the incident owner |

**Evidence to record:** Service name, environment, user-visible impact, who reported it and how, external monitor timeout rate and p50/p95, matching archive entries, error-tracker fields, actions already taken.

**Return:** [RB-00/INC-05](#inc-05)

## INC-02

**Record UTC start time, symptoms and incident window**

- **Objective:** Fix the investigation window so every later query uses the same UTC bounds.
- **Mode:** Read-only
- **Preconditions:** Initial report with candidate event times and source identities; establish provisional UTC bounds here, then validate source clocks through [RB-01/EVD-02](foundations/01-evidence-attribution.md#evd-02). Unknown zones remain explicit.

### Commands

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"   # now, in UTC
timedatectl | grep -E "Time zone|System clock"
```

### Decision

| Result                                                  | Next                                                          |
| ------------------------------------------------------- | ------------------------------------------------------------- |
| Window recorded (start, end or "ongoing")               | [RB-00/INC-03](#inc-03)                                       |
| Source timestamps are not in UTC or the zone is unknown | [RB-01/EVD-02](foundations/01-evidence-attribution.md#evd-02) |

**Evidence to record:** UTC start, UTC end (or ongoing), first symptom, first alert, first report.

**Return:** [RB-00/INC-05](#inc-05)

## INC-03

**Determine whether the incident is ongoing**

- **Objective:** Decide between live triage (state changes quickly) and post-hoc investigation (state is gone).
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](foundations/01-evidence-attribution.md))

### Commands

```bash
uptime
# Read existing uptime/APM/edge monitors for this incident window.
# Do not default to homepage or SSR requests. No reviewed safe endpoint => active probing unavailable.
```

### Decision

| Result                                          | Next                                                                                                                            |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Ongoing and customer-impacting                  | Continue to [RB-00/INC-04](#inc-04); keep [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01) in mind for fast mitigation |
| Resolved or intermittent                        | [RB-00/INC-04](#inc-04); collect volatile evidence first via [RB-01/EVD-03](foundations/01-evidence-attribution.md#evd-03)      |
| Service has been down for hours with no restart | [RB-03/CAP-06](diagnostics/03-apache-capacity.md#cap-06); nothing may have restarted it and no alert may have fired             |
| Existing monitors unavailable and no reviewed safe endpoint | Record ongoing state as unknown; continue passive diagnosis and escalate the monitoring gap |

An active probe is optional and requires an explicit execution review before invocation: record the exact health endpoint, authorisation, bounded frequency, known side effects and expected cost. A homepage is not a fallback. After review only, use the bounded command below with the reviewed URL; do not send authentication secrets on the command line.

```bash
# REVIEWED_HEALTH_URL must be the exact endpoint recorded in the execution review.
: "${REVIEWED_HEALTH_URL:?No reviewed safe endpoint; active probing unavailable}"
curl --connect-timeout 3 --max-time 15 --retry 0 -sS -o /dev/null \
  -w "%{http_code} %{time_total}s\n" "$REVIEWED_HEALTH_URL"
```

**Evidence to record:** Ongoing yes/no/unknown, existing monitor interval, current error rate and latency; any probe review, timeout, side effects and result. A curl error or timeout is a failed observation, not a healthy HTTP result.

**Return:** [RB-00/INC-05](#inc-05)

## INC-04

**Route by the strongest symptom**

- **Objective:** Pick exactly one specialist runbook to start with.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result                                                            | Next                                                                                                                                    |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP 502/503/504, SSR timeouts, CDN errors                        | [RB-05/NET-01](diagnostics/05-netlify-ssr-cdn.md#net-01)                                                                                |
| OOM kill, `AH00161`, worker cap, host memory or CPU pressure      | [RB-03/CAP-01](diagnostics/03-apache-capacity.md#cap-01)                                                                                |
| Traffic anomaly, unexpected request volume                        | [RB-02/TRF-01](diagnostics/02-apache-traffic.md#trf-01)                                                                                 |
| PHP/Laravel exceptions, `Allowed memory size`                     | [RB-04/APP-01](diagnostics/04-laravel.md#app-01) (start with `fatal-correlate.py`, not window sampling)                                  |
| Surge or saturation where an attack is suspected                  | [RB-02/TRF-04](diagnostics/02-apache-traffic.md#trf-04) (`route-mix.sh` with first-party agent share) before any block                 |
| Repeated upstream fetches, stale or missing content after a purge | [RB-06/CCH-01](diagnostics/06-cache-invalidation.md#cch-01)                                                                             |
| Exposed credential or secret                                      | [RB-07/SEC-01](diagnostics/07-traffic-security.md#sec-01) (notify the incident owner immediately; do not wait for approval to escalate) |
| Checkout or frontend journey broken                               | [RB-08/DEP-03](diagnostics/08-service-dependencies.md#dep-03)                                                                           |
| Started right after a deploy or config change                     | [RB-09/CFG-04](diagnostics/09-deployment-drift.md#cfg-04)                                                                               |
| Evidence missing or untrusted                                     | [RB-01/EVD-01](foundations/01-evidence-attribution.md#evd-01)                                                                           |

**Evidence to record:** Chosen runbook and the symptom that drove the choice.

**Return:** [RB-00/INC-05](#inc-05)

## INC-05

**Reassess after specialist investigation and close**

- **Objective:** Decide whether the evidence supports a root cause, needs another route, or can move to recovery.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result                            | Next                                                                                                           |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Root cause sufficiently supported | [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01)                                                      |
| New symptom surfaced              | [RB-00/INC-04](#inc-04)                                                                                        |
| Mitigated and verified            | [RB-11/VAL-06](response/11-validation-review.md#val-06) (close only through it)                                |
| Still unexplained                 | Archive observations in the [incident archive](incidents/README.md) and state unresolved hypotheses explicitly |

**Evidence to record:** Current best-supported hypothesis, confidence, open questions.

**Return:** [RB-00/INC-05](#inc-05)
