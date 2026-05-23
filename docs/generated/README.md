# Generated Files

Files in this directory are auto-generated and **not committed**.

This directory is git-ignored except for this `README.md`. Regenerate locally when
needed; do not edit any generated output manually.

## Regenerate

- Repository structure: `php tools/ai/generate-repo-structure.php --with-scc`
- AI workflow outputs: `php tools/ai/ai.php <command>` (see `tools/ai/ai.php`)

## Check freshness

- `php tools/ai/generate-repo-structure.php --check --with-scc`
- `php tools/ai/ai.php <command>` writes paired `.json` / `.md` outputs here.

## Policy

See `docs/ai/generated-artifacts.md` for the canonical generated-artifact policy.
