# AI Scripts Reference

This document explains installer, validation, generation, and context scripts maintained in this repository.

## Installer Entrypoints

- `php tools/ai/install-ai-kit.php`
  - Canonical installer implementation.
  - Profiles: `minimal|copilot|opencode|dual|guarded`.
  - Flags: `--target`, `--runtime`, `--project-name`, `--dry-run`, `--force`, `--no-base`, `--allow-core-overwrite`.
  - Safety: core base policy files are protected from accidental overwrite unless `--allow-core-overwrite` is explicitly passed.
- `bash tools/ai/install-ai-kit.sh`
  - Thin wrapper that forwards args to `install-ai-kit.php`.
- `bash tools/ai/install-copilot-kit.sh`
  - Legacy compatibility wrapper mapping old Copilot profile names to unified installer profiles.

## Unified AI CLI

- `php tools/ai/ai.php`
  - Unified entrypoint for workflow-control commands.
  - Current commands: `list`, `snapshot`, `freshness`, `budget`, `workflow`, `diff-summary`, `risk`, `verify`, `next`, `rebase-state`, `decision`, `why`, `session-resume`, `commit-msg`, `pr-summary`, `logs`, `env-check`, `file-context`, `orphans`, `auto-fix`, `impact`, `ask`, `estimate`, `conflicts`, `find`, `symbols`, `preflight`, `package-lock`, `package-verify`, `audit-instructions`, `adapter-plan`, `install`, `upgrade`, `adapter-validate`, `rollback`.
  - Writes paired outputs under `docs/ai/generated/` and updates `docs/ai/generated/artifacts.json`.

## Validation And Generation

- `php tools/ai/validate-ai-config.php`
  - Verifies root AI workflow surfaces, references, and policy consistency.
- `php tools/ai/validate-ai-catalog.php`
  - Verifies catalog/manifest integrity.
- `php tools/ai/generate-ai-catalog.php`
  - Regenerates `docs/ai/catalog.md` and package catalog artifacts.
  - Use `--check` in CI or pre-commit verification.
- `php tools/ai/generate-repo-structure.php`
  - Regenerates `docs/ai/generated/repo-structure.{json,csv,md,log}`.
  - Use `--check --with-scc` to enforce drift checks.
- `php tools/ai/export-ai-universal-rules.php`
  - Verifies or exports package release bundles.

## Context Packing Scripts

- `bash scripts/copilot/run-repomix-context.sh <path>`
  - Dependency-checking entrypoint for context packing.
  - Runs `repomix-context-tree.sh all` and validates outputs.
- `bash scripts/copilot/repomix-context-tree.sh <analyze|plan|pack|all|clean|purge> [root]`
  - Tree-based context planner and packer.
  - Requires: `repomix`, `scc`, `jq`.
- `bash scripts/copilot/repomix-scc-router.sh ...`
  - Ranked route planner used by tree-context pipeline.

## Generated Artifacts Maintained By Scripts

- `docs/ai/catalog.md`
- `packages/ai-universal-rules/catalog.json`
- `packages/ai-universal-rules/docs/BROWSE.md`
- `llms.txt`
- `docs/ai/generated/repo-structure.json`
- `docs/ai/generated/repo-structure.csv`
- `docs/ai/generated/repo-structure.md`
- `docs/ai/generated/repo-structure.log`

## Verification Contract

Use this sequence after workflow/tooling changes:

```bash
php tools/ai/validate-ai-config.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
php tools/ai/generate-repo-structure.php --check --with-scc
```

For a one-command baseline, run:

```bash
bash scripts/doctor.sh
```

## Test Coverage

- `tests/php/CliToolsTest.php` validates CLI contracts for core AI tools, including generated-output check mode.
- `tests/php/GenerateRepoStructureTest.php` validates generator behavior and metadata guardrails.
