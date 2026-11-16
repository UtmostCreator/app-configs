---
adr: 26
title: "Editors and IDEs: VS Code, Neovim, Android Studio on Linux"
status: proposed
date: 2026-11-16
platforms: [cross, windows]
areas: [editors, ide, tool-selection]
permits: []
forbids: []
amends: []
supersedes: []
superseded_by: []
related: [8, 11, 19, 21, T-0037, T-0042]
---
# ADR-0026: Editors and IDEs: VS Code, Neovim, Android Studio on Linux
Status: proposed (no row is owner-decided; nothing here is built) · Date: 2026-11-16 · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). No existing ADR-0011 row changes. The git editor is ADR-0008's.

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| GUI IDE | VS Code | VSCodium; Zed | P+W | Pr | Record |
| Terminal editor | Neovim | Helix; Vim | P+W | Pr | Record |
| GNOME Text Editor | GNOME base on Linux, exempt from parity (tag OS, not Exempt); removal via environment.gnome.excludePackages is a T-0029 option | none | P+W | Pr | Record |
| Android (P) | Android Studio on Linux (`nix/modules/home/gui.nix:28`); macOS and Windows not added | IntelliJ CE; VS Code plus Flutter | P | Pr | Record; Deferred on macOS (mobileDev, Q9) |
| Android (W) | optional | same | W | Pr | Record |
| Discard | PhpStorm (paid); Notepad++ (fails R1 test (c)); BBEdit (catalog drift); Godot (P, by hand) | none | none | Pr | Manual |

## Consequences
- Records today's state; nothing is installed or removed.
