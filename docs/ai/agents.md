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

Installed paths are created by running the installer packs (`adapter-copilot` or `adapter-opencode`). The table uses plain text for those paths to distinguish them from source-controlled files.

| Agent               | Copilot installed path                    | OpenCode installed path               | Use When                                                                                           | Read First                                                                                                             | Avoid                                                                                                   | Expected Output                                                                        |
| ------------------- | ----------------------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `architect`         | .github/agents/architect.agent.md         | .opencode/agents/architect.md         | scoping or designing a change before implementation                                                | `docs/ai/project-context.md`, `docs/ai/workflow.md`                                                                    | implementing before boundaries are clear, broad speculative redesign                                    | scoped plan with risk posture and verification scope                                   |
| `implementer`       | .github/agents/implementer.agent.md       | .opencode/agents/implementer.md       | implementing one approved bounded slice                                                            | `docs/ai/capabilities/verify-change/CAPABILITY.md`, `docs/ai/failure-handling.md`                                      | broad refactors, hidden side effects, unverified edits                                                  | coherent diff plus focused verification evidence                                       |
| `refactorer`        | .github/agents/refactorer.agent.md        | .opencode/agents/refactorer.md        | structure-only cleanup where behavior should remain unchanged                                      | `docs/ai/capabilities/review-diff/CAPABILITY.md`                                                                       | behavior changes without approval                                                                       | refactor plan and unchanged-behavior evidence                                          |
| `release-auditor`   | .github/agents/release-auditor.agent.md   | .opencode/agents/release-auditor.md   | medium/high-risk release readiness, rollback, and observability review                             | `docs/ai/workflow.md`, `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md`                           | low-risk trivia use, implementation work                                                                | release safety assessment with rollback posture                                        |
| `researcher`        | .github/agents/researcher.agent.md        | .opencode/agents/researcher.md        | read-only ownership discovery and risk mapping                                                     | `docs/ai/project-context.md`, `docs/ai/agents.md`                                                                      | speculative edits and policy invention                                                                  | evidence-backed map of paths, risks, open questions                                    |
| `reviewer`          | .github/agents/reviewer.agent.md          | .opencode/agents/reviewer.md          | diff-first review for correctness, regressions, and policy fit                                     | `docs/ai/capabilities/review-diff/CAPABILITY.md`, `docs/ai/failure-handling.md`                                        | reimplementation, style-only nit focus                                                                  | review verdict, risk findings, missing checks                                          |
| `config-maintainer` | .github/agents/config-maintainer.agent.md | .opencode/agents/config-maintainer.md | changing editor, shell, runtime, or tool config while preserving current behavior                  | `docs/ai/project-context.md`, `docs/ai/capabilities/config-change-safety/CAPABILITY.md`, `docs/ai/failure-handling.md` | unrelated cleanup, unverified safety claims, machine-wide changes without approval                      | affected surface, compatibility notes, verification notes, rollback note when relevant |
| `workflow-auditor`  | .github/agents/workflow-auditor.agent.md  | .opencode/agents/workflow-auditor.md  | reviewing AI workflow files, instruction drift, repo context drift, or unsupported workflow claims | `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/AI-GUARDRAILS.md`                                        | inventing new policy, expanding scope into implementation, duplicating canonical rules in adapter files | verdict, drift findings, severity, concrete file-level fixes                           |
| `repository-researcher` | .github/agents/repository-researcher.agent.md | .opencode/agents/repository-researcher.md | collecting read-only repository evidence with ai-search before planning or edits | `docs/ai/tools/ai-search.md`, `docs/ai/tools/actions/search-evidence.md` | editing files, unsafe modes without approval | evidence summary with uncertainty and safest next step |
| `repository-reviewer` | .github/agents/repository-reviewer.agent.md | .opencode/agents/repository-reviewer.md | diff-first review that starts from changed/staged evidence | `docs/ai/tools/ai-search.md`, `docs/ai/tools/tool-map.md` | broad full-repo scans before narrow evidence | verdict with evidence, risk, and verification gap |

## Reusable Package Agent Templates

These are reference assets in `packages/ai-universal-rules/`. They are not live root-repo agents unless a runtime adapter installs them.

| Runtime          | Agent               | Path                                                                         | Purpose                                                                                |
| ---------------- | ------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `opencode`       | `architect`         | `packages/ai-universal-rules/templates/core/agents/architect.md`             | plan medium or large changes, affected areas, and rollout posture                      |
| `opencode`       | `implementer`       | `packages/ai-universal-rules/templates/core/agents/implementer.md`           | implement a bounded slice with focused verification                                    |
| `opencode`       | `refactorer`        | `packages/ai-universal-rules/templates/core/agents/refactorer.md`            | improve structure when behavior is already correct                                     |
| `opencode`       | `release-auditor`   | `packages/ai-universal-rules/templates/core/agents/release-auditor.md`       | review rollout, rollback, observability, and migration safety                          |
| `opencode`       | `researcher`        | `packages/ai-universal-rules/templates/core/agents/researcher.md`            | provide read-only grounding before planning or implementation                          |
| `opencode`       | `reviewer`          | `packages/ai-universal-rules/templates/core/agents/reviewer.md`              | review correctness, regressions, policy fit, and missing verification                  |
| `opencode`       | `config-maintainer` | `packages/ai-universal-rules/templates/core/agents/config-maintainer.md`     | change editor, shell, runtime, or tool config safely                                   |
| `opencode`       | `workflow-auditor`  | `packages/ai-universal-rules/templates/core/agents/workflow-auditor.md`      | audit AI workflow files and instruction drift                                          |
| `github-copilot` | `architect`         | `packages/ai-universal-rules/templates/core/agents/architect.md`             | plan medium or large changes and risk posture                                          |
| `github-copilot` | `implementer`       | `packages/ai-universal-rules/templates/core/agents/implementer.md`           | implement a bounded slice with focused verification                                    |
| `github-copilot` | `refactorer`        | `packages/ai-universal-rules/templates/core/agents/refactorer.md`            | refactor structure without changing correct behavior                                   |
| `github-copilot` | `release-auditor`   | `packages/ai-universal-rules/templates/core/agents/release-auditor.md`       | assess rollout, rollback, observability, and migration safety                          |
| `github-copilot` | `researcher`        | `packages/ai-universal-rules/templates/core/agents/researcher.md`            | gather read-only repo grounding before action                                          |
| `github-copilot` | `reviewer`          | `packages/ai-universal-rules/templates/core/agents/reviewer.md`              | review a change set from the diff first                                                |
| `github-copilot` | `config-maintainer` | `packages/ai-universal-rules/templates/core/agents/config-maintainer.md`     | change editor, shell, runtime, or tool config safely                                   |
| `github-copilot` | `workflow-auditor`  | `packages/ai-universal-rules/templates/core/agents/workflow-auditor.md`      | audit AI workflow files and instruction drift                                          |
| `optional`       | `architecture-plan` | `packages/ai-universal-rules/templates/optional/agents/architecture-plan.md` | produce a bounded architecture plan when a shared workflow needs deeper design framing |
| `optional`       | `bugfix`            | `packages/ai-universal-rules/templates/optional/agents/bugfix.md`            | reproduce and fix a bounded bug with minimal scope                                     |
| `optional`       | `build-config`      | `packages/ai-universal-rules/templates/optional/agents/build-config.md`      | update build, packaging, or verification configuration                                 |
| `optional`       | `docs`              | `packages/ai-universal-rules/templates/optional/agents/docs.md`              | align documentation after behavior or setup changes                                    |
| `optional`       | `infra-auditor`     | `packages/ai-universal-rules/templates/optional/agents/infra-auditor.md`     | audit dependency, release, build, or compatibility risk                                |
| `optional`       | `ui-builder`        | `packages/ai-universal-rules/templates/optional/agents/ui-builder.md`        | implement UI work while preserving interaction patterns and accessibility              |
| `optional`       | `upgrade`           | `packages/ai-universal-rules/templates/optional/agents/upgrade.md`           | plan or apply dependency and platform upgrades carefully                               |

## Selection Rules

- Use `workflow-auditor` when the main risk is drift, unsupported claims, or duplicated workflow logic.
- Use `config-maintainer` when the main risk is silent behavior change in editor, shell, runtime, or shared config.
- Use read-only investigation before implementation when ownership, blast radius, or root cause is still unclear.
- If the runtime surface cannot run the desired agent directly, follow the equivalent capability flow from `docs/ai/capabilities/` and record the fallback in the task summary.
