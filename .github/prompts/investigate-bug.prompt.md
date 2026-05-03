---
mode: agent
name: investigate-bug
description: Investigate a bug with a read-first workflow, exact evidence, and the smallest safe fix path
argument-hint: 'Describe the symptom, expected behavior, and any suspected file or PR'
---

Investigate a bug in this repository.

This prompt file is an optional workflow asset. It should guide the investigation flow, not replace repository context, capabilities, or path-specific instructions.

Workflow:

1. Clarify failing behavior.
2. Search with `scripts/ai/ai-search.sh text ...`.
3. Narrow with `scripts/ai/ai-search.sh files ...` or `scripts/ai/fd-files.sh`.
4. Preview with `scripts/ai/preview-file.sh`.
5. Trace history with `scripts/ai/git-forensics.sh` and `git grep` where needed.
6. Use GitHub MCP or `gh` for issue, PR, and workflow context.
7. Summarize likely root cause, evidence, and the smallest safe fix.

Fallback:

If prompt files are unavailable on the active Copilot surface, follow the same process manually with `.github/skills/repo-investigation/SKILL.md` plus `docs/ai/workflow.md`.

Inputs:

- symptom:
- expected behavior:
- optional file/path:
- optional PR/issue:
