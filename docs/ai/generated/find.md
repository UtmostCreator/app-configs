# Find

- Status: `ok`
- Generated at: `2026-04-29T00:34:19+00:00`
- Commit: `92d5dbc`
- Branch: `main`
- Recommended next action: `Open highest scoring match first, then refine query if needed.`

```json
{
    "schema_version": 1,
    "artifact": "find.json",
    "generated_at": "2026-04-29T00:34:19+00:00",
    "command": "php tools/ai/ai.php find workflow",
    "based_on_commit": "92d5dbc",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Open highest scoring match first, then refine query if needed.",
    "data": {
        "query": "workflow",
        "path_matches_count": 13,
        "path_matches": [
            {
                "path": ".github/agents/workflow-auditor.agent.md",
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
                "line": 8,
                "preview": "2. `docs/ai/workflow.md`"
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 11,
                "preview": "5. `docs/ai/agent-ops-checklist.md` when verifying workflow integration or drift"
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 24,
                "preview": "- Type: `configuration repo + AI workflow kit`"
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 25,
                "preview": "- Summary: `Opinionated local development configuration plus a live benchmark for durable cross-tool AI workflow setup.`"
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 42,
                "preview": "8. `scripts/copilot/gh-pr-context.sh`, GitHub MCP, or `gh` + `jq` for PR/issue/workflow context."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 48,
                "preview": "14. `scripts/copilot/repomix-scc-router.sh` only when an older local ranked-bundle workflow still specifically depends on it."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 59,
                "preview": "- For behavior-changing agent workflows, include regression evidence (golden-task checks, replay notes, and human-review status when required)."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 60,
                "preview": "- For preview-environment workflows, include environment identifier, TTL posture, and cleanup status in task evidence."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 77,
                "preview": "- Keep canonical workflow guidance in `docs/ai/` and keep adapter files thin."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 78,
                "preview": "- Fix adapter drift instead of teaching conflicting workflows."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 83,
                "preview": "- Prefer grounded workflows: use `RAG` for source-of-truth retrieval, agent/tool orchestration for action, and hybrid designs only when both are required."
            },
            {
                "path": ".github/copilot-instructions.md",
                "line": 85,
                "preview": "- Require traceable tool use and explicit handoffs for multi-agent workflows."
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
                "line": 79,
                "preview": "- name: Lint GitHub Actions workflows"
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
                "line": 6,
                "preview": "- Type: `configuration repo + AI workflow kit`"
            },
            {
                "path": "AGENTS.md",
                "line": 7,
                "preview": "- Summary: `Opinionated editor, shell, terminal, PHP, and keyboard configuration plus a reusable cross-tool AI workflow package.`"
            },
            {
                "path": "AGENTS.md",
                "line": 22,
                "preview": "- Before changing code, config, docs, or workflow logic, search for similar existing patterns in the touched area and nearby owners; report the closest meaningful overlap as a percentage."
            },
            {
                "path": "AGENTS.md",
                "line": 25,
                "preview": "- Keep canonical workflow logic in `docs/ai/capabilities/`, not in one giant instruction file."
            },
            {
                "path": "AGENTS.md",
                "line": 26,
                "preview": "- Treat this repository as both a live config repo and a worked example of repo-scoped AI workflow design."
            },
            {
                "path": "AGENTS.md",
                "line": 61,
                "preview": "- config changes that break local developer workflows silently"
            },
            {
                "path": "AGENTS.md",
                "line": 67,
                "preview": "- Capability composition notes: `start with project-context for unfamiliar areas; use config-change-safety before risky editor or shell edits; use docs-sync whenever setup or workflow behavior changes`"
            },
            {
                "path": "AGENTS.md",
                "line": 84,
                "preview": "- changes do not add needless workflow complexity"
            },
            {
                "path": "AGENTS.md",
                "line": 96,
                "preview": "- do not bury key workflow logic only inside `.github/` or only inside a single vendor file"
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
                "line": 164,
                "preview": "- Run `php tools/ai/validate-ai-config.php` after changing root workflow files"
            },
            {
                "path": "README.md",
                "line": 167,
                "preview": "- Run `just ai-check` if you want one local command that wraps the three AI workflow checks above"
            },
            {
                "path": "README.md",
                "line": 173,
                "preview": "- Minimum folders and files to copy into another repo: `.github/copilot-instructions.md`, `.github/hooks/tool-policy.json`, `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/agents.md`, `docs/ai/failure-handling.md`, `docs/ai/copilot-cli-repo-integration.md`, `docs/ai/capabilities/project-context/`, `docs/ai/capabilities/verify-change/`, `docs/ai/capabilities/review-diff/`, `scripts/copilot/`"
            },
            {
                "path": "README.md",
                "line": 175,
                "preview": "- Recommended read order in this repo: `README.md` -> `.github/copilot-instructions.md` -> `docs/ai/project-context.md` -> `docs/ai/workflow.md` -> `docs/ai/agents.md` -> `docs/ai/failure-handling.md` -> relevant `docs/ai/capabilities/*`"
            },
            {
                "path": "README.md",
                "line": 183,
                "preview": "- Keep skills and prompt packs minimal until real workflow repetition exists; avoid large catalogs without clear ownership"
            },
            {
                "path": "README.md",
                "line": 184,
                "preview": "- Prioritize documented and verified workflows over quantity of agents, skills, or plugins"
            },
            {
                "path": "README.md",
                "line": 203,
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
                "path": "docs/ai/AI-GUARDRAILS.md",
                "line": 6,
                "preview": "- Keep canonical workflow knowledge in `docs/ai/` and thin adapter knowledge in runtime-specific files."
            },
            {
                "path": "docs/ai/AI-GUARDRAILS.md",
                "line": 27,
                "preview": "- Escalate workflows that can execute generated code, mutate external systems, or retain persistent memory across tasks."
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
                "line": 18,
                "preview": "| `workflow-auditor` | `.github/agents/workflow-auditor.agent.md` | reviewing AI workflow files, instruction drift, repo context drift, or unsupported workflow claims | `docs/ai/project-context.md`, `docs/ai/workflow.md`, `docs/ai/AI-GUARDRAILS.md` | inventing new policy, expanding scope into implementation, duplicating canonical rules in adapter files | verdict, drift findings, severity, concrete file-level fixes |"
            },
            {
                "path": "docs/ai/agents.md",
                "line": 24,
                "preview": "| `release-auditor` | `.opencode/agents/release-auditor.md` | medium/high-risk rollout and rollback review | `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md`, `docs/ai/workflow.md` | low-risk use for trivial edits | release safety assessment and rollback posture |"
            },
            {
                "path": "docs/ai/agents.md",
                "line": 54,
                "preview": "- Use `workflow-auditor` when the main risk is drift, unsupported claims, or duplicated workflow logic."
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
            },
            {
                "path": "docs/ai/capabilities/README.md",
                "line": 15,
                "preview": "- `bug-regression` - reproduce, fix, and prove config or workflow defects"
            },
            {
                "path": "docs/ai/capabilities/bug-regression/CAPABILITY.md",
                "line": 5,
                "preview": "Reproduce a config or workflow defect with the smallest reliable check, apply a bounded fix, and prove the issue is closed."
            },
            {
                "path": "docs/ai/capabilities/docs-sync/CAPABILITY.md",
                "line": 5,
                "preview": "Keep setup and workflow documentation aligned with the actual repository after behavior, file, or path changes."
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md",
                "line": 11,
                "preview": "- risky workflows need repeatable quality checks before merge"
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md",
                "line": 3,
                "preview": "Use golden tasks to pin expected agent behavior for high-value or risky workflows."
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md",
                "line": 88,
                "preview": "user_request: \"Start work on an AI workflow task in this repository\""
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md",
                "line": 113,
                "preview": "user_request: \"Investigate and fix a workflow bug\""
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md",
                "line": 134,
                "preview": "id: app_configs_workflow_drift_001"
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md",
                "line": 139,
                "preview": "user_request: \"Audit workflow drift\""
            },
            {
                "path": "docs/ai/capabilities/evaluation-and-regression/HUMAN_REVIEW_RULES.md",
                "line": 9,
                "preview": "- non-reproducible results in medium/high-risk workflows"
            },
            {
                "path": "docs/ai/capabilities/preview-environments/CAPABILITY.md",
                "line": 10,
                "preview": "- pull-request workflows require isolated environment checks"
            },
            {
                "path": "docs/ai/capabilities/service-boundary-patterns/CAPABILITY.md",
                "line": 5,
                "preview": "Define public, internal, tool, and data boundaries so agent-enabled workflows do not blur trust and risk surfaces."
            },
            {
                "path": "docs/ai/capabilities/service-boundary-patterns/CAPABILITY.md",
                "line": 9,
                "preview": "- workflows span multiple services or internal tool surfaces"
            },
            {
                "path": "docs/ai/capabilities/verify-change/CAPABILITY.md",
                "line": 5,
                "preview": "Choose the smallest relevant proof for a config, docs, or workflow change and report evidence cleanly."
            },
            {
                "path": "docs/ai/catalog.md",
                "line": 5,
                "preview": "This generated file is the live inventory for AI workflow assets in this repository and the reusable `packages/ai-universal-rules/` package."
            }
        ]
    }
}
```
