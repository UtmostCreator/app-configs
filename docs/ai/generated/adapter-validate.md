# Adapter validate

- Status: `ok`
- Generated at: `2026-04-29T19:33:42+00:00`
- Commit: `fdd960a`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Run package-verify and audit-instructions first if missing.`

```json
{
    "schema_version": 1,
    "artifact": "adapter-validate.json",
    "generated_at": "2026-04-29T19:33:42+00:00",
    "command": "php tools/ai/ai.php adapter-validate",
    "based_on_commit": "fdd960a",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run package-verify and audit-instructions first if missing.",
    "data": {
        "status": "ok",
        "package_verify_status": "ok",
        "install_manifest_present": true,
        "derived_install_manifest_present": true,
        "manifest_drift_detected": false,
        "checks": [
            "package-verify artifact",
            "instruction-audit artifact",
            "install manifest present",
            "derived manifest drift"
        ]
    }
}
```
