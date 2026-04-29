# Preflight

- Status: `failed`
- Generated at: `2026-04-29T01:20:33+00:00`
- Commit: `fe37d92`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Resolve failed checks before install/apply.`

```json
{
    "schema_version": 1,
    "artifact": "preflight.json",
    "generated_at": "2026-04-29T01:20:33+00:00",
    "command": "php tools/ai/ai.php preflight",
    "based_on_commit": "fe37d92",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "failed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Resolve failed checks before install/apply.",
    "data": {
        "status": "failed",
        "checks": [
            {
                "name": "php_version",
                "status": "passed",
                "required": ">=8.2"
            },
            {
                "name": "ext_json",
                "status": "passed"
            },
            {
                "name": "ext_mbstring",
                "status": "failed"
            },
            {
                "name": "ext_zip",
                "status": "failed",
                "reason": "ZipArchive is required for ZIP backups"
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
        "recommended_next_action": "Resolve failed checks before install/apply."
    }
}
```
