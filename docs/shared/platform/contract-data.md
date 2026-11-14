<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0025
  kind: template
  status: template
  summary: Contract Data
  review:
    approval_ref: unknown
    summary_by: agent
---
# Contract Data

Use this location for project-owned JSON or YAML contracts that agents, skills, or
automation consume. For example, a skill may declare the CLI commands it is allowed
to preview, its input/output shape, or its verification requirements.

## Ownership And Locations

| Purpose | Location | Ownership |
| --- | --- | --- |
| Human-maintained contract source | `reference/contracts/` | Project-owned |
| Generated preview, report, or expanded view | `../../generated/contracts/` | Disposable generated output |
| Glyphbrace guidance kit | `docs/ai/` | Kit-owned; do not add project contracts here |

The `docs/shared/` tree is seeded by Glyphbrace only when a file is absent. After that, the
repository owns it. `docs/generated/` is intentionally ignored: regenerate output
there instead of editing it by hand.

## Suggested Layout

```
docs/
  shared/platform/reference/contracts/
    skill-capabilities.contract.json
    cli-command-policy.contract.json
  generated/contracts/
    skill-command-preview.json
    agent-command-preview.json
```

Keep the source contract small, reviewable, and versioned with the project. A preview
may combine that contract with installed provider capabilities, current CLI help, or
repository facts, but it must identify its source inputs and be safe to regenerate.

When documentation mode is `none`, use an equivalent project-owned location outside
`docs/`, such as `contracts/`, and keep generated previews under a separate
ignored output directory.
