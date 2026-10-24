---
id: RB-10
title: Safe mitigation, recovery and rollback
type: runbook
domain: mitigation
priority: P0
mode: changes-production
status: active
owner: platform
updated: undated
tags: [mitigation, recovery, rollback, change-approval, restart, capacity, waf, token-rotation, mod_remoteip, x-forwarded-for, restart-policy, alerting, token-header]
symptoms: [need to restore service, approved change, rollback required]
steps: [MIT-01, MIT-02, MIT-03, MIT-04, MIT-05, MIT-06]
related: [RB-00, RB-08, RB-11]
---

# RB-10 — Safe mitigation, recovery and rollback

> [Runbook index](../README.md) · Priority P0 · Mode: changes production (approval gated)

The only runbook that changes production state: configuration edits, cache clears, restarts, WAF changes and token rotation. Every change needs approval, a rollback, and monitoring. Steps here are marked Changes production.

## Mandatory state transitions

`MIT-01 planned → MIT-02 approved → MIT-03 rollback-ready → MIT-04 applied → MIT-05 monitored`

`MIT-06` is allowed only under the recorded rollback authorisation from MIT-02, or a new approval through MIT-02. External runbooks enter at MIT-01 or MIT-02. A link, incident severity, or lack of an approver never substitutes for approval.

Before **MIT-03, MIT-04 and MIT-06**, independently verify the production target/environment, incident and change ID, named operator, approval record/time, exact authorised scope and rollback scope. Before MIT-04 also verify the prepared backup, tested inverse operation, monitoring and rollback trigger. **Unknown approval or target: Block; no production commands.** Escalate to the incident owner. If scope or target changes, return to MIT-02. These are operator gates, not an automated access-control system.

The approval record must state which changes and rollback are authorised, what restoration means, and who verifies it. Credential rotation can be irreversible: rollback must never re-enable a compromised credential. Plan forward recovery where an inverse is unsafe.

## Variables

```bash
RB=docs/runbooks/shared/commands
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[MIT-01](#mit-01) · [MIT-02](#mit-02) · [MIT-03](#mit-03) · [MIT-04](#mit-04) · [MIT-05](#mit-05) · [MIT-06](#mit-06)

## MIT-01

**Define the immediate mitigation and alternatives**

- **Objective:** Pick the least risky action that reduces customer impact.
- **Mode:** Read-only (planning)
- **Preconditions:** Target and evidence validated; the mandatory state-transition gates above apply independently.

### Commands

```bash
(
set -euo pipefail
# Planning step. Prefer reversible, narrow, observable options:
# 1) serve stale/cached content  2) reduce concurrency safely  3) scoped rate limit  4) rollback a deploy
# Recurring candidates from the runbooks (each needs approval at RB-10/MIT-02):
# - replace an unconditional cache flush with targeted invalidation and coalesced purges (RB-06/CCH-07)
# - single-flight / lock around cold cache rebuilds (RB-06/CCH-05)
# - rotate exposed credentials and move them to a header, shipped together (RB-07/SEC-05)
# - record the forwarded client address (mod_remoteip with an explicit trusted-proxy list) (RB-01/EVD-04)
# - add an availability alert and an automatic restart policy (RB-03/CAP-06)
# - memory-model the Apache worker cap before changing it; longer term consider Event + PHP-FPM (RB-03/CAP-02)
)
```

### Decision

| Result | Next |
| --- | --- |
| Mitigation chosen | [RB-10/MIT-02](#mit-02) |
| Only a blanket control available | Re-check [RB-08/DEP-03](../diagnostics/08-service-dependencies.md#dep-03) before proceeding |

**Evidence to record:** Chosen mitigation, alternatives rejected and why.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-02

**Check approval, production permissions and collateral damage**

- **Objective:** Confirm you are authorised and the blast radius is understood.
- **Mode:** Read-only (approval gate)
- **Preconditions:** Target and evidence validated; the mandatory state-transition gates above apply independently.

### Commands

```bash
(
set -euo pipefail
# Record approver and approval time. Confirm:
# - who can authorise this change
# - dependent services (see service map)
# - maintenance window requirements
)
```

### Decision

| Result | Next |
| --- | --- |
| Approved | [RB-10/MIT-03](#mit-03) |
| Not approved or approver unreachable | Stop; escalate to the incident owner. Credential exposure notifications are never blocked by this gate |

**Evidence to record:** Approver, time, scope.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-03

**Prepare change, monitoring, rollback and dependency validation**

- **Objective:** Have rollback and monitoring ready before applying anything.
- **Mode:** Approved preparation; writes a restricted backup on the server
- **Preconditions:** Target and evidence validated; the mandatory state-transition gates above apply independently.

### Commands

```bash
(
set -euo pipefail
# After MIT-02 approval. Record exact file/symlink scope and obtain an exclusive
# configuration-edit lock/freeze shared by every operator and deployment tool.
: "${CHANGE_DIR:?Set the approved fresh absolute backup directory}"
[[ "$CHANGE_DIR" == /* && "$CHANGE_DIR" != / ]]
sudo test ! -e "$CHANGE_DIR"
sudo install -d -m 0700 "$CHANGE_DIR"
# Canonical remoteip example: review these four entries against the real a2enmod/a2enconf diff.
# Parent directories must already exist; directory creation requires a separately designed inverse.
sudo python3 "$RB/scoped-config-rollback.py" snapshot /etc/apache2 "$CHANGE_DIR/apache.json" \
  mods-enabled/remoteip.load mods-enabled/remoteip.conf \
  conf-available/remoteip.conf conf-enabled/remoteip.conf
sudo apache2ctl configtest
)
```

The helper preserves bytes, file mode, numeric owner/group, symlink targets, nanosecond modification time and all readable extended attributes, including POSIX ACLs exposed as `system.posix_acl_*`. Attribute read/write failures block success. Inode identity, ctime, access time, hardlinks, directory metadata and unsupported filesystem/security-label semantics are outside this contract. Rehearse required ACL/xattr handling on a representative filesystem with the production permissions; where those are required but unavailable, rollback is not qualified. Restricted manifests contain full original bytes and must follow evidence retention controls.

Only explicitly listed files/symlinks can be restored or removed. Never substitute a recursive `/etc/apache2` restore. Existing parent directory mtime/ctime can change when an entry is added/removed; if restoring directory metadata is required, design and qualify a separate scoped inverse. Unrelated configuration entries are neither deleted nor reverted. This is a filesystem inverse, not a deployment transaction: retain the edit lock/freeze through snapshot, apply, monitoring and rollback. The helper detects scoped drift before its first write but cannot prevent a non-cooperating writer racing after that comparison.

Restart-policy preparation (only if separately approved, with a separate fresh `CHANGE_DIR`):

```bash
(
set -euo pipefail
: "${CHANGE_DIR:?Set the approved fresh absolute backup directory}"
[[ "$CHANGE_DIR" == /* && "$CHANGE_DIR" != / ]]
sudo test ! -e "$CHANGE_DIR"
sudo install -d -m 0700 "$CHANGE_DIR"
# Do not create an untracked parent directory. If absent, return to MIT-02 to design its inverse.
sudo test -d /etc/systemd/system/apache2.service.d
sudo test ! -e /etc/systemd/system/apache2.service.d/incident-restart.conf
sudo python3 "$RB/scoped-config-rollback.py" snapshot /etc/systemd/system/apache2.service.d \
  "$CHANGE_DIR/restart.json" incident-restart.conf
systemctl show apache2 -p Restart -p RestartUSec   # record the before values
)
```

### Decision

| Result | Next |
| --- | --- |
| Change, rollback and monitoring prepared | [RB-10/MIT-04](#mit-04) |

**Evidence to record:** Change diff, rollback command, dashboards to watch.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-04

**Apply only the authorised mitigation**

- **Objective:** Apply exactly the approved change, nothing more.
- **Mode:** Changes production
- **Preconditions:** Target and evidence validated; the mandatory state-transition gates above apply independently.

### Commands

```bash
(
set -euo pipefail
# Example: record the forwarded client address (adapt to the approved change).
# Verify first that the header really carries client addresses and use your own load balancer address.
sudo a2enmod remoteip
printf 'RemoteIPHeader X-Forwarded-For\nRemoteIPTrustedProxy <load-balancer-private-address>\n' | sudo tee /etc/apache2/conf-available/remoteip.conf >/dev/null
sudo a2enconf remoteip
# While the exclusive edit freeze is held, review the actual diff against approval.
# Capture expected post-change state even if configtest/reload fails, then inspect
# the restricted manifests before authorising rollback. Never refresh it to hide drift.
sudo python3 "$RB/scoped-config-rollback.py" checkpoint "$CHANGE_DIR/apache.json"
sudo apache2ctl configtest
sudo systemctl reload apache2
)
```

Restart-policy application (only if separately approved):

```bash
(
set -euo pipefail
: "${CHANGE_DIR:?Set the approved absolute backup directory from the change record}"
[[ "$CHANGE_DIR" == /* && "$CHANGE_DIR" != / ]]
# Independent example: run only if restart-policy changes are in the approval scope.
# Require this dedicated filename to be absent; if it exists, design a reviewed edit instead.
sudo test ! -e /etc/systemd/system/apache2.service.d/incident-restart.conf
printf '[Service]\nRestart=on-failure\nRestartSec=5\n' | sudo tee /etc/systemd/system/apache2.service.d/incident-restart.conf >/dev/null
sudo python3 "$RB/scoped-config-rollback.py" checkpoint "$CHANGE_DIR/restart.json"
sudo systemctl daemon-reload
systemctl show apache2 -p Restart -p RestartUSec  # verify effective values and higher-priority overrides
)
```

### Decision

| Result | Next |
| --- | --- |
| Applied | [RB-10/MIT-05](#mit-05) |
| Unexpected error on apply | [RB-10/MIT-06](#mit-06) |

**Evidence to record:** Exact commands run, UTC time, operator.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-05

**Monitor for regressions, new errors and overload**

- **Objective:** Watch for secondary effects for an agreed interval.
- **Mode:** Read-only
- **Preconditions:** Target and evidence validated; the mandatory state-transition gates above apply independently.

### Commands

```bash
(
set -euo pipefail
# Use explicit post-change bounds; follow the complete recovery measurement matrix.
: "${START_UTC:?Set the post-change UTC start}"
: "${END_UTC:?Set the post-change UTC end}"
START_UTC="$START_UTC" END_UTC="$END_UTC" "$RB"/apache/status-distribution.sh /var/log/apache2/access.log
"$RB"/linux/memory-snapshot.sh
)
```

### Decision

| Result | Next |
| --- | --- |
| No rollback trigger met; full recovery still needs the measurement matrix | [RB-11/VAL-01](11-validation-review.md#val-01) |
| Regression or rollback condition met | [RB-10/MIT-06](#mit-06) |

**Evidence to record:** Metrics before and after at agreed intervals.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)

## MIT-06

**Restore the previous state if rollback conditions are met**

- **Objective:** Return to the last known good state when conditions are met.
- **Mode:** Changes production
- **Preconditions:** Target and evidence validated; the mandatory state-transition gates above apply independently.

### Commands

```bash
(
set -euo pipefail
# Recheck recorded approval, exact target/scope, manifest diff and exclusive edit freeze.
: "${CHANGE_DIR:?Set the approved absolute backup directory from the change record}"
[[ "$CHANGE_DIR" == /* && "$CHANGE_DIR" != / ]]
# A missing checkpoint or changed scoped state blocks before any restoration.
# If apply stopped early, review partial state under the edit freeze and create
# the first checkpoint only with recorded rollback authorisation; never overwrite it.
sudo python3 "$RB/scoped-config-rollback.py" restore "$CHANGE_DIR/apache.json"
sudo apache2ctl configtest
sudo systemctl reload apache2
sudo apache2ctl -M   # verify original module state; repeat reviewed client/peer acceptance checks
)
```

Restart-policy rollback (only if separately approved):

```bash
(
set -euo pipefail
: "${CHANGE_DIR:?Set the approved absolute backup directory from the change record}"
[[ "$CHANGE_DIR" == /* && "$CHANGE_DIR" != / ]]
# Restore only the dedicated approved drop-in; concurrent scoped drift blocks.
sudo python3 "$RB/scoped-config-rollback.py" restore "$CHANGE_DIR/restart.json"
sudo systemctl daemon-reload
systemctl show apache2 -p Restart -p RestartUSec  # must match recorded before values
)
```

### Decision

| Result | Next |
| --- | --- |
| Rolled back and stable | [RB-00/INC-04](../00-incident-intake.md#inc-04); choose a different route |
| No rollback needed | [RB-11/VAL-01](11-validation-review.md#val-01) |

**Evidence to record:** Rollback authorisation, operator/target, exact backup path, reviewed original/expected manifest diff, successful scoped bytes/metadata comparison, effective module/policy state and independent service-health check. A successful reload alone is not restoration evidence. Record isolated staging rehearsal evidence for the actual filesystem, effective service configuration and reviewed health checks; local fixture tests do not establish operational qualification. Configuration restoration is not atomic; on a copy/configtest/reload failure, stop and escalate without claiming rollback succeeded.

**Return:** [RB-11/VAL-01](11-validation-review.md#val-01)
