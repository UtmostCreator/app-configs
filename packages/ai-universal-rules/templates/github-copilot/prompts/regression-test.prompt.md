---
name: regression-test
description: Use when the main task is to create a failing or proving regression test for a reported bug or edge case
argument-hint: "Describe the behavior, failure mode, and expected result"
---

Use this prompt when the most important outcome is a focused regression test or deterministic reproduction.

Workflow:

1. identify the smallest useful proving surface
2. add the narrowest practical test or reproduction
3. confirm failure or proving behavior when practical
4. stop unless the request also includes the fix

Do not widen into a broader refactor or feature task.
