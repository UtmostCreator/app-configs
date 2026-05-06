---
applyTo: "**"
description: "Tool selection and script enforcement — use rg/fd/approved scripts; never use bare grep/find"
---

# Tool Selection Rules

## Required Tools

When searching code or files, always prefer repository-aware tools:

- Use `rg` (ripgrep) instead of `grep` for code search
- Use `fd` instead of `find` for file discovery
- Use `ast-grep` / `sg` for structural code queries

When the repository provides wrapper scripts, use those in preference to direct tool invocation:

- `bash scripts/ai/ai-search.sh "<query>"` — safe repository text search
- `bash scripts/ai/rg-code.sh "<pattern>"` — code-specific rg wrapper
- `bash scripts/ai/fd-files.sh "<pattern>"` — file discovery wrapper
- `bash scripts/ai/preview-file.sh "<path>"` — safe file preview
- `bash scripts/ai/query-usage.sh "<symbol>"` — symbol usage search
- `bash scripts/ai/git-forensics.sh "<symbol-or-path>"` — git history tracing

Only use scripts that are listed in both `docs/ai/script-registry.md` and `docs/ai/script-registry.json`.

Direct git state/history commands and minimal local introspection are narrow exceptions when they are explicitly allowed by the active tool policy. Search, discovery, usage lookup, and file preview should still go through registered `scripts/ai` wrappers.

## Prohibited

Do not use these for search or discovery:

- `grep` (bare) — use `rg` or `ai-search.sh` instead
- `find` (bare) — use `fd` or `fd-files.sh` instead
- `cat` for broad exploration — use `preview-file.sh` instead

## Script Boundary

Only run scripts listed in `docs/ai/script-registry.md`, `docs/ai/script-registry.json`, and `docs/ai/scripts-reference.md`.

Prompt files must not grant broader tools than the selected agent.

Forbidden prompt-file examples:

- planner or review prompts with `tools: ['edit']`
- research prompts with broad `tools: ['execute']` instead of fine-grained `execute/runInTerminal`
- any prompt file with `tools: ['*']`

Do not run scripts outside `scripts/ai/` unless explicitly required by the task.

Do not run destructive commands: `rm -rf`, `git push --force`, `git reset --hard`, deploy commands.

## Path Note

Scripts should be run from the repository root. When the script location is unclear, use the repository-root script path:

```
bash scripts/ai/ai-search.sh "query"
```

`scripts/ai` is the script directory at the root of the installed repository.
