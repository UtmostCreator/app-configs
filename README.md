# app-configs

Opinionated development configuration plus a reusable cross-tool AI workflow kit.

This repository has two jobs:

- keep my editor, shell, terminal, PHP, and keyboard setup consistent
- serve as a practical benchmark for repo-scoped AI workflows across portable `AGENTS.md`, GitHub Copilot, and Claude-style runtime adapters

## What Is Here

- `AI-universal-rules/` - canonical cross-tool AI workflow package
- `docs/ai/` - the live AI workflow instantiation for this repository
- `vscode/` - workspace, user settings, keybindings, and launch config
- `shell/` - shell and prompt config
- `tools/` - Ghostty, Karabiner, and Neovim config
- `php/` - PHP runtime and Pint config
- `docs/` - setup notes for keyboard, shell, Neovim, VS Code, and local tooling

## AI Workflow Design

The root repository follows a simple layered model:

1. `AGENTS.md` and `CLAUDE.md` provide durable baseline memory
2. `docs/ai/project-context.md` captures repo facts
3. `docs/ai/capabilities/` holds canonical reusable procedures
4. `.github/` acts as the GitHub Copilot adapter
5. `AI-universal-rules/` remains the reusable package and reference implementation

The goal is to keep canonical workflow knowledge in one place and keep runtime-specific files thin.

## Repository Layout

```text
.
├── AGENTS.md
├── CLAUDE.md
├── AI-universal-rules/
├── docs/
│   ├── ai/
│   ├── keyboard.md
│   ├── nvim-setup.md
│   ├── shell-setup.md
│   ├── software-and-cli-tools.md
│   └── vscode-extensions.md
├── php/
│   ├── php.ini
│   └── pint.json
├── shell/
│   ├── .zshrc
│   └── starship.toml
├── tools/
│   ├── ghostty/
│   ├── karabiner/
│   └── nvim/
├── vscode/
│   ├── keybindings.json
│   ├── launch.json
│   ├── user/
│   ├── workspace-example.json
│   └── workspace-template.json
└── .github/
    ├── copilot-instructions.md
    ├── agents/
    └── instructions/
```

## Quick Start

### Local config use

- read the relevant setup note in `docs/`
- copy or merge the matching config file into your local environment
- replace any machine-specific placeholders before using shared templates

### AI workflow use

- start with `AGENTS.md`
- read `docs/ai/project-context.md`
- use the smallest relevant capability in `docs/ai/capabilities/`
- only then use runtime-specific adapter files such as `.github/copilot-instructions.md`
- run `php tools/ai/validate-ai-config.php` after changing root workflow files

## Important Notes

- Some settings are intentionally machine-specific; shared docs should call those out instead of hiding them.
- Example repos under `AI-universal-rules/examples/` are references, not root-repo behavior.
- This repo prefers a simple production-grade workflow model over a huge catalog of agents, skills, or plugins.

## Key Files

- `AGENTS.md`
- `CLAUDE.md`
- `docs/ai/project-context.md`
- `docs/ai/workflow.md`
- `docs/ai/validation.md`
- `docs/ai/hooks.md`
- `AI-universal-rules/README.md`
- `vscode/user/settings.json`
