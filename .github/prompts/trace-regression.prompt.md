---
mode: agent
---

Trace a regression in this repository.

Workflow:

1. Identify affected file, function, or literal.
2. Use `scripts/copilot/git-forensics.sh S ...` and `scripts/copilot/git-forensics.sh G ...` first.
3. Use `scripts/copilot/git-forensics.sh L ...` for function or line evolution.
4. Use `scripts/copilot/git-forensics.sh blame ...` for current line ownership.
5. Use `git range-diff` when branch comparison is needed.
6. Summarize first likely bad change, evidence, and follow-up checks.

Inputs:

- regression description:
- optional file:
- optional symbol:
- optional branch pair:
