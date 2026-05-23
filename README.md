# app-configs

Personal macOS development environment configuration files ΓÇö terminal, editor, shell, keyboard, and PHP reference material.

> **Looking for the AI Workflow Kit?** It has moved to [awesome-ai-utmostcreator](https://github.com/UtmostCreator/awesome-ai-utmostcreator).

## Ghostty Full Disk Access Popup

> macOS Settings -> Privacy & Security -> Full Disk Access -> enable Ghostty via the toggle

## What Is Here

- Ghostty terminal configuration for a fast, keyboard-first terminal workflow
- Neovim setup bootstrapped with `lazy.nvim`, including tmux-aware navigation and testing plugins
- Zsh, Starship, and shell setup designed for repeatable CLI productivity
- PHP runtime and Laravel Pint configuration for consistent formatting and local development
- VS Code settings, launch config, and extension recommendations for project work
- Karabiner and keyboard documentation for cross-platform ergonomics
- PHP design patterns, principles, and built-in function reference examples
- Doctor script and git hooks for local health checks

## Documentation

- `docs/software-and-cli-tools.md` — curated macOS development environment and CLI stack
- `docs/shell-setup.md` — shell, prompt, and secret-handling setup
- `docs/nvim-setup.md` — Neovim deployment and prerequisites
- `docs/vscode-extensions.md` — VS Code extension recommendations
- `docs/keyboard.md` — keyboard and Karabiner ergonomics notes
- `docs/windows/QUICKSTART.md` — persistent SSH agent with 8h passphrase prompt on Windows
- `docs/windows/ssh-agent-setup.md` — long-form Windows SSH reference and rollback notes

## Configurations

- `configs/ghostty/` ΓÇö terminal configuration
- `configs/nvim/` ΓÇö Neovim configuration and plugins
- `configs/karabiner/` ΓÇö keyboard remapping config
- `configs/php/` ΓÇö PHP runtime (`php.ini`) and Laravel Pint (`pint.json`)
- `configs/shell/` ΓÇö Starship prompt, `.zshrc`, `.gitconfig`
- `configs/vscode/` ΓÇö workspace settings, user settings, keybindings, launch config

## PHP Reference

- `reference/php/design-patterns/` ΓÇö primary PHP design pattern example corpus
- `reference/php/design-principles/` ΓÇö PHP principles and composition examples
- `reference/php/php-built-ins/` ΓÇö PHP built-in function usage examples

## Scripts

- `scripts/doctor.sh` ΓÇö local toolchain health check
- `scripts/hooks/pre-commit.sh` ΓÇö merge conflict marker detection + PHP lint
- `scripts/hooks/commit-msg.sh` ΓÇö commit message format validation

## Style Configs (reference)

These exist as starter configs for target projects. No JS/TS/CSS source exists in this repo:

- `.eslintrc.json` ΓÇö ESLint for Vue 3 + TypeScript
- `.prettierrc.json` ΓÇö Prettier formatting rules
- `.stylelintrc.json` ΓÇö Stylelint for Tailwind/Vue
- `.editorconfig` ΓÇö editor whitespace, indent, EOL (active)

## Quick Start

1. Read the relevant setup doc in `docs/`
2. Copy or merge the config from `configs/` into your local environment
3. Replace machine-specific placeholders
4. Run `bash scripts/doctor.sh` to verify your local toolchain

## Important Notes

- Some settings are intentionally machine-specific; shared docs call those out
- Git hooks use Lefthook (`.lefthook.yml`) ΓÇö run `lefthook install` to activate

## Key Files

- `docs/software-and-cli-tools.md`
- `docs/shell-setup.md`
- `docs/nvim-setup.md`
- `docs/keyboard.md`
- `docs/vscode-extensions.md`
- `docs/windows/QUICKSTART.md`
- `configs/ghostty/config`
- `configs/nvim/init.lua`
- `configs/php/pint.json`
- `configs/vscode/user/settings.json`
- `scripts/git-branch-origin.sh`

