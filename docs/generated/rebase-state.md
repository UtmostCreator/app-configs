# Rebase state

- Status: `ok`
- Generated at: `2026-04-29T00:30:55+00:00`
- Commit: `92d5dbc`
- Branch: `main`
- Recommended next action: `Open next.json and execute the recommended action.`

```json
{
    "schema_version": 1,
    "artifact": "rebase-state.json",
    "generated_at": "2026-04-29T00:30:55+00:00",
    "command": "php tools/ai/ai.php rebase-state",
    "based_on_commit": "92d5dbc",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Open next.json and execute the recommended action.",
    "data": {
        "status": "ok",
        "runs": [
            {
                "command": "php tools/ai/ai.php snapshot",
                "exit": 0
            },
            {
                "command": "php tools/ai/ai.php diff-summary --base main",
                "exit": 0
            },
            {
                "command": "php tools/ai/ai.php risk --base main",
                "exit": 0
            },
            {
                "command": "php tools/ai/ai.php verify --changed",
                "exit": 0
            },
            {
                "command": "php tools/ai/ai.php freshness",
                "exit": 0
            },
            {
                "command": "php tools/ai/ai.php budget",
                "exit": 0
            },
            {
                "command": "php tools/ai/ai.php next",
                "exit": 1
            }
        ],
        "next_artifact": "docs/ai/generated/next.json"
    }
}
```
