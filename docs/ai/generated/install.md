# Install

- Status: `ok`
- Generated at: `2026-05-06T17:58:57+00:00`
- Commit: `f0e8a6e`
- Branch: `main`
- Recommended next action: `Run install --backup-only before install --apply.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-05-06T17:58:57+00:00",
    "command": "php tools/ai/ai.php install --dry-run",
    "based_on_commit": "f0e8a6e",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run install --backup-only before install --apply.",
    "data": {
        "status": "planned",
        "mode": "safe-merge",
        "runtime_mode": "HUMAN_TTY",
        "profile": "full-governance",
        "packs": [
            "capabilities-extended-full",
            "hooks-pack",
            "ci-pack",
            "scripts-pack",
            "policy-pack",
            "evidence-pack",
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "base",
            "setup-docs",
            "capabilities-core"
        ],
        "apply": false,
        "summary": {
            "create": 1,
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
