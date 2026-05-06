# Full Install Verify

- Status: `partial`
- Generated at: `2026-05-06T01:53:02+00:00`

## Executed Steps

- Step 1 (`preflight`): `"C:\xampp\php\php.exe" tools/ai/ai.php preflight` -> exit `0`, artifact status `ok`
  - Goal: Installer prerequisites are ready.
- Step 2 (`package-verify`): `"C:\xampp\php\php.exe" tools/ai/ai.php package-verify` -> exit `1`, artifact status `failed`
  - Goal: Template package lock is valid.
- Step 3 (`adapter-plan`): `"C:\xampp\php\php.exe" tools/ai/ai.php adapter-plan --profile full-governance --mode safe-merge --force --allow-core-overwrite --reinstall` -> exit `0`, artifact status `ok`
  - Goal: Install plan is deterministic and conflict-aware.
- Step 4 (`install-dry-run`): `"C:\xampp\php\php.exe" tools/ai/ai.php install --profile full-governance --mode safe-merge --force --allow-core-overwrite --reinstall --dry-run` -> exit `0`, artifact status `ok`
  - Goal: Install workflow is planned before apply.
- Step 5 (`validate-config`): `"C:\xampp\php\php.exe" tools/ai/validate-ai-config.php` -> exit `0`, artifact status `not-applicable`
  - Goal: AI config references and workflow checks are valid.
- Step 6 (`validate-catalog`): `"C:\xampp\php\php.exe" tools/ai/validate-ai-catalog.php` -> exit `0`, artifact status `not-applicable`
  - Goal: Catalog metadata is consistent.
- Step 7 (`catalog-check`): `"C:\xampp\php\php.exe" tools/ai/generate-ai-catalog.php --check` -> exit `1`, artifact status `not-applicable`
  - Goal: Catalog outputs are up to date.
- Step 8 (`repomix-analyze`): `bash scripts/ai/repomix-context-tree.sh analyze .` -> exit `0`, artifact status `unknown`
  - Goal: Repository structure/context signals are generated.
- Step 9 (`advisor-all`): `"C:\xampp\php\php.exe" tools/ai/ai.php advisor --all` -> exit `0`, artifact status `ok`
  - Goal: Advisor analyzes repo and suggests fixes.
- Step 10 (`verify-changed`): `"C:\xampp\php\php.exe" tools/ai/ai.php verify --changed` -> exit `2`, artifact status `failed`
  - Goal: Changed-scope verification summary is current.

## Recommended Next Steps

- 1) Re-run failed step(s) in listed order.
- 2) If advisor is blocked, review docs/ai/generated/advisor-secret-findings.json.
- 3) Re-run: php tools/ai/ai.php verify --changed.
