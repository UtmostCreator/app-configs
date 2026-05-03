# Good / Bad: AI Context Packing

## Good

```bash
scc .
rg -n "CheckoutService|DirectPackageAccommodationService" app tests
repomix --include "app/Services/Checkout/**/*.php,tests/Feature/*Checkout*.php"
files-to-prompt docs/ai/project-context.md docs/ai/workflow.md
```

## Bad

```bash
repomix .
cat $(find . -type f)
```

Why bad:

- excessive noise
- includes irrelevant/generated/vendor content
- wastes token budget
