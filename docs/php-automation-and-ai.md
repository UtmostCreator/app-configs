# PHP Test Automation + AI Assist Base

## Baseline automation added

The `justfile` now provides starter commands:
- `just php-pint`
- `just php-pint-test`
- `just php-unit`
- `just php-feature`
- `just php-test`
- `just php-stan`

These are safe placeholders: if a binary is missing, the command explains what is missing.

## What to add next (highest ROI)

1. **Coverage + mutation foundation**
   - Add Xdebug/PCOV coverage command.
   - Add Infection PHP (mutation testing) for critical modules.

2. **Faster feedback loop**
   - Add changed-files-only test runner script.
   - Add parallel test execution defaults.

3. **Golden feature test templates**
   - create reusable test stubs for:
     - auth endpoints
     - validation errors
     - policy/permission checks
     - queue/job behavior

4. **Quality gates**
   - pre-commit: pint + php -l + secret scan.
   - CI: full phpunit + phpstan + coverage threshold.

## AI sub-agent / skill ideas

You can create a dedicated skill/agent set for PHP testing:

- **agent: php-test-writer**
  - input: changed files + routes/controllers/services
  - output: unit + feature tests + edge cases

- **agent: php-refactor-safety**
  - output: risk map, required regression tests, rollback notes

- **agent: php-failing-test-fixer**
  - input: failing test logs
  - output: minimal fix candidates + explanation

### Minimal workflow

1. `just ai-review` for test plan.
2. AI agent drafts tests for changed code.
3. `just php-unit` and `just php-feature`.
4. AI agent summarizes failures and suggests minimal fix.
5. rerun tests + commit.
