---
name: bug-regression
description: Use when fixing a bug, adding a regression test, or proving a minimal fix with direct evidence
argument-hint: "Describe the bug, expected behavior, and where it appears"
---

This prompt file is an optional workflow asset. Keep a fallback path that uses repository instructions and direct chat prompts if preview support or prompt-file enablement is unavailable.

Use this prompt for bug-fix work that should start from a focused reproduction.

Do not use this prompt for feature planning, broad refactors, or release-only review.

Reproduce the reported bug with the smallest practical automated test first when appropriate.

Then:

1. confirm the test fails when practical
2. apply the smallest safe fix
3. follow the verification ladder: focused proof first, affected layer tests second, broader repository verification third, build as a smoke check when relevant, and release-safety review only when risk warrants it
4. summarize root cause, fix, and evidence

Defer to project context for repository facts and to `verify-change` or `review-diff` when those narrower workflows fit better.

Do not perform unrelated refactors.

Gotchas:

- do not weaken assertions to force a pass
- do not skip the reproduction step when a focused check is practical
- do not report a recommendation as if it was verified
