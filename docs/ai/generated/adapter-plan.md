# Adapter plan

- Status: `ok`
- Generated at: `2026-04-30T23:03:09+00:00`
- Commit: `dfa2cd8`
- Branch: `main`
- Recommended next action: `Run install --dry-run then install --backup-only before apply.`

```json
{
    "schema_version": 1,
    "artifact": "adapter-plan.json",
    "generated_at": "2026-04-30T23:03:09+00:00",
    "command": "php tools/ai/ai.php adapter-plan",
    "based_on_commit": "dfa2cd8",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install --dry-run then install --backup-only before apply.",
    "data": {
        "mode": "safe-merge",
        "targets": [
            "copilot",
            "opencode"
        ],
        "profile": "full-governance",
        "packs": [
            "capabilities-extended-full",
            "hooks-pack",
            "ci-pack",
            "scripts-pack",
            "policy-pack",
            "evidence-pack",
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "base",
            "setup-docs",
            "capabilities-core"
        ],
        "create": [],
        "modify": [],
        "conflicts": [],
        "actions": [
            {
                "pack": "capabilities-extended-full",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/dependency-upgrade",
                "target": "docs/ai/capabilities/dependency-upgrade",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "hooks-pack",
                "type": "file",
                "source": "scripts/hooks/pre-commit.sh",
                "target": "scripts/hooks/pre-commit.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "hooks-pack",
                "type": "file",
                "source": "scripts/hooks/commit-msg.sh",
                "target": "scripts/hooks/commit-msg.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "hooks-pack",
                "type": "file",
                "source": "docs/ai/hooks.md",
                "target": "docs/ai/hooks.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "ci-pack",
                "type": "file",
                "source": ".github/workflows/validate-ai-surface.yml",
                "target": ".github/workflows/validate-ai-surface.yml",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "ci-pack",
                "type": "file",
                "source": "docs/ai/validation.md",
                "target": "docs/ai/validation.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/common.sh",
                "target": "scripts/ai/common.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/ai-search.sh",
                "target": "scripts/ai/ai-search.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/ai-diff-context.sh",
                "target": "scripts/ai/ai-diff-context.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/ai-verify.sh",
                "target": "scripts/ai/ai-verify.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/ai-rollback.sh",
                "target": "scripts/ai/ai-rollback.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/ai-edit.sh",
                "target": "scripts/ai/ai-edit.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/pack-context.sh",
                "target": "scripts/ai/pack-context.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/pre-tool-use.sh",
                "target": "scripts/ai/pre-tool-use.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/post-tool-use.sh",
                "target": "scripts/ai/post-tool-use.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/run-repomix-context.sh",
                "target": "scripts/ai/run-repomix-context.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/repomix-context-tree.sh",
                "target": "scripts/ai/repomix-context-tree.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/repomix-scc-router.sh",
                "target": "scripts/ai/repomix-scc-router.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/git-forensics.sh",
                "target": "scripts/ai/git-forensics.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/gh-pr-context.sh",
                "target": "scripts/ai/gh-pr-context.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/preview-file.sh",
                "target": "scripts/ai/preview-file.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/query-usage.sh",
                "target": "scripts/ai/query-usage.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/fd-files.sh",
                "target": "scripts/ai/fd-files.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/rg-code.sh",
                "target": "scripts/ai/rg-code.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/copilot/watch-loop.sh",
                "target": "scripts/ai/watch-loop.sh",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/ai/repo-tool-inventory.sh",
                "target": "scripts/ai/repo-tool-inventory.sh",
                "action": "OVERWRITE_MANAGED",
                "required": false,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "scripts/ai/install-mandatory-tools.sh",
                "target": "scripts/ai/install-mandatory-tools.sh",
                "action": "OVERWRITE_MANAGED",
                "required": false,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "docs/ai/repo-required-tools.md",
                "target": "docs/ai/repo-required-tools.md",
                "action": "OVERWRITE_MANAGED",
                "required": false,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "scripts-pack",
                "type": "file",
                "source": "docs/ai/mandatory-tools-install.md",
                "target": "docs/ai/mandatory-tools-install.md",
                "action": "OVERWRITE_MANAGED",
                "required": false,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "policy-pack",
                "type": "file",
                "source": "docs/ai/command-risk-taxonomy.md",
                "target": "docs/ai/command-risk-taxonomy.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "policy-pack",
                "type": "file",
                "source": "docs/ai/failure-handling.md",
                "target": "docs/ai/failure-handling.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "policy-pack",
                "type": "file",
                "source": ".schemas/evidence-event.schema.json",
                "target": ".schemas/evidence-event.schema.json",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "evidence-pack",
                "type": "file",
                "source": "docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md",
                "target": "docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "evidence-pack",
                "type": "file",
                "source": "docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md",
                "target": "docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "skip-if-exists",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/core/copilot-instructions.template.md",
                "target": ".github/copilot-instructions.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/github-copilot/instructions",
                "target": ".github/instructions",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/github-copilot/agents",
                "target": ".github/agents",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-copilot",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/github-copilot/prompts",
                "target": ".github/prompts",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-opencode",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/opencode/agents",
                "target": ".opencode/agents",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-opencode",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/opencode/commands",
                "target": ".opencode/commands",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "adapter-opencode",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/opencode/skills",
                "target": ".opencode/skills",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "capabilities-extended-lite",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/bug-regression",
                "target": "docs/ai/capabilities/bug-regression",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "capabilities-extended-lite",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/release-safety",
                "target": "docs/ai/capabilities/release-safety",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/core/AGENTS.template.md",
                "target": "AGENTS.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/core/project-context.template.md",
                "target": "docs/ai/project-context.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "file",
                "source": "packages/ai-universal-rules/templates/shared/guardrails/AI-GUARDRAILS.md",
                "target": "docs/ai/AI-GUARDRAILS.md",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/project-context",
                "target": "docs/ai/capabilities/project-context",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/verify-change",
                "target": "docs/ai/capabilities/verify-change",
                "action": "OVERWRITE_MANAGED",
                "required": true,
                "merge_strategy": "replace",
                "reason": "target exists"
            },
            {
                "pack": "base",
                "type": "dir",
                "source": "packages/ai-universal-rules/templates/capabilities/review-diff",
                "target": "docs/ai/capabilities/review-diff",
                "action": "OVERWRITE_MANAGED",
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
