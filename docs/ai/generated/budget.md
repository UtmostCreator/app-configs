# Budget

- Status: `ok`
- Generated at: `2026-04-29T00:30:54+00:00`
- Commit: `92d5dbc`
- Branch: `main`
- Recommended next action: `Context budget looks safe for a focused next step.`

```json
{
    "schema_version": 1,
    "artifact": "budget.json",
    "generated_at": "2026-04-29T00:30:54+00:00",
    "command": "php tools/ai/ai.php budget",
    "based_on_commit": "92d5dbc",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Context budget looks safe for a focused next step.",
    "data": {
        "context_window": 32000,
        "estimated_total_tokens": 9811,
        "remaining_tokens": 22189,
        "artifact_count": 23,
        "artifacts": [
            {
                "artifact": "file-context.json",
                "estimated_tokens": 1812,
                "stale": false
            },
            {
                "artifact": "freshness.json",
                "estimated_tokens": 1565,
                "stale": false
            },
            {
                "artifact": "project-snapshot.json",
                "estimated_tokens": 1165,
                "stale": false
            },
            {
                "artifact": "budget.json",
                "estimated_tokens": 696,
                "stale": false
            },
            {
                "artifact": "env-check.json",
                "estimated_tokens": 670,
                "stale": false
            },
            {
                "artifact": "verify.json",
                "estimated_tokens": 505,
                "stale": false
            },
            {
                "artifact": "workflow.json",
                "estimated_tokens": 430,
                "stale": false
            },
            {
                "artifact": "rebase-state.json",
                "estimated_tokens": 338,
                "stale": false
            },
            {
                "artifact": "session-resume.json",
                "estimated_tokens": 270,
                "stale": false
            },
            {
                "artifact": "ai-commands.json",
                "estimated_tokens": 240,
                "stale": false
            },
            {
                "artifact": "why.json",
                "estimated_tokens": 217,
                "stale": false
            },
            {
                "artifact": "ask.json",
                "estimated_tokens": 211,
                "stale": false
            },
            {
                "artifact": "decision-add.json",
                "estimated_tokens": 201,
                "stale": false
            },
            {
                "artifact": "auto-fix.json",
                "estimated_tokens": 175,
                "stale": false
            },
            {
                "artifact": "commit-msg.json",
                "estimated_tokens": 167,
                "stale": false
            },
            {
                "artifact": "logs.json",
                "estimated_tokens": 161,
                "stale": false
            },
            {
                "artifact": "next.json",
                "estimated_tokens": 159,
                "stale": false
            },
            {
                "artifact": "pr-summary.json",
                "estimated_tokens": 155,
                "stale": false
            },
            {
                "artifact": "diff-summary.json",
                "estimated_tokens": 150,
                "stale": false
            },
            {
                "artifact": "impact.json",
                "estimated_tokens": 147,
                "stale": false
            },
            {
                "artifact": "risk.json",
                "estimated_tokens": 141,
                "stale": false
            },
            {
                "artifact": "orphans.json",
                "estimated_tokens": 120,
                "stale": false
            },
            {
                "artifact": "conflicts.json",
                "estimated_tokens": 116,
                "stale": false
            }
        ]
    }
}
```
