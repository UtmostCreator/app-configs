<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0017
  kind: template
  status: template
  summary: Documentation maintenance
  review:
    approval_ref: unknown
    summary_by: agent
---
# Documentation maintenance

Glyphbrace never moves, deletes or adopts existing project documentation. Restructure it by hand, in reviewed steps:

1. Inventory the existing documentation and decide, for each file, whether it is durable knowledge (`shared/`), time-boxed work (`work/`), machine output (`generated/`) or not documentation at all.
2. Assign non-documentation artifacts (dumps, caches, binaries, secret findings, OS debris) to an explicit location outside `docs/`.
3. Move content with `git mv` so history follows it, and update inbound links in the same change.
4. Keep a short moved stub only where readers or external links need the old path.
5. Check that every document is reachable from [`../index.md`](../index.md) and that no link is broken before merging.
