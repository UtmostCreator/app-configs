# Good / Bad: Shell Scripts

## Good

```bash
bash -n scripts/install.sh
shellcheck scripts/install.sh
shfmt -d scripts/install.sh
bats tests/install.bats
```

## Bad

```bash
bash scripts/install.sh
sed -i 's/foo/bar/g' scripts/*.sh
```

Why bad:

- runs before syntax/lint validation
- broad edits can break quoting and portability
