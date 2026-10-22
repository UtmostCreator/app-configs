---
id: RB-SHARED-EVIDENCE-SCHEMA
title: Evidence record schema
type: reference
domain: evidence
status: active
owner: platform
updated: 2026-10-22
tags: [evidence, schema, observation, hypothesis, confirmed, timeline]
symptoms: [how to record findings]
---

# Evidence schema

> [Runbook index](../README.md) · Produced by every step; consumed by [RB-01/EVD-05](../foundations/01-evidence-attribution.md#evd-05) and the [incident archive](../incidents/README.md)

Keep the record type separate from the assessment. Only `id`, `kind`, `summary` and `source` are required for a quick observation; add the other fields when they support the claim.

| Field | Values / purpose |
| --- | --- |
| `kind` | `observation`, `hypothesis`, `action`, `decision` |
| `assessment` | `supported`, `provisional`, `rejected`, `unresolved`; absence of evidence is unresolved |
| `context` | `historical-event`, `current-state`, `reproduction` |
| `measurement.coverage` | `complete`, `partial`, `unknown`; command success alone does not establish completeness |

## Record template

Illustrative values, not incident findings:

```yaml
id: OBS-004
kind: observation
assessment: supported
summary: Apache access records selected in the verified window
source: apache-access-log
step: RB-02/TRF-01
context: historical-event
window:
  start: 2026-10-13T08:15:00Z
  end: 2026-10-13T08:20:00Z
measurement:
  name: logged_requests_by_receipt_time
  value: 10800
  unit: requests
  coverage: complete
confidence: high
limitations:
  - Excludes work still in flight and requests that never produced an access record
provenance:                 # optional; omit unavailable fields
  collected_utc: 2026-10-13T08:25:00Z
  command: START_UTC=2026-10-13T08:15:00Z END_UTC=2026-10-13T08:20:00Z request-rate.sh access.log
  source_version: deployed revision and parser version
  identity: sanitised host/boot/container identity
  evidence_file: restricted artifact location
  sha256: checksum of the preserved artifact
related: [HYP-001]
```

## Existing records

Preserve historical incident files. Their legacy `status` can be interpreted as follows; new records use `kind` and `assessment` separately.

| Legacy status | Interpretation |
| --- | --- |
| `observation` | kind observation; assessment supported only to the extent directly measured |
| `hypothesis` | kind hypothesis; assessment provisional |
| `confirmed` | assessment supported; determine kind from the record, do not invent it |
| `rejected` | assessment rejected |
| `unverifiable` | assessment unresolved; record the missing evidence |

Legacy `evidence_kind` maps to `context`; legacy collection/identity fields map to `provenance`. Do not infer coverage or upgrade confidence during migration.

For aggregates, also record the UTC interval, observation time, source timezone, selected files, filters, exclusions, denominator, parsed/rejected counts, exit status and coverage limitations. Relative commands such as `"60 minutes ago"` need the collection time to be reproducible. Keep raw evidence in access-controlled storage; link its location rather than copying it into incident notes.

For hypotheses, state the prediction, competing explanations, the next discriminating observation, and the result that would reject the hypothesis. Missing evidence leaves the outcome unresolved. See [systematic debugging](debugging-method.md).

Never record secret values: counts, locations and key names only.

## Where records go

`docs/runbooks/incidents/<YYYY-MM-DD>/` with `timeline.md`, `observations.md`, `hypotheses.md`, `actions.md`, `conclusions.md`. Start from the [incident template](../incidents/_template/timeline.md).
