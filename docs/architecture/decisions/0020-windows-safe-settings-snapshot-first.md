---
adr: 20
title: "Windows safe settings: committed settings snapshot first, opt-in step W, rollback"
status: decided-unverified
date: 2026-11-16
platforms: [windows]
areas: [settings, startup, appx, bootstrap, profiles]
permits: [hkcu-startup-disable, user-appx-removal, settings-snapshot, settings-rollback, setup-profile-selector]
forbids: [hklm-writes-in-step-w, elevated-step-w, provisioned-appx-removal, scheduled-task-changes-in-step-w, appx-install-automation, com-automation, security-settings, reboot-dependent-settings, default-setup-profile]
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

## Decision
One opt-in step W in ops/windows/bootstrap.ps1, never in the default run:
- Switches: `-WindowsSnapshot <label>`, `-WindowsSettings <label> -SetupProfile personal|work`, `-WindowsRollback <label>`. Mutually exclusive with each other and with `-ToolsOnly`, `-Export`, `-Report`, `-EnableSystemRestore`, `-ClaudeStatusLine` (exit 2). Label `^[a-z0-9][a-z0-9-]{0,39}$`.
- `-SetupProfile` is required for `-WindowsSettings`: hand-validated, case-sensitive `^(personal|work)$`; missing or any other value exits 2 before anything is read. "home" appears only in help text (home = personal), aligned with the Unix `myConfig.profile` `work|personal`. Snapshot and rollback take no profile. The profile is recorded in undo.json; there is no state file. There is no default profile.
- Closed catalogue ops/windows/windows-settings.psd1 (planned, not yet in the repo): hive-relative keys; entries with Id, Kind, Key, Value or Pattern, Target, WindowsDefault, Profiles (non-empty subset of personal, work), Scope (user|machine), Tag. Step W applies only Scope=user. Machine entries belong to ADR-0035, which defines a separate elevated `-MachineWide` mode; the HKLM, elevation and scheduled-task bans below are scoped to step W.
- Snapshot `ops/windows/settings-snapshots/<label>.json`: committed, values only, never overwritten, captured before any apply, covering ALL entries (every profile and scope). Apply and rollback require it tracked and unchanged against HEAD. Drift means the live value equals neither the snapshot nor the target: current == target is a no-op, current == snapshot is applied, anything else is drift and apply refuses (exit 3) and prints `-WindowsSnapshot <label>-<yyyymmdd>`. An entry missing from the snapshot makes apply refuse that entry (exit 3) and print the snapshot command (N7).
- N12: each catalogue Tag has a closed, hive-relative key allowlist (closed Tag set: startup, consumer, support, work-app, report-only, visual, telemetry-user). A schema test rejects an entry whose key is outside its Tag's list; no `\Policies\` key and no HKLM for Scope=user.
- Undo record `undo.json` under `%LOCALAPPDATA%\app-configs\windows-settings\<UTC>-<PID>\`, written before the first write. Exit 3 unless LOCALAPPDATA is absolute, existing and outside the repo.
- HKCU only, non-elevated, no reboot. A "sign-out" effect is allowed (visual effects).

## Catalogue content
- (a) Startup (Tag startup): `StartupApproved\Run` `MicrosoftEdgeAutoLaunch_*` (resolved by exact enumeration) and OneDrive set disabled (`03 00 00 00` + FILETIME LE). TeamsTfwStartupTask State 2 to 1, Profiles [work] only (N8: Teams is removed in personal; a schema test forbids a startup entry for a package removed in that profile). State 0 = already off (no-op).
- (b) Appx, removed for the current user only.
  - Tag consumer, Profiles both, 17 exact names (19 Appx names in total with the two support names below; the three work apps are separate): Microsoft.BingNews, Microsoft.BingWeather, Microsoft.BingSearch, Microsoft.MicrosoftSolitaireCollection, Clipchamp.Clipchamp, Microsoft.PowerAutomateDesktop, Microsoft.WindowsFeedbackHub, Microsoft.Windows.DevHome, Microsoft.Todos, Microsoft.YourPhone, MicrosoftWindows.CrossDevice, MicrosoftCorporationII.MicrosoftFamily, Microsoft.GamingApp, Microsoft.XboxGamingOverlay, Microsoft.XboxSpeechToTextOverlay, Microsoft.Xbox.TCUI, Microsoft.XboxIdentityProvider (dependents first).
  - Tag support, Profiles [personal] only: Microsoft.GetHelp, MicrosoftCorporationII.QuickAssist.
  - Tag work-app, removed in personal only: MSTeams, Microsoft.OutlookForWindows, Microsoft.MicrosoftOfficeHub.
- (c) Report-only (Tag report-only): the Work Folders tasks (print the elevated command) and the OneDrive Startup Task. A NOTICE never changes the exit code.
- (d) Protected set, never removed: ZuneMusic (Media Player), DesktopAppInstaller, WindowsStore, StorePurchaseApp, SecHealthUI, WindowsTerminal, MicrosoftCorporationII.WindowsSubsystemForLinux, frameworks VCLibs, UI.Xaml, NET.Native, WindowsAppRuntime. At runtime skip IsFramework, NonRemovable and SignatureKind System with a NOTICE.
- (e) Visual effects (Tag visual, Profiles both, Scope user, effect sign-out; documented in docs/platforms/windows/visual-effects.yaml): `VisualFXSetting`=3 (absent today; rollback deletes it); `MinAnimate` "0" (REG_SZ); `TaskbarAnimations` 0; `UserPreferencesMask` via value kind BinaryBit (byte 0-7, single-bit mask, bit 31 forbidden; drift check and rollback act on the NAMED bits only, merged into the live bytes, other bits untouched (N10)).
  - Bits: menu animation byte0 0x02, combo slide byte0 0x04, tooltip fade byte1 0x08, menu-item fade byte1 0x04, control animations byte4 0x02 (unverified; human toggle check first).
  - On this account the mask goes from `9E 1E 07 80 12 00 00 00` to `98 12 07 80 10 00 00 00`.
  - Kept on: ClearType font smoothing, thumbnails, window shadows, drag contents, translucent selection, icon-label shadows, Peek, smooth-scroll list boxes.
  - Docs say: sign out right after apply (a SystemParametersInfo write from the dialog before sign-out can overwrite the mask).
  - Visual effects must be in the catalogue before the first `windows-main` snapshot.

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

## Boundary rules (static test, to be built)
Labels: F, N and D ids (F9, F13, N1, N5, D3-i ...) are finding and design ids from the T-0055 design review, explained where used.
- R1 closed command map of canonical names with owning seams. R2 registry literals only in the HKCU seams (and the named ADR-0035 machine seams). R3 banned registry and dynamic members.
- R4 closed type allowlist (review finding F13: replaces deny-listing; covers `[wmiclass]`, `[wmi]`, `[adsi]`). R5 no `$PSDefaultParameterValues`, `$ExecutionContext`, aliases or provider prefixes (`alias:`, `function:`, `variable:`, `cert:`, `wsman:`).
- R6 per-cmdlet parameter allowlists with full names, no splatting, no positionals, first in pipeline; extended to service, task and CIM cmdlets: Set-Service Name/StartupType/ErrorAction; Stop-/Start-Service Name/ErrorAction; Disable-/Enable-ScheduledTask TaskPath/TaskName/ErrorAction; Get-CimInstance ClassName/Filter/Property/ErrorAction (N5).
- R7 New-Object TypeName/ArgumentList only (positions 0/1), no COM. R8 anchored exe strings `reg|regedit|schtasks|sc|wsl` `.exe` plus bare `reg`/`schtasks`.
- R9 `-LiteralPath` only in W functions and seams where the cmdlet supports it (N1: New-Item has no -LiteralPath in 5.1; the old extension idea is dropped; filesystem writes stay the deliberate design exclusion D3-i: the step writes only its snapshot and undo files, not covered by R9).
- R10 nested scriptblocks count as their function. A test that every `$CommandOwners` entry is still used. `[Environment]::SetEnvironmentVariable` banned.
- Static analysis has limits: it reads source text and cannot prove runtime behaviour.

## Tests to be built
W1 to W27 are the planned unit tests of step W (W1 the catalogue schema test, W25 the check that the committed snapshot covers every catalogue entry); SD-1 to SD-20 and more are seeded tests (inject one defect into a copy, assert it is caught); P1 to P12 are the ADR-0035 tests; V-tests cover the visual-effects entries. None exist yet.

Human checks (all pending except H0):
- H0 (done): all 19 Appx names (17 consumer + 2 support) and the 3 work apps are provisioned on this PC.
- H1: toggle Edge and OneDrive startup on, run `-WindowsRollback`, compare the exact bytes; Teams State 1.
- H2a: after an apply, `-WindowsSettings -DryRun` is a no-op, then a real run is a no-op with no undo directory.
- H2b: toggle Edge and OneDrive on, then `-WindowsSettings -DryRun` exits 3 with the drift message.
- H2c: after rollback, `-DryRun` is a no-op again.
- Visual effects: toggle the five UserPreferencesMask options by hand to confirm the bits, apply, sign out, compare.

Stays decided-unverified until H1.

## Consequences
- Amendment notes (wording):
  - ADR-0010: for step W's scope only, apply may run before T-0047 completes (owner decision); snapshot, undo.json and `-DryRun` replace the restore point and powercfg requirement for this non-elevated scope; the snapshot is not the phase-3 baseline.
  - ADR-0019: windows-app-automation stays forbidden except removing the closed list for the current user and re-registering those packages during `-WindowsRollback` (`Add-AppxPackage -RegisterByFamilyName -MainPackage`, no network install); windows-settings-apply is narrowed to the catalogue.
  - ADR-0011: registry tweaks stay discarded except the closed catalogue.
  - ADR-0002: step W is added to the bootstrap surface.
- Updates to T-0041 (AC4 wording) and T-0048 are dated in their tickets.
- Rollback depends on re-registration succeeding; unit-tested only until H1 (unknown on a real host).
- Amended by ADR-0034: NVIDIA global 3D settings follow the same snapshot-first rule in a separate elevated step, not step W.
- Amended by ADR-0035: personal telemetry entries and the elevated `-MachineWide` mode; step W's own HKCU-only rule is unchanged.
