# Install

- Status: `blocked`
- Generated at: `2026-05-03T16:31:03+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Add the required pack with --with or choose a profile that includes it.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-05-03T16:31:03+00:00",
    "command": "php tools/ai/ai.php install",
    "based_on_commit": "92683f9",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "blocked",
    "score": null,
    "stale": false,
    "recommended_next_action": "Add the required pack with --with or choose a profile that includes it.",
    "data": {
        "status": "blocked",
        "reason": "post-install script requires missing pack: scripts-pack",
        "script_id": "repomix-context",
        "selected_packs": [
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "base",
            "setup-docs",
            "capabilities-core"
        ]
    }
}
```
