# Install Instructions

- Installed at: `2026-04-29T13:36:17+00:00`
- Profile: `dual`
- Packs: ``

## Before Install

1. Run dry-run first.
2. Confirm profile and optional packs.
3. Check required tools for selected packs.

## During Install

- Dry-run: `php tools/ai/ai.php install --profile dual --dry-run`
- Backup: `php tools/ai/ai.php install --backup-only --apply --profile dual`
- Apply: `php tools/ai/ai.php install --apply --profile dual --backup <backup-id>`

## After Install

- Verify: `php tools/ai/ai.php verify --json`
- Resolve placeholders: `php tools/ai/ai.php placeholders --fail`
- Toolchain check: `php tools/ai/ai.php toolchain --with repomix,scc --check`
- Script list: `php tools/ai/ai.php run-script --list`

## Installed Scripts

- none

## Installed Files

