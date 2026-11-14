<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0029
  kind: template
  status: template
  summary: Inventory correction example
  review:
    approval_ref: unknown
    summary_by: agent
---
# Inventory correction example

## Current plan

An active item lives in `work/active/<item-id>/` with one current `plan.md` and a
lower-case `ticket.md` containing the received request.

## Decisions and findings

Superseded approved plans live under `decisions/`; `findings.md` records investigation
facts. Neither replaces durable domain guidance, which is distilled into `docs/shared/`.

## Evidence boundary

Command output and screenshots belong under `evidence/` while the item is active. On
closure, move the complete directory to `docs/work/archive/<year>/`; retain release and
investigation history rather than deleting it.
