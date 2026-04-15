# Hooks

Hooks are optional adapter-level enforcement, not the canonical workflow source.

## Included Example

- `.github/hooks/tool-guardian.json`
- `.github/hooks/tool-policy.json`
- `.github/hooks/scripts/tool-guardian.ps1`
- `scripts/copilot/pre-tool-use.sh`
- `scripts/copilot/post-tool-use.sh`
- `.husky/pre-commit`
- `.husky/commit-msg`
- `.lefthook.yml`
- `scripts/hooks/pre-commit.sh`
- `scripts/hooks/commit-msg.sh`

This example uses a `preToolUse` hook to block obviously dangerous tool invocations before they execute.
The repo also includes optional git commit hooks that both Husky and Lefthook can point at.

## Current Guard Scope

- destructive git commands such as `git reset --hard` and `git push --force`
- destructive shell deletion commands such as `rm -rf`, `del /s`, and `rmdir /s`
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

- this example is PowerShell-first for the current Windows environment
- some runtimes or surfaces may not load repo hooks automatically
- the hook is pattern-based and should be treated as a safety net, not a complete security system
- secret scanning remains best-effort locally; CI or broader audits should still exist for higher assurance
