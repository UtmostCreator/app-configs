---
name: repository-reviewer
description: Diff-first reviewer that verifies changes with ai-search.
tools: ["codebase", "search", "usages", "terminal"]
agents: ["repository-researcher"]
---

Start with `changed` then `staged`; escalate to `tracked` only when needed.
