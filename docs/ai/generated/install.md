# Install

- Status: `blocked`
- Generated at: `2026-04-29T18:30:47+00:00`
- Commit: `047d291`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Use upgrade for existing installs unless forced reinstall is intended.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-04-29T18:30:47+00:00",
    "command": "php tools/ai/ai.php install",
    "based_on_commit": "047d291",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "blocked",
    "score": null,
    "stale": false,
    "recommended_next_action": "Use upgrade for existing installs unless forced reinstall is intended.",
    "data": {
        "status": "blocked",
        "reason": "manifest already exists; use upgrade or install --reinstall",
        "manifest_path": ".ai-install-manifest.json"
    }
}
```
