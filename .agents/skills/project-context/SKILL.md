---
name: project-context
description: Use when entering an unfamiliar repository area before planning, reviewing, or editing; identify ownership, boundaries, risks, and appropriate verification depth.
---

## What I Do

I provide durable repository context for `<PROJECT_NAME>` and point to the support files that other workflows should read next.

## Choose This Skill When

- You are entering an unfamiliar repository area before planning or editing.
- You need ownership, boundaries, approval boundaries, risk posture, or verification depth before implementation.
- You need repository facts before another workflow can proceed.

## Choose Another Skill When

- Use `repo-search` when you need to locate files or trace references.
- Use `repo-investigation` when you are diagnosing a specific observed problem.

## Task Context Sources

Load the smallest relevant task context first when available. If none exists, stay read-only and produce the missing ownership, path, target, and verification map.

Answer five task-anchor questions only as far as the task needs: the owner of the area, the existing implementation, the governing decisions, known failures or open tickets, and the smallest test that proves the change.

When the repository provides a read-only maintenance or context briefing script (its instructions will name it), run it first. Treat any section it marks `unknown` or `unavailable` as not established, never as clean. Without it, fall back in this order: the decision index and ticket catalog, then a code-intelligence service (for example a code graph index) when installed and current, then targeted search and source reads.

When the task turns on an earlier decision, a rejected approach, or a constraint with history, and the repository provides an optional local search index (for example a QMD collection of decisions), search its decisions first, then architecture notes, then tickets. A hit is a pointer: confirm it in the decision index and the current source before relying on it. Skip this on ordinary tasks and when the index is absent.

## Domain Language

When correctness turns on a domain term (a business concept, or a word such as
session, run or permission whose meaning changes behavior), use the repository's
glossary or domain docs if present and keep their terms in plans, code and tests.
When a term is overloaded, or its definition disagrees with the code or an
accepted decision, report the contradiction with its sources and route the
choice to `clarification`. A missing glossary does not block work; do not create
a glossary or decision record as a side effect, and do not treat current code as
proof that its domain behavior is correct.

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

A value still in `<TOKEN>` form is an UNKNOWN, not an instruction. Never invent a command to fill the gap: discover the real one from the repository (build files, CI config, contributor docs), use it, and report the token as unresolved.

## Review Priorities

- `<REVIEW_PRIORITIES>`

## Change Hygiene

Search for nearby patterns before changing code, config, docs, or workflow logic;
prefer reuse when behavioral or responsibility overlap is substantial. State numeric
similarity only when a tool measured it, naming the method and scope. After changes,
sweep edited files and nearby references for stale paths, placeholders, and generated-output drift.

## Approval Boundaries

- `<APPROVAL_REQUIRED_CHANGES>`

## Common Gotchas

- `<KNOWN_GOTCHA_THEMES>`

## Output Contract

- current owner or `unknown`
- affected paths and targets
- canonical docs to read next
- approval boundaries relevant to the request
- focused verification starting point
- recommended next stage: research, plan, implement, review
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
