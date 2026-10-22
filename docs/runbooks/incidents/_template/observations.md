---
id: INC-TEMPLATE-OBSERVATIONS
title: Incident observations (template)
type: incident-evidence
domain: incident-history
status: template
owner: platform
updated: 2026-10-22
tags: [incident, template, observations]
symptoms: []
---

# Observations

> [Incident archive](../README.md) · [Runbook index](../../README.md)

Directly measured facts only. One record per observation using the [evidence schema](../../shared/evidence-schema.md).

| ID | Event UTC / interval | Collected UTC | Context / coverage | Summary and source | Step | Confidence |
| --- | --- | --- | --- | --- | --- | --- |
| OBS-001 | `<event interval>` | `<collection time>` | historical-event / unknown | `<measurement and restricted source location>` | `RB-xx/YYY-nn` | medium |

Use `current-state` for present process, configuration or policy snapshots and `reproduction` for isolated test results. Neither establishes past production state without independent historical evidence. Record host/boot/container identity, revision, filters, exit status and omissions in the full evidence record.

See also: [timeline](timeline.md) · [observations](observations.md) · [hypotheses](hypotheses.md) · [actions](actions.md) · [conclusions](conclusions.md)
