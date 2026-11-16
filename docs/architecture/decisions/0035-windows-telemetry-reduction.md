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
  - Each carries `verified: false` until a human Settings-page check (N14: a human checks each Settings page).
- Machine scope, applied only by `-MachineWide` (elevated):
  - E2 `DataCollection` `DoNotShowFeedbackNotifications`=1; E3 `System` `PublishUserActivities`/`UploadUserActivities`=0; E4 `SQMClient\Windows` `CEIPEnable`=0;
  - S1 DiagTrack Disabled and Stopped (the snapshot records DelayedAutoStart; capture refuses if True (N6));
  - T1 CEIP Consolidator, UsbCeip; T2 DiskDiagnosticDataCollector; T3 `Feedback\Siuf` DmClient, DmClientOnScenarioDownload; T4 `Autochk\Proxy` set Disabled.
- Record only (no change): E1 `AllowTelemetry`, the Limit* policies, dmwappushservice (already Manual), location (Deny).
- Excluded: the Compatibility Appraiser and the other Application Experience tasks, WerSvc, plus everything in `forbids`.

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

## Execution
- `-WindowsSettings <label> -SetupProfile personal` (non-elevated) applies user scope, then prints the elevated command.
- `-WindowsSettings <label> -SetupProfile personal -MachineWide` (elevated) applies machine scope only (user entries are never written elevated), in order: checks, committed and unchanged snapshot, drift, restore point, undo.json, writes, re-read.
  - Restore point reuses Get-RestorePoints and New-RestorePoint (ADR-0007): a point under 24 h old, else create one. System Protection off exits 3 and prints the manual Control Panel step and an elevated `Enable-ComputerRestore -Drive 'C:\'` line (N13).
  - Key creation is allowed only in Set-MachinePolicyValue, for Assert-MachineTarget keys; `key_existed` is recorded; rollback removes only keys this run created, and only if empty (N2).
- `-WindowsRollback <label> [-MachineWide]` is always allowed.
- `-DryRun` with `-MachineWide` evaluates every check and refusal, prints the would-change list and writes nothing (no restore point, no undo.json, no writes); it returns the same exit code as a real run.
- Drift here means the same as in ADR-0020: the live value equals neither the snapshot nor the target (current == target is a no-op, current == snapshot is applied, otherwise exit 3).
- Exit codes: work with `-MachineWide` exits 2; `-MachineWide` non-elevated exits 3; step W elevated without `-MachineWide` exits 3.
- The `-MachineWide` help text is the explicit acknowledgement that no account on this PC is used for work. setup.md tells the owner to run `-WindowsRollback -MachineWide` before adding a work account or enrolling.

## Closed seams
- Writers: Set-ServiceStart, Set-TaskEnabled, Set-MachinePolicyValue.
- Readers: Get-DeviceJoinState (`dsregcmd.exe /status` only; returns parsed booleans only), Get-MdmEnrollments, Get-EnabledLocalUserCount.
- A pure Assert-MachineTarget with hive-relative keys (3 policy keys, DiagTrack, 6 tasks).
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
- User-scope items stay `verified: false` until a human Settings-page check; DiagTrack behaviour after a Windows feature update (it may be re-enabled) is unknown.
- Status stays decided-unverified until built and run on a real host.
