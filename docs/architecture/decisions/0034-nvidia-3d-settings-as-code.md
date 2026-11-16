---
adr: 34
title: "NVIDIA global 3D settings as code (personal profile, NVIDIA hardware only): captured Profile Inspector profile, snapshot first"
status: decided-unverified
date: 2026-11-16
platforms: [windows]
areas: [nvidia, gpu, settings, profiles]
permits: [nvidia-profile-snapshot, nvidia-profile-import, profile-inspector-elevated-step, gpu-vendor-detection]
forbids: [typed-drs-values, drs-database-file-copy, nvidia-driver-update, nvidia-app-profiles, unpinned-profile-inspector, work-profile-gpu-settings, mandatory-driver-install, amd-gpu-settings]
amends: [2, 10, 19, 20]
supersedes: []
superseded_by: []
related: [7, 35, T-0055]
---
# ADR-0034: NVIDIA global 3D settings as code (personal profile, NVIDIA hardware only): captured Profile Inspector profile, snapshot first
Status: decided-unverified (owner decision 2026-11-16; not built; staged) · Date: 2026-11-16 · Amends: ADR-0002, ADR-0010, ADR-0019, ADR-0020 · Sources: T-0055, NVIDIA Profile Inspector (MIT, https://github.com/Orbmu2k/nvidiaProfileInspector, winget id `Orbmu2k.nvidiaProfileInspector`)

Cites [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md) (anything the repo writes on the Windows host needs an ADR and an owner decision; see below). Follows the snapshot-first rule of [ADR-0020](0020-windows-safe-settings-snapshot-first.md); related to [ADR-0035](0035-windows-telemetry-reduction.md) (same profile selector).

## Owner decisions (2026-11-16, quoted)
- The owner updates the driver by hand first (this PC has 457.49 from 2020), sets values in Control Panel, then captures. Staged: files first, step later.
- "ensure work profile won't have drivers as mandatory because video card could be AMD or Nvidia so we must be careful home profile Nvidia ok".
- "first save defeault settings so we can easily rollback commit them as default and then apply new" (applies here as the snapshot-first rule).
- 2026-11-16, asked "May -MachineWide and the NVIDIA profile step run before T-0047 closes?": "Yes, allow now".

## Facts
- Driver 457.49 (2020-11-20) is installed on this PC. The owner's pasted values include settings from newer drivers (Image Scaling, Sysmem Fallback Policy, Shader Cache Size, Vulkan/OpenGL present method). So values come from a capture after the manual driver update, never typed (ADR-0010 guessed-values rule).
- NVIDIA Profile Inspector is installed by hand, version- and hash-pinned in ops/windows/nvidia/nvidia-profile.psd1 (planned) (with DriverVersion).

## Decision
- Files: `ops/windows/nvidia/snapshots/<label>.nip` (captured), ops/windows/nvidia/global-3d.nip (planned; initially a byte copy of the snapshot), the psd1 manifest. A `.nip` allowlist schema test (no paths, names or executables).
- Values are captured from the live driver, never typed; the DRS database file is never copied.
- Personal profile and NVIDIA hardware only. Work profile: no GPU settings, no driver requirement. AMD or other GPUs: untouched.
- Stages:
  - Slice 0: owner round-trip test after the driver update (export, change, import, compare).
  - Slice 1: the committed `.nip`, the static test and docs.
  - Slice 2: an elevated opt-in `-NvidiaProfile` that requires `-SetupProfile personal` (work or missing exits 2). Drift is as defined in ADR-0020 (the live value equals neither the snapshot nor the target). Order: Get-GpuVendors (`Win32_VideoController` PNPDeviceID; `VEN_10DE` required; none exits 0 with NOTICE "no NVIDIA GPU"; read failure exits 3), elevation, tool hash and version, driver version, committed snapshot, drift, undo export, `-silentImport`, re-export compare.
- `-DryRun` starts no Profile Inspector process.
- The step never installs or updates drivers or tools. A missing tool exits 3 and prints `winget install --id Orbmu2k.nvidiaProfileInspector --exact --version <pinned>`.
- Rollback: NVIDIA Control Panel "Restore", then import the snapshot. Whether import merges or replaces is unverified; settled in Slice 0.

## Why
- Typed DRS setting ids and values are version-specific guesses; a capture is exact for the installed driver.
- Profile Inspector is the established open-source tool for these settings (MIT) and supports silent import and export.
- Hardware detection keeps the step off AMD, Intel and work machines.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Typed values from the owner's list | Values from newer drivers than 457.49; would be guessed (ADR-0010). |
| Copy the DRS database file | Binary, driver-specific, may hold app profiles and paths. |
| NVIDIA App or Control Panel only (manual) | No reviewable record; kept as the manual fallback. |
| Install or update the driver in the step | Not a settings change; the owner updates by hand. |
| Unpinned Profile Inspector | Unreviewable behaviour; version and hash are pinned. |

## Discarded
Typed DRS values, DRS database file copy, driver update automation, NVIDIA app-profile (per-game) management, work-profile GPU settings, a mandatory driver install, AMD settings.

## Reconstruction of the owner's pasted values (cross-check only, not a source)
| Setting | Value | Setting | Value |
|---------|-------|---------|-------|
| Image Scaling | Off | Low Latency Mode | Ultra |
| Ambient Occlusion | Off | Max Frame Rate | 120 |
| Anisotropic Filtering | App-controlled | MFAA | Off |
| FXAA | Off | OpenGL GDI compatibility | Auto |
| Gamma correction | On | OpenGL rendering GPU | GTX 1660 Ti |
| AA Mode / AA Setting | App-controlled | Power management | Prefer maximum performance |
| Transparency AA | missing | Preferred refresh rate | Highest available |
| Background Max FPS | missing | Shader Cache Size | Driver Default |
| CUDA GPUs | All | Texture filtering: aniso sample optimization | Off |
| Sysmem Fallback Policy | Driver Default | Texture filtering: negative LOD bias | Clamp |
| DSR | Off | Texture filtering: quality | High quality |
| Texture filtering: trilinear optimization | On | Threaded optimization | Auto |
| Triple buffering | On | Vertical sync | On |
| VR pre-rendered frames | 1 | VRSS | Off |
| Vulkan/OpenGL present method | Auto | | |

Note: a global "Prefer maximum performance" power setting costs battery life on a laptop.

## Consequences
- ADR-0010 (the step may apply before T-0047 completes; owner 2026-11-16 "Yes, allow now") and ADR-0019 (DRS profile apply outside the ADR-0020 catalogue is permitted here) carry "Amended by ADR-0034" notes.
- ADR-0002 and ADR-0020 carry "Amended by ADR-0034" notes: a second, elevated opt-in step (`-NvidiaProfile`) joins the bootstrap surface in Slice 2; it is not part of step W.
- Slice 2 is unbuilt; the import merge behaviour, the exact `.nip` content and the Profile Inspector pin (version, hash) are `unknown` until Slice 0.
- Status stays decided-unverified until Slice 0 and a real-host check.
