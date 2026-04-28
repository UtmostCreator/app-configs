# Acme Orders - Repository Instructions

## Project Summary

- Project: `Acme Orders`
- Type: `backend service`
- Summary: `Order, payment, and fulfillment APIs for Acme's commerce platform.`
- Primary language: `TypeScript`
- Primary runtime: `Node.js`
- Active paths: `src/orders, src/payments, src/fulfillment, tests/integration`
- Inactive or legacy paths: `legacy/, prototype/`
- Primary entrypoints: `src/server.ts, src/orders/routes.ts, src/payments/payment-service.ts`

## Default Workflow

- `research when owner is unclear -> plan for multi-step or risky work -> implement bounded slice -> review in fresh context -> verify with evidence -> add release audit for medium or high risk`

Workflow rules:

- Prefer the smallest safe change.
- Keep stable policy here and move procedural depth into capabilities, commands, or staged agents.
- Classify non-trivial work as `low`, `medium`, or `high`.
- Say `unknown` instead of guessing when repository evidence is missing.
- If a slice grows beyond roughly 6 files or 400 changed lines, rescope it.

## Approval Required Before Proceeding

- schema changes, payment authorization changes, dependency upgrades, secret or environment edits
- A human approver must be able to explain each changed section well enough to own the merge.

## Capability Map

- Core project context file: `docs/ai/project-context.md`
- Available capabilities: `project-context, verify-change, review-diff, bug-regression, release-safety`
- Capability composition notes: `bug-regression uses project-context then verify-change; release-safety joins for payment and rollout-sensitive work`

## Verification Rules

- Primary verification command: `pnpm test:unit && pnpm test:integration --filter orders`
- Primary build command: `pnpm build`
- Primary test command: `pnpm test:unit`
- Preferred narrow-first verification pattern: `run package-local or route-level tests before the full integration suite`
- Do not claim verification you did not run.

## Review Priorities

- payment correctness, idempotency, auth boundaries, contract stability, migration safety
