# Install Instructions

- Installed at: `2026-05-01T00:03:26+00:00`
- Profile: `full-governance`
- Packs: `capabilities-extended-full, hooks-pack, ci-pack, scripts-pack, policy-pack, evidence-pack, adapter-opencode, capabilities-extended-lite, base, setup-docs, capabilities-core`

## Step Chain

1. Step 1 -> Preflight: `php tools/ai/ai.php preflight`
   - Next: Step 2 (`package-verify`)
2. Step 2 -> Package Verify: `php tools/ai/ai.php package-verify`
   - Next: Step 3 (`adapter-plan`)
3. Step 3 -> Adapter Plan: `php tools/ai/ai.php adapter-plan --profile full-governance`
   - Next: Step 4 (`install --dry-run`)
4. Step 4 -> Install Dry-Run: `php tools/ai/ai.php install --profile full-governance --reinstall --dry-run`
   - Next: Step 5 (`install --backup-only`)
5. Step 5 -> Backup: `php tools/ai/ai.php install --backup-only --apply --profile full-governance --reinstall`
   - Next: Step 6 (`install --apply --backup <id>`)
6. Step 6 -> Apply: `php tools/ai/ai.php install --apply --profile full-governance --reinstall --backup <backup-id>`
   - Next: Step 7 (post-install verification sequence)

## Before Install

1. Run dry-run first.
2. Confirm profile and optional packs.
3. Check required tools for selected packs.

## During Install

- Dry-run: `php tools/ai/ai.php install --profile full-governance --reinstall --dry-run`
- Backup: `php tools/ai/ai.php install --backup-only --apply --profile full-governance --reinstall`
- Apply: `php tools/ai/ai.php install --apply --profile full-governance --reinstall --backup <backup-id>`

## After Install

- Verify: `php tools/ai/ai.php verify --json`
- Resolve placeholders: `php tools/ai/ai.php placeholders --fail`
- Toolchain check: `php tools/ai/ai.php toolchain --with repomix,scc --check`
- Required-tools inventory check: `bash scripts/ai/repo-tool-inventory.sh --check`
- Required-tools inventory regenerate: `bash scripts/ai/repo-tool-inventory.sh`
- Mandatory-tools installer dry-run: `bash scripts/ai/install-mandatory-tools.sh --dry-run`
- Script list: `php tools/ai/ai.php run-script --list`

- Repomix analyze: `bash scripts/ai/repomix-context-tree.sh analyze .`
- Advisor analyze/fixes: `php tools/ai/ai.php advisor --all`
- Full-install verifier: `php tools/ai/verify-full-install.php`

Advisor recommendations are strongest after a full OpenCode install and fresh Repomix analysis, because advisor consumes generated repository signals/context artifacts under `docs/ai/generated/`.

OpenCode agent visibility note: agents in `.opencode/agents/` must not be marked `hidden: true` in frontmatter if you expect them in normal agent listings.

## Completion Criteria

- Run `php tools/ai/verify-full-install.php` after the sequence above.
- Completion is `full` only when install, validation, repomix analysis, and advisor checks all pass in order.
- If status is not `full`, follow the script output for ordered remediation steps.

## Installed Scripts

- `repomix-context` -> `scripts/ai/run-repomix-context.sh`
- `repomix-tree` -> `scripts/ai/repomix-context-tree.sh`
- `repomix-scc-router` -> `scripts/ai/repomix-scc-router.sh`
- `pack-context` -> `scripts/ai/pack-context.sh`
- `repo-tool-inventory` -> `scripts/ai/repo-tool-inventory.sh`
- `install-mandatory-tools` -> `scripts/ai/install-mandatory-tools.sh`

## Installed Files

- `.github/workflows/validate-ai-surface.yml`
- `.opencode/agents`
- `.opencode/commands`
- `.opencode/skills`
- `.schemas/evidence-event.schema.json`
- `AGENTS.md`
- `docs/ai/AI-GUARDRAILS.md`
- `docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md`
- `docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md`
- `docs/ai/capabilities/bug-regression`
- `docs/ai/capabilities/dependency-upgrade`
- `docs/ai/capabilities/project-context`
- `docs/ai/capabilities/release-safety`
- `docs/ai/capabilities/review-diff`
- `docs/ai/capabilities/verify-change`
- `docs/ai/command-risk-taxonomy.md`
- `docs/ai/failure-handling.md`
- `docs/ai/hooks.md`
- `docs/ai/mandatory-tools-install.md`
- `docs/ai/project-context.md`
- `docs/ai/repo-required-tools.md`
- `docs/ai/validation.md`
- `scripts/ai/ai-diff-context.sh`
- `scripts/ai/ai-edit.sh`
- `scripts/ai/ai-rollback.sh`
- `scripts/ai/ai-search.sh`
- `scripts/ai/ai-verify.sh`
- `scripts/ai/common.sh`
- `scripts/ai/fd-files.sh`
- `scripts/ai/gh-pr-context.sh`
- `scripts/ai/git-forensics.sh`
- `scripts/ai/install-mandatory-tools.sh`
- `scripts/ai/pack-context.sh`
- `scripts/ai/post-tool-use.sh`
- `scripts/ai/pre-tool-use.sh`
- `scripts/ai/preview-file.sh`
- `scripts/ai/query-usage.sh`
- `scripts/ai/repo-tool-inventory.sh`
- `scripts/ai/repomix-context-tree.sh`
- `scripts/ai/repomix-scc-router.sh`
- `scripts/ai/rg-code.sh`
- `scripts/ai/run-repomix-context.sh`
- `scripts/ai/watch-loop.sh`
- `scripts/hooks/commit-msg.sh`
- `scripts/hooks/pre-commit.sh`
