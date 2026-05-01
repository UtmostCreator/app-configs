# Agent Reference

Use this file as the durable reference for what the repository agents do, when to use them, and what they must not do.

## Documentation Rule

- Every live agent must document its purpose, trigger, read-first context, scope, expected output, and avoid list.
- Every new or changed live agent must update this file in the same slice as the agent definition.
- Keep agent-specific files thin. Put shared policy in `docs/ai/` and capability docs.
- Repo-local read-only commands are approval-free by default when they do not change files, install software, use privileged access, or mutate remote systems.
- Read-only status does not override approval for secrets, credentials, private endpoints, billing, auth, admin surfaces, or external systems with side effects.
- If an agent hits a command failure, record it using `docs/ai/failure-handling.md`.
- For long-running commands, agents must use timeout/health controls when available and must not let commands run indefinitely without progress evidence.
- Agents should prefer watchdog-enabled orchestration (for example `tools/ai/full-install-validation.php`) over direct long-running command execution.

## Live Repo Agents

| Agent | Path | Use When | Read First | Avoid | Expected Output |
| --- | --- | --- | --- | --- | --- |
| `workflow-auditor` | `.github/agents/workflow-auditor.agent.md` | reviewing AI workflow files, instruction drift, repo context drift, or unsupported workflow claims | `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/AI-GUARDRAILS.md` | inventing new policy, expanding scope into implementation, duplicating canonical rules in adapter files | verdict, drift findings, severity, concrete file-level fixes |
| `config-maintainer` | `.github/agents/config-maintainer.agent.md` | changing editor, shell, runtime, or tool config while preserving current behavior | `docs/ai/project-context.md`, `docs/ai/capabilities/config-change-safety/CAPABILITY.md`, `docs/ai/failure-handling.md` | unrelated cleanup, unverified safety claims, machine-wide changes without approval, broad retries after a failed mutating command | affected surface, compatibility notes, verification notes, rollback note when relevant |
| `Repository Architect` | `.github/agents/architect.agent.md` | planning medium or large repository changes in Copilot runtime | `docs/ai/project-context.md`, `docs/ai/workflow.md` | implementing before boundaries are clear, broad speculative redesign | scoped plan with risk posture and verification scope |
| `Repository Implementer` | `.github/agents/implementer.agent.md` | implementing one approved bounded slice in Copilot runtime | `docs/ai/capabilities/verify-change/CAPABILITY.md`, `docs/ai/failure-handling.md` | broad refactors, hidden side effects, unverified edits | coherent diff plus focused verification evidence |
| `Repository Refactorer` | `.github/agents/refactorer.agent.md` | structure-only cleanup where behavior should remain unchanged | `docs/ai/capabilities/review-diff/CAPABILITY.md` | behavior changes without approval | refactor plan and unchanged-behavior evidence |
| `Release Auditor` | `.github/agents/release-auditor.agent.md` | medium/high-risk release readiness, rollback, and observability review | `docs/ai/workflow.md`, `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md` | low-risk trivia use, implementation work | release safety assessment with rollback posture |
| `Repository Researcher` | `.github/agents/researcher.agent.md` | read-only ownership discovery and risk mapping in Copilot runtime | `docs/ai/project-context.md`, `docs/ai/agents.md` | speculative edits and policy invention | evidence-backed map of paths, risks, open questions |
| `Repository Reviewer` | `.github/agents/reviewer.agent.md` | diff-first review for correctness, regressions, and policy fit | `docs/ai/capabilities/review-diff/CAPABILITY.md`, `docs/ai/failure-handling.md` | reimplementation, style-only nit focus | review verdict, risk findings, missing checks |
| `architect` | `.opencode/agents/architect.md` | planning medium or high-risk repository changes | `docs/ai/project-context.md`, `docs/ai/capabilities/project-context/CAPABILITY.md` | direct implementation before plan boundaries are clear | bounded plan with phases, risk posture, and verification scope |
| `implementer` | `.opencode/agents/implementer.md` | implementing one bounded slice after plan approval | `docs/ai/capabilities/verify-change/CAPABILITY.md`, `docs/ai/failure-handling.md` | broad refactors, undocumented side effects, unverified edits | small coherent diff plus verification evidence |
| `researcher` | `.opencode/agents/researcher.md` | read-only grounding and ownership discovery | `docs/ai/project-context.md`, `docs/ai/agents.md` | speculative edits, policy invention | evidence-backed map of paths, risks, and open questions |
| `reviewer` | `.opencode/agents/reviewer.md` | post-change review and regression checks | `docs/ai/capabilities/review-diff/CAPABILITY.md`, `docs/ai/failure-handling.md` | re-implementing solved code, style-only nit focus | review verdict, risk findings, and missing checks |
| `release-auditor` | `.opencode/agents/release-auditor.md` | medium/high-risk rollout and rollback review | `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md`, `docs/ai/workflow.md` | low-risk use for trivial edits | release safety assessment and rollback posture |
| `refactorer` | `.opencode/agents/refactorer.md` | structure-only cleanup when behavior is already correct | `docs/ai/capabilities/review-diff/CAPABILITY.md` | behavioral changes without explicit approval | structural improvement plan and unchanged-behavior evidence |

## Reusable Package Agent Templates

These are reference assets in `packages/ai-universal-rules/`. They are not live root-repo agents unless a runtime adapter installs them.

| Runtime | Agent | Path | Purpose |
| --- | --- | --- | --- |
| `opencode` | `architect` | `packages/ai-universal-rules/templates/opencode/agents/architect.md` | plan medium or large changes, affected areas, and rollout posture |
| `opencode` | `implementer` | `packages/ai-universal-rules/templates/opencode/agents/implementer.md` | implement a bounded slice with focused verification |
| `opencode` | `refactorer` | `packages/ai-universal-rules/templates/opencode/agents/refactorer.md` | improve structure when behavior is already correct |
| `opencode` | `release-auditor` | `packages/ai-universal-rules/templates/opencode/agents/release-auditor.md` | review rollout, rollback, observability, and migration safety |
| `opencode` | `researcher` | `packages/ai-universal-rules/templates/opencode/agents/researcher.md` | provide read-only grounding before planning or implementation |
| `opencode` | `reviewer` | `packages/ai-universal-rules/templates/opencode/agents/reviewer.md` | review correctness, regressions, policy fit, and missing verification |
| `opencode optional` | `bugfix` | `packages/ai-universal-rules/templates/optional/opencode/agents/bugfix.md` | reproduce and fix a bounded bug with minimal scope |
| `opencode optional` | `build-config` | `packages/ai-universal-rules/templates/optional/opencode/agents/build-config.md` | update build, packaging, or verification configuration |
| `opencode optional` | `docs` | `packages/ai-universal-rules/templates/optional/opencode/agents/docs.md` | align documentation after behavior or setup changes |
| `opencode optional` | `infra-auditor` | `packages/ai-universal-rules/templates/optional/opencode/agents/infra-auditor.md` | audit dependency, release, build, or compatibility risk |
| `opencode optional` | `ui-builder` | `packages/ai-universal-rules/templates/optional/opencode/agents/ui-builder.md` | implement UI work while preserving interaction patterns and accessibility |
| `opencode optional` | `upgrade` | `packages/ai-universal-rules/templates/optional/opencode/agents/upgrade.md` | plan or apply dependency and platform upgrades carefully |
| `github-copilot` | `Repository Architect` | `packages/ai-universal-rules/templates/github-copilot/agents/architect.agent.md` | plan medium or large changes and risk posture |
| `github-copilot` | `Repository Implementer` | `packages/ai-universal-rules/templates/github-copilot/agents/implementer.agent.md` | implement a bounded slice with focused verification |
| `github-copilot` | `Repository Refactorer` | `packages/ai-universal-rules/templates/github-copilot/agents/refactorer.agent.md` | refactor structure without changing correct behavior |
| `github-copilot` | `Release Auditor` | `packages/ai-universal-rules/templates/github-copilot/agents/release-auditor.agent.md` | assess rollout, rollback, observability, and migration safety |
| `github-copilot` | `Repository Researcher` | `packages/ai-universal-rules/templates/github-copilot/agents/researcher.agent.md` | gather read-only repo grounding before action |
| `github-copilot` | `Repository Reviewer` | `packages/ai-universal-rules/templates/github-copilot/agents/reviewer.agent.md` | review a change set from the diff first |

## Selection Rules

- Use `workflow-auditor` when the main risk is drift, unsupported claims, or duplicated workflow logic.
- Use `config-maintainer` when the main risk is silent behavior change in editor, shell, runtime, or shared config.
- Use read-only investigation before implementation when ownership, blast radius, or root cause is still unclear.
- If the runtime surface cannot run the desired agent directly, follow the equivalent capability flow from `docs/ai/capabilities/` and record the fallback in the task summary.
