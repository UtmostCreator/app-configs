---
id: RB-11
title: Regression validation and post-incident review
type: runbook
domain: validation
priority: P1
mode: passive-and-isolated-tests
status: active
owner: platform
updated: undated
tags: [validation, regression, post-incident, review, acceptance, baseline, follow-up]
symptoms: [verify recovery, close incident, write review]
steps: [VAL-01, VAL-02, VAL-03, VAL-04, VAL-05, VAL-06]
related: [RB-00, RB-06, RB-08, RB-10]
---

# RB-11 — Regression validation and post-incident review

> [Runbook index](../README.md) · Priority P1 · Mode: passive evidence and isolated staging tests

Measure recovery using the [evidence matrix](../shared/recovery-evidence.md#recovery-measurement-matrix) and capture the review. Missing critical measurements remain unknown. Track repository corrections separately from the [operational qualification record](../shared/qualification-status.md). Close an incident only through [RB-11/VAL-06](#val-06).

## Variables

```bash
RB=docs/runbooks/shared/commands
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[VAL-01](#val-01) · [VAL-02](#val-02) · [VAL-03](#val-03) · [VAL-04](#val-04) · [VAL-05](#val-05) · [VAL-06](#val-06)

## VAL-01

**Check service health, latency, error rates and resource consumption**

- **Objective:** Confirm that the service is healthy by measurement.
- **Mode:** Read-only
- **Preconditions:** Target, execution mode and evidence window validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Select an explicit post-change UTC window and complete evidence files first.
: "${START_UTC:?Set the recorded post-change window start in UTC}"
: "${END_UTC:?Set the recorded post-change window end in UTC}"
export START_UTC END_UTC
"$RB"/apache/request-rate.sh /var/log/apache2/access.log
"$RB"/apache/status-distribution.sh /var/log/apache2/access.log
# Only on an existing format with duration_us=%D; otherwise use existing APM/edge latency.
"$RB"/apache/latency-summary.sh /var/log/apache2/access.log
"$RB"/linux/memory-snapshot.sh # Current state only; obtain interval pressure/OOM metrics separately.
```

### Decision

| Result | Next |
| --- | --- |
| Every required signal has a complete measurement within agreed [thresholds](../shared/thresholds.md) | [RB-11/VAL-02](#val-02) |
| Critical signal missing / unknown | Keep recovery unverified; obtain the missing measurement or record an explicit incident-owner risk acceptance |
| Out of thresholds | [RB-00/INC-04](../00-incident-intake.md#inc-04) |

**Evidence to record:** Error rate, latency, memory and load vs baseline.

**Return:** [RB-00/INC-05](../00-incident-intake.md#inc-05)

## VAL-02

**Select incident-specific regressions and run applicable cache tests**

- **Objective:** Select relevant regressions; demonstrate cache behaviour when the incident or mitigation affects it.
- **Mode:** Active isolated staging experiment; offline evidence verification is passive
- **Preconditions:** Target, execution mode and evidence window validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

Before running tests, record each candidate regression as **applicable**, **not-applicable** or **unresolved**, with rationale and supporting incident/change evidence. Mark applicable cases as required. Cache/lock/invalidation changes or a stampede hypothesis require the cache experiment; a DNS-only or certificate-only incident may justify not-applicable. Authentication, routing and critical journeys also require an explicit selection rather than automatic active requests. Uncertain relevance is unresolved, never not-applicable. Track selected tests and results in the incident record.

For applicable cache cases, follow the [isolated single-flight protocol](../shared/single-flight-validation.md). It requires an application-specific barrier/latch harness, two identified instances, a unique cold key, independently counted upstream attempts and correct results for every caller. Do not substitute request-path counts or HTTP success for these measurements.

```bash
# Offline validation of the complete staging ledger; does not send requests:
python3 "$RB"/verify-single-flight.py cold-key-events.jsonl \
  --origin-ledger mock-origin-events.jsonl \
  --run-id synthetic-run --key-hash synthetic-key --requests 100
```

**Expected output:** One actual upstream attempt and cache publication for 100 verified concurrent misses across at least two instances; all callers receive the expected value. Complete warm-read, invalidation, expiry, failure, authentication and routing cases from the protocol. If the harness or complete upstream ledger is missing, mark the case unresolved.

### Decision

| Result | Next |
| --- | --- |
| All applicable required cache cases pass | [RB-11/VAL-03](#val-03) for the next selected regression |
| Cache cases documented not-applicable with rationale | [RB-11/VAL-03](#val-03); skip other explicitly not-applicable cases and continue to VAL-05 |
| Applicability unresolved or a required case lacks evidence | Keep validation unresolved; obtain evidence or record an explicit qualified risk decision at VAL-05 |
| Fails | [RB-06/CCH-05](../diagnostics/06-cache-invalidation.md#cch-05) |

**Evidence to record:** Regression selection, rationale, required cases and pass/fail/unresolved results; revision, cache/lock scope, namespace/key hash, barrier/latch evidence, instance and caller IDs, upstream ledger reconciliation, value assertions, timeout/retry counts and cleanup result.

**Return:** [RB-00/INC-05](../00-incident-intake.md#inc-05)

## VAL-03

**Check authentication, rate limiting and legitimate-user access**

- **Objective:** Verify protective controls do not block legitimate users.
- **Mode:** Active validation in isolated staging; production probes only at reviewed safe endpoints
- **Preconditions:** Target, execution mode and evidence window validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

Run only when selected as applicable at VAL-02. In production, use only individually reviewed safe endpoints with known side effects; if none exists, mark active validation unavailable and use existing monitoring.

```bash
curl --connect-timeout 3 --max-time 15 -sS -o /dev/null -w "%{http_code}\n" https://<site>/<public-path>
curl --connect-timeout 3 --max-time 15 -sS -o /dev/null -w "%{http_code}\n" https://<site>/<protected-path>
```

### Decision

| Result | Next |
| --- | --- |
| Public access works, protected paths protected | [RB-11/VAL-04](#val-04) |
| False positives found | [RB-10/MIT-01](10-mitigation-recovery.md#mit-01) |

**Evidence to record:** Per-path expected status **and semantics**: authenticated principal/role, denied protected operation, no side effects on rejected requests, correct authorised payload/action, missing/empty/invalid/revoked credentials rejected, rate-limit response and permitted-user behaviour. A redirect to a login page, cached 200, or custom error payload can make status-only checks misleading. Exercise state-changing operations only in isolated staging. Include the [proxy spoofing cases](../foundations/01-evidence-attribution.md#proxy-trust-acceptance) after trust changes.

**Return:** [RB-00/INC-05](../00-incident-intake.md#inc-05)

## VAL-04

**Verify frontend, CMS and checkout end-to-end journeys**

- **Objective:** Run the critical journeys.
- **Mode:** Active validation in isolated staging; production probes only at reviewed safe endpoints
- **Preconditions:** Target, execution mode and evidence window validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Only if selected as applicable at VAL-02: manual or scripted journey in staging.
# Record each step and outcome; justified not-applicable cases proceed to VAL-05.
```

### Decision

| Result | Next |
| --- | --- |
| Journeys pass | [RB-11/VAL-05](#val-05) |
| A journey fails | [RB-08/DEP-02](../diagnostics/08-service-dependencies.md#dep-02) |

**Evidence to record:** Journey results.

**Return:** [RB-00/INC-05](../00-incident-intake.md#inc-05)

## VAL-05

**Compare measured results with baseline and acceptance criteria**

- **Objective:** Make the acceptance decision explicit.
- **Mode:** Read-only
- **Preconditions:** Target, execution mode and evidence window validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Compare with [thresholds](../shared/thresholds.md).
```

### Decision

| Result | Next |
| --- | --- |
| All required rows pass, or the incident owner records a qualified decision with explicit gaps | [RB-11/VAL-06](#val-06) |
| Not accepted | [RB-00/INC-04](../00-incident-intake.md#inc-04) |

**Evidence to record:** Incident-specific regression selection and results (including justified not-applicable cases and unresolved required cases), completed [measurement matrix](../shared/recovery-evidence.md#recovery-measurement-matrix), per-signal pass/fail/unknown, observation duration, rollback triggers and any incident-owner risk acceptance.

**Return:** [RB-00/INC-05](../00-incident-intake.md#inc-05)

## VAL-06

**Record outcomes, unresolved hypotheses and follow-ups**

- **Objective:** Archive evidence and close.
- **Mode:** Local documentation/evidence write; no production changes
- **Preconditions:** Target, execution mode and evidence window validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Copy docs/runbooks/incidents/_template to docs/runbooks/incidents/<YYYY-MM-DD> and fill it in,
# including command-review.md: response metrics always; the full keep/merge/shorten/drop review when the
# template's criteria apply (severity 1-2, harmful action, acted-on wrong hypothesis, recurrence, > 10 rounds).
```

Promote new reusable commands to the [command helpers](../shared/commands/README.md) and new "do not run" patterns to the [fast path](../shared/fast-path.md), so the next investigation starts from them.

### Decision

| Result | Next |
| --- | --- |
| Recovery decision is supported and evidence archived | [RB-00/INC-05](../00-incident-intake.md#inc-05) to close |

**Evidence to record:** Link to the [incident archive](../incidents/README.md) entry, production rounds used versus the shortest path in hindsight.

**Return:** [RB-00/INC-05](../00-incident-intake.md#inc-05)
