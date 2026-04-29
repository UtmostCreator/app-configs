# Toolchain

- Status: `ok`
- Generated at: `2026-04-29T18:30:47+00:00`
- Commit: `047d291`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Review missing tools and rerun with --toolchain-apply only when needed.`

```json
{
    "schema_version": 1,
    "artifact": "toolchain.json",
    "generated_at": "2026-04-29T18:30:47+00:00",
    "command": "php tools/ai/ai.php toolchain",
    "based_on_commit": "047d291",
    "based_on_branch": "feat/installer-transaction-engine",
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
            "base"
        ],
        "check_requested": true,
        "install_plan_requested": false,
        "apply_requested": false,
        "tools": [],
        "install_actions": [],
        "apply_results": []
    }
}
```

                "present": true,
                "version": "scc version 3.7.0",
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
        "install_actions": [],
        "apply_results": []
    }
}
```
