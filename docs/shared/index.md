<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0015
  kind: template
  status: template
  summary: Project knowledge index
  review:
    approval_ref: unknown
    summary_by: agent
---
# Project knowledge index

Yours. Glyphbrace creates a file here only when it is absent; it never modifies
or removes one that exists.

| Tree | Holds |
|---|---|
| [`overview/`](overview/README.md) | how this project works and how to work on it |
| [`domains/`](domains/README.md) | feature and business knowledge, one directory per domain |
| [`platform/`](platform/README.md) | cross-cutting mechanisms (APIs, caching, auth), not business domains |
| [`operations/`](operations/README.md) | runbooks: what to read when something is on fire |
| [`templates/`](templates/README.md) | seeded templates and fictional examples; copy, do not fill in place |

| Domain | Owner | Status | Verified |
|---|---|---|---|
| _add your first domain: copy [`domains/domain-template/`](domains/domain-template/README.md)_ | | | |

Rules: every directory under `shared/` contains a `README.md` or `index.md`;
no loose file directly under `domains/`; data lives in a `reference/`
subdirectory, never beside prose; a domain allows `<domain>/<file>` and
`<domain>/reference/<file>` only. Link every document you add from its
directory's index, so each one is reachable from this page.
