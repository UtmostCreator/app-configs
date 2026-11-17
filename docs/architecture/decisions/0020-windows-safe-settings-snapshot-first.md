---
adr: 20
title: "Windows safe settings: committed settings snapshot first, opt-in step W, rollback"
status: decided-unverified
date: 2026-11-16
platforms: [windows]
areas: [settings, startup, appx, bootstrap, profiles]
permits: [hkcu-startup-disable, user-appx-removal, opt-in-user-appx-removal, settings-snapshot, settings-rollback, setup-profile-selector]
forbids: [hklm-writes-in-step-w, elevated-step-w, provisioned-appx-removal, scheduled-task-changes-in-step-w, appx-install-automation, com-automation, security-settings, reboot-dependent-settings, default-setup-profile, appx-removal-without-opt-in]
amends: [2, 10, 11, 19]
supersedes: []
superseded_by: []
related: [16, 34, 35, T-0041, T-0042, T-0047, T-0048, T-0052, T-0055]
---
# ADR-0020: Windows safe settings: committed settings snapshot first, opt-in step W, rollback
Status: decided-unverified (owner decision 2026-11-16; not built. Once built, Appx removal and re-registration are unit-tested only, and the HKCU write path is verified by human check H1) · Date: 2026-11-16 · Amends: ADR-0002, ADR-0010, ADR-0011, ADR-0019 · Sources: T-0055, T-0048 windows.yaml, T-0052

Cites [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md) (anything the repo writes on the Windows host needs an ADR and an owner decision; the quotes below are that decision). Amended by ADR-0034 (NVIDIA 3D settings) and ADR-0035 (telemetry, elevated `-MachineWide` mode).

## Owner decisions (2026-11-16, quoted)
- "safest options for windows also setup and installed (w/o changing critical settings etc)"; "yes add claude statu line windows implement and windows settings also safe to do"; "first save defeault settings so we can easily rollback commit them as default and then apply new".
- Q1: the snapshot is the current hand-tuned state; rollback restores it; factory defaults stay a documented manual path. Q2: label `windows-main`. Q3: OfficeHub startup unchanged. Q4: no extra settings.
- Built-ins per profile: "copilot for work, an[d] outlook, media player both" plus "teams work profile should stay". Teams, OfficeHub (M365 Copilot) and Outlook are work-only (removed in personal); Media Player (ZuneMusic) is kept in both. This SUPERSEDES the earlier single-profile keep list (MSTeams, OfficeHub, OutlookForWindows, ZuneMusic kept), dated 2026-11-16. Quick Assist and Get Help: removed in personal, KEPT in work (owner chose "Keep in work"). All are provisioned on this PC (read-only check H0), so re-registration is feasible.
- Visual effects: "research what to select in here and create yaml file without ui impact or worsening ui ux on windows".
- Profile selector: the owner chose a "Required switch" over an interactive prompt.

## Owner decisions (2026-11-17, quoted; T-0055 T3 review)
- OQ0 "Verified only": "Approve the schema and all 71 catalogue entries for documentation and validation, not automatic execution. Only source-validated and host-confirmed entries become executable; others remain report-only." "OQ0 approval should unblock T3 implementation, not authorise unverified registry writes" (snapshot-first and fail-closed are retained).
- OQ3 to OQ9 "Adopt all": preserve Edge and OneDrive startup in the work profile; redact device-specific identifiers (the Edge value-name suffix); record AllowTelemetry, MaxTelemetryAllowed and both Limit* values read-only; prohibit unrestricted script-wide table changes (SCRIPT-STATE = no, see R5); require real-host apply and rollback verification (H1, H3, H4); profile-specific plain-text notices.
- Appx removal "Separate opt-in (-RemoveApps)": a normal profile apply never removes applications; removal needs `-RemoveApps`, a pre-removal snapshot and stated rollback limits (re-registration does not restore app data).
- Work Teams startup "Plan's rule": preserve startup enforced by policy; if management status is unknown, do not modify it; on verified unmanaged devices, allow an explicitly selected startup change. This replaces "work applies the TeamsTfwStartupTask disable".
- OQ2 "Skip with notice": an entry whose HKCU key is absent prints a NOTICE and is skipped (O1 refined under "Seams and owned commands").
- Inference recorded for owner visibility (OQ1 was not asked separately): the machine Tags telemetry-machine and telemetry-record are treated as approved for documentation and validation, because the OQ0 answer approves "the schema and all 71 catalogue entries", which include the machine entries, and because ADR-0035 (owner decisions 2026-11-16: "allow 2 script option for telemetry or for this setup and be able to select during install"; "Yes, allow now") already authorises machine-scope telemetry entries applied only by the elevated `-MachineWide` mode. They execute only through `-MachineWide`. The MaxTelemetryAllowed record added by OQ6 makes 72 entries; it is read-only.

## Decision
One opt-in step W in ops/windows/bootstrap.ps1, never in the default run:
- Switches: `-WindowsSnapshot <label>`, `-WindowsSettings <label> -SetupProfile personal|work [-RemoveApps] [-DisableTeamsStartup]`, `-WindowsRollback <label>`. Mutually exclusive with each other and with `-ToolsOnly`, `-Export`, `-Report`, `-EnableSystemRestore`, `-ClaudeStatusLine` (exit 2). `-RemoveApps` and `-DisableTeamsStartup` modify `-WindowsSettings` only: either one without `-WindowsSettings`, or with `-MachineWide`, exits 2; `-DisableTeamsStartup` also needs `-SetupProfile work` (else exit 2). Label `^[a-z0-9][a-z0-9-]{0,39}$`.
- `-SetupProfile` is required for `-WindowsSettings`: hand-validated, case-sensitive `^(personal|work)$`; missing or any other value exits 2 before anything is read. "home" appears only in help text (home = personal), aligned with the Unix `myConfig.profile` `work|personal`. Snapshot and rollback take no profile. The profile is recorded in undo.json; there is no state file. There is no default profile.
- Closed catalogue `ops/windows/windows-settings.psd1`: hive-relative keys; entries with Id, Kind, Key, ValueName or Pattern, Target, WindowsDefaultState and WindowsDefault, Profiles (non-empty subset of personal, work), Scope (user|machine), Tag, and the further fields in "Catalogue contract" below (ValueName is the registry value name, written "Value" here until 2026-11-17). Step W applies only Scope=user. Machine entries belong to ADR-0035, which defines a separate elevated `-MachineWide` mode; the HKLM, elevation and scheduled-task bans below are scoped to step W.
- Snapshot `ops/windows/settings-snapshots/<label>.json`: committed, values only, never overwritten, captured before any apply, covering ALL entries (every profile and scope). Apply and rollback require it tracked and unchanged against HEAD. Drift means the live value equals neither the snapshot nor the target: current == target is a no-op, current == snapshot is applied, anything else is drift and apply refuses (exit 3) and prints `-WindowsSnapshot <label>-<yyyymmdd>`. An entry missing from the snapshot makes apply refuse that entry (exit 3) and print the snapshot command (N7).
- N12: each catalogue Tag has a closed, hive-relative allowlist of keys with their allowed value names, services and tasks, owned by `Get-WindowsSettingsTagKeys` (table in "Catalogue contract"). Closed Tag set: startup, consumer, support, work-app, report-only, visual, telemetry-user, telemetry-machine, telemetry-record (the last two per the 2026-11-17 owner decisions). A schema test (W1) rejects an entry whose (Tag, key, value name) is outside its Tag's list; no `\Policies\` key and no HKLM for Scope=user.
- Undo record `undo.json` under `%LOCALAPPDATA%\app-configs\windows-settings\<UTC>-<PID>\`, written before the first write. Exit 3 unless LOCALAPPDATA is absolute, existing and outside the repo.
- HKCU only, non-elevated, no reboot. A "sign-out" effect is allowed (visual effects).

## Catalogue content
- (a) Startup (Tag startup): `StartupApproved\Run` `MicrosoftEdgeAutoLaunch_*` (resolved by exact enumeration) and OneDrive set disabled (`03 00 00 00` + FILETIME LE), Profiles [personal] only (owner 2026-11-17: the work profile preserves Edge and OneDrive startup). TeamsTfwStartupTask State 2 to 1, Profiles [work] only (N8: Teams is removed in personal under `-RemoveApps`; a schema test forbids a startup entry for a package removed in that profile), written only under the Teams rule in "Catalogue contract". State 0 = already off (no-op).
- (b) Appx, removed for the current user only, and only with `-RemoveApps` (owner 2026-11-17); a profile apply without it removes no app and prints one NOTICE with the count.
  - Tag consumer, Profiles both, 17 exact names (19 Appx names in total with the two support names below; the three work apps are separate): Microsoft.BingNews, Microsoft.BingWeather, Microsoft.BingSearch, Microsoft.MicrosoftSolitaireCollection, Clipchamp.Clipchamp, Microsoft.PowerAutomateDesktop, Microsoft.WindowsFeedbackHub, Microsoft.Windows.DevHome, Microsoft.Todos, Microsoft.YourPhone, MicrosoftWindows.CrossDevice, MicrosoftCorporationII.MicrosoftFamily, Microsoft.GamingApp, Microsoft.XboxGamingOverlay, Microsoft.XboxSpeechToTextOverlay, Microsoft.Xbox.TCUI, Microsoft.XboxIdentityProvider (dependents first).
  - Tag support, Profiles [personal] only: Microsoft.GetHelp, MicrosoftCorporationII.QuickAssist.
  - Tag work-app, removed in personal only: MSTeams, Microsoft.OutlookForWindows, Microsoft.MicrosoftOfficeHub.
- (c) Report-only (Tag report-only): the Work Folders tasks and the OneDrive Startup Task, each a plain-text NOTICE per profile (texts in "Catalogue contract"); no command and no task name is printed (a task name can contain the user SID). A NOTICE never changes the exit code.
- (d) Protected set, never removed, owned by `Get-WindowsSettingsProtectedAppx`: Microsoft.ZuneMusic (Media Player), Microsoft.DesktopAppInstaller, Microsoft.WindowsStore, Microsoft.StorePurchaseApp, Microsoft.SecHealthUI, Microsoft.WindowsTerminal, MicrosoftCorporationII.WindowsSubsystemForLinux; framework name prefixes (ordinal, case-insensitive) `Microsoft.VCLibs.`, `Microsoft.UI.Xaml.`, `Microsoft.NET.Native.`, `Microsoft.WindowsAppRuntime.`. At runtime skip IsFramework, NonRemovable and SignatureKind System with a NOTICE.
- (e) Visual effects (Tag visual, Profiles both, Scope user, effect sign-out; documented in docs/platforms/windows/visual-effects.yaml): `VisualFXSetting`=3 (absent today; rollback deletes it); `MinAnimate` "0" (REG_SZ); `TaskbarAnimations` 0; `UserPreferencesMask` via value kind BinaryBit (byte 0-7, single-bit mask, bit 31 forbidden; drift check and rollback act on the NAMED bits only, merged into the live bytes, other bits untouched (N10)).
  - Bits: menu animation byte0 0x02, combo slide byte0 0x04, tooltip fade byte1 0x08, menu-item fade byte1 0x04, control animations byte4 0x02 (unverified; human toggle check first).
  - On this account the mask goes from `9E 1E 07 80 12 00 00 00` to `98 12 07 80 10 00 00 00`.
  - Kept on: ClearType font smoothing, thumbnails, window shadows, drag contents, translucent selection, icon-label shadows, Peek, smooth-scroll list boxes.
  - Docs say: sign out right after apply (a SystemParametersInfo write from the dialog before sign-out can overwrite the mask).
  - Visual effects must be in the catalogue before the first `windows-main` snapshot.

## Catalogue contract (2026-11-17, T-0055 T3)
Owners. `Get-WindowsSettingsTagKeys` (N12) and `Get-WindowsSettingsProtectedAppx` (protected set) are pure functions in `ops/windows/bootstrap.ps1`. Each body is exactly one `return` of a hashtable or array literal of constants (single-quoted strings, integers, nested literals, `$true`, `$false`; no other variable, no command, no member access). They are not seams and are not in `$SeamNames`. Assert-WindowsSettingsTarget and Assert-MachineTarget take lists only from these two functions and entries only from the catalogue. W1 pins both functions, the entry Ids and the labels to this section and to ADR-0035 "Key expansion".

Fields and Kinds.
- Common: Id (`^[a-z0-9][a-z0-9-]{0,47}$`, unique), Tag, Kind, Scope, Profiles. Tags, Kinds and Ids compare ordinally; keys and value names compare ordinal case-insensitive after a canonical-form check (no hive prefix, no leading, trailing or doubled backslash, no `.` or `..` segment, no space at a segment edge, no wildcard).
- DWord (REG_DWORD; Target Int32 0 to 0x7FFFFFFF); String (REG_SZ); BinaryBit (REG_BINARY, `UserPreferencesMask` only; Byte 0-7, one-bit Mask, never byte 3 with mask 0x80, Target 0 or 1); StartupApproved (REG_BINARY, 12 bytes; Target 'disabled' = bytes 0-3 `03 00 00 00`, FILETIME written at apply; Pattern allowed); AppxRemove (Name; Target 'absent'; OptIn 'RemoveApps'); Notice (text per profile); Service (Name; Target 'Disabled' = StartupType Disabled and stopped); Task (TaskPath, TaskName; Target 'Disabled'); Record (RecordOf DWord, String or Service).
- Writer entries (every Kind except Notice and Record) carry Source, Host and Executable (below); all except AppxRemove also carry WindowsDefaultState (value, absent or unknown) and WindowsDefault only when the state is value, Verified (bool, `$false` until its human check) and Effect (none, or sign-out for Tag visual only). startup-teams also carries NoOpValues `@(0)`, OptIn 'DisableTeamsStartup', PolicyValues `@(3,4)` and RequiresUnmanaged `$true`. Record entries carry Source and Host (documentation only), never Executable.
- Targets: identity includes Scope; a BinaryBit target is (key, value name, Byte, Mask) and no whole-value entry shares its value; a Pattern conflicts with any exact name it matches under the same key; Appx names, services and tasks are unique; no Record shares a target with a writer.
- Record: no Target, WindowsDefault, Verified, Effect or Executable; never written by apply or rollback; never a drift refusal; captured by the snapshot only. N6 (capture refuses DelayedAutoStart True) applies to S1 DiagTrack only; dmwappushservice is a Record, DelayedAutoStart True on this PC, captured and never refused.

Labels and Executable.
- Source: public (a Microsoft Learn page names the hive, key and value name); adr (the 2026-11-16 decision text of this ADR or ADR-0035, or docs/platforms/windows/visual-effects.yaml, which (e) designates, names the value and the key or its trailing segments; the 2026-11-17 tables never count); chosen (the key was chosen in T3); none (no source located).
- Host (read-only reads on this PC, 2026-11-17): HC key and value present (AppxRemove: provisioned, H0; Service and Task: the object exists); HK key present, value absent; UC key absent; HP value present but the bit awaits the human toggle check.
- Executable is catalogue eligibility: Source public or adr AND Host HC. It is separate from the runtime gates (profile, `-RemoveApps`, `-DisableTeamsStartup`, `-MachineWide`, corporate-device detection, drift, the absent-key skip) and from Verified (a human check of the effect). Apply and rollback write only executable entries that pass their gates. A report-only (non-executable) writer entry prints `NOTICE step W: <Id> is report-only (not source-validated and host-confirmed); not changed`, is never written, never causes a drift refusal and never changes the exit code; the snapshot still captures it.
- Today 41 entries are executable and 22 report-only (11 HK, 4 UC, 5 HP, 2 chosen). A default personal run (`-WindowsSettings <label> -SetupProfile personal`, no modifier) writes only startup-edge and startup-onedrive (both already disabled on this PC, so no-ops), animate-windows and taskbar-animations. The seven executable telemetry-user entries stay refused until corporate-device detection exists (AC-P4), then apply on a verified unmanaged device.
- Promotion: an HK, UC or HP entry becomes HC by a dated, reviewed relabel in this section and in ADR-0035 "Key expansion", with the psd1 and the W1 oracle in the same commit, when host evidence shows the value (HK, UC: a read-only read of key and value; HP: the toggle check). The OQ0 approval covers this; no new owner decision is needed. A chosen or none Source becomes public or adr the same way, by citing a page or ADR text that names the key and value.
- Set-MachinePolicyValue and ADR-0035 N2 key creation are deferred until an E entry is promoted; until then `-MachineWide` writes only S1 and T1 to T4.

Opt-ins and gates.
- `-RemoveApps` is the only way step W removes apps. Without it no app is removed and one NOTICE gives the count. With it, every removed package needs a record in the committed snapshot (N7) and is listed in undo.json before its removal (the pre-removal snapshot). Rollback re-registers removed packages from the provisioned image (`-RegisterByFamilyName -MainPackage`); it does not restore app data, settings, sign-ins or updates, and a package that is not provisioned cannot be re-registered. HC for AppxRemove means provisioned (H0); on this PC only MSTeams, Microsoft.OutlookForWindows and Microsoft.MicrosoftOfficeHub are installed for the current user.
- Teams rule: startup-teams is written only when `-DisableTeamsStartup` is given (with `-WindowsSettings -SetupProfile work`), ADR-0035 corporate-device detection verifies the device unmanaged (every check succeeds and none is positive), and the live State is not in PolicyValues (3 and 4 are policy-enforced; mapping inferred from Microsoft Learn "StartupTaskState Enum" (https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptaskstate), unconfirmed for the registry value). A detection failure, detection not yet built, or any positive check means management unknown or managed: NOTICE, unchanged.
- Redaction: device-specific value names are stored redacted in the snapshot (`MicrosoftEdgeAutoLaunch_<redacted>`, with the match count and the exact bytes). Apply and rollback resolve the live name by exact enumeration and need exactly one match; zero or several matches print a NOTICE and skip the entry. The AC9 deny-list rejects any snapshot value-name field matching `(?i)_[0-9a-f]{32}$`; it applies to value-name fields only, never to byte strings. undo.json (local, never committed) may hold the exact name.

Notices (plain text; no command, task name or SID):
- notice-work-folders, personal: "NOTICE step W: Work Folders sync tasks are not changed by step W; they need elevation. Change them by hand only if you do not use Work Folders."
- notice-work-folders, work: "NOTICE step W: Work Folders sync tasks are not changed in the work profile; they stay as configured."
- notice-onedrive-task, personal: "NOTICE step W: the OneDrive scheduled startup task is not changed by step W; the OneDrive sign-in entry is handled by the startup entries."
- notice-onedrive-task, work: "NOTICE step W: OneDrive startup is not changed in the work profile."

N12 allowlist (`Get-WindowsSettingsTagKeys`; user Tags HKCU, machine Tags HKLM; consumer, support, work-app and report-only have no rows):
| Tag | Key | Value names |
|---|---|---|
| startup | Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run | OneDrive; pattern MicrosoftEdgeAutoLaunch_* |
| startup | Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask | State |
| visual | Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects | VisualFXSetting |
| visual | Control Panel\Desktop\WindowMetrics | MinAnimate |
| visual | Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced | TaskbarAnimations |
| visual | Control Panel\Desktop | UserPreferencesMask |
| telemetry-user | Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo | Enabled |
| telemetry-user | Software\Microsoft\Windows\CurrentVersion\Privacy | TailoredExperiencesWithDiagnosticDataEnabled |
| telemetry-user | Software\Microsoft\Siuf\Rules | NumberOfSIUFInPeriod |
| telemetry-user | Software\Microsoft\InputPersonalization | RestrictImplicitInkCollection, RestrictImplicitTextCollection |
| telemetry-user | Software\Microsoft\InputPersonalization\TrainedDataStore | HarvestContacts |
| telemetry-user | Software\Microsoft\Personalization\Settings | AcceptedPrivacyPolicy |
| telemetry-user | Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy | HasAccepted |
| telemetry-user | Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager | SubscribedContent-338389Enabled, SystemPaneSuggestionsEnabled, SoftLandingEnabled, SubscribedContent-338393Enabled, SubscribedContent-353694Enabled, SubscribedContent-353696Enabled, SubscribedContent-310093Enabled |
| telemetry-user | Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement | ScoobeSystemSettingEnabled |
| telemetry-user | Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced | Start_TrackProgs, Start_IrisRecommendations |
| telemetry-user | Control Panel\International\User Profile | HttpAcceptLanguageOptOut |
| telemetry-machine | SOFTWARE\Policies\Microsoft\Windows\DataCollection | DoNotShowFeedbackNotifications |
| telemetry-machine | SOFTWARE\Policies\Microsoft\Windows\System | PublishUserActivities, UploadUserActivities |
| telemetry-machine | SOFTWARE\Policies\Microsoft\SQMClient\Windows | CEIPEnable |
| telemetry-machine | service | DiagTrack |
| telemetry-machine | tasks | \Microsoft\Windows\Customer Experience Improvement Program\Consolidator; \Microsoft\Windows\Customer Experience Improvement Program\UsbCeip; \Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector; \Microsoft\Windows\Feedback\Siuf\DmClient; \Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload; \Microsoft\Windows\Autochk\Proxy |
| telemetry-record | SOFTWARE\Policies\Microsoft\Windows\DataCollection | AllowTelemetry, LimitDiagnosticLogCollection, LimitDumpCollection |
| telemetry-record | SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection | AllowTelemetry, MaxTelemetryAllowed |
| telemetry-record | SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location | Value |
| telemetry-record | service | dmwappushservice |
The telemetry rows equal the distinct (key, value names) of ADR-0035 "Key expansion" (W1 checks this).

Entries (72, in catalogue order; AppxRemove Ids are `appx-` plus the package name lowercased with each `.` replaced by `-`; telemetry labels per row in ADR-0035 "Key expansion"):
| Tag | Kind | Profiles | Ids | Source | Host | Executable |
|---|---|---|---|---|---|---|
| startup | StartupApproved | personal | startup-edge, startup-onedrive | adr | HC | yes |
| startup | DWord | work | startup-teams | adr | HC | yes (Teams rule) |
| consumer | AppxRemove | personal, work | the 17 consumer names of (b), in order | adr | HC (H0) | yes (`-RemoveApps`) |
| support | AppxRemove | personal | appx-microsoft-gethelp, appx-microsoftcorporationii-quickassist | adr | HC (H0) | yes (`-RemoveApps`) |
| work-app | AppxRemove | personal | appx-msteams, appx-microsoft-outlookforwindows, appx-microsoft-microsoftofficehub | adr | HC (H0) | yes (`-RemoveApps`) |
| report-only | Notice | personal, work | notice-work-folders, notice-onedrive-task | - | - | - |
| visual | DWord | personal, work | preset | adr | HK | no |
| visual | String | personal, work | animate-windows | adr | HC | yes |
| visual | DWord | personal, work | taskbar-animations | adr | HC | yes |
| visual | BinaryBit | personal, work | fade-slide-menus, combo-slide, fade-slide-tooltips, fade-menu-items, animate-controls | adr | HP | no |
| telemetry-user | DWord | personal | the 19 U-row Ids of ADR-0035 "Key expansion", in order | per row | per row | per row |
| telemetry-machine | DWord, Service, Task | personal | the 11 E2-E4, S1, T1-T4 row Ids, in order | per row | per row | per row |
| telemetry-record | Record | personal | the 7 record row Ids, in order | per row | per row | - |
The 17 consumer Ids: appx-microsoft-bingnews, appx-microsoft-bingweather, appx-microsoft-bingsearch, appx-microsoft-microsoftsolitairecollection, appx-clipchamp-clipchamp, appx-microsoft-powerautomatedesktop, appx-microsoft-windowsfeedbackhub, appx-microsoft-windows-devhome, appx-microsoft-todos, appx-microsoft-yourphone, appx-microsoftwindows-crossdevice, appx-microsoftcorporationii-microsoftfamily, appx-microsoft-gamingapp, appx-microsoft-xboxgamingoverlay, appx-microsoft-xboxspeechtotextoverlay, appx-microsoft-xbox-tcui, appx-microsoft-xboxidentityprovider.

## Why
- Owner asked for safe settings with a rollback saved first; a values-only committed snapshot is reviewable in git and independent of any Windows backup.
- A closed catalogue plus static boundary tests keeps step W from growing into the general Windows layer that ADR-0019 rules out.
- HKCU, non-elevated writes need no restore point; undo.json and `-DryRun` cover recovery.

## Classification of the snapshot (review finding F9)
A reviewed reference record like T-0048 windows.yaml, not runtime state. Owner-reviewed commits only; one host per label; values only, no identifiers. Redaction: positive schema validation first, a deny-list second. T-0052's settings.json backup stays local by design.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Snapshot to %LOCALAPPDATA% only | Not reviewable, lost with the profile; owner asked to "commit them as default". |
| Restore factory defaults on rollback | Owner Q1: the snapshot is the hand-tuned state; factory defaults stay a manual documented path. |
| Interactive profile prompt | Owner chose a required switch; a prompt breaks unattended and dry-run use. |
| Default `-SetupProfile` | Owner chose explicit selection; a default could touch a work PC. |
| Provisioned Appx removal (all users) | Needs elevation, affects other accounts, not user-scoped. |
| WinUtil or debloat scripts | Open-ended tweak sets; see docs/platforms/windows/winutil.md. |

## Discarded
Provisioned Appx removal, Appx install automation, COM automation, security settings, reboot-dependent settings, scheduled-task changes in step W, HKLM writes in step W, a default profile.

## Boundary rules (static test)
Labels: F, N and D ids (F9, N1, N5, D3-i ...) are finding and design ids from the T-0055 design review, explained where used. Specified 2026-11-17 (T-0055 T2); no change of scope, profiles or written settings.

Scope. The rules apply to the functions in `$BoundaryScope` (tests/windows/bootstrap.tests.ps1) and their nested scriptblocks. `$BoundaryScope` equals every script function reachable (names matched case-insensitively) from the entry points Invoke-WindowsSnapshot, Invoke-WindowsSettings and Invoke-WindowsRollback, which the dispatcher Invoke-BootstrapRun calls in its `-WindowsSnapshot`, `-WindowsSettings`, `-WindowsRollback` and `-MachineWide` branches; traversal stops at trusted and pinned helpers. A declared W switch without a branch fails. Those branches contain only entry-point calls, `Say` and `return`. Branch contract: the condition is a bare positive `if ($Switch)` read (or `$Switch -and ...`); each statement is one entry-point or `Say` call, or a `return` of one or of a constant; no member access; the `$hasX` and `switch` forms fail closed (a declared switch without such a branch is an error). Every seam is also in `$SeamNames`. Names, parameters, keys and pins compare ordinally; banned member names compare case-insensitively.

Whole script (inside and outside scope): every call to a W seam (the script-function `$CommandOwners` keys in the table below, minus the trusted and pinned helpers) is inside one of its listed owners; every call to an entry point is inside its dispatcher branch. Write-NewFile, Get-RestorePoints and New-RestorePoint are already called outside W, so their owner rule applies only inside scope; Say, Get-UtcStamp and Test-IsAdmin are common keys.

Maps (test data, passed to the checker as parameters): `$CommandOwners` (key -> owner -> full parameter names; keys are a cmdlet, seam or helper `Verb-Noun`, a member `.Name`, or a registry prefix `HKCU:\` / `HKLM:\`; `$null` only for member keys, prefix keys and trusted helpers), `$BoundaryCommon` (key -> full parameter names), `$BoundaryTypeAllow`, `$BoundarySwitches` (Raw, RegisterByFamilyName). A parameter-list entry written `Name=Value` pins that parameter to the constant string Value (used for the Get-CimInstance -ClassName class); a pinned parameter must be present in every call.

- Trusted helpers (outside scope, reviewed by hand; changed only by editing this list): Say, Get-UtcStamp, Test-IsAdmin (common keys); Write-NewFile (create-new writer using [IO.File]; owner Write-WindowsSettingsFile); Get-RestorePoints and New-RestorePoint (owner Invoke-WindowsSettings, T8, ADR-0007). Other shared helpers are not callable from scope.
- Pinned helpers: Invoke-Native and Resolve-Program (outside scope). No `$BoundaryScope` function other than these pinned callers calls them, and only in these exact inline forms:
  - Get-DeviceJoinState: `Invoke-Native -ExePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\dsregcmd.exe') -Arguments @('/status')`, optional `-TimeoutSeconds <int constant>`.
  - Test-WindowsSettingsCommitted: `Invoke-Native -ExePath (Resolve-Program -Name 'git.exe') -WorkingDirectory $script:RepoRoot -Arguments <array>`, optional `-TimeoutSeconds <int constant>`; the array is exactly `@('ls-files', '--error-unmatch', '--', <path>)` or `@('diff', '--quiet', '--no-ext-diff', '--no-textconv', 'HEAD', '--', <path>)`, and only <path> may be a variable.
- R1 closed command map. A command in scope is: a `$CommandOwners` key called inside one of its owners (this wins over the other cases: a seam is never callable from another function, even inside scope); a non-seam, non-entry `$BoundaryScope` function; or a `$BoundaryCommon` key. No function in scope calls an entry point. No writer seam (Set-UserRegistryValue, Remove-UserAppxPackage, Register-UserAppxPackage, Set-MachinePolicyValue, Set-ServiceStart, Set-TaskEnabled) is reachable from Invoke-WindowsSnapshot. Meta-tests on the real and the fixture maps: key grammar; every (key, owner) pair and every common key is used; `$null` lists only where allowed; owned and common keys are disjoint, and none is an R3 command; external common keys are in S1's `$safe` list; every allowlisted parameter is canonical (exact case, not an alias) in the cmdlet metadata, resolved with `-ArgumentList` set to the owner's prefix (`HKCU:\` or `HKLM:\`) or to `$env:SystemRoot`, or in the script function's param block, and its switch status matches `$BoundarySwitches`; unresolvable metadata fails. Each scope, owner and helper name is defined once, at top level; no script function is named like an external cmdlet key, a common key or an R3 command.
- R2 registry literals match `(?i)(?<![A-Za-z0-9_])(?:HKCU|HKLM|HKCR|HKU|HKCC)(?=[:\\])|HKEY_[A-Z_]+|Registry::`. In scope the only ones allowed are exactly `HKCU:\` and exactly `HKLM:\`, each in the owners of that prefix key. In those owners every path argument (-LiteralPath; -Path of New-Item) is written inline as `(Join-Path -Path '<prefix>' -ChildPath <expr>)`. Messages print hive-relative keys.
- R3 banned:
  (a) commands, never map keys: Invoke-Expression, Invoke-Command, Invoke-Item, Invoke-WebRequest, Invoke-RestMethod, Start-Process, Stop-Process, Start-Job, Add-Type, Import-Module, New-Module, New-PSDrive, Set-Alias, New-Alias, Get-Command, Get-/Set-/New-Variable, Set-Item, Clear-Item, Clear-ItemProperty, Copy-Item, Copy-ItemProperty, Move-Item, Move-ItemProperty, Rename-Item, Rename-ItemProperty, Set-Acl, Set-/New-/Remove-CimInstance, Invoke-CimMethod, Get-WmiObject, Invoke-WmiMethod, Set-WmiInstance, Register-/Set-/Unregister-ScheduledTask, Get-/Add-/Remove-AppxProvisionedPackage, Enable-/Disable-WindowsOptionalFeature, Set-ExecutionPolicy, Restart-Computer, Set-Content, Add-Content, Out-File;
  (b) the `&` and `.` invocation operators, whatever the operand;
  (c) members, as property access or call: OpenSubKey, OpenBaseKey, OpenRemoteBaseKey, FromHandle, CreateSubKey, DeleteSubKey, DeleteSubKeyTree, DeleteValue, SetValue, SetAccessControl, Flush; Invoke, InvokeReturnAsIs, InvokeWithContext, InvokeMember, InvokeScript, InvokeProvider, InvokeCommand, SessionState, NewScriptBlock, CreateInstance, CreateDelegate, DynamicInvoke; Assembly, DefinedTypes, ExportedTypes, Module, DeclaredMethods, DeclaredFields, TypeHandle; GetMethod(s), GetProperty/GetProperties, GetField(s), GetMember(s), GetConstructor(s), GetNestedType(s), GetInterface(s), GetEvent(s), GetRuntime*, GetTypes, GetTypeFromProgID, GetTypeFromCLSID, and GetType with an argument (GetBytes, GetString, GetEnumerator and GetFileName stay allowed);
  (d) a non-constant member name; static member access (property or method) on anything but an R4-listed type literal (`::new` on such a type is allowed); `.ForEach`/`.Where` with a non-scriptblock argument;
  (e) assignment to a member, including `++` and `--` on a member (index assignment `$h['k'] = v` is allowed on locals only; see R5 SCRIPT-STATE);
  (f) file redirection (stream merging such as `2>&1` is allowed); `data` statements.
  GetValue, GetValueKind, GetValueNames and GetSubKeyNames are owned members, allowed only in their R1 owners.
- R4 closed type allowlist (replaces a deny-list; so `[wmiclass]`, `[wmi]`, `[adsi]`, `[type]`, `[scriptblock]`, `[powershell]`, `[Environment]` and `Microsoft.Win32` types are rejected) for type literals, casts, parameter types, the right side of `-is`, `-isnot` and `-as` (a type literal, never a string) and the New-Object TypeName: string, char, bool, boolean, byte, int, int32, long, int64, object, array, void, switch, hashtable, ordered, pscustomobject, datetime, bitconverter, io.path, text.utf8encoding, collections.generic.list, and arrays of these (leading `System.` ignored, case-insensitive). Generic arguments are checked recursively. A New-Object TypeName is a constant with no backtick or comma, parsed as a type literal and checked the same way. No AttributeAst in scope; no type definition and no `using` statement in the script.
- R5 session state. Variables in scope: locals (parameters, assignment targets and foreach variables of the same function); `$script:` reads of names in `$BoundaryScriptReads` only (initially RepoRoot, a string; the only way to read a script-level variable; a test requires every such name to be assigned only by plain `=` at script level (no cast, comma list or compound operator) a string or number literal, or a Split-Path or Join-Path of `$PSScriptRoot`, single-quoted literals and nested such calls (no array or comma argument, no -Resolve), so a read can never yield a mutable object); `$env:` reads; `$_`, `$PSItem`, `$null`, `$true`, `$false`, `$Matches`, `$PID`. Rejected: any other unqualified name; a local named like an automatic or preference variable (a fixed 5.1 list in the test, including `$PSCmdlet`, `$ExecutionContext`, `$Host`, `$MyInvocation`, `$PSBoundParameters`, `$args`, `$input`, `$Profile`, `$PSDefaultParameterValues`, `*Preference`); assignment to `$script:`, `$global:` or `$env:`; SCRIPT-STATE (owner 2026-11-17: "no"): assignment, compound assignment, `++` or `--` on an index or member expression rooted at `$script:` or `$global:`, and any method call on such an expression; drive-qualified variables other than `$env:` reads; strings starting with `alias:`, `function:`, `variable:`, `env:`, `cert:` or `wsman:`. No aliases; detection never reads the session: R1 rejects any name that is not an exact key, and a non-hyphenated name that is not a script function is reported as an alias. Entry-point parameters mirror the switch names (-Label, -SetupProfile, -DryRun, -MachineWide, -RemoveApps, -DisableTeamsStartup); -RemoveApps and -DisableTeamsStartup are modifier switches whose dispatcher branch holds only a `Say` and `return 2` (given without `-WindowsSettings`).
- R6 parameters. No splatting for any command. Every key with a parameter list is called with full names from its owner's list and no positionals; only `$BoundarySwitches` parameters take no value. Every owned external cmdlet is first in its pipeline. Value pins: ForEach-Object only `-Process` with a scriptblock literal; Where-Object only `-FilterScript` with a scriptblock literal; Select-Object only `-First` and `-ExpandProperty` (a constant not on the R3(c) list); Get-CimInstance `-ClassName` is the owner's constant class; Invoke-Native and Resolve-Program as pinned above. Output is discarded with `[void]` or `$null =`. Maximum lists: (N5) Set-Service Name/StartupType/ErrorAction; Stop-/Start-Service Name/ErrorAction; Disable-/Enable-ScheduledTask and Get-ScheduledTask TaskPath/TaskName/ErrorAction; Get-CimInstance ClassName/Filter/Property/ErrorAction; Get-AppxPackage Name/ErrorAction; Remove-AppxPackage Package/ErrorAction (never AllUsers or User); Add-AppxPackage RegisterByFamilyName/MainPackage/ErrorAction (never Path, Register, DependencyPath or ForceApplicationShutdown).
- R7 New-Object only with a named `-TypeName` (R4) and an optional `-ArgumentList`; no positionals, no COM.
- R8 tripwire: no string in scope matching `(?i)(?:^|[\s"'\\/=])(?:reg|regedit|schtasks|sc|wsl|cmd|powershell|pwsh)\.(?:exe|com)(?=$|[\s"';|&])` or `(?i)^\s*(?:reg|regedit|schtasks|sc|wsl|cmd|powershell|pwsh)\s*$`. Programs run only through the pinned forms. A printed elevated command names the script, never an executable: `Say "step W: run elevated: .\ops\windows\bootstrap.ps1 ..."`.
- R9 every map cmdlet whose metadata (resolved as in R1) has -LiteralPath takes -LiteralPath and never -Path. Exempt: New-Item (no -LiteralPath in 5.1, N1) and Join-Path. Filesystem writes stay the deliberate exclusion D3-i: only the snapshot and undo files, through Write-WindowsSettingsFile and Write-NewFile.
- R10 nested scriptblocks count as their function; no function definition inside a scope function. `[Environment]::SetEnvironmentVariable` banned.
- Runtime containment (not static; lands with each writer): every user writer seam first calls the pure Assert-WindowsSettingsTarget, and every machine writer seam first calls Assert-MachineTarget; each refuses (exit 3) unless the target is an executable writer entry of the catalogue (never Record or Notice; "Catalogue contract") for the current profile and scope: a (Tag, hive-relative key, value name) triple on `Get-WindowsSettingsTagKeys` (key ordinal case-insensitive, no `.` or `..` segment); a service or task on that list; an Appx name in the closed removal list for the profile, under `-RemoveApps`, not matched by `Get-WindowsSettingsProtectedAppx`; a re-registration family from that list. The asserts also check the value: on apply it must equal the entry's Target; on rollback it must equal the snapshot value; for BinaryBit, only the named bits may change. Tested by unit tests of the assert functions, by each real writer seam with its owned cmdlet replaced by a recording test function (an off-catalogue or report-only target is refused with no call), and by a W test that every stubbed writer call in apply and rollback targets an executable catalogue entry.
- Static analysis has limits: it reads source text and cannot prove runtime behaviour. A local that is assigned only conditionally can still be read from the caller's scope; that reaches only non-pinned seam arguments, which runtime containment checks. Accepted risks: git honours repository config (for example `core.fsmonitor`), and the first `git.exe` on PATH is trusted, as in step C; `$env:SystemRoot` and PATH come from the parent environment, and `Update-SessionPath` (outside scope) rebuilds `$env:Path` from the user PATH, the same trust as step C.

### Seams and owned commands
Callers: S = reachable from Invoke-WindowsSnapshot; A = Invoke-WindowsSettings (user scope); M = its `-MachineWide` path; R = Invoke-WindowsRollback (MR with `-MachineWide`). Code rows name concrete functions; a writer row never names a function reachable from S.

| Seam | Lands | Callers | Owns (key: parameters) |
|---|---|---|---|
| Get-UserRegistryValue | T4 | S, A, R | `HKCU:\`; Get-Item: LiteralPath, ErrorAction; .GetValueNames, .GetValueKind, .GetValue |
| Get-UserRegistryValueNames | T4 | S, A, R | `HKCU:\`; Get-Item: LiteralPath, ErrorAction; .GetValueNames |
| Set-UserRegistryValue | T6 (removal T7) | A, R | `HKCU:\`; Set-ItemProperty: LiteralPath, Name, Value, Type, ErrorAction; Remove-ItemProperty: LiteralPath, Name, ErrorAction |
| Get-UserAppxPackage | T4 | S, A, R | Get-AppxPackage: Name, ErrorAction |
| Remove-UserAppxPackage | T6 | A | Remove-AppxPackage: Package, ErrorAction |
| Register-UserAppxPackage | T7 | R | Add-AppxPackage: RegisterByFamilyName, MainPackage, ErrorAction |
| Read-WindowsSettingsCatalogue | T3/T4 | S, A, R | Import-PowerShellDataFile: LiteralPath, ErrorAction (catalogue `ops/windows/windows-settings.psd1`) |
| Read-WindowsSettingsFile | T4 | S, A, R | Get-Content: LiteralPath, Raw, Encoding, ErrorAction; ConvertFrom-Json: InputObject |
| Write-WindowsSettingsFile | T4 | S, A | New-Item: Path, ItemType, ErrorAction; ConvertTo-Json: InputObject, Depth; Write-NewFile |
| Test-WindowsSettingsCommitted | T6 | A, R | Invoke-Native: ExePath, Arguments, WorkingDirectory, TimeoutSeconds; Resolve-Program: Name (pinned) |
| Get-MachinePolicyValue | T4 | S, M, MR | `HKLM:\`; Get-Item: LiteralPath, ErrorAction; .GetValueNames, .GetValueKind, .GetValue |
| Get-ServiceStart | T4 | S, M, MR | Get-CimInstance: ClassName ('Win32_Service'), Filter, Property, ErrorAction |
| Get-TaskState | T4 | S, M, MR | Get-ScheduledTask: TaskPath, TaskName, ErrorAction |
| Set-MachinePolicyValue | deferred until an E entry is promoted (was T8) | M, MR | `HKLM:\`; Set-ItemProperty, Remove-ItemProperty (as above); New-Item: Path, ErrorAction (no Force: it replaces a key); Remove-Item: LiteralPath, ErrorAction |
| Set-ServiceStart | T8 | M, MR | Set-Service: Name, StartupType, ErrorAction; Stop-Service, Start-Service: Name, ErrorAction |
| Set-TaskEnabled | T8 | M, MR | Disable-ScheduledTask, Enable-ScheduledTask: TaskPath, TaskName, ErrorAction |
| Get-DeviceJoinState (detection) | T8 | A, M | Invoke-Native: ExePath, Arguments, TimeoutSeconds (pinned) |
| Get-DomainMembership (detection) | T8 | A, M | Get-CimInstance: ClassName ('Win32_ComputerSystem'), Property, ErrorAction |
| Get-MdmEnrollments (detection) | T8 | A, M | `HKLM:\`; Get-ChildItem: LiteralPath, ErrorAction; .GetValue, .GetValueNames |
| Get-EnabledLocalUserCount | T8 | M | Get-CimInstance: ClassName ('Win32_UserAccount'), Filter, Property, ErrorAction |
| (owner) Invoke-WindowsSettings | T8 | dispatcher | Get-RestorePoints, New-RestorePoint |

Assert-WindowsSettingsTarget and Assert-MachineTarget are pure and own nothing.

Decided 2026-11-17 (owner): O1 step W never creates a missing HKCU key; refined the same day (OQ2, "Skip with notice"): an entry whose key is absent prints `NOTICE step W: <Id>: key absent; skipped`, is not written, and the run continues; the NOTICE never changes the exit code. The snapshot records the key as absent and rollback never creates it. Drift, an unreadable key or a value of the wrong type still refuse (exit 3). O1 applies to Scope user only; machine keys follow ADR-0035 N2 (deferred with Set-MachinePolicyValue). O2 ADR-0035 lists the reader seams above.

## Tests to be built
W1 to W27 are the planned unit tests of step W (W1 the catalogue schema test, W25 the check that the committed snapshot covers every catalogue entry; a T6 W test refuses Tag telemetry-user entries while corporate-device detection is not built, AC-P4 fail closed). Boundary rules are tested by BR0 to BR10 and BR-real (BRn tests Rn; BR0 the fixture and scope; BR-real the real script, anchored on the dispatcher; the R prefix belongs to the report-script tests). Seeded tests (inject one defect into a copy, assert it is caught) are the cases inside them; the design review's SD numbering is retired. P1 to P12 are the ADR-0035 tests; V-tests cover the visual-effects entries. BR tests exist (T2, T2.x); W1, W1g, V1 and V2 exist (T3); no P test exists yet.
W1 (T3) pins, as oracles copied from this ADR and ADR-0035: the 72 entry Ids in order, the N12 table, the protected set, and each entry's Source, Host and Executable; it also checks the psd1 syntax tree and bytes (data only, single-quoted strings, ASCII).

Human checks (all pending except H0):
- H0 (done): all 19 Appx names (17 consumer + 2 support) and the 3 work apps are provisioned on this PC.
- H1: toggle Edge and OneDrive startup on, run `-WindowsRollback`, compare the exact bytes (personal path); Teams State 1 (work path: `-SetupProfile work -DisableTeamsStartup` on a verified unmanaged device).
- H2a: after an apply, `-WindowsSettings -DryRun` is a no-op, then a real run is a no-op with no undo directory.
- H2b: toggle Edge and OneDrive on, then `-WindowsSettings -DryRun` exits 3 with the drift message.
- H2c: after rollback, `-DryRun` is a no-op again.
- Visual effects: toggle the five UserPreferencesMask options by hand to confirm the bits, apply, sign out, compare.
- H3: on a real host, `-WindowsSettings <label> -SetupProfile personal -MachineWide`, then `-WindowsRollback <label> -MachineWide`; compare S1 and T1 to T4 with the snapshot (ADR-0035).
- H4: `-WindowsSettings <label> -SetupProfile personal -RemoveApps`, then `-WindowsRollback <label>`; each removed package is registered again. On this PC the run removes MSTeams, Microsoft.OutlookForWindows and Microsoft.MicrosoftOfficeHub (the only installed catalogue packages); their app data is not restored, so the owner runs H4 only when that loss is acceptable.
- Verified flips (T10, each with its W1 expectation in the same commit): startup-edge and startup-onedrive by H1 (personal path); startup-teams by H1 (work path); visual entries by the visual-effects check; telemetry-user entries by N14; telemetry-machine writers by H3. AppxRemove entries have no Verified field; H4 verifies them. Record and Notice entries are never written.

Stays decided-unverified until H1 and H4.

## Consequences
- Amendment notes (wording):
  - ADR-0010: for step W's scope only, apply may run before T-0047 completes (owner decision); snapshot, undo.json and `-DryRun` replace the restore point and powercfg requirement for this non-elevated scope; the snapshot is not the phase-3 baseline.
  - ADR-0019: windows-app-automation stays forbidden except removing the closed list for the current user under `-RemoveApps` and re-registering those packages during `-WindowsRollback` (`Add-AppxPackage -RegisterByFamilyName -MainPackage`, no network install); windows-settings-apply is narrowed to the executable catalogue entries.
  - ADR-0011: registry tweaks stay discarded except the closed catalogue.
  - ADR-0002: step W is added to the bootstrap surface.
- Updates to T-0041 (AC4 wording) and T-0048 are dated in their tickets.
- Rollback depends on re-registration succeeding; unit-tested only until H4 (unknown on a real host); re-registration does not restore app data.
- Amended by ADR-0034: NVIDIA global 3D settings follow the same snapshot-first rule in a separate elevated step, not step W.
- Amended by ADR-0035: personal telemetry entries and the elevated `-MachineWide` mode; step W's own HKCU-only rule is unchanged.
