---
name: new-feature
description: Use when implementing a bounded feature with existing repository patterns and focused verification
argument-hint: "Describe the feature, expected behavior, and any constraints"
---

This prompt file is an optional workflow asset. It is not a guaranteed equivalent to a native command system and may require preview support or feature enablement on the active Copilot surface.

Use this prompt for a bounded feature slice that should follow existing repository patterns.

Do not use this prompt for broad architecture changes, large migrations, or bug-first regression work.

Implement the feature with the smallest safe change.

Steps:

1. Inspect the current implementation in `<ACTIVE_PATHS>`.
2. Identify the existing owner of the behavior.
3. Extend current patterns before adding new abstractions.
4. Add focused tests if behavior changes.
5. Verify with the most relevant command, starting from `<PRIMARY_TEST_COMMAND>` or `<PRIMARY_VERIFY_COMMAND>`.

Defer to project context for repository facts and to `verify-change` or `review-diff` when those narrower workflows fit better.

Gotchas:

- do not introduce a new subsystem when an existing owner already fits
- do not skip risk and rollout notes for medium or high-risk changes
