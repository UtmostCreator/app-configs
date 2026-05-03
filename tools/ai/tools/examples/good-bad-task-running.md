# Good / Bad: Task Running

## Good

```bash
just --list
jq '.scripts' package.json
composer run-script --list
just verify
```

## Bad

```bash
npm test
make test
composer test
```

without checking available project tasks.

Why bad:

- command may not exist
- wrong package manager
- misses project-specific verify flow
