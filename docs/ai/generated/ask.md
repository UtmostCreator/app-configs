# Ask

- Status: `ok`
- Generated at: `2026-04-29T00:34:17+00:00`
- Commit: `92d5dbc`
- Branch: `main`
- Recommended next action: `Clarification resolved; rerun next to continue orchestration.`

```json
{
    "schema_version": 1,
    "artifact": "ask.json",
    "generated_at": "2026-04-29T00:34:17+00:00",
    "command": "php tools/ai/ai.php ask --resolve q-20260429-003417-256d51 --answer both",
    "based_on_commit": "92d5dbc",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Clarification resolved; rerun next to continue orchestration.",
    "data": {
        "status": "resolved",
        "question_id": "q-20260429-003417-256d51",
        "question": "Which runtime adapter is in scope?",
        "options": [
            "copilot",
            "opencode",
            "both"
        ],
        "why_needed": "Decision ambiguity materially changes implementation direction.",
        "default_if_unanswered": "both",
        "blocks": [
            "next"
        ],
        "resolved_at_utc": "2026-04-29T00:34:17+00:00",
        "answer": "both",
        "resolution_mode": "explicit-answer"
    }
}
```
