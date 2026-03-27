---
description: Compatibility command for diff-first review; prefer the review-diff skill for reusable guidance
agent: reviewer
---

Prefer the `review-diff` skill when available. This command remains as a thin compatibility wrapper.

Review the current change set with a correctness-first mindset.

Steps:

1. Start from the diff.
2. Inspect unchanged files only when needed to verify a concern.
3. Prioritize correctness, regressions, contract drift, and missing tests.
4. Summarize findings before any broad overview.
5. Separate confirmed failures from likely concerns.
