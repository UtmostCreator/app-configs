# Control Model

This package assumes the same broad concepts can exist across tools without implying the same level of control.

## Explicit File-Based Control

OpenCode is the stronger reference model for explicit repo-local control:

- `AGENTS.md` for project rules
- `.opencode/agents/` for role definitions
- `.opencode/commands/` for first-class workflow commands
- `.opencode/skills/` for reusable context
- `opencode.json` and config-directory support for explicit configuration layering

This makes more of the behavior visible in files and easier to reason about as a repo-defined system.

## Runtime-Mediated Control

GitHub Copilot supports similar capability categories, but behavior depends more on runtime, IDE, feature availability, and enablement:

- repo-wide custom instructions
- path-specific instructions
- nearest `AGENTS.md`
- custom agents
- prompt files
- MCP and tool configuration

The concept exists, but the exact behavior can differ between VS Code, CLI, and GitHub.com.

## Practical Rule

Treat OpenCode as the explicit-control reference and Copilot as a surface-aware adapter model.

That means:

- use commands as native OpenCode workflow assets
- use prompt files as optional Copilot workflow assets
- do not describe prompt files as a command system
- do not assume Copilot custom-agent properties behave uniformly across runtimes

## What To Tell Users

When documenting the kit:

- say what is file-driven
- say what is preview-only
- say what requires enablement
- say what degrades safely if unsupported
