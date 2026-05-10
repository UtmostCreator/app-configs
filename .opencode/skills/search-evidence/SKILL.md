---
name: search-evidence
description: Collect repository evidence using ai-search
---

# search-evidence

Use this skill for bounded repository evidence collection.

Required sequence:

1. `git status --short`
2. `AI_OUTPUT=json bash scripts/ai/ai-search.sh changed QUERY . --fixed`
3. `AI_OUTPUT=json bash scripts/ai/ai-search.sh staged QUERY . --fixed`
4. `AI_OUTPUT=json bash scripts/ai/ai-search.sh tracked QUERY . --fixed`
