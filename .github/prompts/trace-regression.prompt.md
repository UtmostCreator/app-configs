---
mode: agent
name: trace-regression
description: Trace a regression through history first, then report the likeliest bad change and follow-up proof
argument-hint: 'Describe the regression and include an optional file, symbol, or branch pair'
---

Trace a regression in this repository.

This prompt file is an optional workflow asset. Use it for history-driven investigation, not for direct implementation.

Workflow:

1. Identify affected file, function, or literal.
2. Use `scripts/ai/git-forensics.sh S ...` and `scripts/ai/git-forensics.sh G ...` first.
3. Use `scripts/ai/git-forensics.sh L ...` for function or line evolution.
4. Use `scripts/ai/git-forensics.sh blame ...` for current line ownership.
5. Use `git range-diff` when branch comparison is needed.
6. Summarize first likely bad change, evidence, and follow-up checks.

Fallback:

If prompt files are unavailable on the active Copilot surface, follow the same process manually with `.github/skills/repo-investigation/SKILL.md` and `scripts/ai/git-forensics.sh`.

Inputs:

- regression description:
- optional file:
- optional symbol:
- optional branch pair:
