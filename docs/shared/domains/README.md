<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0008
  kind: template
  status: template
  summary: Domains
  review:
    approval_ref: unknown
    summary_by: agent
---
# Domains

Feature and business knowledge, one directory per domain. This is the longest-lived
content in the repository: code gets rewritten, the domain it serves rarely does.

Start a domain by copying the template:

```sh
cp -r docs/shared/domains/domain-template docs/shared/domains/<your-domain>
```

Then link it from the table in [`../index.md`](../index.md) — a domain nothing links to
is a domain nobody finds.

| Template | Purpose |
|---|---|
| [`domain-template/`](domain-template/README.md) | the shape every domain follows |

Nothing but directories belongs here. A loose file directly under `domains/` is knowledge with no domain to belong to.
