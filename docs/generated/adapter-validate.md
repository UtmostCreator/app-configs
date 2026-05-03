# Adapter validate

- Status: `warning`
- Generated at: `2026-05-03T16:30:54+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Run package-verify and audit-instructions first if missing.`

```json
{
    "schema_version": 1,
    "artifact": "adapter-validate.json",
    "generated_at": "2026-05-03T16:30:54+00:00",
    "command": "php tools/ai/ai.php adapter-validate",
    "based_on_commit": "92683f9",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "warning",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run package-verify and audit-instructions first if missing.",
    "data": {
        "status": "warning",
        "package_verify_status": "failed",
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
