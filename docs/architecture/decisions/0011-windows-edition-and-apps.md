# ADR-0011: Windows edition and apps
Status: edition decided; app list approved as a manual list; automation OPEN · Date: 2026-11-14 (T-0041 approval), 2026-11-15 (edition, TrafficMonitor Lite) · Sources: docs/platforms/wsl/windows-and-wsl.md, `docs/work/active/T-0041-windows-app-list/ticket.md`, `docs/work/active/T-0042-install-selection/ticket.md`

Amended by ADR-0019: Windows app automation is not planned (was OPEN).

## Decision
- Edition: Windows 11 Home is enough. WSL2 needs only Virtual Machine Platform; Pro's Hyper-V Manager, Sandbox, BitLocker and Group Policy are not used. (This PC was being upgraded to Pro anyway; nothing here requires it.)
- Apps: a documented copy-only list, installed by hand with winget, one `winget install --id <id> --exact` at a time. Ids are unverified until `winget show`. Automation is open (Milestone 2).
- Selected by the parity rule (already used on macOS or Linux): Windows Terminal, JetBrainsMono Nerd Font, VS Code, Brave, Firefox, Obsidian, Bruno, LocalSend, KeePassXC, Flameshot, Telegram, Double Commander. Plus TrafficMonitor Lite, a user-approved Windows-only exception (2026-11-15).

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
HeidiSQL, Twinkle Tray (Windows-only), Ghostty (no Windows build), Raycast/Vicinae/PowerToys Run as launchers ("duplicate launchers"), Git Credential Manager (GitHub goes over SSH), registry/DSC tweaks. Deferred: Syncthing on Windows, 1Password desktop, Docker Desktop.

## Consequences
- Open: a Windows launcher, PowerToys Command Palette vs Flow Launcher (reopens "Windows search is enough").
- Candidates, not decided: PowerToys and Flow Launcher (T-0041 open question, ids unconfirmed); Ditto (named only in outside research, not in the repo). AutoHotkey is already discarded above.
- Proposed, not decided (T-0042 Q8): add Teams, Slack, Zoom, Vesktop; reject Discord, Everything, 7-Zip, Git for Windows. Conflict: docs/platforms/windows/setup.md installs Git for Windows.
