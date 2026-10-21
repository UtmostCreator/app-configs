# AI Scripts

Bash 4+ scripts for AI agents and humans. All scripts source `common.sh` for shared utilities unless noted as standalone.

## Usage Policy

- **Prefer wrapper scripts** over raw tools (`rg`, `fd`, `cat`, `grep`, `find`)
- **Never use** bare `grep` or `find` — use `rg-code.sh` / `fd-files.sh` or raw `rg` / `fd`
- **Never use** bare `cat` for exploration — use `preview-file.sh`
- Read-only scripts are approval-free; mutation scripts require explicit approval
- All scripts are registered in `docs/ai/script-registry.json`
- See `tools/ai/tools/tool-map.md` for the full wrapper → fallback mapping
- See `tools/ai/tools/examples/` for good/bad usage examples per category

## Script Categories

### Shared Library

| Script      | Purpose                                           | Run directly?                 |
| ----------- | ------------------------------------------------- | ----------------------------- |
| `common.sh` | Shared functions, env vars, logging, safety gates | No — sourced by other scripts |

### Evidence / Search

Use these to find code, symbols, and file changes before making decisions.

| Script               | Purpose                                                      | When to use                             |
| -------------------- | ------------------------------------------------------------ | --------------------------------------- |
| `ai-search.sh`       | Unified search facade (text, docs, tracked, changed, struct) | Default search — start here             |
| `rg-code.sh`         | Focused ripgrep wrapper with safe defaults                   | Quick text/regex search                 |
| `fd-files.sh`        | Focused fd wrapper with safe defaults                        | Find files by name/pattern              |
| `query-usage.sh`     | Symbol usage search across the repo                          | Before changing a function/class        |
| `git-forensics.sh`   | Git history tracing (blame, log -S, log -G, log -L)          | Investigate who/when/why a line changed |
| `ai-diff-context.sh` | Pack changed files into AI-ready context                     | Build context from current diff         |

### File Inspection

Use these to read and inspect files safely without dumping entire contents.

| Script               | Purpose                                      | When to use                    |
| -------------------- | -------------------------------------------- | ------------------------------ |
| `preview-file.sh`    | Safe bounded file preview with line ranges   | Instead of `cat` — always      |
| `check-file-refs.sh` | Validate file path references in docs/config | After renaming or moving files |
| `repo-stats.sh`      | Per-file/dir line and size metrics           | Context budget planning        |

### Context Packing

Use these to build bounded AI context from the repository.

| Script                    | Purpose                                    | When to use                       |
| ------------------------- | ------------------------------------------ | --------------------------------- |
| `pack-context.sh`         | Pack context for AI consumption            | Quick context for a focused area  |
| `run-repomix-context.sh`  | Run repomix with safe defaults             | Full context pack with exclusions |
| `repomix-context-tree.sh` | Context tree planning and index generation | Large repos — plan before packing |
| `repomix-scc-router.sh`   | Size-aware context routing via scc         | Choose what fits in token budget  |

### Verification / Quality

Use these to verify changes, run tests, and check documentation.

| Script                   | Purpose                                            | When to use                             |
| ------------------------ | -------------------------------------------------- | --------------------------------------- |
| `ai-verify.sh`           | Run narrowest verification first, then escalate    | After any behavior change               |
| `ai-doc-check.sh`        | Documentation quality checks (markdownlint, links) | After doc changes                       |
| `ai-test-select.sh`      | Select focused tests for changed code              | Before running full test suite          |
| `repo-tool-inventory.sh` | Discover available project tools and commands      | Unfamiliar repo — find what's available |

### Project Tasks

Use these to discover and run project-defined tasks.

| Script             | Purpose                                          | When to use               |
| ------------------ | ------------------------------------------------ | ------------------------- |
| `ai-task.sh`       | Discover/run project tasks (just, npm, composer) | Find available commands   |
| `ai-structured.sh` | Structured data queries (JSON, YAML, TOML)       | Parse config without grep |

### PR / External Context

| Script             | Purpose                                       | When to use               |
| ------------------ | --------------------------------------------- | ------------------------- |
| `gh-pr-context.sh` | GitHub PR context (description, diff, checks) | Review or respond to a PR |

### Session / State

Use these to save and restore work state.

| Script                  | Purpose                                   | When to use                          |
| ----------------------- | ----------------------------------------- | ------------------------------------ |
| `session-checkpoint.sh` | Create session snapshots (diff, manifest) | Before risky changes                 |
| `watch-loop.sh`         | File-watch rerun loop                     | Continuous verification during edits |

### Policy Hooks

These are invoked automatically by Copilot/OpenCode tool hooks.

| Script             | Purpose                              | When to use                      |
| ------------------ | ------------------------------------ | -------------------------------- |
| `pre-tool-use.sh`  | Command safety gate — allow/deny/ask | Automatic — do not call directly |
| `post-tool-use.sh` | Command audit logger                 | Automatic — do not call directly |

### Mutation / Edit

These modify files. **Require explicit approval** before use.

| Script           | Purpose                                    | When to use                 |
| ---------------- | ------------------------------------------ | --------------------------- |
| `ai-edit.sh`     | Broad search-and-replace (sd, ast-grep)    | Multi-file edits with proof |
| `ai-rollback.sh` | Snapshot rollback from session checkpoints | Undo a bad change           |

### Install / Setup

| Script                         | Purpose                                       | When to use               |
| ------------------------------ | --------------------------------------------- | ------------------------- |
| `install-mandatory-tools.sh`   | Install required CLI tools (rg, fd, jq, etc.) | New machine setup         |
| `setup-powershell-profile.ps1` | PowerShell profile setup (Windows)            | Windows environment setup |

## Decision Flowchart

```
Need to find something?
├── Text/code search → ai-search.sh (or rg-code.sh for quick regex)
├── File by name     → fd-files.sh
├── Symbol usage     → query-usage.sh
├── Git history      → git-forensics.sh
└── Changed files    → ai-diff-context.sh

Need to read a file?
└── Always → preview-file.sh (never cat)

Need to verify?
├── Code change  → ai-verify.sh
├── Doc change   → ai-doc-check.sh
└── Pick tests   → ai-test-select.sh

Need to edit?
├── Save state first → session-checkpoint.sh
├── Broad edit       → ai-edit.sh (approval required)
└── Undo             → ai-rollback.sh (approval required)
```

## Testing

Every script has a matching test in `tests/scripts/ai/test-<name>.sh`.

Run all tests:

```bash
SUITE_TIMEOUT=60 /opt/homebrew/bin/bash tests/scripts/ai/run-all-tests.sh
```

Run a single suite:

```bash
/opt/homebrew/bin/bash tests/scripts/ai/test-common.sh
```
