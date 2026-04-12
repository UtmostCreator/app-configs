# GitHub Copilot Hybrid Workflow (VS Code + CLI)

Date: 2026-04-12

This repository is configured for a **hybrid Copilot workflow**:

- VS Code Copilot for interactive coding and editor-first collaboration.
- Copilot CLI for terminal-native execution and shell-heavy development flows.

## 1) Critical local setup

### VS Code extensions

Install both:

- `github.copilot`
- `github.copilot-chat`

See: `docs/vscode-extensions.md`.

### Copilot CLI

Install and start:

```bash
npm install -g @github/copilot
copilot --version
copilot
```

Alternative call path via GitHub CLI:

```bash
gh copilot
```

## 2) Repo customization files used to direct Copilot

### Always-on rules

- `.github/copilot-instructions.md`

### Path-specific rules

- `.github/instructions/*.instructions.md`

### Specialist agents

- `.github/agents/laravel-ask.agent.md`
- `.github/agents/laravel-bugfix.agent.md`
- `.github/agents/laravel-feature.agent.md`

### Reusable skill bundles

- `.github/skills/feature-delivery/SKILL.md`

### Reusable VS Code prompt templates

- `.github/prompts/feature-delivery.prompt.md`

## 3) Recommended feature workflow

1. Open task in VS Code Copilot Chat (or terminal with `copilot`).
2. Start with planning mode (`/plan`) and a small first slice.
3. Select an agent for intent:
   - ask/explore -> `Laravel Ask`
   - bugfix -> `Laravel Bugfix`
   - new feature -> `Laravel Feature Delivery`
4. Apply `feature-delivery` skill when feature scope is non-trivial.
5. Execute focused tests first, then broaden only if needed.
6. Keep final output PR-ready: summary + exact verification commands.

## 4) Why this setup

- Keeps fast IDE feedback loops in VS Code.
- Adds reliable terminal execution for scripts/tests/git-heavy tasks.
- Uses repo-level assets so behavior remains consistent across sessions and surfaces.
