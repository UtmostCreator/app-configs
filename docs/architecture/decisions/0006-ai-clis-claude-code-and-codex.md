---
adr: 6
title: "AI CLIs: keep Claude Code and Codex, install only when missing, run Claude in WSL"
status: decided-unverified
date: 2026-11-15
platforms: [linux, wsl]
areas: [ai-cli]
permits: [install-when-missing, claude-in-wsl]
forbids: [reinstall-over-working-binary]
amends: []
supersedes: []
superseded_by: []
related: [T-0047]
---
# ADR-0006: AI CLIs: keep Claude Code and Codex, install only when missing, run Claude in WSL
Status: decided-unverified (installer not yet built) · Date: 2026-11-15 · Sources: T-0047 plan (decisions, S3-5, Milestone 2), `nix/modules/home/ai-cli-updates.nix`, docs/platforms/wsl/windows-and-wsl.md

## Decision
- Keep both CLIs; the repo already runs update timers for both.
- A script called from `ops/install.sh` (Linux hosts only) installs a CLI only when it is missing: download to a file, validate, then run. Never reinstall over a working binary.
- Opt-out key `aiCli: false` in personal.yaml, a deliberate exception to the install selection.
- Daily development runs Claude Code inside WSL2; Windows Claude only for Windows-side work.

## Why
- Closes the reproducibility gap: a new machine gets both CLIs without a manual step.
- Session reasoning: they are vendor binaries, not Nix packages, so the Nix-based selection does not fit (the plan says only "a deliberate exception").
- NixOS needs nix-ld for the vendor binaries (placement decided by desktop check D6).
- WSL2 gives Linux tools, the repo hooks and the same chezmoi config as the other hosts.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Runbook-only manual installs | Safe and simple, but leaves a reproducibility gap. |
| The install-selection group mechanism | Built around Nix package membership. |
| Dropping Codex (suggested by outside research) | Rejected: it is OpenAI's CLI and in use. |

## Discarded
Piping installers to a shell (no `curl | sh`), reinstalling over a working binary, native Windows Claude automation now (Milestone 2).

## Consequences
- Not built yet: the installer is T-0047 task S3-5; until then installs are manual.
- The opt-out key is a second mechanism next to the install selection; keep it limited to these two CLIs.
- Milestone 2 may add native Windows Claude (winget or an inspected install.ps1) with its own `~/.claude`.
- Amended by ADR-0016: the native Windows status line (one opt-in bootstrap step) is no longer discarded; installing Claude Code on Windows stays Milestone 2.
