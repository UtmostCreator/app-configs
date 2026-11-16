---
adr: 33
title: "Communication, sync, notes and backup: Kopia plus Time Machine"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [communication, sync, notes, backup, tool-selection]
permits: [kopia-backup, time-machine-macos]
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [19, 20, 21, T-0041, T-0042]
---
# ADR-0033: Communication, sync, notes and backup: Kopia plus Time Machine
Status: partly-decided (the backup choice is decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (Telegram narrowed to P; the Syncthing deferral reversed; the T-0042 Q8 items for Vesktop, Slack and Zoom resolved) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). Teams and Outlook on Windows are ADR-0020's.

## Owner decision (2026-11-16, quoted)
- O4, backup: "Kopia + Time Machine".

## Decision
One status per row.

| App | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Backup | Kopia on every OS; Time Machine on macOS (OS, built in) as well. A synced kdbx is not a backup. Target and schedule not decided | restic | P; W: employer | DU | Deferred |
| Telegram, Vesktop (discard Discord) | today, in the personal gate (`nix/modules/home/gui.nix:349-356`) / needs a T-0042 group (personalChat; Q2/Q9) / manual | Signal; Discord; web | P | Pr | Record; Deferred (M); Manual |
| Signal | add to the personal gate (changes the linux-desktop derivation) / needs a group / manual | none | P | Pr | Deferred; Manual |
| Teams, Outlook, Windows | owned by ADR-0020 (W only) | Slack | W | see ADR-0020 (DU) | ADR-0020 |
| Teams, Outlook, Linux and macOS | workComms, offered and off by default (Q4, AC-N6). Teams on Linux: PWA (Q5) | Slack | W | Pr | Deferred |
| Slack, Zoom | workComms, off by default; on Windows W, by hand per employer | PWA | W | Pr | Deferred; Manual |
| Syncthing | Home Manager service (today) / needs a group (personalSync) / Syncthing plus Syncthing Tray (unverified) | SyncTrayzor; Nextcloud | P | Pr | Record; Deferred; Manual |
| LocalSend | today / cask today, on the W host: a suspect (LAN listener), kept as is per ADR-0021 P4 / manual | KDE Connect; Warpinator | P target | Pr | Record; removal from W deferred |
| Notes | Obsidian everywhere | Logseq; Joplin; Notesnook | P+W | Pr | Record |
| Granola | ungrouped cask on the W macOS host today. A suspect (it records meetings): in W only with employer consent. Moving it to P needs a T-0042 group | none | P; W with consent | Pr | Record |

## Consequences
- Nothing is installed by this ADR. Kopia's package availability on each OS is unverified.
