# Precedence

This package uses layered instructions, so precedence and composition must be explicit.

## OpenCode

OpenCode combines configuration from multiple sources instead of replacing the whole config at each layer.

Typical precedence model:

1. remote or organizational defaults when configured
2. global user config
3. custom config via environment variables
4. project config such as `opencode.json`
5. `.opencode/` directories and custom config directories
6. inline or runtime overrides

Practical guidance:

- keep global defaults broad
- keep project config repo-specific
- keep capability folders focused on reusable workflows, gotchas, and examples
- keep `.opencode/` assets focused on roles and runtime adapters
- avoid splitting one rule across multiple files unless the layering is intentional

## GitHub Copilot

Copilot can combine multiple instruction sources for the same request.

Important layers:

1. personal or user-level instructions where supported
2. repository-wide instructions in `.github/copilot-instructions.md`
3. path-specific instructions in `.github/instructions/*.instructions.md`
4. nearest `AGENTS.md` for agent-oriented instruction lookup
5. optional agents and prompt files when supported by the active surface

Important behavior:

- repo-wide and path-specific instructions can both apply
- nearest `AGENTS.md` can take precedence for agent instruction lookup
- conflicting instructions can lead to non-deterministic results

## Conflict Avoidance Rules

- keep repo-wide instructions short and general
- keep path-specific instructions narrow and file-focused
- place canonical workflow behavior in capability folders, not in global policy
- avoid repeating the same rule in multiple scopes
- if two instructions could conflict, move one to a narrower owner or remove it

## Safe Composition Pattern

Use this order when building a repository:

1. core policy
2. project context and capability folders
3. repo-wide instructions
4. path-specific instructions
5. nearest-owner instructions only where needed
6. optional workflow assets

This keeps the base system stable even if optional features are unavailable.

## What To Put Where

- core policy: broad safety, review, and working rules
- project context: durable repository facts, commands, boundaries, and active paths
- capability folders: reusable workflows with gotchas and examples
- repo-wide instructions: stable repository-wide behavior that should apply often
- path-specific instructions: narrow file or subsystem guidance
- optional workflow assets: runtime-specific adapters
