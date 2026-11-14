<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0024
  kind: template
  status: template
  summary: Platform
  review:
    approval_ref: unknown
    summary_by: agent
---
# Platform

Cross-cutting mechanism that is not a business domain: graphql, caching, apis, auth,
messaging. One directory per mechanism, same shape as a domain.

If something here has business rules in it, it is a domain — move it to `../domains/`.

## Contract Data

For JSON or YAML contracts that describe a cross-cutting integration, see
[`contract-data.md`](contract-data.md). Keep the human-maintained source contract under
`reference/contracts/`; put regenerated previews under `../../generated/contracts/`.
