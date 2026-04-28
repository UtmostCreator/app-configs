# AI Source of Truth Map

| Area | Source of truth | Role |
| --- | --- | --- |
| Repo AI workflow | `docs/ai/workflow.md` | Canonical repo workflow guidance |
| Project context | `docs/ai/project-context.md` | Canonical project context |
| Guardrails | `docs/ai/AI-GUARDRAILS.md` | Canonical guardrail guidance |
| GitHub Copilot adapter | `.github/copilot-instructions.md` | GitHub-specific adapter |
| Generic agent adapter | `AGENTS.md` | Portable agent adapter |
| Claude adapter | `CLAUDE.md` | Claude-specific adapter |
| AI-readable index | `llms.txt` | Root AI navigation and index file |
| Reusable package | `packages/ai-universal-rules/` | Canonical reusable AI workflow package source |
| Runtime scripts | `scripts/` | Executable operations |
| Copilot runtime logs | `.copilot-logs/` | Default local log and snapshot path |
| Governance policies | `policies/` | Policy instances |
| Schemas | `.schemas/` | Schema contracts |
| Tooling | `tools/ai/` | Generators, validators, exporters, installers |
| Reference material | `reference/` | Non-runtime learning/reference content |
| Config profiles | `configs/` | Optional developer environment profiles |
| Hook implementations | `scripts/hooks/` | Canonical hook behavior |
| Husky adapter | `.husky/` | Optional Node/Husky-compatible hook adapter |
| Lefthook adapter | `.lefthook.yml` | Optional polyglot hook runner adapter |
| Generated docs | `docs/ai/generated/` | Generated repository maps |

## Adapter Rule

Long-form workflow and policy guidance should live under `docs/ai/`.

Adapter surfaces (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`) should stay thin and point to canonical docs.
