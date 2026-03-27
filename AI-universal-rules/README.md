# AI Universal Rules

Portable instruction templates and capability folders for OpenCode and GitHub Copilot.

This package is for teams who want a reusable starting point for AI collaboration rules without baking in one stack, one language, or one project shape. It is intentionally placeholder-driven and tool-aware: one neutral policy core, one neutral capability model, then thin adapters for each platform.

## Who This Is For

- Teams setting up AI instructions in a new repository
- Individuals sharing a clean starter kit with friends or clients
- Repositories that want one policy model but different delivery formats for different tools

## What Is Included

- Core policy templates
- Core capability templates and examples
- OpenCode templates for agents, commands, and skills
- GitHub Copilot templates for repo instructions, path instructions, a compact core agent set, and prompts
- Optional specialist packs for advanced workflows
- Optional delivery pack with a lightweight slice card template
- Two placeholder-only example trees
- Validation guidance to catch unresolved placeholders and user-supplied project-specific leaks

## What Is Not Included

- Project-specific rules
- Language-specific conventions by default
- Full parity between OpenCode and GitHub Copilot
- Guaranteed support for every Copilot surface

## Start Small

Start with the smallest set that matches your target tool:

1. Copy the core templates.
2. Copy the capability folders you actually need.
3. Copy either the OpenCode or GitHub Copilot adapter set.
4. Replace placeholders.
5. Run validation checks for unresolved placeholders and project-specific leaks.
6. Test the setup in a toy repository before rolling it into production work.

Minimum base install for most repositories:

- `docs/ai/project-context.md`
- `docs/ai/capabilities/verify-change/`
- `docs/ai/capabilities/review-diff/`
- `docs/ai/capabilities/project-context/`

Add `bug-regression`, `release-safety`, and `dependency-upgrade` only when the repository actually needs them.

For non-trivial changes, use a trimmed risk model:

- `low`
- `medium`
- `high`

For `medium` and `high` risk changes, define rollback plan, observability signal, and feature-flag posture before implementation.

## Supported Targets

- OpenCode
- GitHub Copilot

See `docs/COMPATIBILITY.md` for the limits of each integration model.

## Folder Map

- `templates/core/`: main neutral policy templates
- `templates/capabilities/`: neutral capability folders with support files
- `templates/snippets/`: reusable text fragments for assembling custom policies
- `templates/opencode/`: base OpenCode files
- `templates/github-copilot/`: base GitHub Copilot files
- `templates/optional/`: specialist add-ons
- `examples/`: placeholder-only example trees
- `docs/`: compatibility, precedence, and install guidance

For live repositories, copy capability folders into `docs/ai/capabilities/` unless your repository already has a better established AI-doc location.

## Important Note About Copilot Prompts

Prompt files are included as optional guidance assets, but support varies by IDE and surface. Treat repo instructions and path instructions as the more stable foundation.

The Copilot adapter intentionally stays lighter than the OpenCode side. Its core workflow roles mirror OpenCode's architect, reviewer, and refactorer concepts, while specialist roles stay on the OpenCode side unless a repository has a proven Copilot-specific need.

If you are new to the kit, start with `docs/ONBOARDING.md`.

See `docs/CAPABILITY-MODEL.md` for the canonical reusable workflow model, `docs/COMPOSITION-RECIPES.md` for common task flows, `docs/EVALUATION.md` for a lightweight quality rubric, and `docs/PROJECT-EXAMPLES.md` for cross-project usage examples.
