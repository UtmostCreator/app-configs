---
adr: 35
title: "Telemetry reduction for the personal setup profile; the work profile touches no telemetry"
status: decided-unverified
date: 2026-11-16
platforms: [windows]
areas: [privacy, telemetry, settings, profiles]
permits: [personal-telemetry-reduction, machine-wide-elevated-apply, telemetry-state-snapshot, corporate-device-detection]
forbids: [hosts-file-blocking, firewall-endpoint-blocking, defender-removal, smartscreen-removal, windows-update-removal, debloater-tools, service-deletion, compatibility-appraiser-disable, work-profile-telemetry-changes, telemetry-on-managed-device, multi-account-machine-wide, default-setup-profile]
amends: [2, 10, 11, 19, 20]
supersedes: []
superseded_by: []
related: [7, 10, 34, T-0048, T-0055]
---
# ADR-0035: Telemetry reduction for the personal setup profile; the work profile touches no telemetry
Status: decided-unverified (owner decision 2026-11-16; not built) · Date: 2026-11-16 · Amends: ADR-0002, ADR-0010, ADR-0011, ADR-0019, ADR-0020 · Sources: T-0055, Microsoft Learn "Configure Windows diagnostic data in your organization" (https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization)

Cites [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md) (owner decision below). Builds on [ADR-0020](0020-windows-safe-settings-snapshot-first.md), which owns the snapshot, undo record, profile selector and catalogue; this ADR adds telemetry entries and a separate elevated `-MachineWide` mode. Amended by none yet.

## Owner decisions (2026-11-16, quoted)
- "disable all telemetry for home windows work profile must not touch it for now".
- "allow 2 script option for telemetry or for this setup and be able to select during install". The selection is a required switch: the owner chose "Required switch" over an interactive prompt (`-SetupProfile personal|work`, ADR-0020).
- 2026-11-16, asked "May -MachineWide and the NVIDIA profile step run before T-0047 closes?": "Yes, allow now". So `-MachineWide` may apply before T-0047 completes (ADR-0010 amended).
- 2026-11-17 owner: the snapshot readers below are approved (O2).
- 2026-11-17 owner (T-0055 T3 review; quoted in ADR-0020 "Owner decisions (2026-11-17)"): OQ0 "Verified only", OQ3 to OQ9 "Adopt all", OQ2 "Skip with notice". For this ADR: only entries marked executable in "Key expansion" are written; AllowTelemetry, MaxTelemetryAllowed and both Limit* values are recorded read-only; real-host apply and rollback verification (H3) is required. The machine Tags are approved by inference, recorded in ADR-0020 for the owner.

## Honesty about what is possible
- Windows Home's minimum diagnostic level is Required. `AllowTelemetry=0` is honoured only on Enterprise, Education and Server (Microsoft Learn, link above).
- This PC is already at 1 (`AllowTelemetry=1`, `MaxTelemetryAllowed=1`).
- Stopping DiagTrack is the only lever that cuts Required uploads. Microsoft recommends at least Required for update quality.

## Decision
Personal profile only, as catalogue entries with Profiles [personal] (work: nothing).
- User scope U1 to U10, applied by step W (non-elevated):
  - U1 advertising ID assert 0;
  - U2 tailored experiences assert 0;
  - U3 feedback Never (`Siuf\Rules` `NumberOfSIUFInPeriod` 0);
  - U4 inking and typing off (`InputPersonalization` Restrict* 1, `TrainedDataStore` `HarvestContacts` 0, `Personalization\Settings` `AcceptedPrivacyPolicy` 0);
  - U5 online speech off (`Speech_OneCore\...\OnlineSpeechPrivacy` `HasAccepted` 0);
  - U6 tips (`ContentDeliveryManager` `SubscribedContent-338389Enabled`, `SystemPaneSuggestionsEnabled`, `SoftLandingEnabled` 0);
  - U7 suggested content (`SubscribedContent-338393`, `-353694`, `-353696`, `-310093Enabled` 0);
  - U8 `UserProfileEngagement` `ScoobeSystemSettingEnabled` 0;
  - U9 `Explorer\Advanced` `Start_TrackProgs`, `Start_IrisRecommendations` 0;
  - U10 `International\User Profile` `HttpAcceptLanguageOptOut` 1.
  - Each carries `verified: false` (`Verified = $false`) until a human Settings-page check (N14: a human checks each Settings page). Only entries marked executable in "Key expansion" are written; the others are report-only (ADR-0020 "Catalogue contract").
- Machine scope, applied only by `-MachineWide` (elevated):
  - E2 `DataCollection` `DoNotShowFeedbackNotifications`=1; E3 `System` `PublishUserActivities`/`UploadUserActivities`=0; E4 `SQMClient\Windows` `CEIPEnable`=0 (all report-only until host-confirmed; Set-MachinePolicyValue is deferred until one is promoted);
  - S1 DiagTrack Disabled and Stopped (the snapshot records DelayedAutoStart; capture refuses if True (N6));
  - T1 CEIP Consolidator, UsbCeip; T2 DiskDiagnosticDataCollector; T3 `Feedback\Siuf` DmClient, DmClientOnScenarioDownload; T4 `Autochk\Proxy` set Disabled.
- Record only (no change; ADR-0020 Record semantics: never written, never a drift refusal, captured by the snapshot): E1 `AllowTelemetry` (HKLM `SOFTWARE\Policies\Microsoft\Windows\DataCollection` and `SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection`), `MaxTelemetryAllowed` (the second key), the Limit* policies `LimitDiagnosticLogCollection` and `LimitDumpCollection`, dmwappushservice (already Manual), location (HKLM, Deny).
- Excluded: the Compatibility Appraiser and the other Application Experience tasks, WerSvc, plus everything in `forbids`.

## Key expansion (2026-11-17, T-0055 T3)
Labels as in ADR-0020 "Catalogue contract" (Source: public, adr, chosen, none; Host: HC, HK, UC). Executable = Source public or adr AND Host HC. Host values were read on this PC on 2026-11-17 (dmwappushservice DelayedAutoStart from the design review's host read).
Sources:
- [MC] Microsoft Learn, "Manage connections from Windows operating system components to Microsoft services" (https://learn.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services), read 2026-11-17.
- [DD] Microsoft Learn, "Configure Windows diagnostic data in your organization" (https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization), read 2026-11-17.
- [ADR] this ADR's 2026-11-16 Decision text. [HOST] a read-only read on this PC.
| Ref | Id | Hive and key | Value name | Target | Source | Citation | Host | Executable |
|---|---|---|---|---|---|---|---|---|
| U1 | tel-advertising-id | HKCU Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo | Enabled | 0 | chosen | ADR named no key; key chosen ([MC] lists the HKLM variant) | HC (0) | no |
| U2 | tel-tailored-experiences | HKCU Software\Microsoft\Windows\CurrentVersion\Privacy | TailoredExperiencesWithDiagnosticDataEnabled | 0 | chosen | ADR named no key; key chosen from [HOST] ([MC] names only a policy under a Policies key) | HC (0) | no |
| U3 | tel-feedback-frequency | HKCU Software\Microsoft\Siuf\Rules | NumberOfSIUFInPeriod | 0 | public | [MC]; [ADR] | UC | no |
| U4 | tel-implicit-ink | HKCU Software\Microsoft\InputPersonalization | RestrictImplicitInkCollection | 1 | public | [MC]; [ADR] | HC (0) | yes |
| U4 | tel-implicit-text | HKCU Software\Microsoft\InputPersonalization | RestrictImplicitTextCollection | 1 | public | [MC]; [ADR] | HC (0) | yes |
| U4 | tel-harvest-contacts | HKCU Software\Microsoft\InputPersonalization\TrainedDataStore | HarvestContacts | 0 | adr | [ADR]; no public page located in [MC] or [DD] | HC (1) | yes |
| U4 | tel-personalization-policy | HKCU Software\Microsoft\Personalization\Settings | AcceptedPrivacyPolicy | 0 | adr | [ADR]; no public page located in [MC] or [DD] | HC (1) | yes |
| U5 | tel-online-speech | HKCU Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy | HasAccepted | 0 | public | [MC]; [ADR] | UC | no |
| U6 | tel-tips-338389 | HKCU Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager | SubscribedContent-338389Enabled | 0 | adr | [ADR]; no public page located in [MC] or [DD] | HC (1) | yes |
| U6 | tel-system-pane-suggestions | same key | SystemPaneSuggestionsEnabled | 0 | adr | [ADR]; no public page located in [MC] or [DD] | HC (1) | yes |
| U6 | tel-soft-landing | same key | SoftLandingEnabled | 0 | adr | [ADR]; no public page located in [MC] or [DD] | HC (1) | yes |
| U7 | tel-suggested-338393 | same key | SubscribedContent-338393Enabled | 0 | none | [ADR] shorthand names no key; key and "Enabled" suffix inferred | HK | no |
| U7 | tel-suggested-353694 | same key | SubscribedContent-353694Enabled | 0 | none | as above | HK | no |
| U7 | tel-suggested-353696 | same key | SubscribedContent-353696Enabled | 0 | none | as above | HK | no |
| U7 | tel-suggested-310093 | same key | SubscribedContent-310093Enabled | 0 | none | as above | HK | no |
| U8 | tel-scoobe | HKCU Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement | ScoobeSystemSettingEnabled | 0 | adr | [ADR] | UC | no |
| U9 | tel-track-progs | HKCU Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced | Start_TrackProgs | 0 | public | [MC]; [ADR] | HK | no |
| U9 | tel-iris-recommendations | same key | Start_IrisRecommendations | 0 | adr | [ADR] | HK | no |
| U10 | tel-accept-language-optout | HKCU Control Panel\International\User Profile | HttpAcceptLanguageOptOut | 1 | public | [MC]; [ADR] | HK | no |
| E2 | tel-m-feedback-notifications | HKLM SOFTWARE\Policies\Microsoft\Windows\DataCollection | DoNotShowFeedbackNotifications | 1 | public | [MC]; [ADR] | HK | no |
| E3 | tel-m-publish-activities | HKLM SOFTWARE\Policies\Microsoft\Windows\System | PublishUserActivities | 0 | public | [MC]; [ADR] | HK | no |
| E3 | tel-m-upload-activities | same key | UploadUserActivities | 0 | public | [MC]; [ADR] | HK | no |
| E4 | tel-m-ceip | HKLM SOFTWARE\Policies\Microsoft\SQMClient\Windows | CEIPEnable | 0 | adr | [ADR] ("3 policy keys"; the non-policy SQMClient\Windows CEIPEnable is already 0) | UC | no |
| S1 | tel-m-diagtrack | service DiagTrack | StartMode | Disabled, stopped | adr | [ADR]; N6 applies to this row only | HC (Auto, Running, DelayedAutoStart False) | yes |
| T1 | tel-m-task-consolidator | task \Microsoft\Windows\Customer Experience Improvement Program\Consolidator | State | Disabled | adr | [ADR] | HC (Ready) | yes |
| T1 | tel-m-task-usbceip | task \Microsoft\Windows\Customer Experience Improvement Program\UsbCeip | State | Disabled | adr | [ADR] | HC (Ready) | yes |
| T2 | tel-m-task-diskdiag | task \Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector | State | Disabled | adr | [ADR] (name completed from [HOST]) | HC (Ready) | yes |
| T3 | tel-m-task-dmclient | task \Microsoft\Windows\Feedback\Siuf\DmClient | State | Disabled | adr | [ADR] | HC (Ready) | yes |
| T3 | tel-m-task-dmclient-download | task \Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload | State | Disabled | adr | [ADR] | HC (Ready) | yes |
| T4 | tel-m-task-autochk-proxy | task \Microsoft\Windows\Autochk\Proxy | State | Disabled | adr | [ADR] | HC (Ready) | yes |
| E1 | rec-allowtelemetry-policy | HKLM SOFTWARE\Policies\Microsoft\Windows\DataCollection | AllowTelemetry | record | chosen | [DD] names the policy "Allow diagnostic data" without a registry path | HK | - |
| E1 | rec-allowtelemetry-current | HKLM SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection | AllowTelemetry | record | chosen | [HOST] live value | HC (1) | - |
| E1 | rec-maxtelemetry-current | same key | MaxTelemetryAllowed | record | adr | [ADR] "Honesty about what is possible"; [HOST] | HC (1) | - |
| REC | rec-limit-diaglog | HKLM SOFTWARE\Policies\Microsoft\Windows\DataCollection | LimitDiagnosticLogCollection | record | chosen | [DD] policy "Limit diagnostic log collection", MDM System/LimitDiagnosticLogCollection; registry name inferred | HK | - |
| REC | rec-limit-dump | same key | LimitDumpCollection | record | chosen | [DD] policy "Limit dump collection", MDM System/LimitDumpCollection; registry name inferred | HK | - |
| REC | rec-dmwappush | service dmwappushservice | StartMode | record | adr | [ADR] | HC (Manual, DelayedAutoStart True; captured, never refused) | - |
| REC | rec-location | HKLM SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location | Value | record | adr | [ADR] "location (Deny)" | HC ('Deny') | - |
Executable: 14 (U4 x4, U6 x3, S1, T1 to T4); `-MachineWide` writes only S1 and T1 to T4. Records are never written.

## Corporate-device detection
Read once before any write; values are printed, never identities.
- Refuse all personal telemetry entries (user and machine), exit 3, no override, when any of these holds:
  - `dsregcmd /status` shows AzureAdJoined, EnterpriseJoined or DomainJoined YES (each field exactly once as YES|NO; a non-zero exit, timeout, missing or unparsable field is a failure);
  - `Win32_ComputerSystem.PartOfDomain` is True;
  - MDM: any `HKLM\SOFTWARE\Microsoft\Enrollments` GUID subkey with a non-empty ProviderID, an enrolled EnrollmentState, a UPN or a DiscoveryServiceFullURL (only the shapes recorded on this PC are allowed (N3)).
- WorkplaceJoined YES: refuse telemetry entries (same scopes).
- Any detection failure: refuse (fail closed).
- More than one enabled local account: `-MachineWide` refuses (user scope stays allowed).
- This PC today: all NO, PartOfDomain False, no MDM, 1 enabled account.
- ADR-0020's Teams rule reuses this detection: "verified unmanaged" means every check above succeeds and none is positive; anything else (a failure, detection not yet built, a positive check) is management unknown or managed, and TeamsTfwStartupTask is left unchanged.

## Execution
- `-WindowsSettings <label> -SetupProfile personal` (non-elevated) applies user scope, then prints the elevated command.
- `-WindowsSettings <label> -SetupProfile personal -MachineWide` (elevated) applies machine scope only (user entries are never written elevated), in order: checks, committed and unchanged snapshot, drift, restore point, undo.json, writes, re-read.
  - Restore point reuses Get-RestorePoints and New-RestorePoint (ADR-0007): a point under 24 h old, else create one. System Protection off exits 3 and prints the manual Control Panel step and an elevated `Enable-ComputerRestore -Drive 'C:\'` line (N13).
  - Key creation is allowed only in Set-MachinePolicyValue, for Assert-MachineTarget keys; `key_existed` is recorded; rollback removes only keys this run created, and only if empty (N2). Set-MachinePolicyValue and this key creation are deferred (owner 2026-11-17, "Verified only") until an E entry is promoted to executable; until then `-MachineWide` writes only S1 and T1 to T4.
- `-WindowsRollback <label> [-MachineWide]` is always allowed.
- `-DryRun` with `-MachineWide` evaluates every check and refusal, prints the would-change list and writes nothing (no restore point, no undo.json, no writes); it returns the same exit code as a real run.
- Drift here means the same as in ADR-0020: the live value equals neither the snapshot nor the target (current == target is a no-op, current == snapshot is applied, otherwise exit 3).
- Exit codes: work with `-MachineWide` exits 2; `-MachineWide` non-elevated exits 3; step W elevated without `-MachineWide` exits 3.
- The `-MachineWide` help text is the explicit acknowledgement that no account on this PC is used for work. setup.md tells the owner to run `-WindowsRollback -MachineWide` before adding a work account or enrolling.

## Closed seams
- Writers: Set-ServiceStart, Set-TaskEnabled, Set-MachinePolicyValue (sets or removes a value; creates only Assert-MachineTarget keys (N2); on rollback removes only keys a run created, when empty; deferred until an E entry is promoted).
- Readers: detection Get-DeviceJoinState (`dsregcmd.exe /status` only; parsed booleans only), Get-DomainMembership (Win32_ComputerSystem PartOfDomain only), Get-MdmEnrollments, Get-EnabledLocalUserCount; snapshot readers Get-MachinePolicyValue, Get-ServiceStart, Get-TaskState (read only, used by `-WindowsSnapshot`, non-elevated).
- Each seam's commands and callers are listed in ADR-0020 "Boundary rules".
- A pure Assert-MachineTarget that reads `Get-WindowsSettingsTagKeys` (telemetry-machine: 3 policy keys, DiagTrack, 6 tasks), keeps no list of its own, accepts only executable writer entries and refuses Record entries.
- Tests P1 to P12 plus dsregcmd and MDM fixtures (to be built).

## Why
- The owner wants personal telemetry reduced and the work profile left untouched.
- A work or managed PC may be under policy; touching telemetry there is unsafe and may conflict with the employer. Detection fails closed.
- Elevation and HKLM writes are kept out of step W (ADR-0020) by a separate, explicitly requested mode with its own restore point.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| `AllowTelemetry=0` | Not honoured on Home; would be a false promise. |
| hosts-file or firewall endpoint blocking | Breaks updates and Store, fragile; in `forbids`. |
| Debloater tools (O&O ShutUp10, WPD and similar) | Open-ended, unreviewed tweak sets; in `forbids`. |
| Disable the Compatibility Appraiser | Feeds update safety blocks; excluded. |
| Interactive profile prompt | Owner chose a required switch. |

## Discarded
Defender or SmartScreen removal, Windows Update removal, service deletion, telemetry changes on a managed or work profile, a default profile, machine-wide changes with more than one enabled account.

## Consequences
- Amendment notes:
  - ADR-0002: an elevated opt-in `-MachineWide` mode exists beside the single elevated WSL step.
  - ADR-0011: registry tweaks stay discarded except the listed policy values, one service and six scheduled tasks (and the ADR-0020 catalogue).
  - ADR-0010: `-MachineWide` may apply before T-0047 completes (owner decision above).
  - ADR-0019: machine-scope settings apply under this ADR.
  - ADR-0020: its HKLM, elevation and scheduled-task bans apply to step W only; this ADR adds the separate mode.
- Machine-scope snapshot entries are part of the same committed snapshot (ADR-0020), captured before any apply.
- User-scope items stay `verified: false` until a human Settings-page check (N14); machine writers stay `Verified = $false` until H3 (ADR-0020); DiagTrack behaviour after a Windows feature update (it may be re-enabled) is unknown.
- Status stays decided-unverified until built and H3 passes on a real host.
