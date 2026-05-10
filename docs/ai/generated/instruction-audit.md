# Instruction audit

- Status: `ok`
- Generated at: `2026-05-10T10:33:08+00:00`
- Commit: `06dde0c`
- Branch: `codex/integrate-ai-search-scripts-into-project`
- Recommended next action: `Use adapter-plan to choose safe merge or sidecar-only mode.`

```json
{
    "schema_version": 1,
    "artifact": "instruction-audit.json",
    "generated_at": "2026-05-10T10:33:08+00:00",
    "command": "php tools/ai/ai.php audit-instructions",
    "based_on_commit": "06dde0c",
    "based_on_branch": "codex/integrate-ai-search-scripts-into-project",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Use adapter-plan to choose safe merge or sidecar-only mode.",
    "data": {
        "count": 56,
        "entries": [
            {
                "path": ".github/copilot-instructions.md",
                "ownership_hint": "mixed_or_user"
            },
            {
                "path": "AGENTS.md",
                "ownership_hint": "mixed_or_user"
            },
            {
                "path": "CLAUDE.md",
                "ownership_hint": "mixed_or_user"
            },
            {
                "path": ".github/instructions/ai-file-standards.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ai-scripts.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ai-search.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ai-tooling.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ai-tools.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ai-workflow.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/approval-boundaries.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/architecture.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/base.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ci-workflows.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/composer.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/config-infra.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/execution-protocol.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/frontend.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/generated-artifacts.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/php.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/security.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/shell.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/targets.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/testing.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/tools.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/architect.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/config-maintainer.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/implementer.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/refactorer.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/release-auditor.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/repository-researcher.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/repository-reviewer.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/researcher.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/reviewer.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/workflow-auditor.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/evidence-first-execution.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/review-search-tool.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/script-inventory.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/search-evidence.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/verify-ai-wiring.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/verify.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/opencode.json",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/ai-scripts/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/ai-search/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/architecture-plan/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/bug-regression/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/dependency-upgrade/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/docs-sync/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/evidence-first-execution/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/new-feature/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/plan-slice/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/project-context/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/regression-test/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/release-safety/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/repo-investigation/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/review-diff/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/verify-change/SKILL.md",
                "ownership_hint": "runtime_adapter"
            }
        ],
        "notes": [
            "Copilot root instructions are broadly supported; sidecar support varies by surface.",
            "OpenCode project rules primarily use AGENTS.md."
        ]
    }
}
```
