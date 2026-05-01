# Install

- Status: `failed`
- Generated at: `2026-04-30T23:59:44+00:00`
- Commit: `28fe104`
- Branch: `main`
- Recommended next action: `Inspect installer output and rerun install after fixing errors.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-04-30T23:59:44+00:00",
    "command": "php tools/ai/ai.php install --apply",
    "based_on_commit": "28fe104",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "failed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Inspect installer output and rerun install after fixing errors.",
    "data": {
        "status": "failed",
        "mode": "safe-merge",
        "runtime_mode": "AI_AGENT",
        "backup_id": "install-20260430-235938",
        "transaction_id": "install-20260430-235942",
        "installer_command": "php tools/ai/install-ai-kit.php --target . --runtime \"both\" --profile \"full-governance\" --force --allow-core-overwrite",
        "installer_exit": 1,
        "installer_stdout_preview": "[install-ai-kit] source root: C:\\xampp\\htdocs\\app-configs\r\n[install-ai-kit] target root: C:\\xampp\\htdocs\\app-configs\r\n[install-ai-kit] profile: full-governance\r\n[install-ai-kit] runtime: both\r\n",
        "installer_stderr_preview": "Error: missing required tools for selected packs: jq, rg\r\n",
        "post_install_script": {
            "requested": null,
            "executed": false,
            "reason": null,
            "exit": null
        }
    }
}
```
