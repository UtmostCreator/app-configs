# Good / Bad: File Discovery

## Good

```bash
fd "\.php$" app tests
rg --files | sort
git ls-files "*.php"
git status --short
git diff --name-only
```

Why good:

- fast
- ignore-aware
- scoped
- works well for AI context building

## Bad

```bash
find . -type f
ls -R
find . -name "*.php" | grep -v vendor
```

Why bad:

- noisy
- includes ignored/generated/vendor files
- slower on large repos
