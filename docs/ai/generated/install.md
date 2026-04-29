# Install

- Status: `ok`
- Generated at: `2026-04-29T01:20:33+00:00`
- Commit: `fe37d92`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Run install --backup-only before install --apply.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-04-29T01:20:33+00:00",
    "command": "php tools/ai/ai.php install --dry-run",
    "based_on_commit": "fe37d92",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install --backup-only before install --apply.",
    "data": {
        "status": "planned",
        "mode": "sidecar-only",
        "runtime_mode": "AI_AGENT",
        "apply": false,
        "install_kind": "fresh_install",
        "required_first": [
            "preflight",
            "package-verify",
            "adapter-plan",
            "install --backup-only"
        ]
    }
}
```
