# Install

- Status: `ok`
- Generated at: `2026-04-29T23:27:28+00:00`
- Commit: `45c4a3a`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Run install --backup-only before install --apply.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-04-29T23:27:28+00:00",
    "command": "php tools/ai/ai.php install --dry-run",
    "based_on_commit": "45c4a3a",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install --backup-only before install --apply.",
    "data": {
        "status": "planned",
        "mode": "safe-merge",
        "runtime_mode": "AI_AGENT",
        "profile": "full-governance",
        "packs": [
            "capabilities-extended-full",
            "hooks-pack",
            "ci-pack",
            "base"
        ],
        "apply": false,
        "summary": {
            "create": 0,
            "skip": 0
        },
        "install_kind": "reinstall",
        "required_first": [
            "preflight",
            "package-verify",
            "adapter-plan",
            "install --backup-only"
        ]
    }
}
```
