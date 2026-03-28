# Hooks

Hooks are optional adapter-level enforcement, not the canonical workflow source.

## Included Example

- `.github/hooks/tool-guardian.json`
- `.github/hooks/scripts/tool-guardian.ps1`

This example uses a `preToolUse` hook to block obviously dangerous tool invocations before they execute.

## Current Guard Scope

- destructive git commands such as `git reset --hard` and `git push --force`
- destructive shell deletion commands such as `rm -rf`, `del /s`, and `rmdir /s`
- obvious secret-adjacent file targeting such as `.env`, `credentials`, `secret`, `token`, or `id_rsa`

## Design Notes

- keep hook logic narrow and deterministic
- prefer blocking a few critical cases over pretending to enforce everything
- keep canonical policy in `docs/ai/` and use hooks only for behavior that a runtime can truly enforce

## Limitations

- this example is PowerShell-first for the current Windows environment
- some runtimes or surfaces may not load repo hooks automatically
- the hook is pattern-based and should be treated as a safety net, not a complete security system
