# Packs

- Status: `ok`
- Generated at: `2026-04-29T18:53:37+00:00`
- Commit: `047d291`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Pack contracts validated.`

```json
{
    "schema_version": 1,
    "artifact": "packs.json",
    "generated_at": "2026-04-29T18:53:37+00:00",
    "command": "php tools/ai/ai.php packs",
    "based_on_commit": "047d291",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Pack contracts validated.",
    "data": {
        "profiles": {
            "minimal": [
                "base",
                "setup-docs",
                "capabilities-core"
            ],
            "copilot": [
                "minimal",
                "adapter-copilot"
            ],
            "opencode": [
                "minimal",
                "adapter-opencode"
            ],
            "dual": [
                "minimal",
                "adapter-copilot",
                "adapter-opencode",
                "capabilities-extended-lite"
            ],
            "accelerated": [
                "dual",
                "scripts-pack",
                "policy-pack",
                "evidence-pack"
            ],
            "full-governance": [
                "accelerated",
                "capabilities-extended-full",
                "hooks-pack",
                "ci-pack"
            ],
            "docs-reference": [
                "docs-reference-pack"
            ],
            "custom": []
        },
        "all_features": [
            "base",
            "setup-docs",
            "capabilities-core",
            "capabilities-extended-lite",
            "capabilities-extended-full",
            "adapter-copilot",
            "adapter-opencode",
            "scripts-pack",
            "policy-pack",
            "hooks-pack",
            "ci-pack",
            "evidence-pack",
            "docs-reference-pack",
            "delivery-pack",
            "optional-agents-pack",
            "optional-prompts-pack",
            "preview-environments-pack",
            "evaluation-pack",
            "service-boundary-pack",
            "mcp-boundaries-pack",
            "advisor-pack"
        ],
        "available_packs": [
            "setup-docs",
            "capabilities-core",
            "base",
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "capabilities-extended-full",
            "policy-pack",
            "scripts-pack",
            "hooks-pack",
            "ci-pack",
            "evidence-pack",
            "docs-reference-pack",
            "delivery-pack",
            "optional-agents-pack",
            "optional-prompts-pack",
            "preview-environments-pack",
            "evaluation-pack",
            "service-boundary-pack",
            "mcp-boundaries-pack",
            "advisor-pack"
        ],
        "registry_errors": [],
        "validation_requested": true,
        "notes": [
            "docs-reference is optional add-on only"
        ]
    }
}
```
