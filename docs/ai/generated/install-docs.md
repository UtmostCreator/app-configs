# Install docs

- Status: `failed`
- Generated at: `2026-05-06T01:52:54+00:00`
- Commit: `6ede0a4`
- Branch: `main`
- Recommended next action: `Run install-docs --write to regenerate install docs.`

```json
{
    "schema_version": 1,
    "artifact": "install-docs.json",
    "generated_at": "2026-05-06T01:52:54+00:00",
    "command": "php tools/ai/ai.php install-docs --check",
    "based_on_commit": "6ede0a4",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "failed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install-docs --write to regenerate install docs.",
    "data": {
        "status": "failed",
        "mode": "check",
        "target": "C:\\xampp\\htdocs\\app-configs",
        "drift": [
            "docs/ai/generated/install-instructions.json",
            "docs/ai/generated/install-instructions.md",
            "docs/ai/generated/install-catalog.json",
            "docs/ai/generated/install-catalog.md",
            "packages/ai-universal-rules/docs/INSTALL-CATALOG.md"
        ]
    }
}
```
