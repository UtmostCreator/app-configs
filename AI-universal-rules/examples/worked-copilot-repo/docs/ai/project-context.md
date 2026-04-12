# Acme Web Project Context

- Project type: `web app`
- Summary: `Customer-facing storefront and account portal.`
- Primary language: `TypeScript`
- Primary runtime: `browser + Node.js`
- Active paths: `apps/web, packages/ui, packages/api-client`
- Inactive paths: `legacy-web/`
- Primary entrypoints: `apps/web/src/app/router.tsx, apps/web/src/features/checkout, packages/api-client/src/index.ts`
- Main verification command: `pnpm --filter web test && pnpm --filter web build`
- Main build command: `pnpm --filter web build`
- Main test command: `pnpm --filter web test`
