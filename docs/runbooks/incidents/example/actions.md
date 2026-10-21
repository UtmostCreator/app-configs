---
id: INC-2026-10-13-actions
title: 2026-10-13 incident — Actions
type: incident-evidence
domain: incident-history
status: under-review
owner: platform
updated: 2026-10-21
tags: [incident, actions, mitigation]
symptoms: [AH00161, oom-kill, 504, cache-clear, purge-storm, token-in-url]
---

# Actions

> [Incident archive](../README.md) · [Runbook index](../../README.md)

| ID | Action | Approved by | Result |
| --- | --- | --- | --- |
| ACT-001 | Blocked the `node` user agent at the edge | incident owner | Broke the frontend; reverted. Lesson: verify dependencies first ([RB-08/DEP-03](../../diagnostics/08-service-dependencies.md#dep-03)). |
| ACT-002 | Rotate the exposed cache-invalidation credential and move it to a request header, shipped together | incident owner | Open ([RB-07/SEC-04](../../diagnostics/07-traffic-security.md#sec-04), [RB-10/MIT-02](../../response/10-mitigation-recovery.md#mit-02)). |
| ACT-003 | Replace the unconditional nightly cache flush with targeted invalidation, after auditing what depends on it | proposed | Open ([RB-06/CCH-01](../../diagnostics/06-cache-invalidation.md#cch-01)). |
| ACT-004 | Coalesce whole-site purges (shared minimum interval, trailing debounce) and purge selectively | proposed | Open ([RB-06/CCH-07](../../diagnostics/06-cache-invalidation.md#cch-07)). |
| ACT-005 | Add single-flight protection and shared cache storage for redirects and GraphQL; do not cache failures | proposed | Open ([RB-06/CCH-05](../../diagnostics/06-cache-invalidation.md#cch-05)). |
| ACT-006 | Add availability alerting and an automatic restart policy for the web server | proposed | Open ([RB-03/CAP-06](../../diagnostics/03-apache-capacity.md#cap-06)). |
| ACT-007 | Record the forwarded client address with a trusted-proxy list | proposed | Open ([RB-01/EVD-04](../../foundations/01-evidence-attribution.md#evd-04)). |
| ACT-008 | Do not raise the Apache worker cap or PHP memory limit until a memory model exists | recommendation | Open ([RB-03/CAP-02](../../diagnostics/03-apache-capacity.md#cap-02)). |

See also: [timeline](timeline.md) · [observations](observations.md) · [hypotheses](hypotheses.md) · [actions](actions.md) · [conclusions](conclusions.md)
