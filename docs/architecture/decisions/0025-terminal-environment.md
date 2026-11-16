---
adr: 25
title: "Terminal environment: terminal, multiplexer, prompt, font, PowerShell"
status: proposed
date: 2026-11-16
platforms: [cross, windows]
areas: [terminal, shell-tools, fonts, tool-selection]
permits: []
forbids: []
amends: []
supersedes: []
superseded_by: []
related: [11, 17, 19, 21, T-0042]
---
# ADR-0025: Terminal environment: terminal, multiplexer, prompt, font, PowerShell
Status: proposed (no row is owner-decided; nothing here is built) · Date: 2026-11-16 · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). No existing ADR-0011 row changes, so this ADR only relates to ADR-0011. The interactive shell is ADR-0017's.

## Decision
One status per row.

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Terminal | Ghostty / Ghostty / Windows Terminal (CM: no Ghostty Windows build, unverified) | WezTerm; Kitty; Alacritty | P+W | Pr | Record |
| GNOME Console | GNOME base on Linux, exempt from parity (OS tag); removal via environment.gnome.excludePackages is a T-0029 option | none | P+W | Pr | Record |
| Multiplexer and prompt | tmux, starship (the Windows prompt is not configured, per ADR-0019) | zellij; oh-my-posh; tide | P+W | Pr | Record |
| Font: JetBrainsMono NF | no owner today (`nix/modules/home/gui.nix:342`). Proposed owner: Home Manager (nerd-fonts.jetbrains-mono plus fonts.fontconfig.enable), plus a row in `docs/architecture/tool-ownership.md` and the `ops/validate-config.sh` allowlist if needed / cask (`nix/modules/darwin/homebrew.nix:86`) / manual | Meslo; Iosevka; Fira Code | P+W | Pr | Deferred |
| Meslo | `nix/modules/darwin/homebrew.nix:87`; drop it only in the same change that repoints `home/.chezmoitemplates/vscode/settings.full.json:678` | keep both | P+W | Pr | Deferred |
| PowerShell 7 | optional on Windows; the bootstrap stays on 5.1 | 5.1 only | P+W | Pr | Manual (windowsUtilities; T-0042 Q8 open) |
| Core CLI | Nix on every Unix host | per tool | P+W | Pr | Record (cliConvenience, devExtras: Q7) |

## Consequences
- Records today's state; the font owner and Meslo are follow-ups (I-04), not applied here.
