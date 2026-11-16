---
adr: 27
title: "Launcher, clipboard, window management, input and macOS UX: Raycast on Windows, PowerToys"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [launcher, clipboard, window-management, input, macos-ux, tool-selection]
permits: [raycast-windows-both-profiles, powertoys-exception]
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [12, 13, 19, 20, 21, T-0041, T-0042]
---
# ADR-0027: Launcher, clipboard, window management, input and macOS UX: Raycast on Windows, PowerToys
Status: partly-decided (the Windows launcher and the PowerToys exception are decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (reverses the "Raycast/Vicinae/PowerToys Run" launcher discard; resolves the launcher, PowerToys and Ditto items) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). The desktop shell is ADR-0012 and ADR-0013's; Windows built-ins and startup are ADR-0020's.

## Owner decisions (2026-11-16, quoted)
- O1, Windows launcher on the work profile: "Raycast in both" (Raycast on Windows personal and work).
- O2, native exceptions: all approved; for this ADR that is PowerToys (part (e) below).

## Decision
One status per row.

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Launcher, Windows | n/a / n/a / Raycast for Windows (2.0, winget, all unverified) | Flow Launcher; PowerToys Command Palette | P+W | DU (owner "Raycast in both") | Manual. Discard Listary and Ueli. The Command Palette dock overlaps TrafficMonitor Lite |
| Launcher, Linux and macOS | Vicinae / Raycast (ungrouped cask, `nix/modules/darwin/homebrew.nix:58`) / n/a | Vicinae macOS beta (unverified); Ueli | P+W | Pr | Record |
| Raycast on W | allowed on every OS; AI and cloud sync off unless the employer allows (ADR-0021 P3b screening) | none | W | Pr | Record |
| Clipboard | deferred to ADR-0013 / Raycast / Win+V (P+W); Raycast | CopyQ; Ditto (discard) | P+W | Pr | Record |
| Window management | GNOME (ADR-0012) / AeroSpace and AltTab (`nix/modules/darwin/homebrew.nix:61-62`) / Snap and FancyZones | Rectangle; yabai; GlazeWM (stays discarded) | P+W | Pr | Record |
| Remap | keyd (system) / Karabiner and LinearMouse (macInput, kept as is on the W macOS host per ADR-0021 P4) / PowerToys Keyboard Manager if needed | Kanata; AutoHotkey and SharpKeys (discard) | P+W | Pr | Record |
| PowerToys (Ex) | none / none / windowsUtilities | none | P+W | DU | Manual |
| macOS UX (OS) | none / BetterDisplay (`nix/modules/darwin/homebrew.nix:63`), Ice (`:81`), NoTunes (`:82`) | Bartender; Rectangle Pro | P+W | Pr | Record |

## R1 test for the Ex row: PowerToys
- (a) licence: free, MIT, for both profiles.
- (b) native or built in: Microsoft's own utility set.
- (c) named gap against the parity pick: FancyZones, Keyboard Manager and Command Palette (no parity pick has a Windows build for window zones or remaps).
- (d) dated 2026-11-16; replaced pick: Snap only; revisit trigger: a parity tool gains a Windows build, or the work profile's employer policy forbids it.
- (e) owner approval 2026-11-16 (O2: all native exceptions approved).
- On W, turn off Mouse Without Borders (LAN listener, unverified) and Advanced Paste's AI (unverified).

## Consequences
- ADR-0011's launcher discard is reversed for Windows only. Nothing is installed by this ADR; winget ids and the Raycast Windows release are unverified.
