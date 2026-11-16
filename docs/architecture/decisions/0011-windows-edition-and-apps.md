---
adr: 11
title: "Windows edition and apps"
status: partly-decided
date: 2026-11-14
platforms: [windows]
areas: [apps, windows-edition]
permits: [windows-home, manual-app-list]
forbids: [windows-app-automation, registry-tweaks, dsc, hotkey-scripts]
amends: []
supersedes: []
superseded_by: []
related: [T-0041, T-0042]
---
# ADR-0011: Windows edition and apps
Status: edition decided; app list approved as a manual list; automation OPEN · Date: 2026-11-14 (T-0041 approval), 2026-11-15 (edition, TrafficMonitor Lite) · Sources: docs/platforms/wsl/windows-and-wsl.md, `docs/work/active/T-0041-windows-app-list/ticket.md`, `docs/work/active/T-0042-install-selection/ticket.md`

Amended by ADR-0019: Windows app automation is not planned (was OPEN).

Amended by ADR-0020 (2026-11-16): registry tweaks stay discarded except the closed settings catalogue (HKCU only, snapshot first). ADR-0020 also removes a closed list of inbox apps for the current user.

Amended by ADR-0035 (2026-11-16): registry tweaks stay discarded except the listed telemetry policy values, one service and six scheduled tasks (personal profile, elevated `-MachineWide` only).

## Decision
- Edition: Windows 11 Home is enough. WSL2 needs only Virtual Machine Platform; Pro's Hyper-V Manager, Sandbox, BitLocker and Group Policy are not used. (This PC was being upgraded to Pro anyway; nothing here requires it.)
- Apps: a documented copy-only list, installed by hand with winget, one `winget install --id <id> --exact` at a time. Ids are unverified until `winget show`. Automation is open (Milestone 2).
- Selected by the parity rule (already used on macOS or Linux): Windows Terminal, JetBrainsMono Nerd Font, VS Code, Brave, Firefox, Obsidian, Bruno, LocalSend, KeePassXC, Flameshot, Telegram, Double Commander. Plus TrafficMonitor Lite, a user-approved Windows-only exception (2026-11-15).
- Owner exception 2026-11-16: HeidiSQL is a Windows-only exception, approved like TrafficMonitor Lite (owner: "both Beekeeper Studio and hidesql"); it was previously discarded. It is a permanent Windows exception pinned on the taskbar (docs/platforms/windows/taskbar.md); Beekeeper Studio is handled by the tool-selection ADRs (0021 to 0033, in progress).

## Why
- The parity rule keeps one app per job across three OSes and the list short.
- Manual list keeps the repo out of Windows app management (see ADR-0002).

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| ShareX | Windows-only; fails the all-three-OS rule. Flameshot runs everywhere. |
| System Informer | Loads a kernel driver, needs admin; unnecessary as a permanent taskbar monitor. |
| TrafficMonitor Full | Needs admin (LibreHardwareMonitor); Lite chosen. |
| AutoHotkey, Kanata | "hotkey and remap scripts to maintain; karabiner and keyd configs do not port". |
| GlazeWM, Zebar, komorebi | "a keybinding system to design and maintain". |
| WezTerm | A second terminal; Windows Terminal is built in. |

## Discarded
Twinkle Tray (Windows-only), Ghostty (no Windows build), Raycast/Vicinae/PowerToys Run as launchers ("duplicate launchers"), Git Credential Manager (GitHub goes over SSH), registry/DSC tweaks. Deferred: Syncthing on Windows, 1Password desktop, Docker Desktop.

## Consequences
- WinUtil (ChrisTitusTech/winutil) is only an optional, manual, use-at-your-own-risk reference for tool selection and installation, documented in docs/platforms/windows/winutil.md (2026-11-16, owner: "add separate link for windows to allow tools selection and installation or reference his repo"). The repo does not run or vendor it; its Install tab only, never its Tweaks (they conflict with ADR-0020 and ADR-0035).
- Open: a Windows launcher, PowerToys Command Palette vs Flow Launcher (reopens "Windows search is enough").
- Candidates, not decided: PowerToys and Flow Launcher (T-0041 open question, ids unconfirmed); Ditto (named only in outside research, not in the repo). AutoHotkey is already discarded above.
- Proposed, not decided (T-0042 Q8): add Teams, Slack, Zoom, Vesktop; reject Discord, Everything, 7-Zip, Git for Windows. Conflict: docs/platforms/windows/setup.md installs Git for Windows.
