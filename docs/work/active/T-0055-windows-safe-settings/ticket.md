Source: local

# T-0055: Windows safe settings: snapshot first, profiles, telemetry, NVIDIA (feature)

Status: open (decision records written; nothing built)
Relates to: ADR-0020, ADR-0034, ADR-0035, T-0041, T-0042, T-0047, T-0048, T-0052
Note: ADR numbers 0021 to 0033 are reserved for the Windows tool-selection ADRs.

Written 2026-11-16 against main 63d206a.

## Summary
- Add an opt-in bootstrap step W: a committed settings snapshot first, then a closed catalogue of safe HKCU settings and current-user Appx removals, then rollback.
- A required `-SetupProfile personal|work` decides which entries apply (work: no telemetry, no GPU settings, work apps kept).
- ADR-0035 adds personal telemetry reduction with an elevated `-MachineWide` mode and corporate-device detection. ADR-0034 adds NVIDIA global 3D settings as a captured Profile Inspector profile (staged).
- Docs only in this change: ADRs, this ticket, visual-effects.yaml, taskbar pins and winutil notes.

## Owner decisions (2026-11-16, quoted)
- "safest options for windows also setup and installed (w/o changing critical settings etc)"; "yes add claude statu line windows implement and windows settings also safe to do"; "first save defeault settings so we can easily rollback commit them as default and then apply new".
- Q1: the snapshot is the current hand-tuned state; rollback restores it; factory defaults stay a documented manual path. Q2: label `windows-main`. Q3: OfficeHub startup unchanged. Q4: no extra settings.
- Telemetry: "disable all telemetry for home windows work profile must not touch it for now"; "allow 2 script option for telemetry or for this setup and be able to select during install". The selection is a required switch (owner chose "Required switch" over an interactive prompt).
- Built-ins per profile: "copilot for work, an[d] outlook, media player both" plus "teams work profile should stay". Teams, OfficeHub (M365 Copilot) and Outlook are work-only; Media Player (ZuneMusic) is kept in both. This SUPERSEDES the earlier single-profile keep list (2026-11-16). Quick Assist and Get Help: removed in personal, KEPT in work. All are provisioned on this PC (read-only check H0).
- NVIDIA: the owner updates the driver by hand first (this PC has 457.49 from 2020), sets values in Control Panel, then captures; staged (files first, step later); "ensure work profile won't have drivers as mandatory because video card could be AMD or Nvidia so we must be careful home profile Nvidia ok".
- Visual effects: "research what to select in here and create yaml file without ui impact or worsening ui ux on windows".
- WinUtil: "add separate link for windows to allow tools selection and installation or reference his repo".
- Taskbar: "also add yaml and if we can setup this task panel pinned"; "keepass and sync thing goes before putty"; HeidiSQL is a permanent Windows exception.
- 2026-11-16, context only: Tailscale is not used on work hosts. The owner also said "remove deepseek harness for now"; its removal is handled by the NixOS session and is not part of this change.
- 2026-11-16, asked "May -MachineWide and the NVIDIA profile step run before T-0047 closes?": "Yes, allow now" (ADR-0010 amended by ADR-0034 and ADR-0035).
- 2026-11-17, O1 (may step W create a missing HKCU key?): "Refuse, exit 3 (Recommended)". O2 (may ADR-0035 list the read-only reader seams?): "Yes, add them (Recommended)".

## Acceptance criteria
| ID | Criterion |
|---|---|
| AC1 | The snapshot (`windows-main`) is committed before any apply code exists. |
| AC2 | Rollback restores the exact snapshot values (bytes for binary values; Appx re-registered). |
| AC3 | Only the owner's list changes; the protected set is never removed. |
| AC4 | Report-only items print a NOTICE and never change the exit code. |
| AC5 | Step W is opt-in, supports `-DryRun`, runs on PowerShell 5.1, and uses the documented exit codes (2 usage, 3 refusal). |
| AC6 | Boundary tests R1 to R10 are added or strengthened; none is weakened. |
| AC7 | `bats tests/bash/adr-contract.bats` passes. |
| AC8 | Dated entries exist in the T-0041 and T-0048 tickets. |
| AC9 | The snapshot passes redaction: positive schema validation, then a deny-list; no identifiers. |
| AC10 | undo.json is written before the first write. |
| AC11 | Apply refuses on drift against the committed snapshot; drift = the live value equals neither the snapshot nor the target (current == target is a no-op, current == snapshot is applied). |
| AC12 | Docs: setup.md, visual-effects.yaml, taskbar and winutil notes. |
| AC13 | The drift message prints `-WindowsSnapshot <label>-<yyyymmdd>`. |
| AC14 | LOCALAPPDATA guard: absolute, existing, outside the repo, else exit 3. |
| AC-P1 | `-SetupProfile` is required for `-WindowsSettings`; case-sensitive `^(personal\|work)$`; otherwise exit 2 with nothing read. |
| AC-P2 | Work profile changes no telemetry setting; it applies the TeamsTfwStartupTask disable entry (work only); Teams stays installed, as do OfficeHub, Outlook, Quick Assist and Get Help. |
| AC-P3 | Personal profile removes the work apps and the support apps listed in ADR-0020. |
| AC-P4 | Corporate or managed detection (join state, domain, MDM) refuses all personal telemetry entries, fail closed. |
| AC-P5 | `-MachineWide` is elevated, personal only, single enabled account, restore point first. |
| AC-P6 | Telemetry user entries stay `verified: false` until a human Settings-page check. |
| AC-P7 | The `-WindowsRollback -MachineWide` guidance is in setup.md. |
| AC-G1 | `.nip` snapshot captured after the owner's manual driver update, never typed. |
| AC-G2 | `-NvidiaProfile` refuses work or missing profile (exit 2), exits 0 with NOTICE when no NVIDIA GPU, never installs drivers or tools. |
| AC-G3 | Tool and driver pins are verified; DryRun starts no Profile Inspector process. |

## Plan
Sequential; each task starts after the previous is done. Statuses are pending unless noted.

| Task | Work | State |
|---|---|---|
| T1 | Decision records: ADR-0020, ADR-0034, ADR-0035, amendments, this ticket, docs files (this change) | written, awaiting review |
| T2 | Boundary rules R1 to R10 and seeded tests | BR0-BR10 and BR-real added; in review |
| T3 | Catalogue `windows-settings.psd1` and test W1 (the catalogue schema test; ids W, BR and P are defined in ADR-0020; visual effects and telemetry entries before the snapshot) | pending |
| T4 | `-WindowsSnapshot` | pending |
| T5 | Capture and commit `windows-main` (owner) and test W25 (snapshot covers every entry) | pending |
| T6 | `-WindowsSettings` with the profile selector | pending |
| T7 | `-WindowsRollback` | pending |
| T8 | ADR-0035 detection and `-MachineWide` | pending |
| T9 | Docs (setup.md and the platform notes) | pending |
| T10 | Real-host human checks H1, H2a/b/c and the visual-effects sign-out check; then ADR-0020 and ADR-0035 become decided | pending |
| T11 | ADR-0034 Slice 0: owner updates the driver, round-trip test | pending (owner first) |
| T12 | ADR-0034 Slice 1: committed `.nip`, static test, docs | pending |
| T13 | ADR-0034 Slice 2: `-NvidiaProfile` | pending |

## Human checks
- H0 (done): all 19 (17 consumer + 2 support) and the 3 work apps are provisioned on this PC.
- H1: toggle Edge and OneDrive startup on, run rollback, compare exact bytes; Teams State 1.
- H2a, H2b, H2c: defined in ADR-0020 ("Tests to be built"): H2a after an apply, DryRun is a no-op then a real run is a no-op with no undo directory; H2b after toggling Edge and OneDrive on, DryRun exits 3 with the drift message; H2c after rollback DryRun is a no-op again.
- Visual effects: toggle the five UserPreferencesMask options by hand to confirm the bits, then apply, sign out and compare.

## Open
- Bit positions for control animations (byte 4, 0x02) are unverified.
- Whether a Profile Inspector import merges or replaces is unverified (T11).
- DiagTrack behaviour after a Windows feature update is unknown.
- O1 (decided 2026-11-17, owner): step W never creates a missing HKCU key; an entry whose key is absent is refused (exit 3).
- O2 (decided 2026-11-17, owner): ADR-0035 lists the reader seams Get-MachinePolicyValue, Get-ServiceStart, Get-TaskState and Get-DomainMembership. T4 is no longer blocked by it.
- T6 adds a W test that refuses telemetry-user entries until T8 detection exists (AC-P4).
- Host facts to check at T4: non-elevated Get-ScheduledTask reads of the six tasks; Win32_Service.DelayedAutoStart.
