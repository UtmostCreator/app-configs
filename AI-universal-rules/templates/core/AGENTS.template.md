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

- `research when the owner is unclear -> plan for multi-step or risky work -> implement the bounded slice -> review in fresh context -> verify with evidence -> add release audit for medium or high risk`

Workflow rules:

- Prefer the smallest safe change.
- Keep stable policy here and move procedural depth into capabilities, prompts, commands, or staged agents.
- For non-trivial work, classify risk as `low`, `medium`, or `high` to choose review and verification depth.
- Ground decisions in active code and configuration, not aspiration.
- Do not invent systems, services, persistence layers, or infrastructure that are not present.
- Escalate when ambiguity would change architecture, persistence shape, public interfaces, dependency surface, security posture, or rollout risk.
- Say `unknown` when the repository does not prove something.
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

## Capability Map

- Core project context file: `<PROJECT_CONTEXT_PATH>`
- Available capabilities: `<AVAILABLE_CAPABILITIES>`
- Capability composition notes: `<CAPABILITY_COMPOSITION_NOTES>`
- Prefer capability folders for reusable workflow knowledge; keep this file focused on baseline policy.

## Entry Point Rules

- Use prompt files or commands for recurring one-off tasks.
- Use staged agents when fresh context, tool boundaries, or handoffs improve safety.
- Use capability folders or skills for deeper optional procedures.
- Do not turn this file into the only bug-fix, release, or migration workflow definition.

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
- Preferred narrow-first verification pattern: `<NARROW_VERIFY_GUIDANCE>`
- Verification ladder: focused proof first -> affected layer tests second -> broader repository verification third -> build as a smoke check when relevant -> release-safety review only when risk warrants it.
- Do not claim verification you did not run.
- Treat build success as a smoke check unless the project defines otherwise.

## Evidence Expectations

- State which command or check produced the claim.
- Separate direct evidence from inference.
- For behavior changes, name the focused test, flow, or assertion that proves the result.
- For `medium` and `high` risk work, state rollback path and success signal alongside verification.
- Do not report recommendations, assumptions, or unrun checks as completed work.

## Review Priorities

- `<REVIEW_PRIORITIES>`

## Common Gotchas

- `<KNOWN_GOTCHA_THEMES>`
- Capture recurring failure modes in capability `gotchas.md` files instead of bloating global policy.

## Documentation Rules

- Distinguish current implementation from future ideas.
- Prefer code-verified statements over planning assumptions.
- Use exact commands that work in the repository.
- Keep reusable workflow guidance in capability support files with examples and checklists.

## Do Not

- Do not assume a stack, framework, or deployment target that is not confirmed.
- Do not silently widen permissions, scope, or behavior.
- Do not delete files or reshape the module layout without approval.
- Do not treat always-on instructions as a replacement for task entry points, staged agents, or enforcement hooks.
