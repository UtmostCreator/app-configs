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

- `architect` — Copilot: `.github/agents/architect.agent.md`; OpenCode: `.opencode/agents/architect.md`; use when scoping or designing a change before implementation; read first `docs/ai/project-context.md`, `docs/ai/workflow.md`; avoid implementing before boundaries are clear or doing broad speculative redesign; expected output is a scoped plan with risk posture and verification scope.
- `implementer` — Copilot: `.github/agents/implementer.agent.md`; OpenCode: `.opencode/agents/implementer.md`; use when implementing one approved bounded slice; read first `docs/ai/capabilities/verify-change/CAPABILITY.md`, `docs/ai/failure-handling.md`; avoid broad refactors, hidden side effects, or unverified edits; expected output is a coherent diff plus focused verification evidence.
- `refactorer` — Copilot: `.github/agents/refactorer.agent.md`; OpenCode: `.opencode/agents/refactorer.md`; use when doing structure-only cleanup with unchanged behavior; read first `docs/ai/capabilities/review-diff/CAPABILITY.md`; avoid behavior changes without approval; expected output is a refactor plan and unchanged-behavior evidence.
- `release-auditor` — Copilot: `.github/agents/release-auditor.agent.md`; OpenCode: `.opencode/agents/release-auditor.md`; use when reviewing medium/high-risk release readiness, rollback, and observability; read first `docs/ai/workflow.md`, `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md`; avoid low-risk trivia use or implementation work; expected output is a release safety assessment with rollback posture.
- `researcher` — Copilot: `.github/agents/researcher.agent.md`; OpenCode: `.opencode/agents/researcher.md`; use when doing read-only ownership discovery and risk mapping; read first `docs/ai/project-context.md`, `docs/ai/agents.md`; avoid speculative edits, policy invention, or ad-hoc implementation scripts; expected output is an evidence-backed map of paths, risks, open questions, and the next agent.
- `reviewer` — Copilot: `.github/agents/reviewer.agent.md`; OpenCode: `.opencode/agents/reviewer.md`; use when doing diff-first review for correctness, regressions, and policy fit; read first `docs/ai/capabilities/review-diff/CAPABILITY.md`, `docs/ai/failure-handling.md`; avoid reimplementation or style-only nit focus; expected output is a review verdict, risk findings, and missing checks.
- `config-maintainer` — Copilot: `.github/agents/config-maintainer.agent.md`; OpenCode: `.opencode/agents/config-maintainer.md`; use when changing editor, shell, runtime, or tool config while preserving current behavior; read first `docs/ai/project-context.md`, `docs/ai/capabilities/config-change-safety/CAPABILITY.md`, `docs/ai/failure-handling.md`; avoid unrelated cleanup, unverified safety claims, or machine-wide changes without approval; expected output is affected surface, compatibility notes, verification notes, and rollback note when relevant.
- `workflow-auditor` — Copilot: `.github/agents/workflow-auditor.agent.md`; OpenCode: `.opencode/agents/workflow-auditor.md`; use when reviewing AI workflow files, instruction drift, repo context drift, or unsupported workflow claims; read first `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/AI-GUARDRAILS.md`; avoid inventing new policy, expanding scope into implementation, or duplicating canonical adapter rules; expected output is a verdict, drift findings, severity, and concrete file-level fixes.
- `repository-researcher` — Copilot: `.github/agents/repository-researcher.agent.md`; OpenCode: `.opencode/agents/repository-researcher.md`; use when collecting read-only repository evidence with ai-search before planning or edits; read first `docs/ai/tools/ai-search.md`, `docs/ai/tools/actions/search-evidence.md`; avoid editing files, mutation scripts, or unsafe modes without approval; expected output is an evidence summary with uncertainty and the next agent.
- `repository-reviewer` — Copilot: `.github/agents/repository-reviewer.agent.md`; OpenCode: `.opencode/agents/repository-reviewer.md`; use when doing diff-first review starting from changed/staged evidence; read first `docs/ai/tools/ai-search.md`, `docs/ai/tools/tool-map.md`; avoid broad full-repo scans before narrow evidence; expected output is a verdict with evidence, risk, and verification gap.

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
