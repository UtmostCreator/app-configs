# Estimate

- Status: `ok`
- Generated at: `2026-05-10T10:33:04+00:00`
- Commit: `06dde0c`
- Branch: `codex/integrate-ai-search-scripts-into-project`
- Recommended next action: `Use context + diff-summary before implementation.`

```json
{
    "schema_version": 1,
    "artifact": "estimate.json",
    "generated_at": "2026-05-10T10:33:04+00:00",
    "command": "php tools/ai/ai.php estimate",
    "based_on_commit": "06dde0c",
    "based_on_branch": "codex/integrate-ai-search-scripts-into-project",
    "input_hashes": {},
    "status": "ok",
    "score": 26,
    "stale": false,
    "recommended_next_action": "Use context + diff-summary before implementation.",
    "data": {
        "task": "add workflow-control command",
        "complexity": 3,
        "risk_score": 26,
        "risk_level": "low",
        "suggested_first_step": "php tools/ai/ai.php context --task \"add workflow-control command\"",
        "recommended_next_action": "php tools/ai/ai.php diff-summary --base main"
    }
}
```
