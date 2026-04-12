# Acme Commerce Monorepo - Repository Instructions

## Project Summary

- Project: `Acme Commerce Monorepo`
- Type: `monorepo`
- Summary: `Web storefront, orders API, and background worker for commerce flows.`
- Primary language: `TypeScript`
- Primary runtime: `multiple`
- Active paths: `apps/web, services/orders-api, services/order-worker, packages/contracts`
- Inactive or legacy paths: `legacy-admin/, prototype/`
- Primary entrypoints: `apps/web/src/app/router.tsx, services/orders-api/src/server.ts, packages/contracts/src/orders.ts`

## Default Workflow

- `research when owner is unclear -> plan for multi-step or risky work -> implement bounded slice -> review in fresh context -> verify with evidence -> add release audit for medium or high risk`

## Approval Required Before Proceeding

- contract changes, schema changes, payment or auth changes, dependency upgrades, production config edits

## Capability Map

- Core project context file: `docs/ai/project-context.md`
- Available capabilities: `project-context, verify-change, review-diff, bug-regression, release-safety, dependency-upgrade`
- Capability composition notes: `use project-context first when a task spans web, api, or contracts; use release-safety when contracts or rollout posture matter`
