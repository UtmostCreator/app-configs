# Install

- Status: `blocked`
- Generated at: `2026-05-10T11:30:27+00:00`
- Commit: `06dde0c`
- Branch: `codex/integrate-ai-search-scripts-into-project`
- Recommended next action: `Create backup first, then rerun apply with --backup <backup-id>.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-05-10T11:30:27+00:00",
    "command": "php tools/ai/ai.php install --apply",
    "based_on_commit": "06dde0c",
    "based_on_branch": "codex/integrate-ai-search-scripts-into-project",
    "input_hashes": {},
    "status": "blocked",
    "score": null,
    "stale": false,
    "recommended_next_action": "Create backup first, then rerun apply with --backup <backup-id>.",
    "data": {
        "status": "blocked",
        "mode": "sidecar-only",
        "runtime_mode": "HUMAN_TTY",
        "reason": "apply requires explicit backup id",
        "next_action": "php tools/ai/ai.php install --backup-only --apply --mode sidecar-only"
    }
}
```
