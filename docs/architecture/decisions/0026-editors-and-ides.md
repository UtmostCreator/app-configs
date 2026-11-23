---
adr: 26
title: "Editors and IDEs: VS Code, Neovim, Android Studio on Linux"
status: partly-decided
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
Status: partly-decided (2026-11-21: the Notepad++ Windows row is owner-decided; every other row is proposed and nothing else is built) · Date: 2026-11-16 · Sources: tool-selection design round 3

**Laptop delivery · 23 November 2026 · 50% (2/4) · P1 · medium complexity.** VS Code in base profile. Android Studio in optional bundle. Open the intended workspace with multiple windows, then run a real project build and tests. Establish a PHP or JS work session before installing the mobile stack. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). ADR-0011 rows are unchanged except the Notepad++ owner exception (2026-11-21), recorded in ADR-0011 and listed in ADR-0043. The git editor is ADR-0008's.

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| GUI IDE | VS Code | VSCodium; Zed | P+W | Pr | Record |
| Terminal editor | Neovim | Helix; Vim | P+W | Pr | Record |
| GNOME Text Editor | GNOME base on Linux, exempt from parity (tag OS, not Exempt); removal via environment.gnome.excludePackages is a T-0029 option. Not installed on the GNOME-free niri install (ADR-0012) | none | P+W | Pr | Record |
| Android (P) | Android Studio on Linux (`nix/modules/home/gui.nix:28`); macOS and Windows not added | IntelliJ CE; VS Code plus Flutter | P | Pr | Record; Deferred on macOS (mobileDev, Q9) |
| Android (W) | optional | same | W | Pr | Record |
| Second editor (Windows) | Notepad++, a Windows-only owner exception like HeidiSQL (owner 2026-11-21: "for windows i think it is also good to include notepad++ latest version as a second editor"); latest version, no pin | none | P+W | D | winget manifests (ADR-0043) |
| Discard | PhpStorm (paid); BBEdit (catalog drift); Godot (P, by hand) | none | none | Pr | Manual |

## Consequences
- Records today's state; nothing is installed or removed.
