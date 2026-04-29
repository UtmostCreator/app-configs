# Upgrade

- Status: `ok`
- Generated at: `2026-04-29T13:36:39+00:00`
- Commit: `047d291`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `If changes look safe, run upgrade --apply.`

```json
{
    "schema_version": 1,
    "artifact": "upgrade.json",
    "generated_at": "2026-04-29T13:36:39+00:00",
    "command": "php tools/ai/ai.php upgrade --dry-run",
    "based_on_commit": "047d291",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "If changes look safe, run upgrade --apply.",
    "data": {
        "status": "ok",
        "mode": "dry-run",
        "manifest_runtime": "both",
        "manifest_mode": "sidecar-only",
        "package_source_ref": "unknown",
        "latest_available_tag": "unknown",
        "target_ref": null,
        "detected_changes": [],
        "file_actions": [],
        "package_verify_status": "ok"
    }
}
```
