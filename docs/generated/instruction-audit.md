# Instruction audit

- Status: `ok`
- Generated at: `2026-05-03T16:30:52+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Use adapter-plan to choose safe merge or sidecar-only mode.`

```json
{
    "schema_version": 1,
    "artifact": "instruction-audit.json",
    "generated_at": "2026-05-03T16:30:52+00:00",
    "command": "php tools/ai/ai.php audit-instructions",
    "based_on_commit": "92683f9",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Use adapter-plan to choose safe merge or sidecar-only mode.",
    "data": {
        "count": 29,
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
                "path": ".github/instructions/ai-workflow.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/architecture.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/ci.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/config.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/docs.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/frontend.instructions.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".github/instructions/php.instructions.md",
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
                "path": ".opencode/agents/architect.md",
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
                "path": ".opencode/agents/researcher.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/agents/reviewer.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/bug-regression.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/plan-slice.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/review-diff.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/commands/verify.md",
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
                "path": ".opencode/skills/project-context/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/project-stack/SKILL.md",
                "ownership_hint": "runtime_adapter"
            },
            {
                "path": ".opencode/skills/release-safety/SKILL.md",
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
