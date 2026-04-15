---
name: repo-investigation
description: Investigate bugs, regressions, and change history in this repository.
---

When investigating:

1. Start with `scripts/copilot/rg-code.sh` for broad discovery.
2. Use `scripts/copilot/fd-files.sh` for file discovery.
3. Preview candidate files with `scripts/copilot/preview-file.sh`.
4. Use `scripts/copilot/git-forensics.sh` for history tracing.
5. Use `scripts/copilot/gh-pr-context.sh`, GitHub MCP, or `gh` for PR and issue context.
6. Prefer read-only work until root cause is identified.
7. Summarize exact commands used, file paths, line ranges, commits, and confidence.
8. Do not use destructive commands.
