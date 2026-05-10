# Maintenance Install Mode

`maintenance mode` is a temporary, explicit switch that allows full in-repository AI install/upgrade validation while keeping strict default protections.

## Purpose

- unblock policy-gated install workflows in controlled windows
- keep default `ask/deny` posture outside maintenance windows
- allow repository-delivered scripts only
- keep destructive commands blocked

## State File

- path: `.ai-logs/maintenance-mode.json`
- owner tool: `php tools/ai/maintenance-mode.php`
- fields:
  - `enabled` (bool)
  - `reason` (string)
  - `enabled_at_epoch` (int|null)
  - `expires_at_epoch` (int|null)
  - `ttl_seconds` (int|null)
  - `updated_at_epoch` (int)
  - `actor` (string)
  - `warnings` (string[])

## Commands

```bash
php tools/ai/maintenance-mode.php status
php tools/ai/maintenance-mode.php enable --reason "full-governance reinstall" --ttl-seconds 1800
php tools/ai/maintenance-mode.php disable
```

TTL must be between 60 and 14400 seconds.

## Policy Behavior

When maintenance mode is active and unexpired, `scripts/ai/pre-tool-use.sh`:

1. still applies all dangerous-command hard-deny checks
2. allows only repository-delivered scripts and explicit install/verify commands
3. returns `ask` for external `*.sh` script execution
4. falls back to strict default behavior when expired or disabled

## Allowed Installation Workflow (Runbook-aligned)

1. `php tools/ai/ai.php install --profile full-governance --reinstall --dry-run`
2. `php tools/ai/ai.php install --profile full-governance --reinstall --apply`
3. `php tools/ai/validate-ai-config.php`
4. `php tools/ai/validate-install-surface.php`
5. `php tools/ai/validate-ai-catalog.php`
6. `php tools/ai/generate-ai-catalog.php --check`
7. `php tools/ai/verify-full-install.php`
8. `bash scripts/ai/run-repomix-context.sh .`
9. `bash scripts/ai/repomix-context-tree.sh all .`
10. `php tools/ai/ai.php advisor --all`

## Safety Requirements

- always capture `git status --short` before enabling maintenance mode
- run dry-run before apply
- do not run external/non-repo scripts during maintenance windows
- disable mode immediately after install verification finishes
