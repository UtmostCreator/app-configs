# External Repo Install

Use the installer to bootstrap this AI workflow kit into another repository.

## Dry-Run First

```bash
php tools/ai/install-ai-kit.php --target /path/to/target-repo --profile dual --dry-run
```

## Apply Install

```bash
php tools/ai/install-ai-kit.php --target /path/to/target-repo --profile dual
```

After apply, generate install instructions and catalog docs:

```bash
php tools/ai/ai.php install-docs --target /path/to/target-repo --write
php tools/ai/ai.php install-docs --check
```

## Profiles

- `minimal`: base policy, project context, workflow, guardrails, and the three core capabilities
- `copilot`: `minimal` plus GitHub Copilot instructions, instructions, agents, and prompts
- `opencode`: `minimal` plus OpenCode agents, commands, and skills
- `dual`: `minimal` plus both runtime adapters and the lite extended capabilities
- `guarded`: `dual` plus policy, hooks, and evidence packs
- `accelerated`: `dual` plus `scripts-pack`, `policy-pack`, and `evidence-pack`
- `full-governance`: `accelerated` plus `capabilities-extended-full`, `hooks-pack`, and `ci-pack`
- `docs-reference`: docs-only add-on profile for reference material
- `custom`: start from no profile expansion and opt into packs with `--with`

For the exact ordered recipes, selective packs, and reinstall flow, read `docs/ai/install-order.md`.

Legacy wrapper still works:

- `tools/ai/install-copilot-kit.sh --profile minimal|copilot|copilot-guarded`
- `tools/ai/install-opencode-kit.sh --profile minimal|opencode`
- `tools/ai/install-ai-kit.sh` (shell wrapper around PHP installer)

## Selective Pack Installs

Examples:

```bash
# Copilot plus scripts and advisor
php tools/ai/install-ai-kit.php \
  --target /path/to/target-repo \
  --profile copilot \
  --with scripts-pack,advisor-pack

# OpenCode runtime only, without refreshing base policy files
php tools/ai/install-ai-kit.php \
  --target /path/to/target-repo \
  --profile opencode \
  --no-base

# Custom docs-only install with selected optional packs
php tools/ai/install-ai-kit.php \
  --target /path/to/target-repo \
  --profile custom \
  --with base,docs-reference-pack,advisor-pack
```

Useful flags:

- `--with <packs>` adds optional packs such as `scripts-pack`, `advisor-pack`, `docs-reference-pack`, `delivery-pack`, `preview-environments-pack`, `evaluation-pack`, `service-boundary-pack`, and `mcp-boundaries-pack`
- `--without <packs>` removes packs from the chosen profile
- `--all-features` enables every registered optional pack
- `--upgrade-suffix <suffix>` writes colliding targets to suffixed copies instead of skipping them, but only when the existing target differs from the source
- `--run-after-install <id>` runs a registered helper such as `repomix-tree` or `repo-tool-inventory`
- `--toolchain-check` and `--toolchain-install-plan` show required tool state before apply

Example merge-safe docs refresh:

```bash
php tools/ai/install-ai-kit.php \
  --target /path/to/target-repo \
  --profile full-governance \
  --runtime github-copilot \
  --with docs-reference-pack \
  --upgrade-suffix=-upgrade

cd /path/to/target-repo
bash scripts/ai/repo-tool-inventory.sh
bash scripts/ai/repomix-context-tree.sh all .
```

If a destination file already matches the installer source exactly, the installer now skips it instead of producing a redundant `-upgrade` copy.

## Overwrite Behavior

- existing files are skipped by default
- use `--force` to overwrite existing paths
- use `--no-base` when you only want runtime adapters (`.github` and/or `.opencode`) without replacing base policy files

## See Also

- `install-order.md` — full ordered command flow, reinstall flow, and selective pack recipes
- `POST-INSTALL.md` — post-install checklist and commands
- `packages/ai-universal-rules/docs/INSTALL-CATALOG.md` — full profile and pack index
- `packages/ai-universal-rules/docs/INSTALL-GITHUB-COPILOT.md` — GitHub Copilot base install guide
- `packages/ai-universal-rules/docs/INSTALL-OPENCODE.md` — OpenCode base install guide
- core base policy paths remain protected even with `--force`; pass `--allow-core-overwrite` only when intentional

## Adaptation Behavior

The installer adapts placeholders in installed markdown files based on target repo signals:

- project name from target folder (or `--project-name`)
- project type from `composer.json`, `package.json`, or `go.mod`
- primary language from `scc` when available
- active paths from top-level tracked files

Unknown values remain explicit as `unknown` instead of guessed.

## Runtime

Current installer runtime support:

- `github-copilot`
- `opencode`
- `both` (via `--runtime both` or `--profile dual`)

OpenCode-only example:

```bash
bash tools/ai/install-opencode-kit.sh --target /path/to/target-repo --profile opencode
```

Installer target guard:

- installs into `packages/ai-universal-rules/examples/` are intentionally blocked
- use a dedicated external repository or a separate scratch project directory for install testing

## Reinstall On Top Of An Existing Repo

For a dry-run refresh on an already-installed repository:

```bash
php tools/ai/install-ai-kit.php --target /path/to/target-repo --profile full-governance --dry-run
```

If you intentionally want to refresh existing files in place, use `--force`, and add `--allow-core-overwrite` only when you also want the protected base policy files replaced.

## Compatibility Guarantees During V2 Migration

- existing installer/adapter workflow commands stay supported while new aliases are introduced
- direct installer entrypoint (`install-ai-kit.php`) stays available as a compatibility shim
- placeholder syntax stays `<PLACEHOLDER_NAME>`
- canonical install state lives in `.ai-install-manifest.json`
- generated evidence copy may be written to `docs/ai/generated/install-manifest.json`

## Backup Requirements

- backups remain mandatory before apply in workflow mode
- `ZipArchive` is preferred when available
- when `ext_zip` is missing, installer uses directory backup fallback instead of hard-blocking install

## Notes

- this installer is intentionally starter-focused
- review and refine `AGENTS.md` and `docs/ai/project-context.md` after install
- run repo-specific verification after installation
- for folder-level install wiring and intent mapping, consult `docs/ai/repo-directory-map.json`
- for architecture and complete installed asset map, read `docs/ai/installer-architecture.md`
