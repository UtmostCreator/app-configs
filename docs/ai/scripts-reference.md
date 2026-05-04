# AI Scripts Reference

This document explains installer, validation, generation, and context scripts maintained in this repository.

For the Copilot-approved terminal subset, use `docs/ai/script-registry.md` and `docs/ai/script-registry.json` as the tighter allowlist on top of this broader reference.

## Installer Entrypoints

- `php tools/ai/install-ai-kit.php`
  - Canonical installer implementation.
  - Profiles: `minimal|copilot|opencode|dual|guarded|accelerated|full-governance|docs-reference|custom`.
  - Selective flags: `--with`, `--without`, `--all-features`, `--run-after-install`, `--toolchain-check`, `--toolchain-install-plan`, `--toolchain-apply`, `--verify-after`.
  - Core flags: `--target`, `--runtime`, `--project-name`, `--dry-run`, `--force`, `--no-base`, `--allow-core-overwrite`, `--mode`, `--dependency-mode`, `--hook-driver`.
  - Safety: core base policy files are protected from accidental overwrite unless `--allow-core-overwrite` is explicitly passed.
- `bash tools/ai/install-ai-kit.sh`
  - Thin wrapper that forwards args to `install-ai-kit.php`.
- `bash tools/ai/install-copilot-kit.sh`
  - Legacy compatibility wrapper mapping old Copilot profile names to unified installer profiles.
- `bash tools/ai/install-opencode-kit.sh`
  - Compatibility wrapper mapping OpenCode-only installs to unified installer profiles.

For ordered installation recipes and selective pack examples, use `docs/ai/install-order.md`.

## Unified AI CLI

- `php tools/ai/ai.php`
  - Unified entrypoint for workflow-control commands.
  - Current commands: `list`, `snapshot`, `freshness`, `budget`, `workflow`, `diff-summary`, `risk`, `verify`, `next`, `rebase-state`, `decision`, `why`, `session-resume`, `commit-msg`, `pr-summary`, `logs`, `env-check`, `file-context`, `orphans`, `auto-fix`, `impact`, `ask`, `estimate`, `conflicts`, `find`, `symbols`, `preflight`, `package-lock`, `package-verify`, `audit-instructions`, `adapter-plan`, `plan`, `install`, `upgrade`, `adapter-validate`, `rollback`, `version`, `packs`, `placeholders`, `hooks`, `toolchain`, `run-script`, `install-docs`, `advisor`.
  - Writes paired outputs under `docs/ai/generated/` and updates `docs/ai/generated/artifacts.json`.
  - Wizard entrypoint: `php tools/ai/ai.php install --wizard`.
  - Toolchain helper: `php tools/ai/ai.php toolchain --with repomix,scc --install-plan`.
  - Script runner: `php tools/ai/ai.php run-script --list` then `php tools/ai/ai.php run-script repomix-context --dry-run`.
  - Recommended analysis path before final verification: run Repomix context analysis, then advisor.
  - Repomix-first: `bash scripts/ai/repomix-context-tree.sh analyze .` (or `bash scripts/ai/repomix-context-tree.sh analyze .`).
  - Advisor pass: `php tools/ai/ai.php advisor --all`.
  - Advisor uses generated repository signals and context artifacts (`docs/ai/generated/project-signals.json`, `docs/ai/generated/advisor-context.md`) to provide deterministic fix suggestions.
  - Install docs generator: `php tools/ai/ai.php install-docs --write` and drift check via `php tools/ai/ai.php install-docs --check`.
  - Install-over-existing-repo flow: `php tools/ai/ai.php install --profile full-governance --reinstall --dry-run`, then `--apply` once the plan is correct.
  - Compatibility contract: existing command names remain supported while successor aliases are introduced.

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
- `php tools/ai/verify-full-install.php`
  - Runs the ordered full-install verification chain (preflight -> package verify -> plan -> dry-run -> validation -> repomix -> advisor -> verify).
  - Writes `docs/ai/generated/full-install-verify.json` and `docs/ai/generated/full-install-verify.md`.
  - Reports whether install state is `full` or `partial`, which steps ran, and ordered remediation steps.
- `php tools/ai/full-install-validation.php`
  - One-command 0-100 validation runner for install, verification, inventory, linting, and tests.
  - Includes watchdog controls: timeout, idle-timeout, heartbeat logs, retry policy, and cancellation flag.
  - Writes `docs/ai/generated/full-install-validation.{json,md,log}`.
  - Fast default excludes the heaviest gates (`phpunit`, deep full-install verify) unless explicitly enabled.
  - Use `--release-gate` for major releases to enable heavy gates.
  - Optional flags: `--include-phpunit`, `--include-deep-verify`.
  - Smoke mode example: `php tools/ai/full-install-validation.php --smoke --with-scc --timeout-sec=300 --idle-timeout-sec=120 --heartbeat-sec=5 --clear-cancel`.
  - Full mode example: `php tools/ai/full-install-validation.php --profile=full-governance --mode=safe-merge --with-scc --apply --timeout-sec=900 --idle-timeout-sec=300 --heartbeat-sec=5 --retries=1 --clear-cancel`.
  - Release-gate example: `php tools/ai/full-install-validation.php --profile=full-governance --mode=safe-merge --with-scc --apply --release-gate --timeout-sec=900 --idle-timeout-sec=300 --heartbeat-sec=5 --retries=1 --clear-cancel`.
- `php tools/ai/export-ai-universal-rules.php`
  - Verifies or exports package release bundles.

## Context Packing Scripts

- Source scripts in this repository are under `scripts/ai/`.
- Installed scripts-pack targets are written to `scripts/ai/` by installer exports.

- `bash scripts/ai/run-repomix-context.sh <path>`
  - Dependency-checking entrypoint for context packing.
  - Runs `repomix-context-tree.sh all` and validates outputs.
- `bash scripts/ai/repomix-context-tree.sh <analyze|plan|pack|all|clean|purge> [root]`
  - Tree-based context planner and packer.
  - Requires: `repomix`, `scc`, `jq`.
- `bash scripts/ai/repomix-scc-router.sh ...`
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
