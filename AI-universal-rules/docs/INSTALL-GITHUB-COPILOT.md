# Install For GitHub Copilot

Start with the most stable Copilot primitives first:

- `.github/copilot-instructions.md`
- `.github/instructions/*.instructions.md`

Add agents and prompt files only after confirming your target Copilot surface supports them the way you expect.

## Minimum Stable Copy Set

Copy these files into your target repository:

- `templates/core/copilot-instructions.template.md` -> `.github/copilot-instructions.md`
- `templates/core/project-stack.template.md`
- `templates/github-copilot/instructions/architecture.instructions.md`
- `templates/github-copilot/instructions/frontend.instructions.md`
- `templates/github-copilot/instructions/testing.instructions.md`
- `templates/github-copilot/instructions/targets.instructions.md`

## Optional Add-Ons

Agents are optional workflow adapters:

- `templates/github-copilot/agents/architect.agent.md`
- `templates/github-copilot/agents/reviewer.agent.md`
- `templates/github-copilot/agents/refactorer.agent.md`

Prompt files are preview-only workflow assets:

- `templates/github-copilot/prompts/new-feature.prompt.md`
- `templates/github-copilot/prompts/bug-regression.prompt.md`
- `templates/github-copilot/prompts/review-code.prompt.md`

Delivery planning assets are optional:

- `templates/optional/delivery/README.md`
- `templates/optional/delivery/slice-card.template.md`

## Surface Guidance

### VS Code / CLI

- Safest setup: repo instructions plus path instructions
- Custom agents: use only the compact core set when they add value
- Prompt files: preview-only and environment-dependent
- Treat advanced agent behavior such as handoffs or tool restrictions as capabilities to validate locally, not assumptions

### GitHub.com Coding Agent

- Safest setup: repo instructions, path instructions where supported, and `AGENTS.md`
- Custom agent behavior can differ from local IDE behavior, so keep the agent set small
- Some custom-agent properties are not supported uniformly
- Do not treat prompt-file-driven workflows as the default plan on GitHub.com

## Setup Steps

1. Rename `copilot-instructions.template.md` to `.github/copilot-instructions.md`.
2. Copy only the instruction files first.
3. Replace placeholders across all copied files.
4. Add `.github/agents/` only if the target surface supports the behaviors you want, and start with the architect, reviewer, and refactorer only.
5. Add `.github/prompts/` only if your IDE or toolchain supports prompt files and your team accepts preview features.
6. Search for unresolved `<PLACEHOLDER_NAME>` tokens and remove project-specific leaks.

## Suggested First Test

- Ask Copilot to summarize the repo using the repo-wide and path-specific instructions.
- If using agents, ask the architect for a medium-sized implementation plan.
- If using agents, ask for a diff review using the reviewer agent.
- If using prompt files, test one prompt and confirm the feature is enabled on your surface.
- Confirm medium-sized plans include risk level (`low` | `medium` | `high`).
- For `medium` and `high` risk, confirm rollback plan, observability signal, and feature-flag posture are present.

## Recommendation

Start with repo instructions and path instructions first. If you add agents, keep the Copilot set aligned to the OpenCode core: architect, reviewer, and refactorer. Treat prompt files as an optional enhancement, not part of the required base install.
