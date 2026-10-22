---
id: RB-07
title: Traffic abuse, WAF and security exposure
type: runbook
domain: security
priority: P1
mode: read-only
status: active
owner: platform
updated: 2026-10-22
tags: [security, waf, bot, user-agent, secrets, credential-rotation, rate-limit, abuse, query-string-secret, fail-open, token-header, purge-endpoint]
symptoms: [suspected bot traffic, exposed secret, credential leak, request to block a user-agent, token in URL, unauthenticated purge]
steps: [SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06]
related: [RB-01, RB-08, RB-10, RB-11]
---

# RB-07 — Traffic abuse, WAF and security exposure

> [Runbook index](../README.md) · Priority P1 · Mode: read-only

Investigate suspected abuse and secret exposure. Diagnosis is read-only; any blocking, rotation or rule change goes through [RB-10/MIT-02](../response/10-mitigation-recovery.md#mit-02). Credential exposure must be escalated to the incident owner immediately; do not wait for authorisation to notify. Secrets sent in URL query strings are written to access logs, application logs and proxies: treat them as compromised.

## Variables

```bash
APACHE_LOG=/var/log/apache2/access.log
RB=docs/runbooks/shared/commands
APP_DIR=/var/www/<app>
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[SEC-01](#sec-01) · [SEC-02](#sec-02) · [SEC-03](#sec-03) · [SEC-04](#sec-04) · [SEC-05](#sec-05) · [SEC-06](#sec-06)

## SEC-01

**Investigate exposed secrets and cache-invalidation credentials**

- **Objective:** Establish what was exposed, where, and for how long, without displaying the secret.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Count, never print, occurrences. Secrets in query strings land in access logs:
sudo zgrep -hcE "[?&](token|key|secret|api_key|password)=" /var/log/apache2/access.log*
grep -rIlE "[?&](token|key|secret)=" "$APP_DIR/storage/logs" | head
git log --all --oneline -S"<token-prefix>" | head   # history search; avoid printing the value
# Also check notes, exported log copies and chat paste for the same value.
```

### Decision

| Result | Next |
| --- | --- |
| Credential exposed | Notify the incident owner now; plan rotation via [RB-10/MIT-02](../response/10-mitigation-recovery.md#mit-02); check how it is accepted in [RB-07/SEC-05](#sec-05), then [RB-07/SEC-04](#sec-04) |
| Credential only in logs sent to a restricted store | Still rotate: assume anyone with log access has it |
| No exposure found | [RB-07/SEC-02](#sec-02) |

**Evidence to record:** What type of credential, where exposed, exposure window, who was notified (no values). Note what the credential can do (for example purge a whole CDN on demand recreates the incident).

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

### Credential exposure containment

Notify the incident owner promptly, preserve a restricted evidence copy, identify credential privileges and exposure interval, and find dependent callers before rotation. Through [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01), authorise a coordinated server/caller credential change, revoke the exposed value, confirm the replacement works and the revoked/missing/empty values fail closed, and restrict/redact exported logs and notes without destroying required evidence. Never paste a secret into a ticket or shell argument to prove a match. Inspect prior use for unauthorised operations and record scope/unknowns. Rollback must not restore a compromised credential.

For client attribution, include the [proxy trust acceptance tests](../foundations/01-evidence-attribution.md#proxy-trust-acceptance); forwarding headers and user agents alone cannot authorise a block or identify a caller.

## SEC-02

**Correlate suspected bot traffic with verified IP attribution and behaviour**

- **Objective:** Decide whether traffic is abusive using behaviour, not labels.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
"$RB"/apache/top-clients.sh "$APACHE_LOG" 20
# Reverse-DNS check of a few top IPs (compare forward and reverse):
host <ip>
```

### Decision

| Result | Next |
| --- | --- |
| Behaviour consistent with abuse (probing, credential stuffing, scraping beyond norms) | [RB-07/SEC-03](#sec-03) |
| Attribution unreliable (proxy addresses) | [RB-01/EVD-04](../foundations/01-evidence-attribution.md#evd-04) |
| Traffic looks like normal first-party behaviour | [RB-08/DEP-04](08-service-dependencies.md#dep-04) |

**Evidence to record:** Clients, behaviour, verified attribution status.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## SEC-03

**Identify first-party automation and critical dependencies before blocking**

- **Objective:** Avoid blocking your own frontend or integrations.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Which paths does the suspicious user agent hit?
awk -F'"' '$6 ~ /<ua-substring>/ {split($2,a," "); print a[2]}' "$APACHE_LOG" | cut -d? -f1 | sort | uniq -c | sort -nr | head -20
```

### Decision

| Result | Next |
| --- | --- |
| Requests match known server-side rendering or integration paths | [RB-08/DEP-01](08-service-dependencies.md#dep-01); do not apply a blanket block |
| No legitimate dependency | [RB-07/SEC-04](#sec-04) |

**Evidence to record:** Paths hit by the user agent and the first-party owner of each.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## SEC-04

**Evaluate protective controls, rotation and false-positive risk**

- **Objective:** Design the narrowest effective control.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Design step; no production change here.
```

### Decision

| Result | Next |
| --- | --- |
| Scoped control identified (rate limit, path rule, IP set with verified attribution) | [RB-07/SEC-06](#sec-06) |
| Only a blanket control would work | Reject; escalate to the incident owner with the dependency evidence from [RB-08/DEP-03](08-service-dependencies.md#dep-03) |

**Evidence to record:** Proposed control, scope, expected false positives.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## SEC-05

**Verify authentication of operational endpoints fails closed**

- **Objective:** Confirm cache-clear, purge and similar endpoints reject missing or empty credentials.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Code review (read-only): look for comparisons where both sides can be undefined.
grep -rnE "token !== |getQuery\(event\)\.token|getHeader\(event" server/api | head
# A missing configuration value compared with a missing request value (undefined !== undefined is false) lets the request through.
# Test only in non-production: request each endpoint with no token and expect 401.
```

### Decision

| Result | Next |
| --- | --- |
| A missing or empty token is accepted (fail-open) | Critical: unauthenticated cache clear/purge is possible. [RB-10/MIT-02](../response/10-mitigation-recovery.md#mit-02) and a regression test in [RB-11/VAL-03](../response/11-validation-review.md#val-03) |
| Credential is accepted from the query string | Plan a header-based credential and rotation shipped together: [RB-10/MIT-02](../response/10-mitigation-recovery.md#mit-02) |
| All endpoints reject missing credentials | [RB-07/SEC-06](#sec-06) |

**Evidence to record:** Per endpoint: how the credential is read, behaviour when missing.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## SEC-06

**Require an authorised change and validate**

- **Objective:** Move the change into the gated workflow.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result | Next |
| --- | --- |
| Change proposed | [RB-10/MIT-02](../response/10-mitigation-recovery.md#mit-02), then [RB-11/VAL-03](../response/11-validation-review.md#val-03) |

**Evidence to record:** Change request reference.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
