# Control Model

This package assumes the same broad concepts can exist across tools without implying the same level of control.

## Explicit File-Based Control

Use this section to explain which assets are the canonical source of workflow knowledge and which assets are runtime adapters.

OpenCode is the stronger reference model for explicit repo-local control:

- `AGENTS.md` for project rules
- durable project context such as `docs/ai/project-context.md` for repository facts
- capability folders such as `docs/ai/capabilities/` for canonical reusable workflow knowledge, gotchas, and examples
- `.opencode/agents/` for role definitions
- `.opencode/commands/` for runtime command adapters
- `.opencode/skills/` for runtime skill adapters
- `opencode.json` and config-directory support for explicit configuration layering

This makes more of the behavior visible in files and easier to reason about as a repo-defined system.

## Runtime-Mediated Control

Use this section to explain the adapter surface, not to redefine the canonical workflow model.

GitHub Copilot supports similar categories, but behavior depends more on runtime, IDE, feature availability, and enablement:

- repo-wide custom instructions
- path-specific instructions
- nearest `AGENTS.md`
- custom agents
- prompt files
- MCP and tool configuration

The concept exists, but the exact behavior can differ between VS Code, CLI, and GitHub.com.

In this kit, Copilot adapters should point back to project context and capability folders instead of becoming the only source of workflow truth.

## Practical Rule

Treat OpenCode as the explicit-control reference and Copilot as a surface-aware adapter model.

That means:

- use durable project context for repository facts
- use capability folders as the canonical reusable workflow layer
- use OpenCode skills and commands as runtime adapters around that capability layer
- use Copilot agents and prompt files as optional adapter assets
- do not describe prompt files as a command system
- do not assume Copilot custom-agent properties behave uniformly across runtimes

## What Each Asset Is For

- project context: durable repository facts and boundaries
- capability folders: canonical reusable workflows
- agents: role posture and bounded task behavior
- commands: invocation shortcuts and compatibility wrappers
- skills: runtime access to capability workflows
- prompts: optional surface-specific workflow guidance

## What Each Asset Is Not For

- project context is not where workflow logic should accumulate
- capability folders are not for runtime-specific adapter behavior
- agents are not a replacement for project context or capability folders
- commands are not the only source of workflow truth
- prompts are not guaranteed command equivalents

## What To Tell Users

When documenting the kit:

- say what is file-driven
- say what is preview-only
- say what requires enablement
- say what degrades safely if unsupported
