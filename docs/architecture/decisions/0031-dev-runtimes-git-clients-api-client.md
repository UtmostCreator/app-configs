---
adr: 31
title: "Dev runtimes, Git clients and API client"
status: proposed
date: 2026-11-16
platforms: [cross, windows]
areas: [runtimes, git, api-client, tool-selection]
permits: []
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [14, 16, 19, 21, T-0042, T-0051]
---
# ADR-0031: Dev runtimes, Git clients and API client
Status: proposed (no row is owner-decided; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (resolves the Git for Windows conflict) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). Tool owners are ADR-0014's.

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Runtimes | Nix (ADR-0014). Windows host: none. Discard Node, Yarn, Python, Go, JDK 22, NuGet, Composer and MongoDB Shell there (T-0042 AC28) | mise globals | P+W | Pr | Manual |
| Git for Windows | keep: needed by bootstrap step C, the Windows hooks (T-0051), ADR-0016's Git Bash status line, and `docs/platforms/windows/setup.md` | git in WSL only | P+W | Pr | Manual |
| Git UI | lazygit, gh, delta, difft and VS Code Source Control. Discard GitHub Desktop and Git Extensions | gitui; Fork; GitKraken | P+W | Pr | Record |
| API client | Bruno. Discard Postman | Hoppscotch; Insomnia | P+W | Pr | Record |

## Consequences
- Nothing is installed or removed by this ADR.
