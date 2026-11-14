<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0009
  kind: template
  status: template
  summary: "[DOMAIN NAME]"
  review:
    approval_ref: unknown
    summary_by: agent
---
# [DOMAIN NAME]

Copy this directory to `docs/shared/domains/<your-domain>/`, then link it from
[`../../index.md`](../../index.md).

| Field | Value |
|---|---|
| Owner | [OWNER TO FILL] |
| Status | draft \| active \| stable \| deprecated |
| Verified | YYYY-MM-DD |

One paragraph: what this domain is and where its code lives. Then link only the files
that actually exist — delete the rest of this template's files rather than shipping
empty documents.

- [How it works](how-it-works.md) — mechanism
- [Usage](usage.md) — how to use it
- [Operations](operations.md) — deploy, cache, failure modes, restore
- [Verification](verification.md) — the exact commands
- [Reference](reference/README.md) — samples, payloads, schemas; DATA ONLY
