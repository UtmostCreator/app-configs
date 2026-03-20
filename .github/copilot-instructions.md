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

## Do not

- refactor unrelated code during a bug fix
- weaken assertions to force a pass
- claim success without test evidence
