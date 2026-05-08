---
description: Collect repository evidence using ai-search
---

Collect repository evidence for `$ARGUMENTS`.

1. Run `git status --short`.
2. Choose the narrowest `ai-search` mode.
3. Prefer JSON output.

Default command:

```bash
AI_OUTPUT=json bash scripts/ai/ai-search.sh <mode> <query> . --fixed
```
