# app-configs

macOS-first developer configuration repository plus a reusable cross-tool AI workflow kit.

This repository has two related jobs:

1. document and version daily workstation setup across shell, terminal, Neovim, PHP, keyboard ergonomics, and editor workflow
2. provide a reusable cross-tool AI workflow kit for repo-scoped guidance, validation, and generated catalog surfaces

## Ghostty Full Disk Access Popup

> macOS Settings -> Privacy & Security -> Full Disk Access -> enable Ghostty via the toggle

## Workstation Highlights

- Ghostty terminal configuration for a fast, keyboard-first terminal workflow
- Neovim setup bootstrapped with `lazy.nvim`, including tmux-aware navigation and testing plugins
- Zsh, Starship, and shell setup designed for repeatable CLI productivity
- PHP runtime and Laravel Pint configuration for consistent formatting and local development
- VS Code settings, launch config, and extension recommendations for project work
- Karabiner and keyboard documentation for cross-platform ergonomics
- AI workflow validation and generation scripts for reusable repo guidance
- optional local workflow scaffolding via `just`, `doctor`, and shared commit-hook scripts

## What Is Here

- `docs/software-and-cli-tools.md` - curated macOS development environment and CLI stack
- `docs/shell-setup.md` - shell, prompt, and secret-handling setup
- `docs/nvim-setup.md` - Neovim deployment and prerequisites
- `docs/vscode-extensions.md` - VS Code extension recommendations
- `docs/keyboard.md` - keyboard and Karabiner ergonomics notes
- `tools/ghostty/` - terminal configuration
- `tools/nvim/` - Neovim configuration and plugins
- `tools/karabiner/` - keyboard remapping config
- `tools/design-patterns/` - primary PHP design pattern example corpus
- `tools/design-principles/` - PHP principles and composition examples
- `tools/php-built-ins/` - PHP built-in function usage examples
- `php/` - PHP runtime and Pint configuration
- `vscode/` - workspace, user settings, keybindings, and launch config
- `justfile` - optional workflow entrypoints for local health checks and AI validation
- `scripts/` - Copilot wrappers, doctor checks, and shared git-hook scripts

## Repo Packages And Manifests

- `AI-universal-rules/manifest.json` - canonical package metadata for the reusable AI workflow kit
- `AI-universal-rules/manifest.yml` - YAML mirror for the same package metadata
- `AI-universal-rules/catalog.json` - generated machine-readable catalog of package and root resources
- `docs/ai/catalog.md` - generated human-readable catalog index
- `llms.txt` - generated LLM-oriented index for key docs and assets
- Root Node and Composer package manifests are intentionally not used in this repository

## AI Workflow Kit

The repo also contains a reusable AI workflow layer for repo-scoped guidance across multiple tools.

- `AI-universal-rules/` - canonical reusable package
- `docs/ai/` - live repo-specific AI workflow docs and capability catalog
- `docs/ai/agents.md` - live agent reference and package agent index
- `docs/ai/failure-handling.md` - failure taxonomy, retry rules, and logging contract
- `docs/ai/agent-ops-checklist.md` - phased verification checklist for AI workflow integration
- `docs/ai/integration-matrix.md` - concept-to-file coverage map for the live AI workflow layer
- `tools/ai/` - validation and catalog generation scripts
- `.github/` - GitHub Copilot adapter files for this repository
- `scripts/copilot/` - stronger local AI tooling wrappers for search, PR context, context packing, hooks, and telemetry

The goal is to keep canonical workflow knowledge in one place and keep runtime-specific adapter files thin.

## Repository Layout

```text
.
|-- .editorconfig
|-- .eslintrc.json
|-- .github/
|   |-- agents/
|   |-- copilot-instructions.md
|   |-- hooks/
|   |-- instructions/
|   |-- prompts/
|   |-- skills/
|   `-- workflows/
|-- AGENTS.md
|-- AI-universal-rules/
|   |-- catalog.json
|   |-- docs/
|   |-- examples/
|   |-- manifest.json
|   |-- manifest.yml
|   `-- templates/
|-- CLAUDE.md
|-- CONTRIBUTING.md
|-- docs/
|   |-- ai/
|   |-- keyboard.md
|   |-- nvim-setup.md
|   |-- shell-setup.md
|   |-- software-and-cli-tools.md
|   `-- vscode-extensions.md
|-- justfile
|-- llms.txt
|-- php/
|   |-- php.ini
|   `-- pint.json
|-- scripts/
|   |-- copilot/
|   |-- doctor.sh
|   `-- hooks/
|-- SECURITY.md
|-- shell/
|   |-- .gitconfig
|   |-- .zshrc
|   `-- starship.toml
|-- SUPPORT.md
|-- tools/
|   |-- ai/
|   |-- create_structure.sh
|   |-- design-patterns/
|   |-- design-principles/
|   |-- ghostty/
|   |-- karabiner/
|   |-- nvim/
|   `-- php-built-ins/
`-- vscode/
    |-- keybindings.json
    |-- launch.json
    |-- user/
    |-- workspace-example.json
    `-- workspace-template.json
```

## Quick Start

### Local config use

- Read the relevant setup note in `docs/`
- Copy or merge the matching config into your local environment
- Replace any machine-specific placeholders before using shared templates
- Run `just doctor` after syncing config files if you use the local workflow scaffolding

### AI workflow use

- Start with `AGENTS.md`
- Read `docs/ai/project-context.md`
- Browse `docs/ai/catalog.md` when you need the fastest path to relevant assets
- Use `docs/ai/agents.md` when you need to know which live or package agent fits the job
- Use `docs/ai/failure-handling.md` when commands fail, retries are needed, or you need the approved read-only posture
- Use `docs/ai/agent-ops-checklist.md` to verify the repository after workflow changes
- Use `docs/ai/integration-matrix.md` to see what is covered, partial, or still missing
- Use the smallest relevant capability in `docs/ai/capabilities/`
- Only then use runtime-specific adapter files such as `.github/copilot-instructions.md`
- For GitHub Copilot, install both `github.copilot` and `github.copilot-chat`, then optionally add Copilot CLI for terminal-heavy work
- For tool-routed Copilot workflows, follow `docs/ai/copilot-tooling.md` (instructions -> wrappers -> hooks -> skills/prompts -> MCP)
- For ranked per-folder AI context bundles, follow `docs/ai/context-packing.md`
- Use `scripts/copilot/ai-diff-context.sh` when you need narrow context for changed files, PR files, recent edits, or touched areas
- Use `scripts/copilot/ai-search.sh` when the agent should route all search through one stable entrypoint
- For PHP guidance, search local examples in this order: `tools/design-patterns/` -> `tools/design-principles/` -> `tools/php-built-ins/`
- Use `just php-examples-map` to print the preferred PHP example lookup order
- Use `just php-patterns-search`, `just php-principles-search`, and `just php-builtins-search` for direct corpus search
- Use `scripts/copilot/ai-edit.sh` as the only approved path for broad repository edits
- Use `scripts/copilot/ai-verify.sh` after changes to run the project-aware verification stack
- Use `scripts/copilot/gh-pr-context.sh` for richer PR metadata, checks, reviews, and diff summaries
- Use `scripts/copilot/rg-code.sh` for mode-based search across PHP, JS, config, tracked files, or JSON output
- Run `php tools/ai/validate-ai-config.php` after changing root workflow files
- Run `php tools/ai/validate-ai-catalog.php` after changing package metadata or generated docs
- Run `php tools/ai/generate-ai-catalog.php` after changing cataloged assets or package metadata
- Run `just ai-check` if you want one local command that wraps the three AI workflow checks above
- Use `just verify` for the guarded post-edit verification path
- Use `just edit-ast`, `just edit-text`, and their `-apply` variants instead of raw mass-edit shell commands

### Context packing

- `just context-stats` - analyze folder and file metrics with `scc`
- `just context-plan` - rank folders and create a bundle plan
- `just context-plan-since BRANCH_OR_REF` - create a churn-aware bundle plan limited to files changed since a git ref
- `just context-since BRANCH_OR_REF` - plan or pack a narrower changed-files context slice through `ai-diff-context.sh`
- `just context-pack` - pack the current planned bundles with `repomix`
- `just context-pack-all` - run analysis, planning, and packing in one step
- `just context-pack-all-since BRANCH_OR_REF` - run changed-since stats, plan, and packing in one step
- `just context-plan-json` - print the current `bundle-plan.json` for agent-friendly inspection
- `scripts/copilot/repomix-scc-router.sh` writes both `bundle-plan.tsv` and `bundle-plan.json` under `.repomix-context/`

## Important Notes

- Some settings are intentionally machine-specific; shared docs should call those out instead of hiding them
- Example repos under `AI-universal-rules/examples/` are references, not root-repo behavior
- This repo prefers a practical production-grade workflow model over a large catalog of agents, skills, or plugins
- Safe repo-local read-only commands are approval-free by default unless they touch privileged access, secrets, or external side effects

## Key Files

- `docs/software-and-cli-tools.md`
- `docs/shell-setup.md`
- `docs/nvim-setup.md`
- `docs/keyboard.md`
- `docs/vscode-extensions.md`
- `tools/ghostty/config`
- `tools/nvim/init.lua`
- `php/pint.json`
- `docs/ai/project-context.md`
- `docs/ai/catalog.md`
