# Install For OpenCode

If you are new to the kit, read `docs/ONBOARDING.md` first.

## Minimum Copy Set

Copy these files into your target repository:

- `templates/core/AGENTS.template.md` -> `AGENTS.md`
- `templates/core/project-context.template.md` -> `docs/ai/project-context.md`
- `templates/capabilities/` -> `docs/ai/capabilities/`
- `templates/opencode/agents/architect.md`
- `templates/opencode/agents/reviewer.md`
- `templates/opencode/agents/refactorer.md`
- `templates/opencode/commands/review-diff.md`
- `templates/opencode/commands/verify.md`
- `templates/opencode/skills/project-context/SKILL.md`
- `templates/opencode/skills/review-diff/SKILL.md`
- `templates/opencode/skills/verify-change/SKILL.md`
- `templates/opencode/skills/bug-regression/SKILL.md`

Useful optional OpenCode skills for broader repos:

- `templates/opencode/skills/release-safety/SKILL.md`
- `templates/opencode/skills/dependency-upgrade/SKILL.md`

## Setup Steps

1. Rename `AGENTS.template.md` to `AGENTS.md`.
2. Copy the project context file to `docs/ai/project-context.md`, copy capability folders to `docs/ai/capabilities/`, and copy the `.opencode/` folders into the repository.
3. Replace placeholders across all copied files.
4. Remove sections that do not fit the repository.
5. Search for unresolved `<PLACEHOLDER_NAME>` tokens and remove project-specific leaks.

## Verification

Follow the verification ladder in `docs/CAPABILITY-MODEL.md`.

## Suggested First Test

- Ask the reviewer to inspect a small diff.
- Ask the architect for a plan on a medium-sized task.
- Use the `project-context` skill on an unfamiliar task and confirm it routes to the right active paths.
- Use the `verify-change` skill on a narrow behavior change and confirm it chooses the smallest relevant command first.
- Confirm verification stays narrow first and does not jump straight to a broad build.
- Confirm the plan includes risk level (`low` | `medium` | `high`).
- For `medium` and `high` risk, confirm rollback plan, observability signal, and feature-flag posture are present.

## Optional Delivery Pack

If your team wants explicit per-slice planning for non-trivial work, copy:

- `templates/optional/delivery/README.md`
- `templates/optional/delivery/slice-card.template.md`

## Add Optional Packs Later

Only copy optional OpenCode agents when the repository needs specialized workflows such as upgrades, docs, UI work, or build auditing.
