# Workflow

## Default Task Flow

1. read `docs/ai/project-context.md` when the target area or ownership is unclear
2. classify risk as `low`, `medium`, or `high`
3. choose the smallest fitting capability
4. update the bounded slice
5. review the diff against canonical docs and adapter files
6. verify with direct evidence
7. record command failures, retries, and corrected usage when they occur
8. sync setup docs when behavior, paths, or commands changed

For medium or high risk agentic work, load `docs/ai/capabilities/authorization-and-tool-governance/CAPABILITY.md` before mutating tool use.
For medium or high risk agentic work, load `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md` so outputs include traceable evidence.
For behavior-changing agentic work, load `docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md` and run relevant golden-task checks.
For medium or high risk changes requiring realistic integration checks, load `docs/ai/capabilities/preview-environments/CAPABILITY.md`.
For cross-service or internal-tool architecture changes, load `docs/ai/capabilities/service-boundary-patterns/CAPABILITY.md`.

Prefer the simplest working path first. Add more staged agents, prompts, or runtime-specific workflow layers only when the smaller flow stops being clear, safe, or verifiable.

Optional local helpers:

- Copilot tooling integration order and adapter split in `docs/ai/copilot-tooling.md`
- Agentic workflow controls, security review points, and architecture routing in `docs/ai/agent-ops.md`
- phased integration verification in `docs/ai/agent-ops-checklist.md`
- concept coverage review in `docs/ai/integration-matrix.md`
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
For `high` risk tool actions, require explicit approval before execution and record the decision in task evidence.
Before merge of behavior-changing agent workflows, record regression evidence and apply human-review rules for medium/high-risk outcomes.
When preview environments are used, record environment identifier, TTL posture, and cleanup outcome in task evidence.

Safe repo-local read-only commands are approval-free by default. Stop and ask before a supposedly read-only step touches secrets, privileged locations, remote mutation, billing, auth, or other side-effecting surfaces.

## Command Risk Tiers

Task risk labels (low/medium/high) describe overall task scope and blast radius. Command risk tiers describe the reversibility of a single command invocation. See `docs/ai/command-risk-taxonomy.md` for the canonical classification matrix and entrypoint table.

| Tier | Label               | Default approval         | Examples                                            |
| ---- | ------------------- | ------------------------ | --------------------------------------------------- |
| 1    | read-only           | auto-approve             | `git log`, `rg`, read-only wrapper scripts          |
| 2    | modification        | confirm                  | `git commit`, `ai-edit apply`, source file writes   |
| 3    | deletion / recovery | deny / explicit approval | `rm`, `purge`, `ai-rollback apply`, destructive git |

For mixed-risk wrappers (ai-edit, ai-rollback, repomix-scc-router), tier is determined by the subcommand or flag, not the script name. See `docs/ai/command-risk-taxonomy.md` for the full invocation matrix.

## Agentic Work

When the task involves agents, RAG, tool loops, or multi-stage handoffs:

- establish observability before optimization
- evaluate grounded correctness, not just successful execution
- choose `RAG`, `ADK`, or hybrid architecture based on whether the workflow must recall, act, or do both
- keep identities task-scoped and avoid overprivileged agents
- treat prompt, document, web, and memory inputs as untrusted unless proven otherwise
- keep `docs/ai/agents.md` current when live agents or their responsibilities change
- follow `docs/ai/failure-handling.md` for command failure logging and retry policy

## Adapter Rule

When canonical docs and runtime adapters disagree, fix the drift instead of teaching two different workflows.
