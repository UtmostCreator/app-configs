---
id: RB-INCIDENTS
title: Incident evidence archive
type: index
domain: incident-history
status: active
owner: platform
updated: 2026-10-21
tags: [incidents, archive, evidence, history, post-incident]
symptoms: [what happened before, similar past incident]
---

# Incident evidence archive

> [Runbook index](../README.md) · Written from [RB-11/VAL-06](../response/11-validation-review.md#val-06)

Historical evidence is archived by event and evidence type. It is **not** rewritten as definitive root-cause statements: new records separate `kind` and `assessment` under the [evidence schema](../shared/evidence-schema.md). Historical records retain their original legacy statuses; use the documented mapping without upgrading their claims.

## Index

| Date (UTC) | Summary | Status |
| --- | --- | --- |
| [example](example/conclusions.md) | Overnight Apache OOM outage and morning SSR 504s; cache clear and deploy hypotheses open | Under review |

## Add an incident

1. Copy [`_template/`](_template/timeline.md) to `<YYYY-MM-DD>/`.
2. Fill the five files; link every claim to the runbook step that produced it (for example `RB-03/CAP-03`).
3. Run `bash docs/runbooks/shared/commands/validate-runbook-links.sh`.
4. Add a row to the index above.

Never store secrets, tokens, customer data or real hostnames here.
