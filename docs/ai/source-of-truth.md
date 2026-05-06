# AI Source of Truth Map

| Area                       | Source of truth                   | Role                                          |
| -------------------------- | --------------------------------- | --------------------------------------------- |
| Repo AI workflow           | `docs/ai/workflow.md`             | Canonical repo workflow guidance              |
| Project context            | `docs/ai/project-context.md`      | Canonical project context                     |
| Guardrails                 | `docs/ai/AI-GUARDRAILS.md`        | Canonical guardrail guidance                  |
| Adapter contract           | `docs/ai/adapter-contract.md`     | Canonical adapter thinness and drift rules    |
| AI file standards          | `docs/ai/ai-file-standards.md`    | Canonical primitive roles and line budgets    |
| Session re-entry           | `docs/ai/session-reentry.md`      | Canonical resume and checkpoint workflow      |
| Risk taxonomy              | `docs/ai/risk-taxonomy.md`        | Canonical risk classification model           |
| Approval boundaries        | `docs/ai/approval-boundaries.md`  | Canonical approval gates                      |
| Verification matrix        | `docs/ai/verification-matrix.md`  | Path-based verification guidance              |
| Tool policy                | `docs/ai/tool-policy.md`          | Canonical command safety and order            |
| Context packaging safety   | `docs/ai/context-packaging.md`    | Secret-scan and manifest safety contract      |
| Generated artifacts policy | `docs/ai/generated-artifacts.md`  | Generated output ownership and drift controls |
| Handoff contract           | `docs/ai/handoff-contract.md`     | Multi-agent/session handoff requirements      |
| GitHub Copilot adapter     | `.github/copilot-instructions.md` | GitHub-specific adapter                       |
| Generic agent adapter      | `AGENTS.md`                       | Portable agent adapter                        |
| Claude adapter             | `CLAUDE.md`                       | Claude-specific adapter                       |
| AI-readable index          | `llms.txt`                        | Root AI navigation and index file             |
| Reusable package           | `packages/ai-universal-rules/`    | Canonical reusable AI workflow package source |
| Runtime scripts            | `scripts/`                        | Executable operations                         |
| Copilot runtime logs       | `.ai-logs/`                       | Default local log and snapshot path           |
| Governance policies        | `policies/`                       | Policy instances                              |
| Schemas                    | `.schemas/`                       | Schema contracts                              |
| Tooling                    | `tools/ai/`                       | Generators, validators, exporters, installers |
| Reference material         | `reference/`                      | Non-runtime learning/reference content        |
| Config profiles            | `configs/`                        | Optional developer environment profiles       |
| Hook implementations       | `scripts/hooks/`                  | Canonical hook behavior                       |
| Husky adapter              | `.husky/`                         | Optional Node/Husky-compatible hook adapter   |
| Lefthook adapter           | `.lefthook.yml`                   | Optional polyglot hook runner adapter         |
| Generated docs             | `docs/ai/generated/`              | Generated repository maps                     |

## Adapter Rule

Long-form workflow and policy guidance should live under `docs/ai/`.

Adapter surfaces (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`) should stay thin and point to canonical docs.
