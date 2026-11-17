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
  (e) assignment to a member, including `++` and `--` on a member (index assignment `$h['k'] = v` is allowed);
  (f) file redirection (stream merging such as `2>&1` is allowed); `data` statements.
  GetValue, GetValueKind, GetValueNames and GetSubKeyNames are owned members, allowed only in their R1 owners.
- R4 closed type allowlist (replaces a deny-list; so `[wmiclass]`, `[wmi]`, `[adsi]`, `[type]`, `[scriptblock]`, `[powershell]`, `[Environment]` and `Microsoft.Win32` types are rejected) for type literals, casts, parameter types, the right side of `-is`, `-isnot` and `-as` (a type literal, never a string) and the New-Object TypeName: string, char, bool, boolean, byte, int, int32, long, int64, object, array, void, switch, hashtable, ordered, pscustomobject, datetime, bitconverter, io.path, text.utf8encoding, collections.generic.list, and arrays of these (leading `System.` ignored, case-insensitive). Generic arguments are checked recursively. A New-Object TypeName is a constant with no backtick or comma, parsed as a type literal and checked the same way. No AttributeAst in scope; no type definition and no `using` statement in the script.
- R5 session state. Variables in scope: locals (parameters, assignment targets and foreach variables of the same function); `$script:` reads (the only way to read a script-level variable); `$env:` reads; `$_`, `$PSItem`, `$null`, `$true`, `$false`, `$Matches`, `$PID`. Rejected: any other unqualified name; a local named like an automatic or preference variable (a fixed 5.1 list in the test, including `$PSCmdlet`, `$ExecutionContext`, `$Host`, `$MyInvocation`, `$PSBoundParameters`, `$args`, `$input`, `$Profile`, `$PSDefaultParameterValues`, `*Preference`); assignment to `$script:`, `$global:` or `$env:`; drive-qualified variables other than `$env:` reads; strings starting with `alias:`, `function:`, `variable:`, `env:`, `cert:` or `wsman:`. No aliases; detection never reads the session: R1 rejects any name that is not an exact key, and a non-hyphenated name that is not a script function is reported as an alias. Entry-point parameters mirror the switch names (-Label, -SetupProfile, -DryRun, -MachineWide).
- R6 parameters. No splatting for any command. Every key with a parameter list is called with full names from its owner's list and no positionals; only `$BoundarySwitches` parameters take no value. Every owned external cmdlet is first in its pipeline. Value pins: ForEach-Object only `-Process` with a scriptblock literal; Where-Object only `-FilterScript` with a scriptblock literal; Select-Object only `-First` and `-ExpandProperty` (a constant not on the R3(c) list); Get-CimInstance `-ClassName` is the owner's constant class; Invoke-Native and Resolve-Program as pinned above. Output is discarded with `[void]` or `$null =`. Maximum lists: (N5) Set-Service Name/StartupType/ErrorAction; Stop-/Start-Service Name/ErrorAction; Disable-/Enable-ScheduledTask and Get-ScheduledTask TaskPath/TaskName/ErrorAction; Get-CimInstance ClassName/Filter/Property/ErrorAction; Get-AppxPackage Name/ErrorAction; Remove-AppxPackage Package/ErrorAction (never AllUsers or User); Add-AppxPackage RegisterByFamilyName/MainPackage/ErrorAction (never Path, Register, DependencyPath or ForceApplicationShutdown).
- R7 New-Object only with a named `-TypeName` (R4) and an optional `-ArgumentList`; no positionals, no COM.
- R8 tripwire: no string in scope matching `(?i)(?:^|[\s"'\\/=])(?:reg|regedit|schtasks|sc|wsl|cmd|powershell|pwsh)\.(?:exe|com)(?=$|[\s"';|&])` or `(?i)^\s*(?:reg|regedit|schtasks|sc|wsl|cmd|powershell|pwsh)\s*$`. Programs run only through the pinned forms. A printed elevated command names the script, never an executable: `Say "step W: run elevated: .\ops\windows\bootstrap.ps1 ..."`.
- R9 every map cmdlet whose metadata (resolved as in R1) has -LiteralPath takes -LiteralPath and never -Path. Exempt: New-Item (no -LiteralPath in 5.1, N1) and Join-Path. Filesystem writes stay the deliberate exclusion D3-i: only the snapshot and undo files, through Write-WindowsSettingsFile and Write-NewFile.
- R10 nested scriptblocks count as their function; no function definition inside a scope function. `[Environment]::SetEnvironmentVariable` banned.
- Runtime containment (not static; lands with each writer): every user writer seam first calls the pure Assert-WindowsSettingsTarget, and every machine writer seam first calls Assert-MachineTarget; each refuses (exit 3) unless the target is a catalogue entry for the current profile and scope: a hive-relative key equal (ordinal, case-insensitive) to a key on its Tag's N12 allowlist with no `.` or `..` segment; an Appx name in the closed removal list for the profile and not in the protected set; a re-registration family from that list. The asserts also check the value name and the value: on apply the value must equal the entry's Target; on rollback it must equal the snapshot value; for BinaryBit, only the named bits may change. Tested by unit tests of the assert functions, by each real writer seam with its owned cmdlet replaced by a recording test function (an off-catalogue target is refused with no call), and by a W test that every stubbed writer call in apply and rollback targets a catalogue entry.
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
| Set-MachinePolicyValue | T8 | M, MR | `HKLM:\`; Set-ItemProperty, Remove-ItemProperty (as above); New-Item: Path, ErrorAction (no Force: it replaces a key); Remove-Item: LiteralPath, ErrorAction |
| Set-ServiceStart | T8 | M, MR | Set-Service: Name, StartupType, ErrorAction; Stop-Service, Start-Service: Name, ErrorAction |
| Set-TaskEnabled | T8 | M, MR | Disable-ScheduledTask, Enable-ScheduledTask: TaskPath, TaskName, ErrorAction |
| Get-DeviceJoinState (detection) | T8 | A, M | Invoke-Native: ExePath, Arguments, TimeoutSeconds (pinned) |
| Get-DomainMembership (detection) | T8 | A, M | Get-CimInstance: ClassName ('Win32_ComputerSystem'), Property, ErrorAction |
| Get-MdmEnrollments (detection) | T8 | A, M | `HKLM:\`; Get-ChildItem: LiteralPath, ErrorAction; .GetValue, .GetValueNames |
| Get-EnabledLocalUserCount | T8 | M | Get-CimInstance: ClassName ('Win32_UserAccount'), Filter, Property, ErrorAction |
| (owner) Invoke-WindowsSettings | T8 | dispatcher | Get-RestorePoints, New-RestorePoint |

Assert-WindowsSettingsTarget and Assert-MachineTarget are pure and own nothing.

Decided 2026-11-17 (owner): O1 step W never creates a missing HKCU key; an entry whose key is absent is refused (exit 3). O2 ADR-0035 lists the reader seams above.

## Tests to be built
W1 to W27 are the planned unit tests of step W (W1 the catalogue schema test, W25 the check that the committed snapshot covers every catalogue entry; a T6 W test refuses Tag telemetry-user entries while corporate-device detection is not built, AC-P4 fail closed). Boundary rules are tested by BR0 to BR10 and BR-real (BRn tests Rn; BR0 the fixture and scope; BR-real the real script, anchored on the dispatcher; the R prefix belongs to the report-script tests). Seeded tests (inject one defect into a copy, assert it is caught) are the cases inside them; the design review's SD numbering is retired. P1 to P12 are the ADR-0035 tests; V-tests cover the visual-effects entries. BR tests are being added in T2; no W, P or V test exists yet.

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
