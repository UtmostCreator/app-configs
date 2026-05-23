# AI Generated Files

Files in this directory are auto-generated and **not committed**.

This directory is git-ignored except for this `README.md` and
`sessions/.gitkeep`. Regenerate locally when needed; do not edit any generated
output manually.

## Regenerate

Common generator commands (see `tools/ai/ai.php` for the full list):

- `php tools/ai/ai.php preflight`
- `php tools/ai/ai.php package-verify`
- `php tools/ai/ai.php adapter-plan`
- `php tools/ai/ai.php install --dry-run`
- `php tools/ai/ai.php advisor`
- `php tools/ai/ai.php install-docs --check`
- `php tools/ai/ai.php verify --changed`
- `php tools/ai/ai.php toolchain`
- `php tools/ai/generate-repo-structure.php --with-scc`

## Subdirectories

- `logs/` - timestamped verification logs (ignored).
- `sessions/` - runtime AI session handoff logs (ignored; only `.gitkeep`
  is tracked). See `docs/ai/generated-artifacts.md` for session log
  generators and validator.

## Policy

See `docs/ai/generated-artifacts.md` for the canonical generated-artifact policy.
