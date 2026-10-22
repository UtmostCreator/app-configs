---
id: RB-09
title: Deployment, environment and configuration drift
type: runbook
domain: deployment
priority: P1
mode: read-only
status: active
owner: platform
updated: 2026-10-22
tags: [deployment, drift, netlify, git, revision, config, environment, build-time, runtime-env, branch-drift]
symptoms: [started after deploy, works locally not in production, config mismatch]
steps: [CFG-01, CFG-02, CFG-03, CFG-04, CFG-05]
related: [RB-06, RB-10]
---

# RB-09 — Deployment, environment and configuration drift

> [Runbook index](../README.md) · Priority P1 · Mode: read-only

Verify what is really deployed and configured before trusting local code. Never print secrets; compare names and effective flags only. Read-only.

## Variables

```bash
SITE_ID=<netlify-site-id>
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[CFG-01](#cfg-01) · [CFG-02](#cfg-02) · [CFG-03](#cfg-03) · [CFG-04](#cfg-04) · [CFG-05](#cfg-05)

## CFG-01

**Verify the affected production site and deployment**

- **Objective:** Confirm which site and deploy served the incident.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
netlify status
netlify api listSiteDeploys --data '{"site_id":"'"$SITE_ID"'"}' | jq -r '.[0:10][] | [.id,.state,.created_at,.commit_ref] | @tsv'
```

### Decision

| Result | Next |
| --- | --- |
| Site and deploy confirmed | [RB-09/CFG-02](#cfg-02) |
| Several sites or contexts could match | Resolve via the [service map](../shared/service-map.md) first |

**Evidence to record:** Site id, deploy id, commit, build time.

**Return:** the invoking runbook

## CFG-02

**Compare deployed revision with locally inspected code**

- **Objective:** Make sure analysis was done on the deployed revision. A checked-out feature branch can contain different routes (for example a proxy route that was removed from the main branch).
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Use objects already present; do not fetch into the production checkout.
# If the deployed object is absent, obtain its artifact in an isolated investigation clone.
git cat-file -e '<deployed-commit>^{commit}'
git rev-parse HEAD
git diff --stat <deployed-commit> HEAD | tail -n 5
git log --oneline <deployed-commit>..HEAD | head
# Inspect the deployed file without checking it out:
git show <deployed-commit>:nuxt.config.ts | head -80
```

### Decision

| Result | Next |
| --- | --- |
| Revisions match | [RB-09/CFG-03](#cfg-03) |
| Local branch differs from production | Re-do findings against the deployed commit; return the confirmed differences to the caller |

**Evidence to record:** Deployed commit vs inspected commit and diff size.

**Return:** the invoking runbook

## CFG-03

**Confirm effective configuration flags and cache settings**

- **Objective:** Check flags without exposing secrets, and check when each is evaluated. A value read from the environment in the framework config is evaluated while the build runs; setting it only in the runtime environment may not change a deployed build.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Names and non-secret values only:
# Inspect the deployed source/artifact and existing allowlisted configuration telemetry.
# Do not boot Artisan in passive triage: providers and application hooks may have side effects.
# Do not dump cache config or environment values; either may include credentials.
# Review config/cache.php in the restricted deployed artifact; extract only allowlisted non-secret fields.
# A source default is not proof of the effective runtime value; record missing telemetry as unknown.
```

### Decision

| Result | Next |
| --- | --- |
| A flag differs from expectation or was changed after the deployed build | Re-verify the effective value against that deploy; [RB-09/CFG-04](#cfg-04) |
| A flag is correct in the dashboard but caching behaves as if off | Check build-time vs runtime evaluation; redeploy only through [RB-10/MIT-02](../response/10-mitigation-recovery.md#mit-02) |
| Config as expected | [RB-09/CFG-04](#cfg-04) |

**Evidence to record:** Flag names and effective values (no secrets).

**Return:** the invoking runbook

## CFG-04

**Correlate deployment events with the incident timeline**

- **Objective:** Check whether a deploy or config change coincides with onset.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
netlify api listSiteDeploys --data '{"site_id":"'"$SITE_ID"'"}' | jq -r '.[] | select(.created_at > "<UTC start minus 2h>") | [.created_at,.state,.commit_ref] | @tsv'
```

**Expected output:** A deploy shortly before onset is a hypothesis, not proof of the trigger.

### Decision

| Result | Next |
| --- | --- |
| Deploy coincides with onset | Record as hypothesis (a deploy clears the CDN and instance memory caches); [RB-09/CFG-05](#cfg-05) |
| No deploy near onset | Weakens the deploy hypothesis; look for other cache resets ([RB-06/CCH-01](06-cache-invalidation.md#cch-01)); [RB-09/CFG-05](#cfg-05) |

**Evidence to record:** Deploys and config changes within +/- 2h of onset.

**Return:** the invoking runbook

## CFG-05

**Return confirmed differences; route rollback candidates**

- **Objective:** Hand off.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result | Next |
| --- | --- |
| Rollback candidate identified | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Differences confirmed | Return to the invoking runbook |
| No differences | Return to the invoking runbook and state "no drift found" |

**Evidence to record:** Confirmed differences list.

**Return:** the invoking runbook
