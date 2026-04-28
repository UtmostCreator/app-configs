# Contributing

Thanks for helping improve `app-configs`.

This repository is both a live personal config repo and a reusable AI workflow kit, so contributions should stay small, explicit, and easy to verify.

## What To Contribute

- fixes for stale paths, broken commands, or drift between canonical docs and runtime adapters
- improvements to `packages/ai-universal-rules/` that make the kit more portable, verifiable, or easier to adopt
- tighter validation, generation, or packaging workflows
- setup docs that are more copy-paste safe without hiding machine-specific assumptions

## What Not To Contribute

- stack-specific guidance that does not match this repository
- large catalog expansions that dilute the repo into a generic marketplace clone
- hidden production defaults derived from examples
- claims of cross-tool parity when support differs by runtime surface

## Design Rules

- keep canonical workflow logic in `docs/ai/capabilities/` or `packages/ai-universal-rules/templates/capabilities/`
- keep runtime adapters thin and pointed back to canonical docs
- preserve portability where practical
- prefer the smallest coherent change over broad rewrites
- say `unknown` when the repository does not prove a claim

## Contribution Flow

1. Read `README.md`, `AGENTS.md`, and the nearest relevant docs.
2. Change the smallest bounded slice.
3. Update generated docs if source metadata changes.
4. Run the narrowest relevant validation.
5. Include evidence in the PR description.

## Validation

Use the smallest relevant check first.

```powershell
php tools/ai/validate-ai-config.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
php tools/ai/export-ai-universal-rules.php --check
```

Run only the checks that match your change unless you touched shared generation or release metadata.

## Local Development and Testing

Run all checks end-to-end:

```bash
just ci
bash scripts/repo-health-check.sh
```

Run individual layers:

```bash
just ai-check      # PHP AI validators (config, catalog, generated-output staleness)
just health-check  # doctor + ai-check + lint + test-php + test-shell
just lint          # shellcheck + shfmt + actionlint + lychee (offline docs link check)
just test-php      # PHPUnit — tools/ai/ai_catalog_lib.php + CLI entrypoint contracts
just test-shell    # bats — pre-tool-use.sh, post-tool-use.sh, doctor.sh
just test          # test-php + test-shell
```

The pre-commit hook now runs `bash scripts/repo-health-check.sh staged` whenever staged changes exist, so new changes go through the full project health matrix before commit.

### Required in CI (must be installed for lint/test-shell to pass)

| Tool         | Install                   |
| ------------ | ------------------------- |
| `shellcheck` | `brew install shellcheck` |
| `shfmt`      | `brew install shfmt`      |
| `actionlint` | `brew install actionlint` |
| `lychee`     | `brew install lychee`     |
| `bats`       | `brew install bats-core`  |
| `jq`         | `brew install jq`         |
| `yq`         | `brew install yq`         |

In CI these tools are installed at pinned versions (see `.github/workflows/validate-ai-surface.yml`). For macOS local use, `brew install` each tool + `brew pin` it to keep versions stable.

### Optional locally (warnings only)

`bats`, `actionlint`, `shellcheck`, `shfmt`, `lychee`, `jq`, and `yq` — `just doctor` warns if absent but does not fail. The full repo health check does require them.

### Test fixtures

All test fixtures live under `tests/fixtures/`. They must be stack-agnostic: no Laravel, Vue, product-specific, or external-network references. Shell tests must not touch the live working tree — use isolated temp directories.

## Generated Files

These files are generated and should not be edited by hand:

- `docs/ai/catalog.md`
- `packages/ai-universal-rules/docs/BROWSE.md`
- `packages/ai-universal-rules/catalog.json`
- `llms.txt`

These local context outputs are also generated and should not be committed:

- `.repomix-context/`
- `repomix-output*.xml`

Regenerate them with:

```powershell
php tools/ai/generate-ai-catalog.php
```

Repomix context bundles are generated with:

```powershell
bash scripts/copilot/repomix-scc-router.sh all .
```

## Pull Requests

- explain why the change is needed
- note validation you actually ran
- call out any runtime-surface tradeoffs or compatibility changes
- keep unrelated cleanup out of the same PR

## Security And Support

- report security issues through `SECURITY.md`
- use `SUPPORT.md` for questions, discussion, and adoption help
