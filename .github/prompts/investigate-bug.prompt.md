---
mode: agent
---

Investigate a bug in this repository.

Workflow:

1. Clarify failing behavior.
2. Search with `scripts/copilot/ai-search.sh text ...`.
3. Narrow with `scripts/copilot/ai-search.sh files ...` or `scripts/copilot/fd-files.sh`.
4. Preview with `scripts/copilot/preview-file.sh`.
5. Trace history with `scripts/copilot/git-forensics.sh` and `git grep` where needed.
6. Use GitHub MCP or `gh` for issue, PR, and workflow context.
7. Summarize likely root cause, evidence, and the smallest safe fix.

Inputs:

- symptom:
- expected behavior:
- optional file/path:
- optional PR/issue:
