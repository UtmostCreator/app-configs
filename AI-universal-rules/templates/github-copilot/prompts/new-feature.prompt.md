---
name: new-feature
description: Plan and implement a small feature using existing repository patterns
argument-hint: "Describe the feature, expected behavior, and any constraints"
---

This prompt file is an optional workflow asset. It is not a guaranteed equivalent to a native command system and may require preview support or feature enablement on the active Copilot surface.

Implement the feature with the smallest safe change.

Steps:

1. Inspect the current implementation in `<ACTIVE_PATHS>`.
2. Identify the existing owner of the behavior.
3. Extend current patterns before adding new abstractions.
4. Add focused tests if behavior changes.
5. Verify with the most relevant command, starting from `<PRIMARY_TEST_COMMAND>` or `<PRIMARY_VERIFY_COMMAND>`.
