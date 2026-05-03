# Adapter plan

- Status: `ok`
- Generated at: `2026-05-03T16:30:52+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Run install --dry-run then install --backup-only before apply.`

```json
{
    "schema_version": 1,
    "artifact": "adapter-plan.json",
    "generated_at": "2026-05-03T16:30:52+00:00",
    "command": "php tools/ai/ai.php adapter-plan",
    "based_on_commit": "92683f9",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install --dry-run then install --backup-only before apply.",
    "data": {
        "mode": "sidecar-only",
        "targets": [
            "copilot",
            "opencode"
        ],
        "profile": "dual",
        "packs": [
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "base",
            "setup-docs",
            "capabilities-core"
        ],
        "create": [],
        "modify": [],
        "conflicts": [
            ".github/copilot-instructions.md",
            ".github/instructions",
            ".github/agents",
            ".github/prompts",
            ".opencode/agents",
            ".opencode/commands",
            ".opencode/skills",
            "docs/ai/capabilities/bug-regression",
            "docs/ai/capabilities/release-safety",
            "AGENTS.md",
            "docs/ai/project-context.md",
            "docs/ai/AI-GUARDRAILS.md",
            "docs/ai/capabilities/project-context",
            "docs/ai/capabilities/verify-change",
            "docs/ai/capabilities/review-diff"
        ],
        "actions": [
            {
                "pack": "adapter-copilot",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/core/copilot-instructions.template.md",
                "target": ".github/copilot-instructions.md",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/github-copilot/instructions",
                "target": ".github/instructions",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/github-copilot/agents",
                "target": ".github/agents",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/github-copilot/prompts",
                "target": ".github/prompts",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-opencode",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/opencode/agents",
                "target": ".opencode/agents",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-opencode",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/opencode/commands",
                "target": ".opencode/commands",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-opencode",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/opencode/skills",
                "target": ".opencode/skills",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "capabilities-extended-lite",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/bug-regression",
                "target": "docs/ai/capabilities/bug-regression",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "capabilities-extended-lite",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/release-safety",
                "target": "docs/ai/capabilities/release-safety",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/core/AGENTS.template.md",
                "target": "AGENTS.md",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/core/project-context.template.md",
                "target": "docs/ai/project-context.md",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/shared/guardrails/AI-GUARDRAILS.md",
                "target": "docs/ai/AI-GUARDRAILS.md",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/project-context",
                "target": "docs/ai/capabilities/project-context",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/verify-change",
                "target": "docs/ai/capabilities/verify-change",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/review-diff",
                "target": "docs/ai/capabilities/review-diff",
                "action": "SKIP_EXISTING_UNMANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            }
        ],
        "backup_required": true,
        "atomic_transaction_steps": [
            "preflight",
            "package-verify",
            "backup",
            "stage",
            "apply",
            "validate"
        ]
    }
}
```
