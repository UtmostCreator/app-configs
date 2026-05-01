# Verify

- Status: `failed`
- Generated at: `2026-05-01T00:03:52+00:00`
- Commit: `104ee24`
- Branch: `main`
- Recommended next action: `Open verify logs and fix the first failing check before proceeding.`

```json
{
    "schema_version": 1,
    "artifact": "verify.json",
    "generated_at": "2026-05-01T00:03:52+00:00",
    "command": "php tools/ai/ai.php verify --changed",
    "based_on_commit": "104ee24",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "failed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Open verify logs and fix the first failing check before proceeding.",
    "data": {
        "status": "failed",
        "mode": "default",
        "summary": {
            "errors": 1,
            "warnings": 1,
            "info": 7
        },
        "check_count": 6,
        "failed_checks": [
            "validate-ai-config"
        ],
        "results": [
            {
                "name": "validate-ai-config",
                "command": "php tools/ai/validate-ai-config.php",
                "exit": 1,
                "passed": false,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260501-020348/validate-ai-config.log"
            },
            {
                "name": "validate-ai-catalog",
                "command": "php tools/ai/validate-ai-catalog.php",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260501-020348/validate-ai-catalog.log"
            },
            {
                "name": "generate-ai-catalog-check",
                "command": "php tools/ai/generate-ai-catalog.php --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260501-020348/generate-ai-catalog-check.log"
            },
            {
                "name": "generate-repo-structure-check",
                "command": "php tools/ai/generate-repo-structure.php --check --with-scc",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": true,
                "log": "docs/ai/generated/logs/verify-20260501-020348/generate-repo-structure-check.log"
            },
            {
                "name": "install-docs-check",
                "command": "php tools/ai/ai.php install-docs --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260501-020348/install-docs-check.log"
            },
            {
                "name": "advisor-check",
                "command": "php tools/ai/ai.php advisor --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260501-020348/advisor-check.log"
            }
        ],
        "findings": [
            {
                "severity": "ERROR",
                "code": "CHECK_FAILED",
                "file": null,
                "message": "Verification check failed: validate-ai-config",
                "suggested_fix": "Inspect docs/ai/generated logs and rerun verify."
            },
            {
                "severity": "WARNING",
                "code": "UNFILLED_REQUIRED_PLACEHOLDER",
                "file": "docs/ai",
                "message": "Unresolved placeholders detected.",
                "suggested_fix": "Run php tools/ai/ai.php placeholders --fail and update placeholders."
            },
            {
                "severity": "INFO",
                "code": "UNFILLED_OPTIONAL_PLACEHOLDER",
                "file": "docs/ai",
                "message": "Optional placeholders may remain unresolved.",
                "suggested_fix": "Review placeholder list and fill values as needed for strict mode."
            },
            {
                "severity": "INFO",
                "code": "MISSING_OPTIONAL_TOOL",
                "file": "scripts/ai",
                "message": "Optional tool missing: fzf",
                "suggested_fix": "Install optional tooling for faster workflows."
            },
            {
                "severity": "INFO",
                "code": "MISSING_OPTIONAL_TOOL",
                "file": "scripts/ai",
                "message": "Optional tool missing: delta",
                "suggested_fix": "Install optional tooling for faster workflows."
            },
            {
                "severity": "INFO",
                "code": "MISSING_OPTIONAL_TOOL",
                "file": "scripts/ai",
                "message": "Optional tool missing: semgrep",
                "suggested_fix": "Install optional tooling for faster workflows."
            },
            {
                "severity": "INFO",
                "code": "MISSING_OPTIONAL_TOOL",
                "file": "scripts/ai",
                "message": "Optional tool missing: ast-grep",
                "suggested_fix": "Install optional tooling for faster workflows."
            },
            {
                "severity": "INFO",
                "code": "HOOK_EXEC_CHECK_PLATFORM_LIMIT",
                "file": "scripts/hooks/pre-commit.sh",
                "message": "Executable bit check skipped on Windows.",
                "suggested_fix": "Verify hook execution manually on Windows."
            },
            {
                "severity": "INFO",
                "code": "HOOK_EXEC_CHECK_PLATFORM_LIMIT",
                "file": "scripts/hooks/commit-msg.sh",
                "message": "Executable bit check skipped on Windows.",
                "suggested_fix": "Verify hook execution manually on Windows."
            }
        ],
        "log_dir": "docs/ai/generated/logs/verify-20260501-020348"
    }
}
```
