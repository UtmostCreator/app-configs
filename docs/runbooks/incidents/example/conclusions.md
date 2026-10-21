---
id: INC-2026-10-13-conclusions
title: 2026-10-13 incident — Conclusions
type: incident-evidence
domain: incident-history
status: under-review
owner: platform
updated: 2026-10-21
tags: [incident, conclusions, review]
symptoms: [AH00161, oom-kill, 504, cache-clear, purge-storm, token-in-url]
---

# Conclusions

> [Incident archive](../README.md) · [Runbook index](../../README.md)

- **Supported by evidence:** kernel OOM kills and a long period with no web service (OBS-001, timeline); a sharp rise in backend request rate with a few endpoint groups dominating (OBS-004, OBS-005); the `node` user agent is first-party SSR (OBS-012); the invalidation credential was exposed (OBS-013); caching and purge code paths that can amplify load (OBS-014 to OBS-016).
- **Not established:** that the nightly cache clear caused the outage (HYP-001); what initiated the ~08:17 surge (HYP-003); whether the frontend cache is shared (HYP-005).
- **Corrections to earlier notes:** purges were amplifiers, not the trigger (OBS-010); `removed: []` does not prove unshared storage; a later healthy memory sample does not contradict the OOM kills.
- **Evidence limits:** the access-log extracts are summaries, not the raw log, so request durations and request-to-fatal-error mapping are unavailable; platform log queries were truncated; request counts reflect completed requests.
- **Follow-ups:** capacity model before changing worker limits ([RB-03/CAP-02](../../diagnostics/03-apache-capacity.md#cap-02)); the actions ACT-002 to ACT-007; the regression matrix in [RB-11/VAL-02](../../response/11-validation-review.md#val-02); confirm publish history for 08:10–08:20 ([RB-09/CFG-01](../../diagnostics/09-deployment-drift.md#cfg-01)).

See also: [timeline](timeline.md) · [observations](observations.md) · [hypotheses](hypotheses.md) · [actions](actions.md) · [conclusions](conclusions.md)
