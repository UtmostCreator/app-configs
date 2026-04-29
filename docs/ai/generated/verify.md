# Verify

- Status: `passed`
- Generated at: `2026-04-29T23:27:52+00:00`
- Commit: `45c4a3a`
- Branch: `feat/installer-transaction-engine`
- Recommended next action: `Run next to choose commit or PR closeout action.`

```json
{
    "schema_version": 1,
    "artifact": "verify.json",
    "generated_at": "2026-04-29T23:27:52+00:00",
    "command": "php tools/ai/ai.php verify --changed",
    "based_on_commit": "45c4a3a",
    "based_on_branch": "feat/installer-transaction-engine",
    "input_hashes": {},
    "status": "passed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run next to choose commit or PR closeout action.",
    "data": {
        "status": "passed",
        "mode": "default",
        "summary": {
            "errors": 0,
            "warnings": 17,
            "info": 23
        },
        "check_count": 6,
        "failed_checks": [],
        "results": [
            {
                "name": "validate-ai-config",
                "command": "php tools/ai/validate-ai-config.php",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260430-012748/validate-ai-config.log"
            },
            {
                "name": "validate-ai-catalog",
                "command": "php tools/ai/validate-ai-catalog.php",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260430-012748/validate-ai-catalog.log"
            },
            {
                "name": "generate-ai-catalog-check",
                "command": "php tools/ai/generate-ai-catalog.php --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260430-012748/generate-ai-catalog-check.log"
            },
            {
                "name": "generate-repo-structure-check",
                "command": "php tools/ai/generate-repo-structure.php --check --with-scc",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": true,
                "log": "docs/ai/generated/logs/verify-20260430-012748/generate-repo-structure-check.log"
            },
            {
                "name": "install-docs-check",
                "command": "php tools/ai/ai.php install-docs --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260430-012748/install-docs-check.log"
            },
            {
                "name": "advisor-check",
                "command": "php tools/ai/ai.php advisor --check",
                "exit": 0,
                "passed": true,
                "auto_fix_applied": false,
                "log": "docs/ai/generated/logs/verify-20260430-012748/advisor-check.log"
            }
        ],
        "findings": [
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
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": ".github/instructions",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": ".github/instructions",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": ".github/agents",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": ".github/agents",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": ".github/prompts",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": ".github/prompts",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": ".opencode/agents",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": ".opencode/agents",
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
                "file": ".github/workflows/validate-ai-surface.yml",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": ".github/workflows/validate-ai-surface.yml",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/validation.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/validation.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/context-packing.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/context-packing.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/scripts-reference.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/scripts-reference.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/toolchain-requirements.md",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/toolchain-requirements.md",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/capabilities/preview-environments",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/capabilities/preview-environments",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/capabilities/evaluation-and-regression",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/capabilities/evaluation-and-regression",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "docs/ai/capabilities/service-boundary-patterns",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "docs/ai/capabilities/service-boundary-patterns",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
            },
            {
                "severity": "WARNING",
                "code": "HASH_DRIFT_MANAGED_FILE",
                "file": "tools/ai/advisor",
                "message": "Managed file hash drift detected.",
                "suggested_fix": "Review local customization and merge with source updates."
            },
            {
                "severity": "INFO",
                "code": "CUSTOMISED_MANAGED_FILE",
                "file": "tools/ai/advisor",
                "message": "Managed file appears customized locally.",
                "suggested_fix": "Keep or merge local changes intentionally."
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
        "log_dir": "docs/ai/generated/logs/verify-20260430-012748"
    }
}
```
