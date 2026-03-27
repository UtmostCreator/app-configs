---
name: review-code
description: Use when reviewing a diff for correctness, risk, and missing tests before merge or handoff
argument-hint: "Describe the goal of the change or the diff under review"
---

This prompt file is an optional workflow asset. Treat it as reusable guidance, not as a guaranteed command equivalent across Copilot runtimes, and assume preview support may vary by surface.

Use this prompt for diff-first review before merge or handoff.

Do not use this prompt for implementation planning, feature design, or broad repository summarization.

Review the current change set.

Start from the diff first.

Prioritize:

1. correctness
2. regressions
3. security and privacy issues
4. contract drift
5. missing tests

Gotchas:

- do not spend the review restating the diff
- do not treat stylistic preferences as the main finding category

Present findings before general summary.

Defer to project context for repository facts and to `review-diff` or `verify-change` when those narrower workflows fit better.
