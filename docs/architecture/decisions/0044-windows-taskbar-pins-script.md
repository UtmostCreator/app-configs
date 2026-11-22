---
adr: 44
title: "Windows taskbar: a user-run script pins the profile's apps and unpins Edge, Copilot and Outlook"
status: decided-unverified
date: 2026-11-21
platforms: [windows]
areas: [windows, taskbar, profiles]
permits: [user-run-taskbar-script, start-layout-policy-hkcu, shell-unpin-verb]
forbids: [scripted-taskbar-from-bootstrap, wsl-running-taskbar-script, taskband-binary-registry-edits]
amends: [11]
supersedes: []
superseded_by: []
related: [19, 20, 21, 36, 43, T-0041]
---
# ADR-0044: Windows taskbar: a user-run script pins the profile's apps and unpins Edge, Copilot and Outlook
Status: decided-unverified 2026-11-21 (owner: "add pins for task panel for the apps we install that are avaiable and if we can add script to unpin from it copilot and edge as well as outlook"; the pin policy is not yet confirmed on Windows 11 Home) · Date: 2026-11-21 · Cites: ADR-0019 (Windows additions need an ADR and an owner decision) · Amends: ADR-0011 (registry tweaks: two HKCU policy values) · Sources: [Configure pinned apps on the taskbar](https://learn.microsoft.com/en-us/windows/configuration/taskbar/pinned-apps) (read 2026-11-21), `Get-StartApps` and the shell verbs on this PC (Windows 11 Home 26H2, build 26300)

## Decision
- `ops/windows/taskbar.ps1`, run by hand in Windows PowerShell 5.1. No other repo script, WSL or CI runs it (CI runs only its stubbed tests).
- Data: the pin order, AppIDs and the unpin list stay in [taskbar-pins.yaml](../../platforms/windows/taskbar-pins.yaml). A `chosen` row is pinned only when its `winget` id is in the profile's ADR-0043 manifest and the app is installed; `system` rows with an AppID are pinned in both profiles. Pending, unknown and Edge (PDF) rows are not pinned.
- With no action switch, the script only reports: what it would pin, what is not installed, what it would unpin.
- `-Unpin`: unpins every app whose AppID starts with a prefix in the `unpin` list (Edge `MSEdge`, new and classic Outlook, Copilot and Microsoft 365 Copilot) by invoking that app's "Unpin from taskbar" shell verb. No elevation. Works at once. English Windows only (the verb name is localised).
- `-Manifest home|work -Pin` (elevated, same account): writes `%LOCALAPPDATA%\app-configs\taskbar\LayoutModification.xml` (`PinListPlacement="Replace"`, every pin `PinGeneration="1"`) and sets `StartLayoutFile` (ExpandString) and `LockedStartLayout` (DWord 1) under `HKCU\Software\Policies\Microsoft\Windows\Explorer`, the values the "Start Layout" user policy writes. Applies at the next sign-in. Replace also drops the default pins (Edge, Store, Copilot, Outlook). It refuses when `StartLayoutFile` already points to another file (IT or another tool owns it).
- `-Undo` (elevated): removes the two values and the XML, only when they are this script's.

## Why
- The owner asked for pins from the installed apps and an unpin script. The shell verb unpin was checked on this PC: Edge, Outlook and Copilot expose "Unpin from taskbar"; no app exposes a pin verb, so pinning needs the layout policy.
- Microsoft documents the layout XML for the taskbar, re-applied at sign-in when the file's timestamp changes, and `PinGeneration` (24H2 with KB5060829 and later) lets the user unpin a policy pin without it coming back.
- AppIDs are taken from `Get-StartApps` at run time, so apps installed later are picked up by running `-Pin` again.

## Strong alternatives
| Option | Why it lost |
|---|---|
| Keep pinning by hand (taskbar.md before 2026-11-21) | Still the fallback; the owner asked for a script. |
| Write the binary `Taskband` registry value and the `User Pinned` shortcuts | Undocumented and fragile; still ruled out. |
| A catalogue entry in ADR-0020 step W | Step W writes fixed values; the layout needs a generated file and per-PC AppIDs. |
| Run it from the bootstrap | Would make the repo change the taskbar on its own; ADR-0019 keeps Windows changes owner-run. |

## Consequences
- ADR-0011 gets a dated line: two HKCU policy values for the taskbar layout, written only by this owner-run script.
- Unverified: whether Explorer honours the per-user Start layout policy on Windows 11 Home (Microsoft lists GPO, CSP, PPKG and Intune, which Home lacks as tools; the registry values are what the GPO writes). If pins do not appear after a sign-out, run `-Undo` and pin by hand ([taskbar.md](../../platforms/windows/taskbar.md)).
- Unverified: that a `DesktopApplicationID` taken from `Get-StartApps` (a `{known-folder}\path` or an exe path) pins those apps; Microsoft's examples use `MSEdge`-style ids and `.lnk` paths.
- On a corporate PC IT usually owns the Start layout policy; the script then refuses to pin, and `-Unpin` may be undone by policy.
- Tests: `tests/windows/taskbar.tests.ps1` (stubbed seams) and `tests/bash/windows-winget-manifests.bats` (pins agree with the manifests).
