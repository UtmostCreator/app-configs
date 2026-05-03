# Post Install

- Profile: `copilot`
- Packs: `adapter-copilot, base, setup-docs, capabilities-core`

## How To Use Installed Assets

- Copilot assets: `.github/copilot-instructions.md`, `.github/instructions/`, `.github/agents/`, `.github/prompts/`.

## Commands

- Verify: `php tools/ai/ai.php verify`
- Strict verify: `php tools/ai/ai.php verify --strict`
- Placeholders: `php tools/ai/ai.php placeholders --fail`
- Upgrade preview: `php tools/ai/ai.php upgrade --dry-run`
- Rollback: `php tools/ai/ai.php rollback --backup <backup-id> --apply`

## Hook Wiring

- Hook scripts are installed when `hooks-pack` is selected; wiring remains explicit.
- Wire hooks with: `php tools/ai/ai.php hooks install --driver husky|lefthook|native`.

## Project Configuration Checklist

- Fill project facts and commands in `docs/ai/project-context.md`.
- Confirm risk areas and approval-required changes.
- Confirm active/inactive paths and runtime targets.
