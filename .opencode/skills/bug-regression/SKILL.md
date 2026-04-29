---
name: bug-regression
description: Use when fixing a bug, adding a regression test, or proving a minimal fix with direct evidence
compatibility: opencode
---

## What I Do

I drive a minimal bug-fix workflow: reproduce, localize, fix narrowly, verify, and report evidence.

## When To Use Me

- when a user reports broken behavior
- when a fix should start with a regression test or deterministic reproduction
- when the safest path is to keep the change tightly bounded

## Read Alongside

- `docs/ai/capabilities/bug-regression/CAPABILITY.md`
- `docs/ai/capabilities/bug-regression/checklist.md`
- `docs/ai/capabilities/bug-regression/gotchas.md`
- `docs/ai/capabilities/bug-regression/examples.md`

## Workflow Reminder

1. identify the owning layer
2. add the smallest practical failing reproduction
3. apply the smallest safe fix
4. verify with the narrowest direct check first
5. report reproduction, root cause, fix, and evidence
