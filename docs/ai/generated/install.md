# Install

- Status: `blocked`
- Generated at: `2026-04-30T23:03:22+00:00`
- Commit: `dfa2cd8`
- Branch: `main`
- Recommended next action: `Add the required pack with --with or choose a profile that includes it.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-04-30T23:03:22+00:00",
    "command": "php tools/ai/ai.php install",
    "based_on_commit": "dfa2cd8",
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
