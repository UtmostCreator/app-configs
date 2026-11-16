---
adr: 14
title: "Tool stack recap: one owner per concern"
status: decided
date: unknown
platforms: [cross]
areas: [tooling, ownership]
permits: [one-owner-per-concern]
forbids: [chezmoi-run-scripts, asdf, nvm, husky]
amends: []
supersedes: []
superseded_by: []
related: []
---
# ADR-0014: Tool stack recap: one owner per concern
Status: decided (recap of an existing decision) · Date: not recorded (original migration plan) · Sources: `docs/plans/migration/implementation.md`, `docs/architecture/tool-ownership.md`, `repo-docs/software-and-cli-tools.md`, `repo-docs/migration-package-ownership.md`

## Decision
| Concern | Owner |
|---------|-------|
| Dotfiles (file rendering only) | chezmoi |
| Runtimes per project, env vars, repo tasks | mise |
| Packages, user systemd units | Nix + Home Manager |
| macOS system defaults, GUI apps | nix-darwin + Homebrew casks |
| NixOS system services | `ops/system-setup.sh` + `nix/modules/nixos` |
| Git hooks | lefthook (ADR-0005) |

## Why
- "One owner per concern": every target path has exactly one owner per host; `ops/validate-config.sh` enforces part of it.
- chezmoi is pure file rendering: the three run-scripts of the first design became zero, and orchestration moved to bootstrap and mise tasks.
- nixpkgs GUI coverage on macOS is uneven, so casks are canonical there.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| chezmoi run-scripts for orchestration | Rejected under "one owner per concern" (v2 of the migration plan). |
| One tool for everything (Nix alone, or chezmoi alone) | Not recorded as considered. |

## Discarded
asdf, nvm, rbenv (mise replaces them), direnv ("mise per-project env replaces it"), husky (lefthook), GUI apps through Nix on macOS.

## Consequences
- A new Home Manager `programs.*`, `services.*` or `xdg.configFile` entry needs an allowlist edit and a row in `docs/architecture/tool-ownership.md`.
- Windows native management is outside this stack (see ADR-0002).
- Global Node, pnpm and PHP come from Nix, not mise.
