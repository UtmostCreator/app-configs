# Quickstart

Use this flow when adapting the kit to a real repository.

## 1. Choose Your Target

- OpenCode only
- GitHub Copilot only
- Both tools in the same repository

## 2. Copy The Minimum Starter Set

For OpenCode:

- `templates/core/AGENTS.template.md` -> `AGENTS.md`
- `templates/core/project-stack.template.md`
- `templates/opencode/agents/`
- `templates/opencode/commands/`
- `templates/opencode/skills/project-stack/SKILL.md`

For GitHub Copilot:

- `templates/core/copilot-instructions.template.md` -> `.github/copilot-instructions.md`
- `templates/core/project-stack.template.md`
- `templates/github-copilot/instructions/`
- `templates/github-copilot/agents/`
- `templates/github-copilot/prompts/` when your surface supports prompt files

## 3. Replace Placeholders

Use `PLACEHOLDERS.md` as the source of truth.

Recommended order:

1. Replace required placeholders in core templates.
2. Replace the same values in the tool-specific templates.
3. Remove optional sections that do not fit the repository.

## 4. Validate

Run:

```powershell
python .\AI-universal-rules\tools\validate-placeholders.py .\AI-universal-rules
python .\AI-universal-rules\tools\check-no-project-specific-leaks.py .\AI-universal-rules
```

Add `--deny-term` or `--denylist-file` when you want to scan for project-specific names from source material that should not appear in the shared kit.

## 5. Test In A Toy Repo

- Ask for a code review using the review role
- Ask for a bug fix plan
- Run the verification workflow text
- Confirm the instructions do not imply unsupported tool features

## 6. Add Optional Packs Later

Only add optional agents and prompts when the project really needs them:

- build or dependency specialists
- UI specialists
- upgrade specialists
- docs specialists
- bugfix specialists
