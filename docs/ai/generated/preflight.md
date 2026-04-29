# Preflight

- Status: `ok`
- Generated at: `2026-04-29T18:30:47+00:00`
- Commit: `047d291`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Run package-verify then adapter-plan.`

```json
{
    "schema_version": 1,
    "artifact": "preflight.json",
    "generated_at": "2026-04-29T18:30:47+00:00",
    "command": "php tools/ai/ai.php preflight",
    "based_on_commit": "047d291",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run package-verify then adapter-plan.",
    "data": {
        "status": "ok",
        "checks": [
            {
                "name": "php_version",
                "status": "passed",
                "required": ">=8.1"
            },
            {
                "name": "ext_json",
                "status": "passed"
            },
            {
                "name": "ext_mbstring",
                "status": "passed"
            },
            {
                "name": "ext_zip",
                "status": "passed",
                "reason": null
            },
            {
                "name": "git",
                "status": "passed"
            },
            {
                "name": "generated_dir_writable",
                "status": "passed"
            },
            {
                "name": "templates_readable",
                "status": "passed"
            }
        ],
        "recommended_next_action": "Run package-verify then adapter-plan."
    }
}
```
