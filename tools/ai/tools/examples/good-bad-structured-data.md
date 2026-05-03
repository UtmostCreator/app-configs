# Good / Bad: Structured Data

## Good

```bash
jq '.scripts' package.json
jq empty composer.json
yq '.jobs | keys' .github/workflows/*.yml
jq '.packages[] | select(.name=="laravel/framework") | .version' composer.lock
```

## Bad

```bash
grep '"scripts"' package.json
grep "laravel/framework" composer.lock
grep "uses:" .github/workflows/*.yml
```

Why bad:

- grep can match comments, examples, or wrong nesting
- structured parsers preserve meaning
