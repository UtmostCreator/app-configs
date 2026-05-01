# Full Install Validation

- Status: `failed`
- Generated at: `2026-04-30T23:59:34+00:00`
- Profile: `full-governance`
- Mode: `safe-merge`
- Apply run: `yes`
- Smoke mode: `no`
- Release gate: `no`
- Include phpunit: `no`
- Include deep verify: `no`
- Timeout: `600s`
- Retries: `1`
- Backup ID: `install-20260430-235938`

## Stages

- `preflight` => `ok`
- `package-verify` => `failed`
- `adapter-plan` => `ok`
- `install-dry-run` => `ok`
- `install-backup-only` => `ok`
- `install-apply` => `failed`
- `bash-lint-all` => `ok`
- `php-lint-all` => `ok`
- `json-parse-all` => `failed`
- `yaml-parse-all` => `ok`
- `run-script-list` => `ok`
- `run-script-dry-run-all` => `ok`
- `validate-install-surface` => `ok`
- `validate-ai-config` => `ok`
- `validate-ai-catalog` => `ok`
- `generate-ai-catalog-check` => `ok`
- `generate-repo-structure-check` => `ok`
- `validate-generated-artifacts` => `ok`
- `verify-json` => `ok`
- `verify-full-install` => `ok`
- `phpunit` => `ok`

## Failures

- `package-verify`: required stage failed
- `install-apply`: required stage failed
- `json-parse-all`: json parse failures found

## Inventory

- Shell files: `55`
- PHP files: `61`
- JSON files: `91`
- YAML files: `7`
- Markdown files: `461`
- SCC enabled for shell inventory: `yes`

## Cancellation

- Create `docs/ai/generated/full-install-validation.cancel` to request cancellation during long-running stages.\n