# Find

- Status: `ok`
- Generated at: `2026-05-03T16:30:48+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Open highest scoring match first, then refine query if needed.`

```json
{
    "schema_version": 1,
    "artifact": "find.json",
    "generated_at": "2026-05-03T16:30:48+00:00",
    "command": "php tools/ai/ai.php find workflow",
    "based_on_commit": "92683f9",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Open highest scoring match first, then refine query if needed.",
    "data": {
        "query": "workflow",
        "path_matches_count": 17,
        "path_matches": [
            {
                "path": ".github/agents/workflow-auditor.agent.md",
                "score": 100,
                "match": "path"
            },
            {
                "path": "docs/ai/generated/workflow.json",
                "score": 100,
                "match": "path"
            },
            {
                "path": "docs/ai/generated/workflow.md",
                "score": 100,
                "match": "path"
            },
            {
                "path": "docs/ai/workflow-graph.json",
                "score": 100,
                "match": "path"
            },
            {
                "path": "docs/ai/workflow.md",
                "score": 100,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/examples/worked-dual-tool-repo/docs/ai/workflow.md",
                "score": 100,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/templates/snippets/workflow.snippet.md",
                "score": 100,
                "match": "path"
            },
            {
                "path": ".github/instructions/ai-workflow.instructions.md",
                "score": 70,
                "match": "path"
            },
            {
                "path": ".github/workflows/export-ai-universal-rules-preview.yml",
                "score": 70,
                "match": "path"
            },
            {
                "path": ".github/workflows/test-external-install.yml",
                "score": 70,
                "match": "path"
            },
            {
                "path": ".github/workflows/validate-ai-surface.yml",
                "score": 70,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/docs/workflows/AGENT-HANDOFFS.md",
                "score": 70,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/docs/workflows/MONOREPO-STRATEGY.md",
                "score": 70,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/docs/workflows/RISK-AND-APPROVALS.md",
                "score": 70,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/docs/workflows/RUNTIME-OBSERVABILITY.md",
                "score": 70,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/docs/workflows/SYSTEM-WORKFLOW.md",
                "score": 70,
                "match": "path"
            },
            {
                "path": "packages/ai-universal-rules/docs/workflows/TASK-ENTRYPOINTS.md",
                "score": 70,
                "match": "path"
            }
        ],
        "content_matches_count": 120,
        "content_matches": [
            {
                "path": ".ai-install-manifest.json",
                "line": 66,
                "preview": "\".github/workflows/validate-ai-surface.yml\": {"
            },
            {
                "path": ".ai-install-manifest.json",
                "line": 68,
                "preview": "\"source\": \".github/workflows/validate-ai-surface.yml\","
            },
            {
                "path": ".github/agents/architect.agent.md",
                "line": 7,
                "preview": "This agent is an optional workflow adapter. If custom agents are unavailable or inconsistent on the active Copilot surface, use repo-wide and path-specific instructions instead."
            },
            {
                "path": ".github/agents/refactorer.agent.md",
                "line": 7,
                "preview": "This agent is an optional workflow adapter. If custom agents are unavailable or too inconsistent on the active surface, use repository and path-specific instructions instead."
            },
            {
                "path": ".github/agents/reviewer.agent.md",
                "line": 7,
                "preview": "This agent is an optional workflow adapter. If the target Copilot surface does not support custom agents the way your team needs, fall back to repo-wide and path-specific instructions."
            },
            {
                "path": ".github/agents/workflow-auditor.agent.md",
                "line": 2,
                "preview": "name: workflow-auditor"
            },
            {
                "path": ".github/agents/workflow-auditor.agent.md",
                "line": 3,
                "preview": "description: Use when reviewing AI workflow files, repo instructions, capability docs, or adapter drift across AGENTS, CLAUDE, docs/ai, and .github"
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 11,
                "preview": "- Summary: `AI workflow starter for app-configs`"
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 30,
                "preview": "- Prefer reusable capability folders for workflow-specific guidance when the repository provides them."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 42,
                "preview": "- Treat prototype paths as exploratory only; promoted prototype code must pass the normal workflow before merge."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 47,
                "preview": "- When a workflow asset has its own `gotchas` section, follow the narrower guidance there."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 58,
                "preview": "- Do not assume custom-agent properties, handoffs, or advanced workflows behave the same on every Copilot surface."
            },
            {
                "path": ".github/instructions/ai-workflow.instructions.md",
                "line": 3,
                "preview": "description: \"Rules for AI workflow docs and runtime adapters\""
            },
            {
                "path": ".github/instructions/ai-workflow.instructions.md",
                "line": 8,
                "preview": "- Keep canonical workflow guidance in `docs/ai/` and adapter-specific guidance in runtime files."
            },
            {
                "path": ".github/instructions/ci.instructions.md",
                "line": 2,
                "preview": "applyTo: \".github/workflows/**/*,**/*.{yml,yaml}\""
            },
            {
                "path": ".github/instructions/ci.instructions.md",
                "line": 10,
                "preview": "- Use GitHub MCP or `gh run` for workflow run context."
            },
            {
                "path": ".github/instructions/docs.instructions.md",
                "line": 3,
                "preview": "description: \"Rules for setup docs, workflow docs, and examples\""
            },
            {
                "path": ".github/prompts/bug-regression.prompt.md",
                "line": 7,
                "preview": "This prompt file is an optional workflow asset. Keep a fallback path that uses repository instructions and direct chat prompts if preview support or prompt-file enablement is unavailable."
            },
            {
                "path": ".github/prompts/bug-regression.prompt.md",
                "line": 22,
                "preview": "Defer to project context for repository facts and to `verify-change` or `review-diff` when those narrower workflows fit better."
            },
            {
                "path": ".github/prompts/docs-sync.prompt.md",
                "line": 3,
                "preview": "description: Use when changed behavior or workflow needs matching documentation updates without broad implementation planning"
            },
            {
                "path": ".github/prompts/docs-sync.prompt.md",
                "line": 11,
                "preview": "1. identify the changed behavior or workflow"
            },
            {
                "path": ".github/prompts/investigate-bug.prompt.md",
                "line": 4,
                "preview": "description: Investigate a bug with a read-first workflow, exact evidence, and the smallest safe fix path"
            },
            {
                "path": ".github/prompts/investigate-bug.prompt.md",
                "line": 10,
                "preview": "This prompt file is an optional workflow asset. It should guide the investigation flow, not replace repository context, capabilities, or path-specific instructions."
            },
            {
                "path": ".github/prompts/investigate-bug.prompt.md",
                "line": 19,
                "preview": "6. Use GitHub MCP or `gh` for issue, PR, and workflow context."
            },
            {
                "path": ".github/prompts/investigate-bug.prompt.md",
                "line": 24,
                "preview": "If prompt files are unavailable on the active Copilot surface, follow the same process manually with `.github/skills/repo-investigation/SKILL.md` plus `docs/ai/workflow.md`."
            },
            {
                "path": ".github/prompts/new-feature.prompt.md",
                "line": 7,
                "preview": "This prompt file is an optional workflow asset. It is not a guaranteed equivalent to a native command system and may require preview support or feature enablement on the active Copilot surface."
            },
            {
                "path": ".github/prompts/new-feature.prompt.md",
                "line": 23,
                "preview": "Defer to project context for repository facts and to `verify-change` or `review-diff` when those narrower workflows fit better."
            },
            {
                "path": ".github/prompts/review-code.prompt.md",
                "line": 7,
                "preview": "This prompt file is an optional workflow asset. Treat it as reusable guidance, not as a guaranteed command equivalent across Copilot runtimes, and assume preview support may vary by surface."
            },
            {
                "path": ".github/prompts/review-code.prompt.md",
                "line": 33,
                "preview": "Defer to project context for repository facts and to `review-diff` or `verify-change` when those narrower workflows fit better."
            },
            {
                "path": ".github/prompts/trace-regression.prompt.md",
                "line": 10,
                "preview": "This prompt file is an optional workflow asset. Use it for history-driven investigation, not for direct implementation."
            },
            {
                "path": ".github/skills/repo-investigation/SKILL.md",
                "line": 3,
                "preview": "description: Use when investigating a bug, regression, suspicious behavior, or change history in this repository and you need a read-first workflow with exact evidence."
            },
            {
                "path": ".github/workflows/export-ai-universal-rules-preview.yml",
                "line": 4,
                "preview": "workflow_dispatch:"
            },
            {
                "path": ".github/workflows/validate-ai-surface.yml",
                "line": 22,
                "preview": "- name: Validate root AI workflow files"
            },
            {
                "path": ".github/workflows/validate-ai-surface.yml",
                "line": 59,
                "preview": "- name: Ensure local-only secret override is not baked into workflows"
            },
            {
                "path": ".github/workflows/validate-ai-surface.yml",
                "line": 62,
                "preview": "hits=\"$(grep -R --line-number -- '--allow-secret-findings=local-only' .github/workflows || true)\""
            },
            {
                "path": ".github/workflows/validate-ai-surface.yml",
                "line": 65,
                "preview": "echo \"FAIL: local-only secret override must not be committed in workflow defaults\""
            },
            {
                "path": ".github/workflows/validate-ai-surface.yml",
                "line": 114,
                "preview": "- name: Lint GitHub Actions workflows"
            },
            {
                "path": ".opencode/commands/verify.md",
                "line": 2,
                "preview": "description: Compatibility command that runs the verification workflow; prefer the verify-change skill for reusable guidance"
            },
            {
                "path": ".opencode/skills/bug-regression/SKILL.md",
                "line": 9,
                "preview": "I drive a minimal bug-fix workflow: reproduce, localize, fix narrowly, verify, and report evidence."
            },
            {
                "path": ".opencode/skills/project-context/SKILL.md",
                "line": 9,
                "preview": "I provide durable repository context for `app-configs` and point to the support files that other workflows should read next."
            },
            {
                "path": ".opencode/skills/project-context/SKILL.md",
                "line": 32,
                "preview": "- Summary: `AI workflow starter for app-configs`"
            },
            {
                "path": ".opencode/skills/project-context/SKILL.md",
                "line": 58,
                "preview": "- Before changing code, config, docs, or workflow logic, search for similar existing patterns in the touched area and nearby owners and report the closest overlap as a percentage."
            },
            {
                "path": ".schemas/ai-universal-rules-manifest.schema.json",
                "line": 13,
                "preview": "\"workflow_layers\","
            },
            {
                "path": ".schemas/ai-universal-rules-manifest.schema.json",
                "line": 50,
                "preview": "\"workflow_layers\": {"
            },
            {
                "path": "AGENTS.md",
                "line": 7,
                "preview": "- Summary: `AI workflow starter for app-configs`"
            },
            {
                "path": "AGENTS.md",
                "line": 16,
                "preview": "Use this default workflow unless the task is clearly trivial:"
            },
            {
                "path": "AGENTS.md",
                "line": 23,
                "preview": "- Before changing code, config, docs, or workflow logic, search for similar existing patterns in the touched area and nearby owners and report the closest overlap as a percentage."
            },
            {
                "path": "AGENTS.md",
                "line": 70,
                "preview": "- Prefer capability folders for reusable workflow knowledge; keep this file focused on baseline policy."
            },
            {
                "path": "AGENTS.md",
                "line": 77,
                "preview": "- Do not turn this file into the only bug-fix, release, or migration workflow definition."
            },
            {
                "path": "AGENTS.md",
                "line": 92,
                "preview": "- Any promoted prototype must be respecified as a normal bounded slice and pass the standard workflow."
            },
            {
                "path": "AGENTS.md",
                "line": 133,
                "preview": "- Keep reusable workflow guidance in capability support files with examples and checklists."
            },
            {
                "path": "CLAUDE.md",
                "line": 3,
                "preview": "This repository is a configuration repo and a live example of cross-tool AI workflow design."
            },
            {
                "path": "CLAUDE.md",
                "line": 9,
                "preview": "- `docs/ai/workflow.md`"
            },
            {
                "path": "CLAUDE.md",
                "line": 29,
                "preview": "- If a runtime surface cannot support a workflow step directly, document the fallback instead of pretending parity."
            },
            {
                "path": "CONTRIBUTING.md",
                "line": 5,
                "preview": "This repository is both a live personal config repo and a reusable AI workflow kit, so contributions should stay small, explicit, and easy to verify."
            },
            {
                "path": "CONTRIBUTING.md",
                "line": 11,
                "preview": "- tighter validation, generation, or packaging workflows"
            },
            {
                "path": "CONTRIBUTING.md",
                "line": 23,
                "preview": "- keep canonical workflow logic in `docs/ai/capabilities/` or `packages/ai-universal-rules/templates/capabilities/`"
            },
            {
                "path": "CONTRIBUTING.md",
                "line": 84,
                "preview": "In CI these tools are installed at pinned versions (see `.github/workflows/validate-ai-surface.yml`). For macOS local use, `brew install` each tool + `brew pin` it to keep versions stable."
            },
            {
                "path": "README.md",
                "line": 3,
                "preview": "macOS-first developer configuration repository plus a reusable cross-tool AI workflow kit."
            },
            {
                "path": "README.md",
                "line": 7,
                "preview": "1. document and version daily workstation setup across shell, terminal, Neovim, PHP, keyboard ergonomics, and editor workflow"
            },
            {
                "path": "README.md",
                "line": 8,
                "preview": "2. provide a reusable cross-tool AI workflow kit for repo-scoped guidance, validation, and generated catalog surfaces"
            },
            {
                "path": "README.md",
                "line": 16,
                "preview": "- Ghostty terminal configuration for a fast, keyboard-first terminal workflow"
            },
            {
                "path": "README.md",
                "line": 22,
                "preview": "- AI workflow validation and generation scripts for reusable repo guidance"
            },
            {
                "path": "README.md",
                "line": 23,
                "preview": "- optional local workflow scaffolding via `just`, `doctor`, and shared commit-hook scripts"
            },
            {
                "path": "README.md",
                "line": 40,
                "preview": "- `justfile` - optional workflow entrypoints for local health checks and AI validation"
            },
            {
                "path": "README.md",
                "line": 45,
                "preview": "- `packages/ai-universal-rules/manifest.json` - canonical package metadata for the reusable AI workflow kit"
            },
            {
                "path": "README.md",
                "line": 54,
                "preview": "The repo also contains a reusable AI workflow layer for repo-scoped guidance across multiple tools."
            },
            {
                "path": "README.md",
                "line": 57,
                "preview": "- `docs/ai/` - live repo-specific AI workflow docs and capability catalog"
            },
            {
                "path": "README.md",
                "line": 60,
                "preview": "- `docs/ai/agent-ops-checklist.md` - phased verification checklist for AI workflow integration"
            },
            {
                "path": "README.md",
                "line": 61,
                "preview": "- `docs/ai/integration-matrix.md` - concept-to-file coverage map for the live AI workflow layer"
            },
            {
                "path": "README.md",
                "line": 66,
                "preview": "The goal is to keep canonical workflow knowledge in one place and keep runtime-specific adapter files thin."
            },
            {
                "path": "README.md",
                "line": 81,
                "preview": "|   `-- workflows/"
            },
            {
                "path": "README.md",
                "line": 133,
                "preview": "- Run `just doctor` after syncing config files if you use the local workflow scaffolding"
            },
            {
                "path": "README.md",
                "line": 135,
                "preview": "### AI workflow use"
            },
            {
                "path": "README.md",
                "line": 143,
                "preview": "- Use `docs/ai/agent-ops-checklist.md` to verify the repository after workflow changes"
            },
            {
                "path": "README.md",
                "line": 148,
                "preview": "- For tool-routed Copilot workflows, follow `docs/ai/copilot-tooling.md` (instructions -> wrappers -> hooks -> skills/prompts -> MCP)"
            },
            {
                "path": "README.md",
                "line": 149,
                "preview": "- For the default tree-context workflow and legacy ranked-folder compatibility, follow `docs/ai/context-packing.md`"
            },
            {
                "path": "README.md",
                "line": 165,
                "preview": "- Run `php tools/ai/validate-ai-config.php` after changing root workflow files"
            },
            {
                "path": "README.md",
                "line": 168,
                "preview": "- Run `just ai-check` if you want one local command that wraps the three AI workflow checks above"
            },
            {
                "path": "README.md",
                "line": 174,
                "preview": "- Minimum folders and files to copy into another repo: `.github/copilot-instructions.md`, `.github/hooks/tool-policy.json`, `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/agents.md`, `docs/ai/failure-handling.md`, `docs/ai/copilot-cli-repo-integration.md`, `docs/ai/capabilities/project-context/`, `docs/ai/capabilities/verify-change/`, `docs/ai/capabilities/review-diff/`, `scripts/ai/`"
            },
            {
                "path": "README.md",
                "line": 176,
                "preview": "- Recommended read order in this repo: `README.md` -> `.github/copilot-instructions.md` -> `docs/ai/project-context.md` -> `docs/ai/workflow.md` -> `docs/ai/agents.md` -> `docs/ai/failure-handling.md` -> relevant `docs/ai/capabilities/*`"
            },
            {
                "path": "README.md",
                "line": 184,
                "preview": "- Keep skills and prompt packs minimal until real workflow repetition exists; avoid large catalogs without clear ownership"
            },
            {
                "path": "README.md",
                "line": 185,
                "preview": "- Prioritize documented and verified workflows over quantity of agents, skills, or plugins"
            },
            {
                "path": "README.md",
                "line": 204,
                "preview": "- This repo prefers a practical production-grade workflow model over a large catalog of agents, skills, or plugins"
            },
            {
                "path": "SECURITY.md",
                "line": 9,
                "preview": "- describe the affected file or workflow surface"
            },
            {
                "path": "SECURITY.md",
                "line": 13,
                "preview": "If the issue involves credentials, local-machine secrets, private endpoints, or a workflow that could cause destructive behavior, treat it as sensitive."
            },
            {
                "path": "SECURITY.md",
                "line": 19,
                "preview": "- AI workflow instructions that could weaken approval boundaries"
            },
            {
                "path": "configs/ghostty/config-ghostyy",
                "line": 17,
                "preview": "# ---------- Shell / workflow ----------"
            },
            {
                "path": "docs/ai/adapter-contract.md",
                "line": 3,
                "preview": "Canonical docs under `docs/ai/` define workflow and policy."
            },
            {
                "path": "docs/ai/adapter-contract.md",
                "line": 16,
                "preview": "- become the sole source of critical workflow steps"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 15,
                "preview": "- `.github/instructions/ai-workflow.instructions.md`"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 29,
                "preview": "- no runtime-specific file claims to be the canonical source of workflow truth"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 37,
                "preview": "- `docs/ai/workflow.md`"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 46,
                "preview": "- the workflow mentions failure logging and retry decisions"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 50,
                "preview": "- behavior-changing agent workflows reference golden tasks, replay rules, or human-review triggers"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 51,
                "preview": "- preview-environment workflows define lifecycle, data/secret isolation, and cleanup expectations when used"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 83,
                "preview": "- docs describe hooks as enforcement and telemetry, not the canonical workflow source"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 110,
                "preview": "- the generated catalog exposes the main live workflow docs, not only capabilities and agents"
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 148,
                "preview": "Goal: produce a repeatable read-only verification run after workflow changes."
            },
            {
                "path": "docs/ai/agent-ops-checklist.md",
                "line": 172,
                "preview": "- This checklist is intentionally repo-focused. It verifies that the workflow layer exists, is discoverable, and is internally coherent."
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 3,
                "preview": "Use this document when the task involves agent loops, tool use, RAG, multi-agent handoffs, or security review of AI-assisted workflows."
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 13,
                "preview": "Do not optimize a workflow you cannot trace, and do not trust a trace alone as proof that the behavior was correct."
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 17,
                "preview": "For agentic workflows, capture enough evidence to reconstruct what happened:"
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 26,
                "preview": "If a workflow can mutate external state, treat missing traceability as a release blocker."
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 32,
                "preview": "Measure whether the workflow was actually good, not only whether it ran:"
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 79,
                "preview": "- escalate when a workflow needs long-lived credentials or broad cross-system access"
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 94,
                "preview": "- cascading failures across delegated workflows"
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 104,
                "preview": "- use an `ADK` or tool-driven agent workflow when the system must act through a repeatable procedure"
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 105,
                "preview": "- use a hybrid when the workflow must both reason over documents and take actions"
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 113,
                "preview": "For specialized domains, ground the workflow in trusted documents first, then let agents act."
            },
            {
                "path": "docs/ai/agent-ops.md",
                "line": 127,
                "preview": "Add roles only when isolation, expertise, or verification quality improves. Do not split one simple workflow into many agents without a clear safety or quality reason."
            },
            {
                "path": "docs/ai/agents.md",
                "line": 20,
                "preview": "| `workflow-auditor` | `.github/agents/workflow-auditor.agent.md` | reviewing AI workflow files, instruction drift, repo context drift, or unsupported workflow claims | `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/AI-GUARDRAILS.md` | inventing new policy, expanding scope into implementation, duplicating canonical rules in adapter files | verdict, drift findings, severity, concrete file-level fixes |"
            },
            {
                "path": "docs/ai/agents.md",
                "line": 22,
                "preview": "| `Repository Architect` | `.github/agents/architect.agent.md` | planning medium or large repository changes in Copilot runtime | `docs/ai/project-context.md`, `docs/ai/workflow.md` | implementing before boundaries are clear, broad speculative redesign | scoped plan with risk posture and verification scope |"
            },
            {
                "path": "docs/ai/agents.md",
                "line": 25,
                "preview": "| `Release Auditor` | `.github/agents/release-auditor.agent.md` | medium/high-risk release readiness, rollback, and observability review | `docs/ai/workflow.md`, `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md` | low-risk trivia use, implementation work | release safety assessment with rollback posture |"
            },
            {
                "path": "docs/ai/agents.md",
                "line": 32,
                "preview": "| `release-auditor` | `.opencode/agents/release-auditor.md` | medium/high-risk rollout and rollback review | `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md`, `docs/ai/workflow.md` | low-risk use for trivial edits | release safety assessment and rollback posture |"
            },
            {
                "path": "docs/ai/agents.md",
                "line": 62,
                "preview": "- Use `workflow-auditor` when the main risk is drift, unsupported claims, or duplicated workflow logic."
            },
            {
                "path": "docs/ai/architecture-locks.md",
                "line": 41,
                "preview": "- Canonical workflow policy and reusable procedure live in neutral docs/capabilities first."
            },
            {
                "path": "docs/ai/capabilities/README.md",
                "line": 3,
                "preview": "These folders are the canonical reusable workflow layer for the root repository."
            },
            {
                "path": "docs/ai/capabilities/README.md",
                "line": 9,
                "preview": "- `docs/ai/agent-ops-checklist.md` - phased verification checklist for workflow integration"
            },
            {
                "path": "docs/ai/capabilities/README.md",
                "line": 10,
                "preview": "- `docs/ai/integration-matrix.md` - coverage map for live AI workflow concepts"
            }
        ]
    }
}
```
