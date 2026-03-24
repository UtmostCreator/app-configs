# Install For OpenCode

## Minimum Copy Set

Copy these files into your target repository:

- `templates/core/AGENTS.template.md` -> `AGENTS.md`
- `templates/core/project-stack.template.md`
- `templates/opencode/agents/architect.md`
- `templates/opencode/agents/reviewer.md`
- `templates/opencode/agents/refactorer.md`
- `templates/opencode/commands/review-diff.md`
- `templates/opencode/commands/verify.md`
- `templates/opencode/skills/project-stack/SKILL.md`

## Setup Steps

1. Rename `AGENTS.template.md` to `AGENTS.md`.
2. Copy the `.opencode/` folders into the repository.
3. Replace placeholders across all copied files.
4. Remove sections that do not fit the repository.
5. Search for unresolved `<PLACEHOLDER_NAME>` tokens and remove project-specific leaks.

## Suggested First Test

- Ask the reviewer to inspect a small diff.
- Ask the architect for a plan on a medium-sized task.
- Run the verify command text manually and confirm the commands make sense for the repo.
- Confirm the plan includes risk level (`low` | `medium` | `high`).
- For `medium` and `high` risk, confirm rollback plan, observability signal, and feature-flag posture are present.

## Optional Delivery Pack

If your team wants explicit per-slice planning for non-trivial work, copy:

- `templates/optional/delivery/README.md`
- `templates/optional/delivery/slice-card.template.md`

## Add Optional Packs Later

Only copy optional OpenCode agents when the repository needs specialized workflows such as upgrades, docs, UI work, or build auditing.
