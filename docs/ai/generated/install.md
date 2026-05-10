# Install

- Status: `ok`
- Generated at: `2026-05-10T15:25:11+00:00`
- Commit: `b75bf1b`
- Branch: `main`
- Recommended next action: `Install apply completed; run adapter-validate next.`

```json
{
    "schema_version": 1,
    "artifact": "install.json",
    "generated_at": "2026-05-10T15:25:11+00:00",
    "command": "php tools/ai/ai.php install --apply",
    "based_on_commit": "b75bf1b",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Install apply completed; run adapter-validate next.",
    "data": {
        "status": "ok",
        "mode": "sidecar-only",
        "runtime_mode": "AI_AGENT",
        "backup_id": "",
        "transaction_id": "install-20260510-152511",
        "installer_command": "php tools/ai/install-ai-kit.php --target . --runtime 'both' --profile 'full-governance' --no-base --force --allow-placeholders",
        "installer_exit": 0,
        "installer_stdout_preview": "[install-ai-kit] source root: /Users/rabbies-admin/Herd/app-configs\n[install-ai-kit] target root: /Users/rabbies-admin/Herd/app-configs\n[install-ai-kit] profile: full-governance\n[install-ai-kit] runtime: both\n[install-ai-kit] copied dir: docs/ai/capabilities/dependency-upgrade\n[install-ai-kit] copied file: .github/hooks/tool-policy.json\n[install-ai-kit] copied file: .github/hooks/tool-guardian.json\n[install-ai-kit] copied file: .github/hooks/scripts/tool-guardian.ps1\n[install-ai-kit] copied file: scripts/hooks/pre-commit.sh\n[install-ai-kit] copied file: scripts/hooks/commit-msg.sh\n[install-ai-kit] copied file: docs/ai/hooks.md\n[install-ai-kit] copied file: .github/workflows/validate-ai-surface.yml\n[install-ai-kit] copied file: .github/workflows/test-external-install.yml\n[install-ai-kit] copied file: .github/workflows/export-ai-universal-rules-preview.yml\n[install-ai-kit] copied file: docs/ai/validation.md\n[install-ai-kit] copied file: scripts/ai/common.sh\n[install-ai-kit] copied file: scripts/ai/ai-search.sh\n[install-ai-kit] copied file: scripts/ai/ai-diff-context.sh\n[install-ai-kit] copied file: scripts/ai/ai-verify.sh\n[install-ai-kit] copied file: scripts/ai/ai-rollback.sh\n[install-ai-kit] copied file: scripts/ai/ai-edit.sh\n[install-ai-kit] copied file: scripts/ai/pack-context.sh\n[install-ai-kit] copied file: scripts/ai/pre-tool-use.sh\n[install-ai-kit] copied file: scripts/ai/post-tool-use.sh\n[install-ai-kit] copied file: scripts/ai/run-repomix-context.sh\n[install-ai-kit] copied file: scripts/ai/repomix-context-tree.sh\n[install-ai-kit] copied file: scripts/ai/repomix-scc-router.sh\n[install-ai-kit] copied file: scripts/ai/git-forensics.sh\n[install-ai-kit] copied file: scripts/ai/gh-pr-context.sh\n[install-ai-kit] copied file: scripts/ai/preview-file.sh\n[install-ai-kit] copied file: tests/scripts/ai/test-preview-file.sh\n[install-ai-kit] copied file: docs/ai/tools/actions/preview-file.md\n[install-ai-kit] copied file: scripts/ai/query-usage.sh\n[install-ai-kit] copied file: scripts/ai/fd-files.sh\n[install-ai-kit] copied file: scripts/ai/rg-code.sh\n[install-ai-kit] copied file: scripts/ai/ai-structured.sh\n[install-ai-kit] copied file: scripts/ai/ai-task.sh\n[install-ai-kit] copied file: scripts/ai/ai-test-select.sh\n[install-ai-kit] copied file: scripts/ai/session-checkpoint.sh\n[install-ai-kit] copied file: scripts/ai/ai-doc-check.sh\n[install-ai-kit] copied file: scripts/ai/check-file-refs.sh\n[install-ai-kit] copied file: scripts/ai/repo-stats.sh\n[install-ai-kit] copied file: scripts/ai/watch-loop.sh\n[install-ai-kit] copied file: scripts/ai/repo-tool-inventory.sh\n[install-ai-kit] copied file: tools/ai/repo-tool-inventory.php\n[install-ai-kit] copied file: scripts/ai/install-mandatory-tools.sh\n[install-ai-kit] copied file: scripts/ai/setup-powershell-profile.ps1\n[install-ai-kit] copied file: docs/ai/repo-required-tools.md\n[install-ai-kit] copied file: docs/ai/mandatory-tools-install.md\n[install-ai-kit] copied file: docs/ai/script-registry.md\n[install-ai-k",
        "installer_stderr_preview": "",
        "post_install_script": {
            "requested": null,
            "executed": false,
            "reason": null,
            "exit": null
        }
    }
}
```
