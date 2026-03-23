# AI Universal Rules

Portable instruction templates for OpenCode and GitHub Copilot.

This package is for teams who want a reusable starting point for AI collaboration rules without baking in one stack, one language, or one project shape. It is intentionally placeholder-driven and tool-aware: one neutral policy core, then thin adapters for each platform.

## Who This Is For

- Teams setting up AI instructions in a new repository
- Individuals sharing a clean starter kit with friends or clients
- Repositories that want one policy model but different delivery formats for different tools

## What Is Included

- Core policy templates
- OpenCode templates for agents, commands, and skills
- GitHub Copilot templates for repo instructions, path instructions, a compact core agent set, and prompts
- Optional specialist packs for advanced workflows
- Two placeholder-only example trees
- Validation scripts to catch unresolved placeholders and user-supplied project-specific leaks

## What Is Not Included

- Project-specific rules
- Language-specific conventions by default
- Full parity between OpenCode and GitHub Copilot
- Guaranteed support for every Copilot surface

## Start Small

Start with the smallest set that matches your target tool:

1. Copy the core templates.
2. Copy either the OpenCode or GitHub Copilot adapter set.
3. Replace placeholders.
4. Run the validation tools.
5. Test the setup in a toy repository before rolling it into production work.

## Supported Targets

- OpenCode
- GitHub Copilot

See `docs/COMPATIBILITY.md` for the limits of each integration model.

## Folder Map

- `templates/core/`: main neutral policy templates
- `templates/snippets/`: reusable text fragments for assembling custom policies
- `templates/opencode/`: base OpenCode files
- `templates/github-copilot/`: base GitHub Copilot files
- `templates/optional/`: specialist add-ons
- `examples/`: placeholder-only example trees
- `tools/`: validation scripts

## Important Note About Copilot Prompts

Prompt files are included as optional guidance assets, but support varies by IDE and surface. Treat repo instructions and path instructions as the more stable foundation.

The Copilot adapter intentionally stays lighter than the OpenCode side. Its core workflow roles mirror OpenCode's architect, reviewer, and refactorer concepts, while specialist roles stay on the OpenCode side unless a repository has a proven Copilot-specific need.
