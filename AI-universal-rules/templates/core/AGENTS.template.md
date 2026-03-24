# <PROJECT_NAME> - Repository Instructions

## Project Summary

- Project: `<PROJECT_NAME>`
- Type: `<PROJECT_TYPE>`
- Summary: `<PROJECT_SUMMARY>`
- Primary language: `<PRIMARY_LANGUAGE>`
- Primary runtime: `<PRIMARY_RUNTIME>`
- Active paths: `<ACTIVE_PATHS>`
- Inactive or legacy paths: `<INACTIVE_PATHS>`
- Primary entrypoints: `<PRIMARY_ENTRYPOINTS>`

## Default Workflow

Use this default workflow unless the task is clearly trivial:

- `plan -> architect for medium or large changes -> implement -> review -> refactor only when structure is the problem -> verify when behavior changed`

Workflow rules:

- Prefer the smallest safe change.
- For non-trivial work, classify risk as `low`, `medium`, or `high` to choose review and verification depth.
- Ground decisions in active code and configuration, not aspiration.
- Do not invent systems, services, persistence layers, or infrastructure that are not present.
- Escalate when ambiguity would change architecture, persistence shape, public interfaces, dependency surface, security posture, or rollout risk.
- If a slice grows beyond roughly 6 files or 300-500 changed lines, pause and confirm it is still one bounded outcome.
- Stop repeated review or fix loops after three iterations and surface unresolved tradeoffs clearly.

## Approval Required Before Proceeding

Ask for approval before making:

- `<APPROVAL_REQUIRED_CHANGES>`
- A human approver must be able to explain each changed section well enough to own the merge.

## Core Engineering Rules

- Keep behavior explicit.
- Prefer existing repository patterns over introducing new ones.
- Keep orchestration and state ownership out of presentation code when the repository already separates those concerns.
- Avoid unrelated refactors during bug fixes.
- Do not modify inactive or legacy paths unless the task explicitly requires it.

## Read This First

Inspect the current implementation before making architectural or behavioral changes:

- `<PRIMARY_ENTRYPOINTS>`

## Architecture Notes

`<ARCHITECTURE_NOTES>`

## Risk Areas

- `<RISK_AREAS>`

## Release and Migration Safety

- For `medium` and `high` risk changes, define rollback or disable path before implementation.
- For `medium` and `high` risk changes, define what observable signal confirms success after deployment.
- Use a feature flag for `medium` or `high` risk behavior changes when practical.
- For additive-only migrations, document rollback posture and proceed.
- For migrations that drop, rename, or restructure existing data, use an expand-contract strategy.
- Plan large backfills separately from schema mutation when data volume or runtime impact is significant.

## Prototype Lane

- Exploratory code may be created in prototype paths.
- Prototype code must not be merged directly into production paths.
- Any promoted prototype must be respecified as a normal bounded slice and pass the standard workflow.

## Testing Rules

- Prefer the lowest test level that proves the behavior.
- Add or update focused tests when behavior changes.
- Keep tests deterministic where possible.
- Do not weaken tests to make changes pass.

## Verification Rules

- Primary verification command: `<PRIMARY_VERIFY_COMMAND>`
- Primary build command: `<PRIMARY_BUILD_COMMAND>`
- Primary test command: `<PRIMARY_TEST_COMMAND>`
- Do not claim verification you did not run.
- Treat build success as a smoke check unless the project defines otherwise.

## Review Priorities

- `<REVIEW_PRIORITIES>`

## Documentation Rules

- Distinguish current implementation from future ideas.
- Prefer code-verified statements over planning assumptions.
- Use exact commands that work in the repository.

## Do Not

- Do not assume a stack, framework, or deployment target that is not confirmed.
- Do not silently widen permissions, scope, or behavior.
- Do not delete files or reshape the module layout without approval.
