# Hooks

Hooks are optional adapter-level enforcement, not the canonical workflow source.

## Included Example

- `.github/hooks/tool-guardian.json`
- `.github/hooks/tool-policy.json`
- `.github/hooks/scripts/tool-guardian.ps1`
- `scripts/ai/pre-tool-use.sh`
- `scripts/ai/post-tool-use.sh`
- `.husky/pre-commit`
- `.husky/commit-msg`
- `.lefthook.yml`
- `scripts/hooks/pre-commit.sh`
- `scripts/hooks/commit-msg.sh`

This example uses a `preToolUse` hook to block obviously dangerous tool invocations before they execute.
The repo also includes optional git commit hooks that both Husky and Lefthook can point at.

## Current Guard Scope

The bash hook (`scripts/ai/pre-tool-use.sh`) enforces the three-tier command risk taxonomy from `docs/ai/command-risk-taxonomy.md`:

- **Tier 1 (read-only)** — auto-approved: pure read CLI tools, git history/diff/blame, scan-only security tools, read-only copilot wrapper scripts, and read-only-adjacent generated-output wrappers
- **Tier 2 (modification)** — confirmation required: `git commit`, `git stash push/pop/drop`, `ai-edit` apply mode
- **Tier 3 (deletion/recovery)** — denied or explicit approval required: `rm`, destructive git (`git reset --hard`, `git push --force`), `ai-rollback apply`, `repomix-scc-router clean/purge`, `just context-clean/purge`

When `COPILOT_STRICT_ALLOWLIST=1` is set in the shell that launches Copilot CLI, the hook also denies commands outside the explicit read-only and approved-wrapper list. In practice this forces raw `grep`, `find`, and `cat`-style AI tool use toward the repo wrappers such as `scripts/ai/rg-code.sh`, `scripts/ai/fd-files.sh`, and `scripts/ai/preview-file.sh`.

Additionally blocked regardless of tier:

- obvious secret-adjacent file targeting such as `.env`, `credentials`, `secret`, `token`, or `id_rsa`
- staged merge-conflict markers before commit
- staged PHP syntax errors before commit when `php` is available
- staged secret scanning through `gitleaks`, with `trufflehog` as fallback when installed

## Design Notes

- keep hook logic narrow and deterministic
- prefer blocking a few critical cases over pretending to enforce everything
- keep canonical policy in `docs/ai/` and use hooks only for behavior that a runtime can truly enforce
- inspect staged content where practical instead of trusting the current working tree

## Limitations

- the bash hook (`pre-tool-use.sh`) is the primary enforcement path on macOS/Linux; the PowerShell guard (`tool-guardian.ps1`) is an optional complementary surface
- some runtimes or surfaces may not load repo hooks automatically
- VS Code IDE agent mode does not load repository hooks; strict allowlist enforcement is a Copilot CLI or cloud-agent concern, not an IDE-agent concern
- the hook is pattern-based and should be treated as a safety net, not a complete security system
- secret scanning remains best-effort locally; CI or broader audits should still exist for higher assurance

## Reuse In Other Repos

For a copy-ready integration checklist, see `docs/ai/copilot-cli-repo-integration.md`.
