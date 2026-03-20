---
applyTo: '**/*.vue,**/*.ts,**/*.tsx,nuxt.config.ts,composables/**,components/**,pages/**,stores/**'
description: 'Frontend rules for Nuxt 4 and Vue 3 projects'
---

# Frontend Rules

- Use Vue 3 Composition API with `<script setup>`; never use Options API.
- Use TypeScript for all `.ts` and `.vue` files in Nuxt (cms-frontend).
- Use Pinia for state management; keep stores in `stores/`.
- Use Tailwind CSS utility classes; avoid inline styles.
- Prefer `useFetch` and `useAsyncData` for data fetching in Nuxt; avoid raw `fetch` in components.
- Co-locate composable logic in `composables/`; keep components focused on rendering.
- Do not use `vue-router` directly; rely on Nuxt's file-based routing.
