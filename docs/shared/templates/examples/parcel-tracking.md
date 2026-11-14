<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0030
  kind: template
  status: template
  summary: Parcel tracking example
  review:
    approval_ref: unknown
    summary_by: agent
---
# Parcel tracking example

## README navigation

An example domain README links to `how-it-works.md`, `usage.md`, `operations.md`,
`verification.md`, and `reference/README.md`. It states the fictional domain owner,
status, and verification date.

## Explanation and usage

`how-it-works.md` explains that a parcel moves from accepted to delivered. `usage.md`
shows how an operator looks up a tracking number without mixing that procedure into the
explanation.

## Operations and verification

`operations.md` describes a delayed-event runbook with rollback. `verification.md`
records the command, expected result, and date that the state transition was checked.

## Reference boundary

Structured payload samples belong under `reference/`; prose remains at the domain root.
