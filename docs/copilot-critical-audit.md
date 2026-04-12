# GitHub Copilot Critical Setup Audit

Date: 2026-04-12

## Critical gaps identified in this repo config

1. **VS Code extension gap:** `github.copilot-chat` is listed, but `github.copilot` was not listed.
   - Copilot Chat depends on the base Copilot experience being available in VS Code.

2. **Terminal agent gap:** GitHub Copilot CLI (`@github/copilot`) was not listed in the CLI tool inventory.
   - Copilot CLI is now a first-party terminal surface with `/plan`, `/fleet`, `/delegate`, `/mcp`, `/agent`, and `/skills` workflows.

## Critical additions made

- Added **GitHub Copilot CLI** to `docs/software-and-cli-tools.md`.
- Added `github.copilot` to `docs/vscode-extensions.md` list and install command block.

## High-impact integrations to add next (critical-first)

1. **Enable Copilot CLI and authenticate once per machine**
   ```bash
   npm install -g @github/copilot
   copilot --version
   copilot
   ```

2. **Adopt repo-level agent behavior for CLI and VS Code parity**
   - Keep `AGENTS.md` instructions concise and task-oriented.
   - This is specifically called out by GitHub Copilot CLI (`/agent` + `/skills`).

3. **Integrate MCP servers only for concrete bottlenecks**
   - Start with GitHub-native MCP workflows (issues/PRs/branches).
   - Add external MCP servers only when a measurable workflow gap exists.

## Why these are marked critical

- They remove direct blockers to using Copilot across both major surfaces you already use: **VS Code** and **terminal CLI**.
- They unlock the built-in issue/PR and delegated workflow model without introducing optional complexity too early.
