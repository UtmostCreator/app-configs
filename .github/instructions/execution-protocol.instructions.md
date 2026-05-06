---
applyTo: "**"
description: "Evidence-first task execution, dirty-worktree protection, scope control, and final verification reporting."
---

# Execution Protocol

For non-trivial repository work, follow `docs/ai/execution-protocol.md`.

Before edits:

- classify task mode
- inspect `git status --short`
- inspect relevant diffs
- protect unrelated user changes
- declare intended scope
- avoid broad rewrites

For code or config changes, final output must include:

- task mode
- changed files
- verification classification
- checks run
- rollback path for medium/high risk
- remaining risks
