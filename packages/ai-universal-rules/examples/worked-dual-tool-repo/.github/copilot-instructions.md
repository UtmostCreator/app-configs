# Repository Instructions For Acme Commerce Monorepo

- Project: `Acme Commerce Monorepo`
- Type: `monorepo`
- Summary: `Web storefront, orders API, and background worker for commerce flows.`
- Active paths: `apps/web, services/orders-api, services/order-worker, packages/contracts`
- Avoid by default: `legacy-admin/, prototype/`
- Project context file: `docs/ai/project-context.md`
- Capability folders available: `project-context, verify-change, review-diff, bug-regression, release-safety, dependency-upgrade`

## Working Style

- Prefer the smallest safe change.
- Keep this file policy-focused and route repeated jobs through prompts or agents.
- Ask for approval before shared-contract, schema, auth, billing, or dependency changes.
- Say `unknown` instead of guessing.

## Quality Bar

- Use package-local proof before root verification.
- Treat root build success as smoke evidence.
- For `medium` and `high` risk changes, define rollback or disable path and post-change signal.
