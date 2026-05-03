# Good / Bad: Research Sequence

## Good

```bash
git status --short
git diff --stat
git log --oneline --decorate -10
rg --files | head -200
rg -n "KEYWORD"
bat -n path/to/file
jq '.scripts' package.json 2>/dev/null || true
```

## Bad

```bash
cat lots/of/files
grep -R "KEYWORD" .
start editing immediately
```

Why bad:

- reads too much
- no repo state awareness
- increases hallucination risk
