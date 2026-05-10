# Installation Guide

Install AI workflow tooling into this repository or any target project.

## Prerequisites

| Tool     | Minimum | Check                                         |
| -------- | ------- | --------------------------------------------- |
| PHP      | 8.1+    | `php -v`                                      |
| Composer | 2.x     | `composer --version`                          |
| Bash     | 4.0+    | `bash --version` (macOS: `brew install bash`) |
| Git      | 2.x     | `git --version`                               |
| jq       | 1.6+    | `jq --version`                                |
| repomix  | latest  | `repomix --version` (`npm i -g repomix`)      |
| scc      | latest  | `scc --version` (`brew install scc`)          |
| rg       | latest  | `rg --version` (`brew install ripgrep`)       |
| fd       | latest  | `fd --version` (`brew install fd`)            |

Install all CLI tools at once:

```bash
/opt/homebrew/bin/bash scripts/ai/install-mandatory-tools.sh
```

## Quick Start (Full Installation)

### 1. Preflight check

```bash
php tools/ai/ai.php preflight
```

### 2. Dry-run to preview changes

```bash
php tools/ai/ai.php install --profile full-governance --reinstall --dry-run
```

### 3. Apply installation

```bash
php tools/ai/ai.php install --profile full-governance --reinstall --apply
```

### 4. Validate

```bash
php tools/ai/validate-ai-config.php
php tools/ai/validate-install-surface.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
```

### 5. Full verification

```bash
php tools/ai/verify-full-install.php
```

## Installation Profiles

| Profile           | Surfaces                                         | Use when                             |
| ----------------- | ------------------------------------------------ | ------------------------------------ |
| `full-governance` | Copilot + OpenCode + scripts + hooks + advisor   | Full AI workflow setup (recommended) |
| `copilot-only`    | Copilot adapter + instructions + agents + skills | VS Code / GitHub Copilot only        |
| `opencode-only`   | OpenCode adapter + skills                        | OpenCode CLI only                    |
| `scripts-only`    | AI scripts + common.sh                           | Bash scripts only                    |

List available profiles and packs:

```bash
php tools/ai/ai.php packs
```

## Install Options

| Option             | Purpose                                          |
| ------------------ | ------------------------------------------------ |
| `--profile <name>` | Select installation profile                      |
| `--reinstall`      | Refresh all surfaces (overwrites managed files)  |
| `--dry-run`        | Preview changes without writing files            |
| `--apply`          | Write files (default is dry-run)                 |
| `--force`          | Overwrite even if target has local modifications |
| `--verify-after`   | Run validation automatically after install       |

## Repomix Context Generation

Generate AI-ready context bundles from any project. Use strong params for projects with deeply nested folder structures.

### Recommended command (for any project)

```bash
SECRETS_SCAN=0 /opt/homebrew/bin/bash scripts/ai/run-repomix-context.sh /Users/USER_NAME/Herd/PROJECT_NAME/ \
  --top 0 \
  --min-code 0 \
  --min-files 0 \
  --depth 3
```

For very large projects, increase `--depth` to 4 or 5. If any bundle exceeds the token cap, it will be marked `split` automatically.

### Parameter reference

| Parameter             | Default | Recommended | Why                                                                   |
| --------------------- | ------- | ----------- | --------------------------------------------------------------------- |
| `--depth`             | 1       | 3           | Captures nested folders; use 4–5 for very large projects              |
| `--top`               | 25      | 0           | `0` means all routes — ensures nothing is skipped                     |
| `--min-code`          | 300     | 0           | `0` captures small files/configs that matter                          |
| `--min-files`         | 2       | 0           | `0` captures single-file routes                                       |
| `--min-score`         | 0       | 0           | No score filtering                                                    |
| `--min-complexity`    | 0       | 0           | No complexity filtering                                               |
| `--max-bundle-tokens` | 100000  | 100000      | Max tokens per bundle; oversized routes are force-split               |
| `--compress`          | off     | on          | Reduces token usage (added automatically by `run-repomix-context.sh`) |
| `--style`             | xml     | xml         | XML style is default and most compatible                              |
| `--context-window`    | 128000  | 128000      | Match your model's context window                                     |
| `SECRETS_SCAN`        | 1       | 0           | Disable if gitleaks is not installed or project is local-only         |
| `MAX_BUNDLE_TOKENS`   | 100000  | 100000      | Env var override for `--max-bundle-tokens`                            |

### Output structure

```
.repomix-context/tree-context/
├── index.md              ← Human-readable route index (open first)
├── tree-plan.json        ← Machine-readable route plan
├── tree-manifest.json    ← Full generation manifest
├── bundles/              ← Packed context files per route
└── indexes/              ← Split-route child indexes
```

### Other context scripts

| Script                    | Purpose                                                 |
| ------------------------- | ------------------------------------------------------- |
| `repomix-context-tree.sh` | Lower-level: analyze, plan, pack, or clean context tree |
| `repomix-scc-router.sh`   | Size-aware routing using scc metrics                    |
| `pack-context.sh`         | Quick focused context for a single area                 |
| `ai-diff-context.sh`      | Context from current git diff only                      |

## Post-Install Validation Commands

```bash
# Validate AI config and references
php tools/ai/validate-ai-config.php

# Validate installed adapter surfaces
php tools/ai/validate-install-surface.php

# Validate catalog metadata
php tools/ai/validate-ai-catalog.php

# Check generated artifacts for drift
php tools/ai/generate-ai-catalog.php --check

# Validate command policy tiers
php tools/ai/validate-command-policy.php .

# Full verification chain
php tools/ai/verify-full-install.php

# Run AI advisor
php tools/ai/ai.php advisor --all
```

## Regenerating Catalog Artifacts

If `--check` shows drift:

```bash
php tools/ai/generate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
```

## Running AI Script Tests

All scripts have tests in `tests/scripts/ai/`. Requires Bash 4+.

```bash
# Run all test suites
SUITE_TIMEOUT=60 /opt/homebrew/bin/bash tests/scripts/ai/run-all-tests.sh

# Run a single suite
/opt/homebrew/bin/bash tests/scripts/ai/test-common.sh
```

## Maintenance Mode

Temporarily permit full install/verify workflows:

```bash
php tools/ai/maintenance-mode.php enable --reason "full-governance reinstall" --ttl-seconds 1800
# run installation commands
php tools/ai/maintenance-mode.php disable
```

## Troubleshooting

### macOS: Bash version too old

System bash is 3.2. Install Homebrew bash:

```bash
brew install bash
/opt/homebrew/bin/bash --version  # should show 5.x
```

Use `/opt/homebrew/bin/bash` to run scripts, or add it to PATH.

### Windows: Git not in PATH

```powershell
$env:Path = "C:\Program Files\Git\cmd;$env:Path"
git --version
```

### repomix not found

```bash
npm i -g repomix
repomix --version
```

If your shell prints `'git' is not recognized as an internal or external command` during installer commands, add Git to PATH and retry:

```powershell
$env:Path = "C:\Program Files\Git\cmd;$env:Path"
git --version
```
