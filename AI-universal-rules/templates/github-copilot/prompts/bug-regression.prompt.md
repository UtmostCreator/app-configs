---
name: bug-regression
description: Reproduce a bug with a focused test when practical and then fix it minimally
argument-hint: "Describe the bug, expected behavior, and where it appears"
---

This prompt file is an optional workflow asset. Keep a fallback path that uses repository instructions and direct chat prompts if preview support or prompt-file enablement is unavailable.

Reproduce the reported bug with the smallest practical automated test first when appropriate.

Then:

1. confirm the test fails when practical
2. apply the smallest safe fix
3. run the most relevant verification
4. summarize root cause, fix, and evidence

Do not perform unrelated refactors.
