# Quickstart

Use this flow when adapting the kit to a real repository.

If you are new to the kit, read `docs/ONBOARDING.md` first.

## 1. Choose Your Target

- OpenCode only
- GitHub Copilot only
- Both tools in the same repository

## 2. Copy The Minimum Starter Set

For OpenCode:

- `templates/core/AGENTS.template.md` -> `AGENTS.md`
- `templates/core/project-context.template.md` -> `docs/ai/project-context.md`
- `templates/capabilities/` -> `docs/ai/capabilities/`
- `templates/opencode/agents/`
- `templates/opencode/commands/`
- `templates/opencode/skills/`

For GitHub Copilot:

- `templates/core/copilot-instructions.template.md` -> `.github/copilot-instructions.md`
- `templates/core/project-context.template.md` -> `docs/ai/project-context.md`
- `templates/capabilities/` -> `docs/ai/capabilities/`
- `templates/github-copilot/instructions/`
- `templates/github-copilot/agents/`
- `templates/github-copilot/prompts/` when your surface supports prompt files

## 2a. Minimum Base Install

For most repositories, start with:

- `docs/ai/capabilities/verify-change/`
- `docs/ai/capabilities/review-diff/`
- `docs/ai/project-context.md`
- `docs/ai/capabilities/project-context/`

Add when the repository actually needs them:

- `docs/ai/capabilities/bug-regression/`
- `docs/ai/capabilities/release-safety/`
- `docs/ai/capabilities/dependency-upgrade/`

See `docs/COMPOSITION-RECIPES.md` for common task-to-capability flows.

## 3. Replace Placeholders

Use `PLACEHOLDERS.md` as the source of truth.

Recommended order:

1. Replace required placeholders in core templates.
2. Replace the same values in the capability folders.
3. Replace the same values in the tool-specific templates.
4. Remove optional sections that do not fit the repository.

## 4. Validate

Run a placeholder and leak check before rollout:

1. Search for unresolved `<PLACEHOLDER_NAME>` tokens.
2. Search for project-specific names that should not exist in shared templates.
3. If your team keeps local validation scripts, run them here.

## 5. Test In A Toy Repo

- Ask for a code review using the review role
- Ask for a bug fix plan
- Use a capability on a realistic task and confirm the trigger description matches the request
- Confirm the verification ladder stays narrow first: focused proof -> affected layer tests -> broader repo verification -> build smoke check when relevant -> release-safety review only when risk warrants it
- Confirm the instructions do not imply unsupported tool features
- For a non-trivial sample task, classify risk as `low`, `medium`, or `high`
- For `medium` and `high` risk, confirm rollback plan, observability signal, and feature-flag posture are stated

## 6. Add Optional Packs Later

Only add optional agents and prompts when the project really needs them:

- build or dependency specialists
- UI specialists
- upgrade specialists
- docs specialists
- bugfix specialists
- delivery slice-card template for non-trivial work
