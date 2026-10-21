---
id: RB-10
title: Safe mitigation, recovery and rollback
type: runbook
domain: mitigation
priority: P0
mode: changes-production
status: active
owner: platform
updated: 2026-10-21
tags: [mitigation, recovery, rollback, change-approval, restart, capacity, waf, token-rotation, mod_remoteip, x-forwarded-for, restart-policy, alerting, token-header]
symptoms: [need to restore service, approved change, rollback required]
steps: [MIT-01, MIT-02, MIT-03, MIT-04, MIT-05, MIT-06]
related: [RB-00, RB-08, RB-11]
---

# RB-10 — Safe mitigation, recovery and rollback

> [Runbook index](../README.md) · Priority P0 · Mode: changes production (approval gated)

The only runbook that changes production state: configuration edits, cache clears, restarts, WAF changes and token rotation. Every change needs approval, a rollback, and monitoring. Steps here are marked Changes production.

## Steps

[MIT-01](#mit-01) · [MIT-02](#mit-02) · [MIT-03](#mit-03) · [MIT-04](#mit-04) · [MIT-05](#mit-05) · [MIT-06](#mit-06)

## MIT-01

**Define the immediate mitigation and alternatives**

- **Objective:** Pick the least risky action that reduces customer impact.
- **Mode:** Read-only (planning)
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Planning step. Prefer reversible, narrow, observable options:
# 1) serve stale/cached content  2) reduce concurrency safely  3) scoped rate limit  4) rollback a deploy
# Recurring candidates from the runbooks (each needs approval at RB-10/MIT-02):
# - replace an unconditional cache flush with targeted invalidation and coalesced purges (RB-06/CCH-07)
# - single-flight / lock around cold cache rebuilds (RB-06/CCH-05)
# - rotate exposed credentials and move them to a header, shipped together (RB-07/SEC-05)
# - record the forwarded client address (mod_remoteip with an explicit trusted-proxy list) (RB-01/EVD-04)
# - add an availability alert and an automatic restart policy (RB-03/CAP-06)
# - memory-model the Apache worker cap before changing it; longer term consider Event + PHP-FPM (RB-03/CAP-02)
```

### Decision

| Result | Next |
| --- | --- |
| Mitigation chosen | [RB-10/MIT-02](#mit-02) |
| Only a blanket control available | Re-check [RB-08/DEP-03](../diagnostics/08-service-dependencies.md#dep-03) before proceeding |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Chosen mitigation, alternatives rejected and why.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-02

**Check approval, production permissions and collateral damage**

- **Objective:** Confirm you are authorised and the blast radius is understood.
- **Mode:** Read-only (approval gate)
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Record approver and approval time. Confirm:
# - who can authorise this change
# - dependent services (see service map)
# - maintenance window requirements
```

### Decision

| Result | Next |
| --- | --- |
| Approved | [RB-10/MIT-03](#mit-03) |
| Not approved or approver unreachable | Stop; escalate to the incident owner. Credential exposure notifications are never blocked by this gate |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Approver, time, scope.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-03

**Prepare change, monitoring, rollback and dependency validation**

- **Objective:** Have rollback and monitoring ready before applying anything.
- **Mode:** Read-only (preparation)
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Snapshot current state for rollback, e.g. for Apache config:
sudo cp -a /etc/apache2 /root/apache2.bak.$(date -u +%Y%m%dT%H%M%SZ)
sudo apache2ctl configtest
```

### Decision

| Result | Next |
| --- | --- |
| Change, rollback and monitoring prepared | [RB-10/MIT-04](#mit-04) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Change diff, rollback command, dashboards to watch.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-04

**Apply only the authorised mitigation**

- **Objective:** Apply exactly the approved change, nothing more.
- **Mode:** Changes production
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Example: record the forwarded client address (adapt to the approved change).
# Verify first that the header really carries client addresses and use your own load balancer address.
sudo a2enmod remoteip
printf 'RemoteIPHeader X-Forwarded-For\nRemoteIPTrustedProxy <load-balancer-private-address>\n' | sudo tee /etc/apache2/conf-available/remoteip.conf >/dev/null
sudo a2enconf remoteip
sudo apache2ctl configtest && sudo systemctl reload apache2
# Example: automatic restart policy
sudo systemctl edit apache2   # add [Service] with Restart=on-failure and RestartSec=5
```

### Decision

| Result | Next |
| --- | --- |
| Applied | [RB-10/MIT-05](#mit-05) |
| Unexpected error on apply | [RB-10/MIT-06](#mit-06) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Exact commands run, UTC time, operator.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-05

**Monitor for regressions, new errors and overload**

- **Objective:** Watch for secondary effects for an agreed interval.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/apache/status-distribution.sh /var/log/apache2/access.log
"$RB"/linux/memory-snapshot.sh
```

### Decision

| Result | Next |
| --- | --- |
| Healthy | [RB-11/VAL-01](11-validation-review.md#val-01) |
| Regression or rollback condition met | [RB-10/MIT-06](#mit-06) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Metrics before and after at agreed intervals.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-06

**Restore the previous state if rollback conditions are met**

- **Objective:** Return to the last known good state when conditions are met.
- **Mode:** Changes production
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Restore the snapshot from RB-10/MIT-03, then:
sudo apache2ctl configtest && sudo systemctl reload apache2
```

### Decision

| Result | Next |
| --- | --- |
| Rolled back and stable | [RB-00/INC-04](../00-incident-intake.md#inc-04); choose a different route |
| No rollback needed | [RB-11/VAL-01](11-validation-review.md#val-01) |

**If the result is unknown:** Record the result as "not determined" and continue with the next branch; do not rule the hypothesis out. If evidence is missing, use [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03).

**Evidence to record:** Rollback trigger, commands, result.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)
