---
adr: 28
title: "Files: file managers, disk usage, duplicates and archives"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [file-managers, disk-usage, archives, tool-selection]
permits: [grandperspective-exception, wiztree-personal-exception]
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [19, 21, 46, 47, T-0042]
---
# ADR-0028: Files: file managers, disk usage, duplicates and archives
Status: partly-decided (the two disk-usage exceptions are decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (resolves the T-0042 Q8 7-Zip item) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md).

## Owner decision (2026-11-16, quoted)
- O2: all native exceptions approved (here: GrandPerspective on macOS, WizTree on Windows personal).

## Decision
One status per row.

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| TUI file manager | yazi | lf; broot | P+W | Pr | Record |
| GUI dual-pane | Double Commander / Nimble Commander (CM: nixpkgs has darwin builds, but ADR-0014 rules out Nix GUI apps on macOS and the Double Commander cask is disabled, so there is no install owner) / Double Commander | Marta; ForkLift; Commander One | P+W | Pr | Record |
| Disk usage, Linux | QDirStat and dust | Baobab; ncdu; gdu | P+W | Pr | Record |
| Disk usage, macOS (Ex) | GrandPerspective and dust | DaisyDisk | P+W | DU | Record. Discard TreeSize |
| Disk usage, Windows P (Ex) | WizTree | WinDirStat | P | DU | Manual |
| Disk usage, Windows W | WinDirStat (GPL) | none | W | Pr | Manual |
| Duplicates | Czkawka / not added (untested, Q9) / on demand | dupeGuru | P | Pr | Record |
| Archives | p7zip, unconditional (`nix/modules/home/dev.nix:129`) / same / built-in extraction (unverified), NanaZip optional | PeaZip; 7-Zip; WinRAR (discard) | P+W | Pr | Record; Manual |

## R1 tests for the Ex rows
| Part | GrandPerspective (macOS) | WizTree (Windows, personal only) |
|---|---|---|
| (a) licence for that profile | free (GPL) | free for personal use only, so P only |
| (b) native or built in | native macOS app | native Windows app |
| (c) named gap against the parity pick | native and maintained; QDirStat's macOS build is a community port. If the only reason were the install owner this would be CM; the owner approved it as an exception, so it stays Ex | MFT scan speed |
| (d) dated row | 2026-11-16; replaced pick QDirStat; revisit when QDirStat has a maintained macOS build | 2026-11-16; replaced pick WinDirStat (a KDirStat-family tool like QDirStat); revisit if the licence changes or work use is needed |
| (e) owner approval | 2026-11-16 | 2026-11-16 |

## Consequences
- Nothing is installed by this ADR. WizTree is not allowed on W (licence).


## Niri file manager and portal comparison (2026-11-22)

For Niri, **Nautilus is not automatically preferred**. Keep it in the safe pilot while confirming whether `xdg-desktop-portal-gnome` still routes FileChooser to it. Upstream Niri documentation says FileChooser may be explicitly routed to `xdg-desktop-portal-gtk` if Nautilus is removed; do **not** replace the ScreenCast backend in the process.

| Candidate | Advantages | Disadvantages / questions |
|---|---|---|
| **Double Commander** (already installed) | Dual-pane, bulk operations, comparisons, SFTP; known developer workflow | Not automatically a freedesktop portal FileChooser |
| **Nautilus** (current) | Existing GNOME file-portal integration; familiar file dialogs/desktop integration | GNOME application dependency, weaker advanced dual-pane functions |
| **Dux Files** | Modern integrated tabs/split features and a potential file picker alternative | Newer implementation, shell ecosystem coupling; verify chooser maturity, path handling, Nix closure |
| **Dolphin** | Very feature-rich, split views, search and network integration | KDE Frameworks/KIO dependencies, integration size |
| **Thunar / Nemo** | Simpler traditional browser, GTK ecosystem; less GNOME Shell dependency | Feature and portal differences; verify external drives, trash, network shares |

The permanent file manager and **FileChooser portal are separate open decisions**. Test keyboard launch, MIME folder defaults, uploads/save dialogs, hidden files, network mounts, removable media/udisks2/GVfs, scaling and drag/drop. [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md) covers GNOME retirement and [ADR-0046](0046-niri-desktop-installation-decision-register.md) gaps G12/G19/G24.
