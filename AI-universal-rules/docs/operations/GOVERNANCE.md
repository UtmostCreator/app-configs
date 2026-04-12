# Governance

This package assumes AI instructions alone are not enough for production work.

## Governance Goals

- keep policy and procedure separate
- limit silent scope expansion
- require evidence for completion claims
- gate destructive or high-impact actions
- make uncertainty legal instead of encouraging guesses

## Required Controls

- exact task contract for non-trivial work
- acceptance criteria before implementation when ambiguity matters
- approval gates for destructive or sensitive changes
- verification evidence for behavior claims
- documented fallback when runtime features are unavailable

## Human Ownership Rule

A human approver must be able to explain each changed section well enough to own the merge.

## Unknown Is Allowed

The workflow should prefer `unknown`, `not verified`, or `needs repo confirmation` over invented certainty.
