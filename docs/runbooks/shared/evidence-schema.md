---
id: RB-SHARED-EVIDENCE-SCHEMA
title: Evidence record schema
type: reference
domain: evidence
status: active
owner: platform
updated: 2026-10-21
tags: [evidence, schema, observation, hypothesis, confirmed, timeline]
symptoms: [how to record findings]
---

# Evidence schema

> [Runbook index](../README.md) · Produced by every step; consumed by [RB-01/EVD-05](../foundations/01-evidence-attribution.md#evd-05) and the [incident archive](../incidents/README.md)

Separate what was **observed** from what is **believed**. Each record has a status:

| Status | Meaning |
| --- | --- |
| `observation` | Directly measured; reproducible from the recorded command |
| `hypothesis` | Plausible explanation, not yet supported by controlled evidence |
| `confirmed` | Supported by evidence that rules out the main alternatives |
| `rejected` | Contradicted by evidence |
| `unverifiable` | Evidence missing (retention, access); say why |

## Record template

```yaml
id: OBS-004                # OBS-, HYP-, ACT- prefix + number
status: observation        # observation | hypothesis | confirmed | rejected | unverifiable
step: RB-03/CAP-03         # runbook step that produced it
utc: 2026-10-13T03:05:12Z  # event time, UTC
source: kernel journal     # file / system / command
summary: Kernel OOM killed an apache2 worker
command: docs/runbooks/shared/commands/linux/oom-events.sh "60 minutes ago"
confidence: high           # low | medium | high
related: [HYP-001]
```

Never record secret values: counts, locations and key names only.

## Where records go

`docs/runbooks/incidents/<YYYY-MM-DD>/` with `timeline.md`, `observations.md`, `hypotheses.md`, `actions.md`, `conclusions.md`. Start from the [incident template](../incidents/_template/timeline.md).
