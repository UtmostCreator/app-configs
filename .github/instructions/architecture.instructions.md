---
applyTo: ".ai-install-manifest.json,.copilot-logs,.editorconfig,.eslintrc.json,.github,.gitignore,.husky,.lefthook.yml,.markdownlint-cli2.yaml,.opencode,.prettierrc.json,.repomixignore,.schemas,.shellcheckrc,.stylelintrc.json,AGENTS.md,CLAUDE.md,CONTRIBUTING.md,README.md,SECURITY.md,SUPPORT.md,composer.json,composer.lock,configs,docs,justfile,llms.txt,packages,phpunit.xml.dist,policies,reference,scripts,tests,tools"
description: "Architecture, ownership, and layering guidance"
---

# Architecture Rules

- Read current code before proposing structural changes.
- Keep logic with its existing owner unless there is a clear architectural reason to move it.
- Prefer extending current patterns before introducing parallel abstractions.
- Ask for approval before making: `secrets, destructive changes, auth or billing changes`
- Approval means a human approver can explain each changed section well enough to own the merge.
- For migrations that drop, rename, or restructure existing data, use expand-contract.
