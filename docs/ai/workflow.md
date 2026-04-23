# Workflow

## Default Task Flow

1. read `docs/ai/project-context.md` when the target area or ownership is unclear
2. classify risk as `low`, `medium`, or `high`
3. choose the smallest fitting capability
4. update the bounded slice
5. review the diff against canonical docs and adapter files
6. verify with direct evidence
7. sync setup docs when behavior, paths, or commands changed

Prefer the simplest working path first. Add more staged agents, prompts, or runtime-specific workflow layers only when the smaller flow stops being clear, safe, or verifiable.

Optional local helpers:

- Copilot tooling integration order and adapter split in `docs/ai/copilot-tooling.md`
- Agentic workflow controls, security review points, and architecture routing in `docs/ai/agent-ops.md`
- `just doctor` for repo health and AI workflow drift checks
- `just ai-check` for the three bundled AI workflow validations
- shared git hook scripts under `scripts/hooks/` when local commit-time enforcement is useful

## Capability Routing

- unfamiliar area or cross-directory task -> `project-context`
- changed behavior or config claim -> `verify-change`
- review of proposed edits -> `review-diff`
- reported defect or regression -> `bug-regression`
- changed docs or setup guidance -> `docs-sync`
- risky shell, editor, runtime, or machine-facing config edit -> `config-change-safety`

## Risk Rules

- `low` - local docs or narrow config edits with obvious rollback
- `medium` - changes affecting shared workflow behavior across one tool surface
- `high` - changes affecting credentials, destructive actions, or multiple runtime surfaces at once

For `medium` and `high` risk work, define rollback posture and affected surfaces before implementation.

## Agentic Work

When the task involves agents, RAG, tool loops, or multi-stage handoffs:

- establish observability before optimization
- evaluate grounded correctness, not just successful execution
- choose `RAG`, `ADK`, or hybrid architecture based on whether the workflow must recall, act, or do both
- keep identities task-scoped and avoid overprivileged agents
- treat prompt, document, web, and memory inputs as untrusted unless proven otherwise

## Adapter Rule

When canonical docs and runtime adapters disagree, fix the drift instead of teaching two different workflows.
