---
description: Search repository evidence using ai-search
agent: plan
---

Run:

```bash
git status --short
AI_OUTPUT=json bash scripts/ai/ai-search.sh text "$ARGUMENTS" . --fixed
```
