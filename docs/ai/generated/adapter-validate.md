# Adapter validate

- Status: `warning`
- Generated at: `2026-04-29T00:47:18+00:00`
- Commit: `799b5e6`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Run package-verify and audit-instructions first if missing.`

```json
{
    "schema_version": 1,
    "artifact": "adapter-validate.json",
    "generated_at": "2026-04-29T00:47:18+00:00",
    "command": "php tools/ai/ai.php adapter-validate",
    "based_on_commit": "799b5e6",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "warning",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run package-verify and audit-instructions first if missing.",
    "data": {
        "status": "warning",
        "package_verify_status": "ok",
        "install_manifest_present": false,
        "checks": [
            "package-verify artifact",
            "instruction-audit artifact",
            "install manifest present"
        ]
    }
}
```
