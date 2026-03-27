# Project Instructions

## Projects

Stack: PHP ^8.4, Laravel 12, Vue 3, Vite, Tailwind 3, PHPUnit 11

## Laravel rules

- Prefer Laravel conventions over custom abstractions.
- Prefer PHPUnit for tests.
- Prefer Form Requests for HTTP validation.
- Prefer Eloquent scopes and query objects over duplicated query logic.
- Keep controllers thin; move business logic to actions/services where appropriate.
- Use policies/gates for authorization.
- Use factories in tests; keep fixtures minimal.

## Frontend rules

- Use Vue 3 Composition API with `<script setup>`.
- Use TypeScript in Nuxt projects.
- Use Pinia for state management.
- Use Tailwind CSS utility classes; avoid inline styles.
- Prefer `useFetch` / `useAsyncData` for data fetching in Nuxt.

## Bug-fix workflow

1. Reproduce the bug with the smallest automated test.
2. Confirm it fails on the current code.
3. Apply the smallest possible fix.
4. Re-run relevant tests and confirm the reproduction test passes.

## Verification rules

- Use the verification ladder: focused proof first, affected layer tests second, broader repository verification third, build as a smoke check when relevant, and release-safety review only when risk warrants it.
- Treat build success as a smoke check, not proof of runtime correctness.
- State exactly which test or command produced the claimed result.

## Scope of this file

- This file is for repo-wide baseline guidance.
- Keep reusable workflow detail in narrower workflow assets when the repository provides them.
- Use narrower instructions or workflow-specific assets for subsystem-specific behavior.

## Common gotchas

- Do not answer from generic Laravel defaults when repo patterns are more specific.
- Do not expand a bug-fix slice into unrelated cleanup.
- Do not report recommendations as if they were executed evidence.

## Do not

- refactor unrelated code during a bug fix
- weaken assertions to force a pass
- claim success without test evidence
