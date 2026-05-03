# Good / Bad: Git Diff Review

## Good

```bash
git status --short
git diff --stat
git diff --check
git diff
```

Human review:

```bash
git diff | delta
difft old.php new.php
```

## Bad

```bash
git diff
# then final answer without git diff --check
```

Why bad:

- misses whitespace errors and conflict markers
- no change-scope summary
