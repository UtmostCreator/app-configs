---
applyTo: "tests/**,__tests__/**,**/*test*,**/*spec*,phpunit.xml*,pest.php,vitest.config.*,playwright.config.*,cypress.config.*"
description: "Testing rules, baseline proof, regression-first bug fixes, and verification ladder"
---

# Testing Rules

## Baseline Gate

Before test or bug-fix changes:

- inspect `git status --short`
- protect unrelated user changes
- run the smallest relevant baseline test command
- stop and report if baseline already fails unexpectedly

## Regression-Fix Protocol

For bug fixes, create and confirm a failing regression test when practical. If no reliable failing test can be created, document why and use the closest deterministic reproduction before modifying source.

## Verification

- start with focused proof
- run affected-layer checks next
- escalate to broader checks only when risk requires it
- do not weaken assertions or hide failures
