---
adr: 37
title: "System monitoring, diagnostics and device software"
status: proposed
date: 2026-11-16
platforms: [cross, windows]
areas: [monitoring, diagnostics, device-software, tool-selection]
permits: []
forbids: [mandatory-driver-install]
amends: [11]
supersedes: []
superseded_by: []
related: [19, 20, 21, 34, 35]
---
# ADR-0037: System monitoring, diagnostics and device software
Status: proposed (no row is owner-decided; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (TrafficMonitor Lite narrowed to P) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). NVIDIA settings are ADR-0034's and telemetry is ADR-0035's; the `mandatory-driver-install` ban follows ADR-0021 P3a.

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Monitor | btop everywhere. GUI: GNOME System Monitor (Linux, on the existing GNOME system only; the GNOME-free niri install has btop and no GUI monitor), Stats (macOS, ungrouped cask; OS), Task Manager (Windows) | Mission Center; iStat Menus | P+W | Pr | Record |
| Taskbar meter | TrafficMonitor Lite (Windows) | none | P | Pr | Manual |
| Diagnostics | HWiNFO64 (kernel driver, a suspect), LatencyMon, WhoCrashed (OS). Discard HWMonitor | Reliability Monitor (W) | P | Pr | Manual |
| Device software | NVIDIA (ADR-0034), Lenovo Vantage, Maono Link, Razer Synapse, Logitech G HUB, OEM USB-C driver. Never mandatory. Install only while the device is attached | Windows Update drivers (W) | P | Pr | Manual |
| Overlays, games, runtimes | Overlays, Steam and Aimlabs: P, by hand, out of scope. The VC++, .NET and VSTO runtimes are dependencies: never removed by hand | none | P; runtimes P+W | Pr | Manual |

## Consequences
- Nothing is installed or removed by this ADR.
