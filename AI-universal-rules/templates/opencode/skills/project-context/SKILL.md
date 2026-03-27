---
name: project-context
description: Use when planning or reviewing work in an unfamiliar area, choosing verification depth, or checking approval boundaries before editing
compatibility: opencode
---

## What I Do

I provide durable repository context for `<PROJECT_NAME>` and point to the support files that other workflows should read next.

## When To Use Me

- before architecture decisions in unfamiliar areas
- before implementation when multiple active paths could own the change
- before review or verification when risk or ownership is unclear
- when another skill needs repository facts first

## Do Not Use Me For

- purely general coding questions with no repository context
- trivial edits where the owner and verification path are already obvious

## Read Alongside

- `docs/ai/capabilities/project-context/CAPABILITY.md`
- `docs/ai/capabilities/project-context/gotchas.md`
- `docs/ai/capabilities/project-context/examples.md`

## Project Shape

- Project type: `<PROJECT_TYPE>`
- Summary: `<PROJECT_SUMMARY>`
- Primary language: `<PRIMARY_LANGUAGE>`
- Primary runtime: `<PRIMARY_RUNTIME>`
- Active paths: `<ACTIVE_PATHS>`
- Inactive paths: `<INACTIVE_PATHS>`
- Targets: `<TARGET_PLATFORMS>`

## Architecture Notes

- Primary entrypoints: `<PRIMARY_ENTRYPOINTS>`
- Notes: `<ARCHITECTURE_NOTES>`
- Risk areas: `<RISK_AREAS>`

## Verification Expectations

- Main verification command: `<PRIMARY_VERIFY_COMMAND>`
- Main build command: `<PRIMARY_BUILD_COMMAND>`
- Main test command: `<PRIMARY_TEST_COMMAND>`
- Preferred narrow-first pattern: `<NARROW_VERIFY_GUIDANCE>`

## Review Priorities

- `<REVIEW_PRIORITIES>`

## Approval Boundaries

- `<APPROVAL_REQUIRED_CHANGES>`

## Common Gotchas

- `<KNOWN_GOTCHA_THEMES>`
