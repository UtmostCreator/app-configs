# Install

- Status: `ok`
- Generated at: `2026-05-06T18:00:48+00:00`
- Commit: `9313d57`
- Branch: `main`
- Recommended next action: `Run install --backup-only before install --apply.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-05-06T18:00:48+00:00",
    "command": "php tools/ai/ai.php install --dry-run",
    "based_on_commit": "9313d57",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install --backup-only before install --apply.",
    "data": {
        "status": "planned",
        "mode": "sidecar-only",
        "runtime_mode": "CI",
        "profile": "dual",
        "packs": [
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "scripts-pack",
            "policy-pack",
            "hooks-pack",
            "base",
            "setup-docs",
            "capabilities-core"
        ],
        "apply": false,
        "summary": {
            "create": 1,
            "skip": 15
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
