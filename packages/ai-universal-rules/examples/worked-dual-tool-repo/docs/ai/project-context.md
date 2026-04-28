# Acme Commerce Monorepo Project Context

## Project Shape

- Project type: `monorepo`
- Summary: `Web storefront, orders API, and background worker for commerce flows.`
- Primary language: `TypeScript`
- Primary runtime: `multiple`
- Supported targets: `web, api, worker`
- Active paths: `apps/web, services/orders-api, services/order-worker, packages/contracts`
- Inactive paths: `legacy-admin/, prototype/`

## Architecture

- Primary entrypoints: `apps/web/src/app/router.tsx, services/orders-api/src/server.ts, packages/contracts/src/orders.ts`
- Architecture notes: `contracts flow from packages/contracts into both web and api; shared changes need compatibility review before rollout.`
- Risk areas: `checkout, order state transitions, contract changes, worker retries`

## Verification

- Main verification command: `pnpm --filter orders-api test && pnpm --filter web test`
- Main build command: `pnpm build`
- Main test command: `pnpm test`
- Preferred narrow-first verification pattern: `run package-local or path-local tests before root build and cross-package checks`
