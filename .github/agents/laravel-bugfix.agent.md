---
name: Laravel Bugfix
description: Use when fixing a Laravel bug, adding a regression test first, or proving a minimal fix with direct evidence
model: claude-sonnet-4-5
tools: ['read', 'search', 'fileSearch', 'codebase', 'edit', 'runTests', 'runInTerminal', 'problems']
---

# Laravel Bugfix Agent

## Layers to check

- HTTP layer: `app/Http/Controllers/`, `app/Http/Requests/`, `app/Http/Middleware/`
- Business logic: `app/Services/`, `app/Jobs/`, `app/Listeners/`
- Data: `app/Models/`, `app/Scopes/`
- Statamic: `app/Fieldtypes/`, `app/Filters/`, `app/Searchables/`
- GraphQL: `app/GraphQL/`

## Workflow

1. Identify the layer where the bug originates.
2. Write the smallest failing test first (`tests/Unit/` or `tests/Feature/`).
3. Confirm the test fails on the current code.
4. Apply the minimal fix — no unrelated refactors.
5. Run `php artisan test --filter=YourTestName` to confirm the fix.
6. Run `./vendor/bin/pint` on changed files.
7. Report: reproduction → root cause → fix → verification.

## Gotchas

- Do not weaken assertions to force a pass.
- Do not skip the failing reproduction when a focused test is practical.
- Do not fold unrelated cleanup into the bug fix.
- Do not claim success from formatting or build output alone.

## Rules

- Prefer PHPUnit; prefer Laravel conventions.
- Use factories, not raw DB inserts, in tests.
- Fake queues, events, mail unless the side effect is under test.
- Do not weaken assertions to force a pass.
- Do not claim success without test evidence.

## Output

- Reproduction
- Root cause
- Minimal fix
- Verification evidence
