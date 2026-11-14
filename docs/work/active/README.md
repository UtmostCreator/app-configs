<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0037
  kind: template
  status: template
  summary: Active work
  review:
    approval_ref: unknown
    summary_by: agent
---
# Active work

One directory per work item. Create only the files the work needs; a temporary
or session folder is not a record.

Each item's folder, `<work-id>` in these paths, is its id followed by a short
slug, and holds its `ticket.md`. The id is the item's verified tracker id
exactly as its source writes it (`DEV-1234-fix-login`), or the next number in
the project's own scheme when its instructions or existing numbered folders use
one. Only when neither applies, and only for a work record that is actually
being created, take a local id: the highest `T-NNNN` among the folders under
`docs/work/active/` and anywhere under `docs/work/archive/` and the ids in
`docs/work/index.md`, plus one, as four digits (`T-0001` when there is none);
its `ticket.md` records `Source: local`. Never take an id only to name a
branch, and never guess a tracker id. The id and folder stay fixed when the
title changes: change the title and summary in `ticket.md` instead. Existing
folders, slug-only ones included, keep their names. Before the record is
integrated, check that no folder on the branch it joins already uses its id;
parallel branches can take the same number, and the record not yet integrated
moves to the next unused id.

```
active/<work-id>/
├── ticket.md      the request, as received
├── plan.md        the CURRENT plan — one file, edited in place
├── decisions/     superseded-but-approved plans, e.g. 2026-01-31-plan-v2-superseded.md
├── findings.md    what investigation established
└── evidence/      command output, logs, screenshots
```

`plan.md` is always current. A superseded plan moves to `decisions/` with its date —
never left beside the live one where it can be followed by mistake.
