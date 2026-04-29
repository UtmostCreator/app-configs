# AI Toolchain Requirements

Use this checklist before running installation, validation, and context-pack workflows.

For a generated repository-wide inventory (from tracked shell scripts), see `docs/ai/repo-required-tools.md` and regenerate it with `bash scripts/ai/repo-tool-inventory.sh`.

## Required

- `bash` - shell runtime for wrapper scripts.
- `git` - repository introspection and tracked-path detection.
- `php` - canonical installer and validators under `tools/ai/`.
- `rg` - search dependency used by doctor and helper scripts.

## Required For Context Packing

- `repomix` - generates context bundles.
- `scc` - code metrics input for route planning.
- `jq` - JSON processing in context routing scripts.

## Optional But Recommended

- `just` - convenient task runner for common commands.
- `yq` - YAML parsing in policy/hook adapters.
- `shellcheck` - shell lint.
- `shfmt` - shell formatter.
- `actionlint` - GitHub Actions lint.
- `lychee` - link checker.
- `bats` - shell test suite.
- `composer` - installs PHP test dependencies.

## Install Commands

### Windows (winget)

```bash
winget install --id BurntSushi.ripgrep.MSVC -e
winget install --id jqlang.jq -e
winget install --id BenBoyter.scc -e
winget install --id Casey.Just -e
winget install --id MikeFarah.yq -e
winget install --id koalaman.shellcheck -e
winget install --id mvdan.shfmt -e
winget install --id rhysd.actionlint -e
winget install --id lycheeverse.lychee -e
```

Install `repomix` with npm:

```bash
npm install -g repomix
```

### macOS (brew)

```bash
brew install ripgrep jq scc just yq shellcheck shfmt actionlint lychee bats-core
npm install -g repomix
```

### Linux (apt)

```bash
sudo apt update
sudo apt install -y ripgrep jq shellcheck
npm install -g repomix
```

`scc`, `just`, `yq`, `shfmt`, `actionlint`, `lychee`, and `bats` may require release binaries or alternate package sources on some distros.

## Verify Installation

Run these checks:

```bash
php tools/ai/ai.php toolchain --with repomix,scc --check
php tools/ai/ai.php toolchain --with repomix,scc --install-plan
bash scripts/doctor.sh
php tools/ai/validate-ai-config.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
php tools/ai/generate-repo-structure.php --check --with-scc
```

If scripts-pack is installed, use:

```bash
php tools/ai/ai.php run-script --list
php tools/ai/ai.php run-script repomix-context --dry-run
```

## Windows PATH Note

Some tools installed by winget are not visible in Git Bash immediately. Repository scripts now auto-scan and append `%LOCALAPPDATA%/Microsoft/WinGet/Packages` executable directories for runtime checks.
