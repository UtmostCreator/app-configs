---
description: Inventory registered AI scripts and risk
agent: repository-researcher
---

List script inventory from canonical docs and highlight risk class.

## Required checks

```bash
git status --short
AI_OUTPUT=json bash scripts/ai/ai-search.sh tracked "scripts/ai/" . --fixed
AI_OUTPUT=json bash scripts/ai/ai-search.sh tracked "docs/ai/script-registry" . --fixed
AI_OUTPUT=json bash scripts/ai/ai-search.sh tracked "docs/ai/scripts-reference.md" . --fixed
```

## Return format

- script id
- installed path
- risk (`read-only` or `mutating`)
- required tools
- parity status across `script-registry.json`, `script-registry.md`, and `scripts-reference.md`
