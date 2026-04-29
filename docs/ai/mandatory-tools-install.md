# Mandatory Tool Install (Cross Platform)

This repository now includes `scripts/ai/install-mandatory-tools.sh` to install the mandatory CLI toolchain used by AI scripts and context-packing flows.

## What Was Scanned

Tool requirements were derived from repository scripts and repomix context output, especially:

- `scripts/ai/run-repomix-context.sh`
- `scripts/ai/repomix-context-tree.sh`
- `scripts/doctor.sh`
- `scripts/ai/common.sh`
- `.repomix-context/tree-context/index.md`

## Mandatory Tools

These are required for the repository's baseline + repomix context flow:

- `bash`
- `git`
- `php`
- `rg` (ripgrep)
- `jq`
- `scc`
- `repomix`

## OS-Aware Install Strategy

The installer detects OS first, then chooses package flow:

- Windows: `winget` + `npm`
- macOS: `brew` + `npm`
- Linux: Ubuntu/Debian (`apt-get`) + `npm`

Linux support in this script is intentionally Ubuntu/Debian-first as requested.

## Usage

Dry-run (recommended first):

```bash
bash scripts/ai/install-mandatory-tools.sh --dry-run
```

Install:

```bash
bash scripts/ai/install-mandatory-tools.sh
```

The script verifies mandatory binaries at the end and exits non-zero if any are still missing.

## Current Environment Detection Example

On this workspace run, `uname -s` returned `MINGW64_NT-10.0-26200`, so the script selects the Windows branch.
