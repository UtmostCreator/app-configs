# Action: Search Evidence

Run before planning, editing, reviewing, or answering repo-specific questions.

```bash
git status --short
AI_OUTPUT=json bash scripts/ai/ai-search.sh changed "$QUERY" . --fixed
AI_OUTPUT=json bash scripts/ai/ai-search.sh staged "$QUERY" . --fixed
AI_OUTPUT=json bash scripts/ai/ai-search.sh tracked "$QUERY" . --fixed
```

Report: commands run, status, files found, relevant lines, uncertainty, and next safest action.
