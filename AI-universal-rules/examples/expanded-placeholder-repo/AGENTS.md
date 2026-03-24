# <PROJECT_NAME> - Expanded Placeholder Example

This example keeps the richer structure of a filled repository-instructions file while staying placeholder-only.

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

- `plan -> architect for medium or large changes -> implement -> review -> verify when behavior changed`
- For non-trivial work, classify risk as `low`, `medium`, or `high`.
- If a slice grows beyond roughly 6 files or 300-500 changed lines, pause and confirm it is still one bounded outcome.

## Approval Required Before Proceeding

- `<APPROVAL_REQUIRED_CHANGES>`
- A human approver must be able to explain each changed section well enough to own the merge.

## Release and Migration Safety

- For `medium` and `high` risk changes, define rollback or disable path before implementation.
- For `medium` and `high` risk changes, define what observable signal confirms success after deployment.
- Use a feature flag for `medium` or `high` risk behavior changes when practical.
- For additive-only migrations, document rollback posture and proceed.
- For migrations that drop, rename, or restructure existing data, use expand-contract.

## Prototype Lane

- Prototype code must not be merged directly into production paths.
- Any promoted prototype must be respecified as a normal bounded slice and pass the standard workflow.

## Verification Rules

- Primary verification command: `<PRIMARY_VERIFY_COMMAND>`
- Primary build command: `<PRIMARY_BUILD_COMMAND>`
- Primary test command: `<PRIMARY_TEST_COMMAND>`

## Review Priorities

- `<REVIEW_PRIORITIES>`
