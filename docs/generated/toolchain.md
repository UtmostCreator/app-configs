# Toolchain

- Status: `ok`
- Generated at: `2026-05-03T16:31:04+00:00`
- Commit: `unknown`
- Branch: `unknown`
- Recommended next action: `Review missing tools and rerun with --toolchain-apply only when needed.`

```json
{
    "schema_version": 1,
    "artifact": "toolchain.json",
    "generated_at": "2026-05-03T16:31:04+00:00",
    "command": "php tools/ai/ai.php toolchain",
    "based_on_commit": "unknown",
    "based_on_branch": "unknown",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Review missing tools and rerun with --toolchain-apply only when needed.",
    "data": {
        "status": "ok",
        "profile": "dual",
        "runtime": "both",
        "packs": [
            "adapter-copilot",
            "adapter-opencode",
            "capabilities-extended-lite",
            "base",
            "setup-docs",
            "capabilities-core"
        ],
        "check_requested": true,
        "install_plan_requested": false,
        "apply_requested": true,
        "tools": [
            {
                "tool": "scc",
                "label": "SCC",
                "present": false,
                "version": "unknown",
                "safe_auto_install": false,
                "requires_before_install": [],
                "install_hints": {
                    "macos": "brew install scc",
                    "linux": "Install scc from your package manager or release binary",
                    "windows": "Install scc via package manager or release binary"
                },
                "install_commands": []
            }
        ],
        "install_actions": [
            {
                "tool": "scc",
                "hint": "Install scc via package manager or release binary",
                "safe_auto_install": false
            }
        ],
        "apply_results": [
            {
                "tool": "scc",
                "status": "blocked",
                "reason": "auto-install not approved",
                "hint": "Install scc via package manager or release binary"
            }
        ]
    }
}
```
