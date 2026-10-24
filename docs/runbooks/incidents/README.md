---
id: RB-INCIDENTS
title: Incident evidence archive
type: index
domain: incident-history
status: active
owner: platform
updated: undated
tags: [incidents, archive, evidence, history, post-incident]
symptoms: [what happened before, similar past incident]
---

# Incident evidence archive

> [Runbook index](../README.md) · Written from [RB-11/VAL-06](../response/11-validation-review.md#val-06)

Historical evidence is archived by event and evidence type. It is **not** rewritten as definitive root-cause statements: new records separate `kind` and `assessment` under the [evidence schema](../shared/evidence-schema.md). Historical records retain their original legacy statuses; use the documented mapping without upgrading their claims.

## Index

| Case | Summary | Status |
| --- | --- | --- |
| [Example](example/conclusions.md) | Fictional high-memory export route exercise covering fatal grouping, route correlation and isolated reproduction | Illustrative only |

## Add an incident

1. Copy [`_template/`](_template/timeline.md) to `<case-slug>/`.
2. Fill the five evidence files; link every claim to the runbook step that produced it (for example `RB-03/CAP-03`).
3. Fill [`command-review.md`](_template/command-review.md): response metrics and the shortest path always; the round-by-round keep/merge/shorten/drop verdicts when the template's full-review criteria apply. Promote new patterns to the [fast path](../shared/fast-path.md).
4. Run `bash docs/runbooks/shared/commands/validate-runbook-links.sh` and `bash docs/runbooks/shared/commands/check-anonymized.sh` (optionally with `ANON_DENYLIST` pointing at a private term list kept outside the repository).
5. Add a row to the index above. Search this archive by signature before the next investigation ([FP-0](../shared/fast-path.md#fp-0--prior-art-no-production-access)).

Never store secrets, tokens, customer data or real hostnames here.
