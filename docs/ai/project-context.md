# app-configs Project Context

## Project Shape

- Project type: `configuration repo + AI workflow kit`
- Summary: `Reusable local development configuration plus a live benchmark for durable cross-tool AI workflow setup.`
- Primary language: `Markdown, JSON, shell config, Lua`
- Primary runtime: `local developer tooling`
- Supported targets: `VS Code, shell, Ghostty, Karabiner, Neovim, PHP tooling, GitHub Copilot, Claude-style agent runtimes`
- Active paths: `AI-universal-rules/, docs/, configs/vscode/, configs/shell/, tools/, configs/php/, .github/`
- Inactive paths: `none declared; treat stale examples or copied stack-specific files as defects`

## Architecture

- Primary entrypoints: `README.md, AGENTS.md, CLAUDE.md, AI-universal-rules/README.md, configs/vscode/user/settings.json, configs/shell/.zshrc, justfile`
- AI reference docs: `docs/ai/agents.md, docs/ai/failure-handling.md, docs/ai/agent-ops-checklist.md, docs/ai/integration-matrix.md`
- Architecture notes: `AI-universal-rules/ is the reusable package; docs/ai/ is the root-repo instantiation; runtime-specific adapter files should stay thin and point back to canonical docs; local workflow scaffolding lives in justfile plus scripts/hooks and is optional rather than canonical policy.`
- PHP reference corpus: `reference/php/design-patterns/` (primary), `reference/php/design-principles/` (secondary), and `reference/php/php-built-ins/` (supporting examples).
- Canonical workflow source: `docs/ai/capabilities/`
- Runtime adapter surfaces: `.github/`, `AGENTS.md`, `CLAUDE.md`
- Risk areas: `stale documentation, mismatched tool-specific instructions, machine-specific paths, silent workflow drift between canonical and adapter files`

## Approval Boundaries

- secrets or credentials
- machine-wide runtime or dependency changes with broad impact
- removal of a supported AI runtime surface
- destructive cleanup outside obviously stale AI adapter files
- safe repo-local read-only commands are approval-free unless they need secrets, privileged access, or external side effects

## Verification

- Main verification command: `no single global command; choose the narrowest non-destructive check supported by the edited tool`
- Main build command: `none required for most changes`
- Main test command: `none global; use targeted validation such as JSON parse, editor load, CLI dry-run, or docs consistency checks`
- Preferred narrow-first verification pattern: `validate the changed config or instruction directly, then run a broader smoke check only if the slice crosses tools`
- Failure policy: `log command failures, corrected usage, and retry decisions using docs/ai/failure-handling.md`

## Query Closeout

- For context-heavy repo investigation, context-packing, or folder-scoped analysis tasks, end with the read-only usage summary from `scripts/copilot/query-usage.sh` or `just query-usage` against the actual scope you inspected.
- Report both `raw estimated tokens` (for context-fit) and `weighted usage` (for Copilot quota planning) in the closeout when the task materially depends on prompt size.
- Treat `raw estimated tokens ~= bytes / 4` as a planning heuristic, not an exact provider token count.
- Treat `weighted usage = raw estimated tokens × model multiplier` as a Copilot planning heuristic, not an official runtime billing formula.
- Use the active model's documented multiplier when known; otherwise say `unknown` rather than guessing.
- This closeout step is approval-free because `query-usage.sh` is read-only and only analyzes repo-local content.

## Review Priorities

- repo truth over borrowed patterns
- portability over vendor lock-in where practical
- simple install paths and clear fallbacks
- evidence-backed docs and commands
