# Good / Bad: GitHub Actions

## Good

```bash
actionlint
yq '.on' .github/workflows/*.yml
yq '.jobs | keys' .github/workflows/*.yml
```

## Bad

```bash
grep -R "uses:" .github/workflows
grep -R "pull_request" .github/workflows
```

Why bad:

- YAML structure matters
- expressions can be invalid even when grep looks fine
