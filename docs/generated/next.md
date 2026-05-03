# Next

- Status: `blocked`
- Generated at: `2026-05-03T16:30:41+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Regenerate stale artifact before continuing.`

```json
{
    "schema_version": 1,
    "artifact": "next.json",
    "generated_at": "2026-05-03T16:30:41+00:00",
    "command": "php tools/ai/ai.php next",
    "based_on_commit": "92683f9",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "blocked",
    "score": null,
    "stale": false,
    "recommended_next_action": "Regenerate stale artifact before continuing.",
    "data": {
        "status": "blocked",
        "reason": "stale artifacts detected",
        "stale_artifacts": [
            "install-transaction.json",
            "placeholders.json"
        ],
        "next_action": "php tools/ai/ai.php install-transaction"
    }
}
```
