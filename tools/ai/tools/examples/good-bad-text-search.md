# Good / Bad: Text Search

## Good

```bash
rg -n "new CheckoutService" tests -g "*.php"
git grep -n "Context Gate"
rg -n "TODO|FIXME" --glob "!vendor" --glob "!node_modules"
```

## Bad

```bash
grep -R "new CheckoutService" .
grep -rn "TODO" . | grep -v vendor
```

Why bad:

- noisy
- slower
- easy to include ignored files
