# Package verify

- Status: `failed`
- Generated at: `2026-04-29T22:49:30+00:00`
- Commit: `670fe37`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Refresh lock or revert unintended template drift.`

```json
{
    "schema_version": 1,
    "artifact": "package-verify.json",
    "generated_at": "2026-04-29T22:49:30+00:00",
    "command": "php tools/ai/ai.php package-verify",
    "based_on_commit": "670fe37",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "failed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Refresh lock or revert unintended template drift.",
    "data": {
        "path": "packages/ai-universal-rules/package-lock.ai.json",
        "mismatch_count": 6,
        "mismatches": [
            {
                "path": "templates/opencode/agents/architect.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:1b10b5f17ac5d1bb1e4480858b77bad42aa0dd2de1d21706c2b704efc81a4a21",
                "current": "sha256:ee2dc498fb57ccb257d4fadd1efcc99743dc0b2dfe31b19522cb42bccd6cfb85"
            },
            {
                "path": "templates/opencode/agents/implementer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:370372a6ed7ebcc32e73bda5a1c093ad69cadc78945bd63a233b40d95ac3a36d",
                "current": "sha256:e2ddff98a8ab50d7f4b7d736c59fb74fb9a59e5fa5df20723d4bb573ebda6642"
            },
            {
                "path": "templates/opencode/agents/refactorer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:3a2dc3ea389c321907a645e82e547854b897d793e62c34379896cfe5d2fdb968",
                "current": "sha256:a57375d9e5d7548264d0450508ce3d882401f4ff19d9d9547302b85de3b166d1"
            },
            {
                "path": "templates/opencode/agents/release-auditor.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:283e5be4899128911d070d0523cf3f5451de1b08195af54e3a4b660d8f126869",
                "current": "sha256:d74feaeb34e7bd4f5dc0e70a65a0c14b5830aea571381583ddacab5881bec6fd"
            },
            {
                "path": "templates/opencode/agents/researcher.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:29f79e9fe4e8b0156817ab7839957edd626b97e573ded1aba534d06167df112c",
                "current": "sha256:38421da9f0ecb4c3ff0e60bba7c0aed69bc5ce865fa29c6ec9ed591afb5dcfe4"
            },
            {
                "path": "templates/opencode/agents/reviewer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:85b1361cf4890fe939407a82037f910d020183d06b8a854b5412c9f2a1abc485",
                "current": "sha256:72f2b8877957bcd3c2c1a3fef08d1e29f8c0065e738e8495ea42712d923b7c52"
            }
        ]
    }
}
```
