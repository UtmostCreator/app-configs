# Acme Orders Project Context

## Project Shape

- Project type: `backend service`
- Summary: `Order, payment, and fulfillment APIs for Acme's commerce platform.`
- Primary language: `TypeScript`
- Primary runtime: `Node.js`
- Supported targets: `api, worker`
- Active paths: `src/orders, src/payments, src/fulfillment, tests/integration`
- Inactive paths: `legacy/, prototype/`

## Architecture

- Primary entrypoints: `src/server.ts, src/orders/routes.ts, src/payments/payment-service.ts`
- Architecture notes: `HTTP routes call service modules; payment operations must remain idempotent and audit-safe.`
- Risk areas: `payments, refund flows, webhook handlers, schema migrations`

## Verification

- Main verification command: `pnpm test:unit && pnpm test:integration --filter orders`
- Main build command: `pnpm build`
- Main test command: `pnpm test:unit`
- Preferred narrow-first verification pattern: `prefer route or service tests before broader integration or full build checks`

## Approval Boundaries

- `schema changes, payment auth changes, dependency upgrades, secret/env edits`
