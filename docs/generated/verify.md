# Verify

- Status: `failed`
- Generated at: `2026-05-03T16:30:41+00:00`
- Commit: `92683f9`
- Branch: `main`
- Recommended next action: `Open verify logs and fix the first failing check before proceeding.`

```json
{
    "schema_version": 1,
    "artifact": "verify.json",
    "generated_at": "2026-05-03T16:30:41+00:00",
    "command": "php tools/ai/ai.php verify --changed",
    "based_on_commit": "92683f9",
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
            "errors": 2,
            "warnings": 29,
            "info": 38
        },
        "check_count": 6,
        "failed_checks": [
            "install-docs-check"
        ],
        "results": [
            {
                "name": "validate-ai-config",
                "command": "php tools/ai/validate-ai-config.php",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260503-183037/validate-ai-config.log"
            },
            {
                "name": "validate-ai-catalog",
                "command": "php tools/ai/validate-ai-catalog.php",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260503-183037/validate-ai-catalog.log"
            },
            {
                "name": "generate-ai-catalog-check",
                "command": "php tools/ai/generate-ai-catalog.php --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260503-183037/generate-ai-catalog-check.log"
            },
            {
                "name": "generate-repo-structure-check",
                "command": "php tools/ai/generate-repo-structure.php --check --with-scc",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260503-183037/generate-repo-structure-check.log"
            },
            {
                "name": "install-docs-check",
                "command": "php tools/ai/ai.php install-docs --check",
                "exit": 1,
                "passed": false,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260503-183037/install-docs-check.log"
            },
            {
                "name": "advisor-check",
                "command": "php tools/ai/ai.php advisor --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260503-183037/advisor-check.log"
            }
        ],
        "findings": [
            {
                "severity": "ERROR",
                "code": "CHECK_FAILED",
                "file": null,
                "message": "Verification check failed: install-docs-check",
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
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/hooks/pre-commit.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/hooks/pre-commit.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/hooks/commit-msg.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/hooks/commit-msg.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/hooks.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/hooks.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/common.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/common.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/ai-search.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/ai-search.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/ai-diff-context.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/ai-diff-context.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/ai-verify.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/ai-verify.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/ai-rollback.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/ai-rollback.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/ai-edit.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/ai-edit.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/pack-context.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/pack-context.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/pre-tool-use.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/pre-tool-use.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/post-tool-use.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/post-tool-use.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/run-repomix-context.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/run-repomix-context.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/repomix-context-tree.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/repomix-context-tree.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/repomix-scc-router.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/repomix-scc-router.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/git-forensics.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/git-forensics.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/gh-pr-context.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/gh-pr-context.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/preview-file.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/preview-file.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/query-usage.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/query-usage.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/fd-files.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/fd-files.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/rg-code.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/rg-code.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/watch-loop.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/watch-loop.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/repo-tool-inventory.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/repo-tool-inventory.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "scripts/ai/install-mandatory-tools.sh",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "scripts/ai/install-mandatory-tools.sh",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/repo-required-tools.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/repo-required-tools.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/command-risk-taxonomy.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/command-risk-taxonomy.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/failure-handling.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/failure-handling.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "AGENTS.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "AGENTS.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "ERROR",
                "code": "MISSING_REQUIRED_TOOL",
                "file": "scripts/ai",
                "message": "Required tool missing: bash",
                "suggested_fix": "Install required scripts-pack dependency."
            },
            {
                "severity": "INFO",
                "code": "MISSING_OPTIONAL_TOOL",
                "file": "scripts/ai",
                "message": "Optional tool missing: fd",
                "suggested_fix": "Install optional tooling for faster workflows."
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
                "message": "Optional tool missing: bat",
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
                "message": "Optional tool missing: yq",
                "suggested_fix": "Install optional tooling for faster workflows."
            },
            {
                "severity": "INFO",
                "code": "MISSING_OPTIONAL_TOOL",
                "file": "scripts/ai",
                "message": "Optional tool missing: shellcheck",
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
        "log_dir": "docs/ai/generated/logs/verify-20260503-183037"
    }
}
```
