# app-configs

macOS development environment for full-stack work, terminal workflows, PHP tooling, editor setup, and CLI-driven delivery.

This repository has two related jobs:

1. document and version my daily developer workstation across shell, terminal, Neovim, PHP, keyboard ergonomics, containers, and editor workflow
2. provide a reusable cross-tool AI workflow kit for repo-scoped guidance, validation, and generated catalog surfaces

## Workstation Highlights

- Ghostty terminal configuration for a fast, keyboard-first terminal workflow
- Neovim setup bootstrapped with `lazy.nvim`, including tmux-aware navigation and testing plugins
- Zsh, Starship, and shell setup designed for repeatable CLI productivity
- PHP runtime and Laravel Pint configuration for consistent formatting and local development
- VS Code settings, launch config, and extension recommendations for project work
- Karabiner and keyboard documentation for cross-platform ergonomics
- AI workflow validation and generation scripts for reusable repo guidance

## What Is Here

- `docs/software-and-cli-tools.md` - curated macOS development environment and CLI stack
- `docs/shell-setup.md` - shell, prompt, and secret-handling setup
- `docs/nvim-setup.md` - Neovim deployment and prerequisites
- `docs/vscode-extensions.md` - VS Code extension recommendations
- `docs/keyboard.md` - keyboard and Karabiner ergonomics notes
- `tools/ghostty/` - terminal configuration
- `tools/nvim/` - Neovim configuration and plugins
- `tools/karabiner/` - keyboard remapping config
- `php/` - PHP runtime and Pint configuration
- `vscode/` - workspace, user settings, keybindings, and launch config

## AI Workflow Kit

The repo also contains a reusable AI workflow layer for repo-scoped guidance across multiple tools.

- `AI-universal-rules/` - canonical reusable package
- `docs/ai/` - live repo-specific AI workflow docs and capability catalog
- `tools/ai/` - validation and catalog generation scripts
- `.github/` - GitHub Copilot adapter files for this repository

The goal is to keep canonical workflow knowledge in one place and keep runtime-specific adapter files thin.

## Repository Layout

```text
.
|-- AGENTS.md
|-- CLAUDE.md
|-- AI-universal-rules/
|-- docs/
|   |-- ai/
|   |-- keyboard.md
|   |-- nvim-setup.md
|   |-- shell-setup.md
|   |-- software-and-cli-tools.md
|   `-- vscode-extensions.md
|-- php/
|   |-- php.ini
|   `-- pint.json
|-- shell/
|   |-- .zshrc
|   `-- starship.toml
|-- tools/
|   |-- ai/
|   |-- ghostty/
|   |-- karabiner/
|   `-- nvim/
|-- vscode/
|   |-- keybindings.json
|   |-- launch.json
|   |-- user/
|   |-- workspace-example.json
|   `-- workspace-template.json
`-- .github/
    |-- copilot-instructions.md
    |-- agents/
    `-- instructions/
```

## Quick Start

### Local config use

- Read the relevant setup note in `docs/`
- Copy or merge the matching config into your local environment
- Replace any machine-specific placeholders before using shared templates

### AI workflow use

- Start with `AGENTS.md`
- Read `docs/ai/project-context.md`
- Browse `docs/ai/catalog.md` when you need the fastest path to relevant assets
- Use the smallest relevant capability in `docs/ai/capabilities/`
- Only then use runtime-specific adapter files such as `.github/copilot-instructions.md`
- Run `php tools/ai/validate-ai-config.php` after changing root workflow files
- Run `php tools/ai/validate-ai-catalog.php` after changing package metadata or generated docs
- Run `php tools/ai/generate-ai-catalog.php` after changing cataloged assets or package metadata

## Important Notes

- Some settings are intentionally machine-specific; shared docs should call those out instead of hiding them
- Example repos under `AI-universal-rules/examples/` are references, not root-repo behavior
- This repo prefers a practical production-grade workflow model over a large catalog of agents, skills, or plugins

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
