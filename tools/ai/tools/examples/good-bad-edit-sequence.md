# Good / Bad: Edit Sequence

## Good

```bash
git status --short
rg -n "target"
bat -n path/to/file

# minimal edit

git diff --check
git diff --stat
git diff
php artisan test --filter=SpecificTest
```

## Bad

```bash
sed -i 's/target/replacement/g' $(find . -type f)
php artisan test
final answer
```

Why bad:

- broad edit
- no scope review
- no diff check
