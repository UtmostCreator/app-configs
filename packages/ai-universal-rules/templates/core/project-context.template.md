# <PROJECT_NAME> Project Context

Use this file as durable project context for instructions, agents, prompts, and capabilities.

## Project Shape

- Project type: `<PROJECT_TYPE>`
- Summary: `<PROJECT_SUMMARY>`
- Primary language: `<PRIMARY_LANGUAGE>`
- Primary runtime: `<PRIMARY_RUNTIME>`
- Supported targets: `<TARGET_PLATFORMS>`
- Active paths: `<ACTIVE_PATHS>`
- Inactive paths: `<INACTIVE_PATHS>`

## Architecture

- Primary entrypoints: `<PRIMARY_ENTRYPOINTS>`
- Architecture notes: `<ARCHITECTURE_NOTES>`
- Risk areas: `<RISK_AREAS>`

## Verification

- Main verification command: `<PRIMARY_VERIFY_COMMAND>`
- Main build command: `<PRIMARY_BUILD_COMMAND>`
- Main test command: `<PRIMARY_TEST_COMMAND>`
- Preferred narrow-first verification pattern: `<NARROW_VERIFY_GUIDANCE>`

## Review Focus

- `<REVIEW_PRIORITIES>`

## Change Hygiene

- Before changing code, config, docs, or workflow logic, search for similar existing patterns in the touched area and nearby owners and report the closest overlap as a percentage.
- If overlap is roughly `>=75%`, flag reuse or replacement immediately and recommend updating the existing pattern instead of adding a duplicate.
- After completing the change, run a touched-scope stale sweep on edited files and nearby references for stale methods, stale data assumptions, stale commands/paths, outdated docs, unresolved placeholders, and generated-output drift.

## Approval Boundaries

- `<APPROVAL_REQUIRED_CHANGES>`

## Workflow Notes

- Capability composition hints: `<CAPABILITY_COMPOSITION_NOTES>`
- Release safety notes: `<RELEASE_SAFETY_NOTES>`
- Known gotcha themes: `<KNOWN_GOTCHA_THEMES>`
