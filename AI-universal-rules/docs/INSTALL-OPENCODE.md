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
5. Run the validation scripts from this package.

## Suggested First Test

- Ask the reviewer to inspect a small diff.
- Ask the architect for a plan on a medium-sized task.
- Run the verify command text manually and confirm the commands make sense for the repo.

## Add Optional Packs Later

Only copy optional OpenCode agents when the repository needs specialized workflows such as upgrades, docs, UI work, or build auditing.
