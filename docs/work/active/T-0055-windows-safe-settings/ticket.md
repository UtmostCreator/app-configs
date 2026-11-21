Source: local

# T-0055: Windows safe settings: snapshot first, profiles, telemetry, NVIDIA (feature)

Status: in progress (T1-T3 landed: ADRs 86ff52e, boundary checker 98d200d, catalogue ace86dd; T4 -WindowsSnapshot next; T5+ need Windows)
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
- 2026-11-17, O1 (may step W create a missing HKCU key?): "Refuse, exit 3 (Recommended)". O2 (may ADR-0035 list the read-only reader seams?): "Yes, add them (Recommended)". O1 refined the same day (OQ2): "Skip with notice".
- 2026-11-17 (T3 review), quoted in ADR-0020 "Owner decisions (2026-11-17)": OQ0 "Verified only" (schema and entries approved for documentation and validation; only source-validated and host-confirmed entries execute; the others are report-only); OQ3 to OQ9 "Adopt all"; Appx removal "Separate opt-in (-RemoveApps)"; work Teams startup "Plan's rule"; OQ2 "Skip with notice". The machine Tags are approved by inference (recorded in ADR-0020 for the owner).

## Acceptance criteria
| ID | Criterion |
|---|---|
| AC1 | The snapshot (`windows-main`) is committed before any apply code exists. |
| AC2 | Rollback restores the exact snapshot values of executable registry entries (bytes for binary values; named bits for BinaryBit) and re-registers packages removed under `-RemoveApps` (re-registration does not restore app data); the Edge entry is skipped with a NOTICE when zero or several live names match. |
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
| AC-P2 | Work profile changes no telemetry setting and removes no app without -RemoveApps; with it, only the 17 consumer apps. It changes TeamsTfwStartupTask only with `-DisableTeamsStartup`, only on a device verified unmanaged by the ADR-0035 detection (every check succeeds, none positive), and never when the live State is policy-enforced (3 or 4); otherwise it prints a NOTICE and leaves it unchanged. Edge and OneDrive startup are unchanged in work. Teams, OfficeHub, Outlook, Quick Assist and Get Help stay installed. |
| AC-P3 | With `-RemoveApps`, the personal profile removes the consumer, support and work apps listed in ADR-0020; without it, no profile removes any app. |
| AC-P4 | Corporate or managed detection (join state, domain, MDM) refuses all personal telemetry entries, fail closed. |
| AC-P5 | `-MachineWide` is elevated, personal only, single enabled account, restore point first. |
| AC-P6 | Telemetry user entries stay `verified: false` until a human Settings-page check. |
| AC-P7 | The `-WindowsRollback -MachineWide` guidance is in setup.md. |
| AC-E1 | Only executable catalogue entries (Source public or adr, Host HC) are written; report-only entries print a NOTICE, are never written and never change the exit code. |
| AC-R1 | No app is removed without `-RemoveApps`; with it, every removed package has a snapshot record and an undo.json entry first. |
| AC-S1 | An entry whose HKCU key is absent prints a NOTICE and is skipped; the run continues (O1 refined). |
| AC-G1 | `.nip` snapshot captured after the owner's manual driver update, never typed. |
| AC-G2 | `-NvidiaProfile` refuses work or missing profile (exit 2), exits 0 with NOTICE when no NVIDIA GPU, never installs drivers or tools. |
| AC-G3 | Tool and driver pins are verified; DryRun starts no Profile Inspector process. |

## Plan
Sequential; each task starts after the previous is done. Statuses are pending unless noted.

| Task | Work | State |
|---|---|---|
| T1 | Decision records: ADR-0020, ADR-0034, ADR-0035, amendments, this ticket, docs files (this change) | written, awaiting review |
| T2 | Boundary rules R1 to R10 and seeded tests | BR0-BR10 and BR-real added; in review |
| T2.x | SCRIPT-STATE checker extension (R5: closed `$script:` reads, no index, member or method mutation on `$script:`/`$global:` roots) and the `-RemoveApps` / `-DisableTeamsStartup` modifier switches in the boundary maps and fixture; before T4 | implemented; awaiting review |
| T3 | Catalogue `windows-settings.psd1` (72 entries), the pure functions Get-WindowsSettingsTagKeys and Get-WindowsSettingsProtectedAppx, tests W1, W1g, V1 and V2 (T3.0 amendment applied) | implemented; awaiting review |
| T4 | `-WindowsSnapshot` (all 72 entries, report-only included; Edge value-name redaction; W1 switches to Read-WindowsSettingsCatalogue) | pending |
| T5 | Capture and commit `windows-main` (owner) and test W25 (snapshot covers every entry) | pending |
| T6 | `-WindowsSettings` with the profile selector, `-RemoveApps`, `-DisableTeamsStartup`, report-only NOTICEs and the absent-key skip | pending |
| T7 | `-WindowsRollback` (skips report-only entries; redacted Edge name resolution; re-registration limits printed) | pending |
| T8 | ADR-0035 detection and `-MachineWide` (S1 and T1-T4 only; Set-MachinePolicyValue deferred until an E entry is promoted) | pending |
| T9 | Docs (setup.md and the platform notes) | pending |
| T10 | Real-host human checks H1, H2a/b/c, H3, H4 and the visual-effects sign-out check; Verified flips; then ADR-0020 and ADR-0035 become decided | pending |
| T11 | ADR-0034 Slice 0: owner updates the driver, round-trip test | pending (owner first) |
| T12 | ADR-0034 Slice 1: committed `.nip`, static test, docs | pending |
| T13 | ADR-0034 Slice 2: `-NvidiaProfile` | pending |

## Human checks
- H0 (done): all 19 (17 consumer + 2 support) and the 3 work apps are provisioned on this PC.
- H1: toggle Edge and OneDrive startup on, run rollback, compare exact bytes (personal path); Teams State 1 (work path, `-DisableTeamsStartup` on a verified unmanaged device).
- H2a, H2b, H2c: defined in ADR-0020 ("Tests to be built"): H2a after an apply, DryRun is a no-op then a real run is a no-op with no undo directory; H2b after toggling Edge and OneDrive on, DryRun exits 3 with the drift message; H2c after rollback DryRun is a no-op again.
- Visual effects: toggle the five UserPreferencesMask options by hand to confirm the bits, then apply, sign out and compare.
- H3, H4 and the Verified flips: defined in ADR-0020 ("Tests to be built"). H4 removes and re-registers MSTeams, Outlook and OfficeHub on this PC; their app data is not restored. H4 covers the personal profile only; a work `-RemoveApps` case (17 consumer apps) is optional.

## Open
- Bit positions for control animations (byte 4, 0x02) are unverified.
- Whether a Profile Inspector import merges or replaces is unverified (T11).
- DiagTrack behaviour after a Windows feature update is unknown.
- O1 (decided 2026-11-17, owner; refined the same day by OQ2 "Skip with notice"): step W never creates a missing HKCU key; an entry whose key is absent prints a NOTICE and is skipped, and the run continues. Machine keys follow ADR-0035 N2.
- O2 (decided 2026-11-17, owner): ADR-0035 lists the reader seams Get-MachinePolicyValue, Get-ServiceStart, Get-TaskState and Get-DomainMembership. T4 is no longer blocked by it.
- T6 adds a W test that refuses telemetry-user entries until T8 detection exists (AC-P4).
- Host facts to check at T4: non-elevated Get-ScheduledTask reads of the six tasks; Win32_Service.DelayedAutoStart.

## Progress
- 2026-11-21 audit: WIN-VIS-01 is not a live defect (windows-settings.psd1:36-40 marks every UserPreferencesMask bit Verified=$false, Executable=$false; bootstrap.ps1 only reads it); bit verification stays task T10. ADR-01: docs/reference/hotkeys.yaml:19-20 cites only ADR-0019; it should also cite ADR-0020, which amends it for HKCU snapshot/apply/rollback.
