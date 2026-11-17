<#
.SYNOPSIS
  Takes a Windows 11 PC to a NixOS-WSL distro named NixOS configured by this
  repo: /etc/nixos (stock NixOS-WSL) + ops/system-setup.sh + nixos-rebuild,
  then standalone Home Manager through ops/install.sh.

.DESCRIPTION
  Re-runnable. It reads the state on each run and skips finished steps; there
  is no state file. Windows PowerShell 5.1, ASCII only.

  powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1
      [-DryRun] [-EnableSystemRestore] [-Export <label>] [-Report <label>]
      [-ToolsOnly] [-ClaudeStatusLine]

  Exit codes: 0 done; 1 failed; 2 bad arguments; 3 stopped for a human step
  (reboot, elevate or de-elevate, a missing precondition).

  -DryRun runs only the read-only probes, prints the step that would run,
  returns the exit code a real run would, and writes nothing on Windows (no
  report, restore point, export, download or directory). It does start the
  distro for its read-only probes (a stopped NixOS becomes Running; the probes
  write and delete one temp file in /tmp) and says so first. It skips the
  nix-shell -p git origin read in step 6. Where the real result depends on state a
  dry run cannot read (a clone that is behind and may have local changes while the
  distro has no git, or Windows git cannot compare, for example because it is
  missing), it says so plainly with the cause and returns 0; everywhere else the code is the real one. Past a step
  that would create the distro, WSL-side state is unknown and is assumed "not
  done".

  Step C (commit tooling) runs first, before the reboot check and any WSL step, in
  non-elevated runs only: chezmoi, gitleaks and lefthook through winget (ids are
  pinned, versions are not), then `lefthook install` in the repo unless a hook
  is already there or core.hooksPath is set. -ToolsOnly runs only step C (an
  elevated -ToolsOnly exits 3). winget is called without
  --accept-source-agreements; if it needs them the run exits 3 and prints the
  command for you to decide.

  -ClaudeStatusLine (opt-in; never part of the default run; non-elevated only;
  ADR-0016) installs the repo Claude Code status line for Claude running natively
  on Windows: home/dot_claude/executable_statusline.sh as
  %USERPROFILE%\.claude\statusline.sh (LF), jq through winget when missing, and
  exactly one key, statusLine, in %USERPROFILE%\.claude\settings.json, copied from
  home/.chezmoitemplates/claude/settings.json. Before it replaces anything it saves
  the current file to %LOCALAPPDATA%\app-configs\claude\<UTC>-<PID>\ (settings.json,
  statusline.sh) and prints the one-command rollback; a run with nothing to change
  keeps no backup. Other keys are kept by value (jq re-indents the file); the backup
  keeps the original bytes. -DryRun prints "would ..." and writes nothing. It cannot
  combine with -ToolsOnly, -Export, -Report or -EnableSystemRestore (exit 2). Exit 3
  for: elevated, CLAUDE_CONFIG_DIR set, a reparse point or read-only target that needs
  writing, no Git for Windows bash, Git Bash home not equal to USERPROFILE, jq older
  than 1.7, an unreadable, non-UTF-8 or non-object settings.json, source agreements.

  Labels match ^[a-z0-9][a-z0-9-]{0,39}$. -Export cannot combine with -Report,
  and neither combines with -EnableSystemRestore. Stray positional arguments
  exit 2. A PowerShell binding error (for example -Export with no value) is
  raised before this script runs and exits 1; it cannot be mapped to 2.

  WSL reports (before-setup, after-install, -Report) are written as root to
  /var/lib/app-configs/host-snapshots/<UTC>-<label>/ inside the distro,
  readable by every user, so the location does not depend on the default user
  or on $HOME. Per-user facts are read as the default user at report time.
  Windows reports go to $StateRoot\host-snapshots\<UTC>-<label>\windows.txt.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$DryRun,
    [switch]$EnableSystemRestore,
    [string]$Export,
    [string]$Report,
    [switch]$ToolsOnly,
    [switch]$ClaudeStatusLine,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

$ErrorActionPreference = 'Stop'

$Distro = 'NixOS'
$AppxName = 'MicrosoftCorporationII.WindowsSubsystemForLinux'
# Equals PREFLIGHT_USERNAME_RE in ops/lib/preflight.sh; no automated parity check yet (Slice 2b).
$UserRegex = '^ *username = "([^"]+)";'
$StateRoot = Join-Path $env:LOCALAPPDATA 'app-configs'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$NixosWslTag = '2605.7.2'
$NixosWslUrl = "https://github.com/nix-community/NixOS-WSL/releases/download/$NixosWslTag/nixos.wsl"
# From the GitHub release API "digest" of the nixos.wsl asset; verified by
# downloading the asset and hashing it (2026-11-15).
$NixosWslSha256 = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
$MinWslVersion = [version]'2.4.4'
$Sw = '/run/current-system/sw/bin'
# Commit tooling (step C): winget ids are pinned, versions are not.
$CommitTools = @(
    @{ Name = 'chezmoi'; Id = 'twpayne.chezmoi'; VersionArgs = @('--version') },
    @{ Name = 'gitleaks'; Id = 'Gitleaks.Gitleaks'; VersionArgs = @('version') },
    @{ Name = 'lefthook'; Id = 'evilmartians.lefthook'; VersionArgs = @('version') }
)

# Every function that touches the system. Tests redefine all of them, and an
# AST scan checks that the guarded commands appear only inside these.
$SeamNames = @(
    'Test-IsAdmin', 'Test-RebootPending', 'Get-WslAppx', 'Invoke-WslRaw',
    'Invoke-Download', 'Get-Sha256', 'Get-OsInfo', 'Get-OptionalFeatureStates',
    'Get-RestorePoints', 'New-RestorePoint', 'Enable-SystemRestore',
    'Get-WingetList', 'Get-PathEntries', 'Get-FreeBytes', 'Test-RepoGitDir',
    'Get-UtcStamp', 'Get-OsArch', 'Invoke-Native', 'Get-ToolVersion', 'Invoke-Winget',
    'Update-SessionPath', 'Test-LefthookHooks', 'Get-HooksPath', 'Invoke-Lefthook',
    'Resolve-Program', 'Get-ForeignHooks', 'Get-WindowsRelation', 'Test-HooksInstaller',
    'Resolve-GitBash', 'Invoke-HooksInstaller', 'Get-HookEnvOverrides',
    'Get-EnvScopes', 'Get-GitBashHome', 'Invoke-Jq', 'Invoke-StatusLineRender', 'Get-TemplateStatusLine'
)

# ---------------------------------------------------------------- step W catalogue bounds (ADR-0020 "Catalogue contract"); pure, not seams, not in $SeamNames; W1 pins them
function Get-WindowsSettingsTagKeys {
    return @{
        'startup' = @{
            Registry = @(
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Names = @('OneDrive', 'MicrosoftEdgeAutoLaunch_*') }
                @{ Key = 'Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask'; Names = @('State') }
            )
            Services = @()
            Tasks = @()
        }
        'consumer' = @{ Registry = @(); Services = @(); Tasks = @() }
        'support' = @{ Registry = @(); Services = @(); Tasks = @() }
        'work-app' = @{ Registry = @(); Services = @(); Tasks = @() }
        'report-only' = @{ Registry = @(); Services = @(); Tasks = @() }
        'visual' = @{
            Registry = @(
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Names = @('VisualFXSetting') }
                @{ Key = 'Control Panel\Desktop\WindowMetrics'; Names = @('MinAnimate') }
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Names = @('TaskbarAnimations') }
                @{ Key = 'Control Panel\Desktop'; Names = @('UserPreferencesMask') }
            )
            Services = @()
            Tasks = @()
        }
        'telemetry-user' = @{
            Registry = @(
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Names = @('Enabled') }
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Privacy'; Names = @('TailoredExperiencesWithDiagnosticDataEnabled') }
                @{ Key = 'Software\Microsoft\Siuf\Rules'; Names = @('NumberOfSIUFInPeriod') }
                @{ Key = 'Software\Microsoft\InputPersonalization'; Names = @('RestrictImplicitInkCollection', 'RestrictImplicitTextCollection') }
                @{ Key = 'Software\Microsoft\InputPersonalization\TrainedDataStore'; Names = @('HarvestContacts') }
                @{ Key = 'Software\Microsoft\Personalization\Settings'; Names = @('AcceptedPrivacyPolicy') }
                @{ Key = 'Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; Names = @('HasAccepted') }
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Names = @('SubscribedContent-338389Enabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-310093Enabled') }
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Names = @('ScoobeSystemSettingEnabled') }
                @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Names = @('Start_TrackProgs', 'Start_IrisRecommendations') }
                @{ Key = 'Control Panel\International\User Profile'; Names = @('HttpAcceptLanguageOptOut') }
            )
            Services = @()
            Tasks = @()
        }
        'telemetry-machine' = @{
            Registry = @(
                @{ Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Names = @('DoNotShowFeedbackNotifications') }
                @{ Key = 'SOFTWARE\Policies\Microsoft\Windows\System'; Names = @('PublishUserActivities', 'UploadUserActivities') }
                @{ Key = 'SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Names = @('CEIPEnable') }
            )
            Services = @('DiagTrack')
            Tasks = @('\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip', '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector', '\Microsoft\Windows\Feedback\Siuf\DmClient', '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload', '\Microsoft\Windows\Autochk\Proxy')
        }
        'telemetry-record' = @{
            Registry = @(
                @{ Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Names = @('AllowTelemetry', 'LimitDiagnosticLogCollection', 'LimitDumpCollection') }
                @{ Key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Names = @('AllowTelemetry', 'MaxTelemetryAllowed') }
                @{ Key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Names = @('Value') }
            )
            Services = @('dmwappushservice')
            Tasks = @()
        }
    }
}

function Get-WindowsSettingsProtectedAppx {
    return @{
        Names = @('Microsoft.ZuneMusic', 'Microsoft.DesktopAppInstaller', 'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.SecHealthUI', 'Microsoft.WindowsTerminal', 'MicrosoftCorporationII.WindowsSubsystemForLinux')
        Prefixes = @('Microsoft.VCLibs.', 'Microsoft.UI.Xaml.', 'Microsoft.NET.Native.', 'Microsoft.WindowsAppRuntime.')
    }
}

# ---------------------------------------------------------------- seams

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-RebootPending {
    return (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
}

# $null = absent, a version string = present, 'unavailable: ...' = unknown.
function Get-WslAppx {
    try {
        $p = Get-AppxPackage -Name $AppxName -ErrorAction Stop | Select-Object -First 1
        if ($p) { return [string]$p.Version }
        return $null
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

# Runs a program. Returns @{Code; Out (stdout); Err (stderr)}. A capture call is
# killed after -TimeoutSeconds (code 124). -Passthrough keeps the console
# attached (TTY) and returns Out and Err = $null. Only the seams below call it.
function Invoke-Native {
    param(
        [string]$ExePath,
        [string[]]$Arguments,
        [switch]$Passthrough,
        [int]$TimeoutSeconds = 900,
        [string]$WorkingDirectory,
        [int]$HeartbeatSeconds = 30
    )
    $what = $script:WaitLabel
    $script:WaitLabel = $null
    if (-not $what) { $what = [IO.Path]::GetFileName($ExePath) }
    $p = $null
    $completed = $false
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $ExePath
        $psi.Arguments = ConvertTo-ArgString $Arguments
        $psi.UseShellExecute = $false
        if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
        if (-not $Passthrough) {
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
        }
        $p = [Diagnostics.Process]::Start($psi)
        if (-not $Passthrough) {
            # Captures never read the console: stdin is closed at once.
            $p.StandardInput.Close()
            $so = $p.StandardOutput.ReadToEndAsync()
            $se = $p.StandardError.ReadToEndAsync()
        }
        # Wait in half-second slices so Ctrl+C is honoured within a second. Captures
        # print a heartbeat line and have a time limit; passthrough calls show their
        # own output (and may prompt), so they get neither.
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $lastBeat = 0.0
        while (-not $p.WaitForExit(500)) {
            if ($Passthrough) { continue }
            $el = $sw.Elapsed.TotalSeconds
            if ($el -ge $TimeoutSeconds) {
                $p.Kill()
                $completed = $true
                return @{ Code = 124; Out = ''; Err = "unavailable: timed out after $TimeoutSeconds s (process killed)" }
            }
            if ($el - $lastBeat -ge [math]::Max(1, $HeartbeatSeconds)) {
                $lastBeat = $el
                Say "still running: $what ($([int]$el) s elapsed)"
            }
        }
        $p.WaitForExit()
        $completed = $true
        if ($Passthrough) { return @{ Code = [int]$p.ExitCode; Out = $null; Err = $null } }
        return @{ Code = [int]$p.ExitCode; Out = $so.Result; Err = $se.Result }
    } catch {
        $completed = $true
        return @{ Code = 127; Out = ''; Err = "unavailable: $($_.Exception.Message)" }
    } finally {
        # Ctrl+C (a stopped pipeline) lands here without $completed.
        if (-not $completed -and $null -ne $p -and -not $p.HasExited) {
            Say "interrupted: $what; stopping the process this script started (PID $($p.Id))"
            try { $p.Kill() } catch { }
        }
    }
}
# The only caller of wsl.exe.
function Invoke-WslRaw {
    param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds = 900)
    return (Invoke-Native -ExePath "$env:SystemRoot\System32\wsl.exe" -Arguments $Arguments -Passthrough:$Passthrough -TimeoutSeconds $TimeoutSeconds)
}

# The full path of an application on PATH (first match), or $null.
function Resolve-Program {
    param([string]$Name)
    $c = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    return $null
}

# $null = not installed, a version line = installed, 'unavailable: ...' = unknown.
function Get-ToolVersion {
    param([string]$Name, [string[]]$VersionArgs)
    try {
        $exe = Resolve-Program $Name
        if (-not $exe) { return $null }
        $r = Invoke-Native -ExePath $exe -Arguments $VersionArgs -TimeoutSeconds 60
        if ($r.Code -ne 0) { return "unavailable: $Name exited $($r.Code)" }
        $v = Get-FirstLine $r.Out
        if ($v) { return $v }
        return 'unavailable: no version output'
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

function Get-WingetInstallArgs {
    param([string]$Id)
    return @('install', '--id', $Id, '--exact', '--source', 'winget', '--accept-package-agreements', '--disable-interactivity')
}

# Returns @{Code; Out; Err}; winget may take minutes, so the limit is 20 minutes.
function Invoke-Winget {
    param([string]$Id)
    $exe = Resolve-Program 'winget'
    if (-not $exe) { $script:WaitLabel = $null; return @{ Code = 127; Out = ''; Err = 'unavailable: winget not found' } }
    return (Invoke-Native -ExePath $exe -Arguments (Get-WingetInstallArgs $Id) -TimeoutSeconds 1200)
}

# Appends the Machine and User PATH entries that this session lacks (a new
# install is on the registry PATH but not in an already running shell).
# Existing process entries are kept; the comparison ignores case and a trailing \.
function Update-SessionPath {
    $have = @($env:Path -split ';' | Where-Object { $_ })
    $seen = @{}
    foreach ($e in $have) { $seen[$e.TrimEnd('\').ToLowerInvariant()] = $true }
    $add = foreach ($scope in @('Machine', 'User')) {
        foreach ($e in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
            if (-not $e) { continue }
            $e = [Environment]::ExpandEnvironmentVariables($e)
            $k = $e.TrimEnd('\').ToLowerInvariant()
            if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $e }
        }
    }
    $env:Path = (@($have) + @($add)) -join ';'
}

# True when .git\hooks\pre-commit exists and mentions lefthook.
function Test-LefthookHooks {
    $hook = Join-Path (Join-Path (Join-Path $RepoRoot '.git') 'hooks') 'pre-commit'
    if (-not (Test-Path -LiteralPath $hook -PathType Leaf)) { return $false }
    return ([IO.File]::ReadAllText($hook)).Contains('lefthook')
}

# Hooks named in .lefthook.yml that exist without lefthook in them; `lefthook
# install` renames each of these to <hook>.old.
function Get-ForeignHooks {
    $dir = Join-Path (Join-Path $RepoRoot '.git') 'hooks'
    $found = foreach ($h in @('pre-commit', 'commit-msg', 'pre-push', 'post-merge')) {
        $p = Join-Path $dir $h
        if ((Test-Path -LiteralPath $p -PathType Leaf) -and -not ([IO.File]::ReadAllText($p)).Contains('lefthook')) { $h }
    }
    return @($found)
}

# git config core.hooksPath: '' = unset, a value, or 'unavailable: ...'.
function Get-HooksPath {
    $exe = Resolve-Program 'git'
    if (-not $exe) { return 'unavailable: git not found' }
    $r = Invoke-Native -ExePath $exe -Arguments @('config', 'core.hooksPath') -WorkingDirectory $RepoRoot -TimeoutSeconds 60
    if ($r.Code -eq 1) { return '' }
    if ($r.Code -ne 0) { return "unavailable: git exited $($r.Code) $(Get-FirstLine $r.Err)".Trim() }
    return (Get-FirstLine $r.Out)
}

function Invoke-Lefthook {
    $exe = Resolve-Program 'lefthook'
    if (-not $exe) { $script:WaitLabel = $null; return @{ Code = 127; Out = ''; Err = 'unavailable: lefthook not found' } }
    return (Invoke-Native -ExePath $exe -Arguments @('install') -WorkingDirectory $RepoRoot -TimeoutSeconds 300)
}
function Invoke-Download {
    param([string]$Url, [string]$OutFile, [int]$ProgressSeconds = 30)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    $total = $null
    try {
        $h = Invoke-WebRequest -UseBasicParsing -Method Head -Uri $Url
        $total = [int64]($h.Headers['Content-Length'] | Select-Object -First 1)
    } catch { $total = $null }
    if ($total) { Say "step 3: download size $([math]::Round($total / 1MB)) MB; progress every $ProgressSeconds s" }
    else { Say "step 3: download size unknown; progress every $ProgressSeconds s" }
    $job = Start-Job -ScriptBlock {
        param($u, $o)
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $o
    } -ArgumentList $Url, $OutFile
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        while (-not (Wait-Job -Job $job -Timeout $ProgressSeconds)) {
            $got = 0
            if (Test-Path -LiteralPath $OutFile) { $got = (Get-Item -LiteralPath $OutFile).Length }
            Say "step 3: $(Format-DownloadProgress -Got $got -Total $total -Seconds ([int]$sw.Elapsed.TotalSeconds))"
        }
        [void](Receive-Job -Job $job -ErrorAction Stop)
    } finally {
        Remove-Job -Job $job -Force
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-OsArch {
    try {
        return [string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

function Get-OsInfo {
    try {
        $o = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return "$($o.Caption) version $($o.Version) build $($o.BuildNumber) $($o.OSArchitecture)"
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

# Array of "Name=State" or 'unavailable: ...'.
function Get-OptionalFeatureStates {
    if (-not (Test-IsAdmin)) { return 'unavailable: needs elevation' }
    try {
        $names = @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
        $out = foreach ($n in $names) {
            $f = Get-WindowsOptionalFeature -Online -FeatureName $n -ErrorAction Stop
            "$n=$($f.State)"
        }
        return @($out)
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

# Array of objects with Created (UTC datetime) and Description, or 'unavailable: ...'.
function Get-RestorePoints {
    if (-not (Test-IsAdmin)) { return 'unavailable: needs elevation' }
    try {
        $pts = @(Get-ComputerRestorePoint -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Created     = [Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime).ToUniversalTime()
                Description = [string]$_.Description
            }
        })
        return ,$pts
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

function New-RestorePoint {
    param([string]$Description)
    try {
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        return @{ Ok = $true; Error = '' }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Enable-SystemRestore {
    param([string]$Drive)
    try {
        Enable-ComputerRestore -Drive $Drive -ErrorAction Stop
        return @{ Ok = $true; Error = '' }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Get-WingetList {
    try {
        $exe = Resolve-Program 'winget'
        if (-not $exe) { return 'unavailable: winget not found' }
        $r = Invoke-Native -ExePath $exe -Arguments @('list', '--source', 'winget', '--disable-interactivity') -TimeoutSeconds 120
        if ($r.Code -ne 0) { return "unavailable: winget exit $($r.Code) $(Get-FirstLine $r.Err)".Trim() }
        return $r.Out
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}
# @{Machine = string[]; User = string[]} or 'unavailable: ...'.
function Get-PathEntries {
    try {
        $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $u = [Environment]::GetEnvironmentVariable('Path', 'User')
        return @{
            Machine = @(([string]$m) -split ';' | Where-Object { $_ })
            User    = @(([string]$u) -split ';' | Where-Object { $_ })
        }
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

# Free bytes (int64) on the drive holding $Path, or 'unavailable: ...'.
function Get-FreeBytes {
    param([string]$Path)
    try {
        $di = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($Path))
        return [int64]$di.AvailableFreeSpace
    } catch {
        return "unavailable: $($_.Exception.Message)"
    }
}

function Test-RepoGitDir {
    return (Test-Path -LiteralPath (Join-Path $RepoRoot '.git') -PathType Container)
}

function Get-UtcStamp {
    return (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
}

# ---------------------------------------------------------------- helpers

function Say {
    param([string]$Message)
    $script:WaitLabel = $null
    $line = "$script:Prefix $Message"
    if ($null -ne $script:LogLines) { [void]$script:LogLines.Add($line) }
    Write-Host (Format-ConsoleLine $line)
}

# The Linux side can leave the console without a carriage return on LF, so every
# line starts with its own CR and begins at column 0.
function Format-ConsoleLine {
    param([string]$Line)
    return "`r$Line"
}

# Says what is about to block and labels the heartbeat of the next Invoke-Native
# call (use it only right before a native call). The label is used once, and any
# later Say or an early return in the caller drops it.
function Start-Wait {
    param([string]$Message)
    Say $Message
    $script:WaitLabel = $Message
}

function Format-DownloadProgress {
    param([int64]$Got, $Total, [int]$Seconds)
    $mb = [math]::Round($Got / 1MB)
    if ($Total -and $Total -gt 0) {
        return "downloaded $mb MB of $([math]::Round($Total / 1MB)) MB ($([math]::Floor(100 * $Got / $Total))%), $Seconds s elapsed"
    }
    return "downloaded $mb MB, $Seconds s elapsed"
}

# Dry runs start the distro for read-only probes; say so once, before the first.
function Write-DryDistroNote {
    if ($script:Dry -and -not $script:DryDistroNoted) {
        $script:DryDistroNoted = $true
        Say 'dry run: starting NixOS for read-only probes (it is left running)'
    }
}

# True when the WSL Appx package is installed; wsl.exe is never run otherwise
# (the inbox stub may show an install prompt).
function Test-WslPackage {
    $a = Get-WslAppx
    return (($a -is [string]) -and ($a -notlike 'unavailable*'))
}

function ConvertTo-ArgString {
    param([string[]]$Items)
    # Windows command-line rules: backslashes only matter before a quote.
    $parts = foreach ($i in $Items) {
        if ($i -ne '' -and $i -notmatch '[\s"]') { $i; continue }
        $s = $i -replace '(\\*)"', '$1$1\"'
        $s = $s -replace '(\\+)$', '$1$1'
        '"' + $s + '"'
    }
    return ($parts -join ' ')
}

# Removes user:password@ from a URL such as https://user:pass@host/path.
function Hide-UrlUserInfo {
    param([string]$Url)
    return ($Url -replace '^([A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@', '$1')
}

# Single-quote a value for embedding in a sh script.
function Quote-Sh {
    param([string]$Value)
    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Get-NixUser {
    param([string]$Root)
    $path = Join-Path (Join-Path (Join-Path $Root 'nix') 'vars') 'default.nix'
    $text = [IO.File]::ReadAllText($path)
    $m = [regex]::Matches($text, '(?m)' + $UserRegex)
    if ($m.Count -ne 1) {
        throw "expected exactly one username line in $path, found $($m.Count)"
    }
    $name = $m[0].Groups[1].Value
    if ($name -notmatch '^[a-z_][a-z0-9_-]{0,31}$') { throw "unsupported username '$name' in $path" }
    return $name
}

function Invoke-Wsl {
    param(
        [string[]]$Arguments,
        [string]$User,
        [string]$Cd,
        [switch]$Passthrough,
        [switch]$Global,
        [int]$TimeoutSeconds = 0
    )
    $env:WSL_UTF8 = '1'
    if ($Global) {
        $full = @($Arguments)
    } else {
        $full = @('-d', $Distro)
        if ($User) { $full += @('-u', $User) }
        if ($Cd) { $full += @('--cd', $Cd) }
        $full += '--exec'
        $full += $Arguments
    }
    $raw = @{ Arguments = $full; Passthrough = $Passthrough }
    if ($TimeoutSeconds -gt 0) { $raw.TimeoutSeconds = $TimeoutSeconds }
    $r = Invoke-WslRaw @raw
    $out = $r.Out
    if ($null -ne $out) { $out = ([string]$out) -replace "`0", '' }
    $err = $r.Err
    if ($null -ne $err) { $err = ([string]$err) -replace "`0", '' }
    return @{ Code = [int]$r.Code; Out = $out; Err = $err }
}

# Runs a script inside the distro. The text travels as one base64 argument.
function Invoke-WslScript {
    param(
        [string]$Script,
        [string]$Name,
        [string]$User,
        [string[]]$ScriptArgs = @(),
        [switch]$Passthrough,
        [int]$TimeoutSeconds = 0
    )
    $clean = $Script -replace "`r", ''
    $b64 = [Convert]::ToBase64String((New-Object Text.UTF8Encoding($false)).GetBytes($clean))
    # $Name only labels the call (it is the mktemp template).
    $sh = 'PATH=' + $Sw + ':$PATH; f=$(mktemp /tmp/app-configs-' + $Name + '-XXXXXX) || exit 1; ' +
          'trap ''rm -f "$f"'' EXIT; b=$1; shift; printf %s "$b" | base64 -d > "$f" && bash -l "$f" "$@" </dev/null'
    $a = @('/bin/sh', '-c', $sh, 'sh', $b64) + $ScriptArgs
    return Invoke-Wsl -Arguments $a -User $User -Passthrough:$Passthrough -TimeoutSeconds $TimeoutSeconds
}

function Get-WslPath {
    param([string]$WindowsPath)
    $p = $WindowsPath -replace '\\', '/'
    $r = Invoke-Wsl -User root -Arguments @('/bin/wslpath', '-u', $p)
    if ($r.Code -ne 0) { return $null }
    # stdout only; the last absolute path line wins over any other noise.
    $line = @(([string]$r.Out) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like '/*' }) | Select-Object -Last 1
    return $line
}

function Get-FirstLine {
    param($Text)
    $l = @(([string]$Text) -split "`n" | ForEach-Object { $_.Trim([char]0xFEFF, "`r", ' ') } | Where-Object { $_ })
    if ($l.Count -eq 0) { return '' }
    return $l[0]
}

function Get-WslVersion {
    $r = Invoke-Wsl -Global -Arguments @('--version')
    $ver = $null
    if ($r.Code -eq 0) {
        $m = [regex]::Match((Get-FirstLine $r.Out), '\d+\.\d+\.\d+(\.\d+)?')
        if ($m.Success) { $ver = [version]$m.Value }
    }
    return @{ Code = $r.Code; Version = $ver; Out = $r.Out }
}

function Get-DistroList {
    $r = Invoke-Wsl -Global -Arguments @('--list', '--quiet')
    $names = @(([string]$r.Out) -split "`n" | ForEach-Object { $_.Trim([char]0xFEFF, "`r", ' ') } | Where-Object { $_ })
    return $names
}

function Get-DistroFacts {
    $s = @'
printf 'comm=%s\n' "$(cat /proc/1/comm 2>/dev/null)"
if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then echo interop=present; else echo interop=absent; fi
printf 'user=%s\n' "$(id -un)"
'@
    $r = Invoke-WslScript -Script $s -Name 'facts'
    $f = @{ Code = $r.Code; Comm = ''; Interop = ''; User = '' }
    foreach ($l in (([string]$r.Out) -split "`n")) {
        $t = $l.Trim()
        if ($t -match '^comm=(.*)$') { $f.Comm = $Matches[1] }
        elseif ($t -match '^interop=(.*)$') { $f.Interop = $Matches[1] }
        elseif ($t -match '^user=(.*)$') { $f.User = $Matches[1] }
    }
    return $f
}

function Test-InWsl {
    param([string[]]$Arguments, [string]$User)
    $r = Invoke-Wsl -User $User -Arguments $Arguments
    return ($r.Code -eq 0)
}

# ---------------------------------------------------------------- reports

$WslReportScript = @'
label=$1
user=$2
repo=$3
du=$4
base=/var/lib/app-configs/host-snapshots
stamp=$(date -u +%Y%m%dT%H%M%SZ)
# begin stale-cleanup
mkdir -p "$base" || exit 1
for d in "$base"/[0-9]*Z-"$label" "$base"/[0-9]*Z-"$label".partial; do
  [ -d "$d" ] || continue
  case "$d" in
    *.partial) rm -rf "$d" ;;
    *) [ -f "$d/.complete" ] || rm -rf "$d" ;;
  esac
done
# end stale-cleanup
final=$base/$stamp-$label
dir=$final.partial
mkdir -p "$dir" || exit 1
# cap <file> <command...>: run as root; header, output, exit code (or absent)
cap() {
  f=$1; shift
  {
    printf '== %s ==\n' "$*"
    if command -v "$1" >/dev/null 2>&1; then
      "$@" 2>&1
      printf 'exit: %s\n' "$?"
    else
      printf 'absent: %s\n' "$1"
    fi
  } >> "$dir/$f"
}
# capu <file> <command line>: run as the default user in a login shell
capu() {
  f=$1; c=$2
  {
    printf '== %s (as %s) ==\n' "$c" "$du"
    runuser -u "$du" -- /run/current-system/sw/bin/bash -lc "export XDG_RUNTIME_DIR=/run/user/\$(id -u); command -v ${c%% *} >/dev/null 2>&1 || { echo 'absent: ${c%% *}'; exit 127; }; $c" </dev/null 2>&1
    last_rc=$?
    printf 'exit: %s\n' "$last_rc"
  } >> "$dir/$f"
}
cap host.txt date -u
cap host.txt uname -r
cap host.txt nixos-version
printf 'WSL_DISTRO_NAME=%s\n' "$WSL_DISTRO_NAME" >> "$dir/host.txt"
if [ -d "$repo" ]; then
  capu host.txt "bash $repo/ops/detect-host.sh"
  detect_rc=$last_rc
  capu host.txt "bash $repo/ops/detect-host.sh --wsl-version"
else
  echo "absent: $repo" >> "$dir/host.txt"
fi
cap system.txt nixos-rebuild list-generations
cap system.txt ls /etc/nixos
capu user.txt id
id_rc=$last_rc
{ printf '== passwd name:uid:home:shell ==\n'
  for u in nixos "$user" "$du"; do
    getent passwd "$u" | cut -d: -f1,3,6,7 || echo "absent: $u"
  done; } >> "$dir/user.txt"
cap systemd.txt cat /proc/1/comm
cap systemd.txt systemctl is-system-running
capu systemd.txt 'systemctl --user --failed --no-legend'
{ printf '== WSLInterop ==\n'
  if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then echo present; else echo absent; fi
  printf '== command -v clip.exe ==\n'
  command -v clip.exe || echo 'absent: clip.exe'; } >> "$dir/interop.txt"
cap nix.txt nix --version
{ printf '== nix config (substituters, trusted-users) ==\n'
  if command -v nix >/dev/null 2>&1; then
    { nix config show 2>/dev/null || nix show-config 2>/dev/null; } | grep -E '^(substituters|trusted-users)'
    echo "exit: $?"
  else
    echo 'absent: nix'
  fi; } >> "$dir/nix.txt"
capu hm.txt 'home-manager generations'
capu mise.txt 'mise --version'
capu mise.txt 'mise ls --current'
cap timers.txt systemctl list-timers --all --no-pager
capu timers.txt 'systemctl --user list-timers --all --no-pager'
capu selection.txt 'ls -l ~/.config/app-configs/selection; cat ~/.config/app-configs/selection/selection.toml'
if [ -d "$repo/.git" ]; then
  capu git.txt "git -C $repo status --short; git -C $repo rev-parse HEAD; git -C $repo config remote.origin.url | sed 's#//[^/@]*@#//#'; if git -C $repo diff --quiet -- nix/flake.lock; then echo 'flake.lock: clean'; else echo 'flake.lock: modified'; fi"
else
  echo "absent: $repo" >> "$dir/git.txt"
fi
if [ -f "$repo/ops/readiness.sh" ]; then
  capu readiness.txt "bash $repo/ops/readiness.sh"
else
  echo "absent: $repo/ops/readiness.sh" >> "$dir/readiness.txt"
fi
# begin sanity-check
# The per-user sections must have run: an interrupted or failed runuser (exit 130,
# 126, 127, empty) must not pass as a report. The login banner is ignored.
bad=
if [ "$id_rc" != 0 ] || ! grep -q 'uid=' "$dir/user.txt" 2>/dev/null; then bad=" id (exit ${id_rc:-none})"; fi
if [ -d "$repo" ] && [ "$detect_rc" != 0 ]; then bad="$bad detect-host (exit ${detect_rc:-none})"; fi
if [ -n "$bad" ]; then
  echo "per-user sections failed:$bad" >> "$dir/report-status.txt"
  printf 'incomplete: %s\n' "$dir"
  printf 'failed:%s\n' "$bad"
  exit 3
fi
# end sanity-check
touch "$dir/.complete"
mv "$dir" "$final" || exit 1
chmod -R a+rX /var/lib/app-configs
printf '%s\n' "$final"
'@
$WslReportScript = $WslReportScript -replace "`r", ''

# True (exit 0) when a complete before-setup report exists; a dir without the
# .complete marker is a leftover of an interrupted run.
$WslHasSnapScript = @'
for d in /var/lib/app-configs/host-snapshots/[0-9]*Z-before-setup; do
  [ -f "$d/.complete" ] && exit 0
done
exit 1
'@
$WslHasSnapScript = $WslHasSnapScript -replace "`r", ''

function Format-Probe {
    param($Value)
    if ($null -eq $Value) { return 'none' }
    if ($Value -is [string]) { return $Value }
    return ((@($Value) | ForEach-Object { [string]$_ }) -join ', ')
}

function Get-ReportSection {
    param([string]$Name, [scriptblock]$Body)
    try {
        $text = (@(& $Body) | ForEach-Object { [string]$_ }) -join "`n"
    } catch {
        $text = "unavailable: $($_.Exception.Message)"
    }
    return "== $Name ==`n$text`n`n"
}

function Write-WindowsReport {
    param([string]$Label)
    Say "collecting the Windows report ($Label); winget list can take up to 2 minutes"
    $stamp = Get-UtcStamp
    $dir = Join-Path (Join-Path $StateRoot 'host-snapshots') "$stamp-$Label"
    $text = ''
    $text += Get-ReportSection 'run' {
        "utc: $stamp"
        "user: $([Environment]::UserName)"
        "elevated: $(Test-IsAdmin)"
    }
    $text += Get-ReportSection 'os' { Get-OsInfo }
    $text += Get-ReportSection 'reboot-pending' { if (Test-RebootPending) { 'yes' } else { 'no' } }
    $text += Get-ReportSection 'wsl' {
        $a = Get-WslAppx
        if ($null -eq $a) {
            'appx: absent'
            'wsl: absent (no Appx package)'
        } elseif ($a -like 'unavailable*') {
            "appx: $a"
            'wsl: not queried (the Appx probe failed)'
        } else {
            "appx: $a"
            $v = Invoke-Wsl -Global -Arguments @('--version')
            "wsl --version (exit $($v.Code)):"
            $v.Out
            $v.Err
            $l = Invoke-Wsl -Global -Arguments @('--list', '--verbose')
            "wsl --list --verbose (exit $($l.Code)):"
            $l.Out
            $l.Err
        }
    }
    $text += Get-ReportSection 'optional-features' { Format-Probe (Get-OptionalFeatureStates) }
    $text += Get-ReportSection 'system-restore' {
        $p = Get-RestorePoints
        if ($p -is [string]) { $p } else {
            $pts = @($p)
            "points: $($pts.Count) (protection state is inferred from the points)"
            if ($pts.Count -gt 0) {
                $n = $pts | Sort-Object Created | Select-Object -Last 1
                "newest: $($n.Created.ToString('o')) $($n.Description)"
            }
        }
    }
    $text += Get-ReportSection 'disk-free-c' { [string](Get-FreeBytes 'C:\') }
    $text += Get-ReportSection 'winget' { Get-WingetList }
    $text += Get-ReportSection 'path' {
        $p = Get-PathEntries
        if ($p -is [string]) { $p } else {
            foreach ($e in $p.Machine) { "machine: $e" }
            foreach ($e in $p.User) { "user: $e" }
        }
    }
    $text += Get-ReportSection 'commit-tooling' {
        $elev = Test-IsAdmin
        foreach ($c in $CommitTools) {
            if ($elev) {
                $p = Resolve-Program $c.Name
                "$($c.Name): skipped (elevated); path: $(if ($p) { $p } else { 'absent' })"
            } else {
                $v = Get-ToolVersion -Name $c.Name -VersionArgs $c.VersionArgs
                "$($c.Name): $(if ($null -eq $v) { 'absent' } else { $v })"
            }
        }
        "hooks installed: $(if (Test-LefthookHooks) { 'yes' } else { 'no' })"
        if ($elev) { 'core.hooksPath: skipped (elevated)' } else {
            $hp = Get-HooksPath
            "core.hooksPath: $(if ($hp) { $hp } else { 'unset' })"
        }
    }
    [void](New-Item -ItemType Directory -Force -Path $dir)
    [IO.File]::WriteAllText((Join-Path $dir 'windows.txt'), ($text -replace "`r", ''), (New-Object Text.UTF8Encoding($false)))
    return $dir
}

# Returns the WSL-side report dir, or $null when the capture failed.
function Write-WslReport {
    param([string]$Label, [string]$User)
    if (-not (Test-WslPackage)) { return $null }
    $f = Get-DistroFacts
    if ($f.Code -ne 0 -or -not $f.User) { return $null }
    Start-Wait "writing the WSL report ($Label); can take up to a minute"
    $r = Invoke-WslScript -Script $WslReportScript -Name 'report' -User root -TimeoutSeconds 300 -ScriptArgs @($Label, $User, "/home/$User/app-configs", $f.User)
    if ($r.Code -eq 124) { Say "warning: the WSL report ($Label) timed out after 300 s; wsl.exe was stopped, but the in-distro report may still be running; its partial dir is ignored and rewritten on the next run" }
    if ($r.Code -eq 3) {
        $lines = @(([string]$r.Out) -split "`n" | ForEach-Object { $_.Trim() })
        $inc = ($lines | Where-Object { $_ -like 'incomplete: *' } | Select-Object -Last 1)
        $why = ($lines | Where-Object { $_ -like 'failed:*' } | Select-Object -Last 1)
        Say "warning: the WSL report ($Label) is INCOMPLETE, its per-user sections failed ($why); kept for inspection ($inc) and not marked complete, so the next run rewrites it"
        return $null
    }
    if ($r.Code -ne 0) { return $null }
    $dir = @(([string]$r.Out) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like '/*' }) | Select-Object -Last 1
    return $dir
}

function Write-BothReports {
    param([string]$Label, [string]$User)
    $w = Write-WslReport -Label $Label -User $User
    if ($w) { Say "WSL report ($Label): $w" } else { Say "warning: WSL report ($Label) not written (distro missing or the capture failed)" }
    $d = Write-WindowsReport -Label $Label
    Say "Windows report ($Label): $(Join-Path $d 'windows.txt')"
}

# ---------------------------------------------------------------- git hooks installer

# True when the repo ships the hooks installer. Then lefthook's own installer must not be
# used (it fails once core.hooksPath is set), and this script never removes a hooks path.
function Test-HooksInstaller {
    return (Test-Path -LiteralPath (Join-Path (Join-Path $RepoRoot 'ops') 'install-git-hooks.sh') -PathType Leaf)
}

# Git for Windows' bash, derived from the git install (never the WindowsApps or System32
# bash launcher, which starts WSL). $null when it cannot be found.
function Resolve-GitBash {
    $dirs = @()
    $git = Resolve-Program 'git'
    if ($git) {
        $d = Split-Path -Parent $git
        for ($i = 0; $i -lt 3 -and $d; $i++) { $dirs += $d; $d = Split-Path -Parent $d }
    }
    if ($env:ProgramFiles) { $dirs += (Join-Path $env:ProgramFiles 'Git') }
    foreach ($d in $dirs) {
        # Only bin\bash.exe: usr\bin\bash.exe, started without a login shell, lacks sed, dirname and mktemp.
        $c = Join-Path $d 'bin\bash.exe'
        if ((Test-Path -LiteralPath $c -PathType Leaf) -and $c -notmatch '\\(WindowsApps|System32)\\') { return $c }
    }
    return $null
}

# Runs ops/install-git-hooks.sh (or with --check) from the repo root (the main worktree).
function Invoke-HooksInstaller {
    param([string]$Bash, [string]$Mode)
    $a = @('ops/install-git-hooks.sh')
    if ($Mode -eq 'check') { $a += '--check' }
    return (Invoke-Native -ExePath $Bash -Arguments $a -WorkingDirectory $RepoRoot -TimeoutSeconds 300)
}

# Names of the environment variables the repo's git hooks refuse: any LEFTHOOK* except
# LEFTHOOK_VERBOSE and LEFTHOOK_QUIET, and SKIP_HOOKS.
function Get-HookEnvOverrides {
    $names = foreach ($v in (Get-ChildItem Env:)) {
        $n = $v.Name
        if (($n -match '^LEFTHOOK' -and @('LEFTHOOK_VERBOSE', 'LEFTHOOK_QUIET') -notcontains $n.ToUpperInvariant()) -or $n -eq 'SKIP_HOOKS') { $n }
    }
    return @($names)
}

function Write-InstallerOutput {
    param($Result)
    $lines = @((([string]$Result.Out) + "`n" + ([string]$Result.Err)) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($l in ($lines | Select-Object -First 20)) { Say "step C: installer: $l" }
    if ($lines.Count -gt 20) { Say "step C: installer: ... ($($lines.Count - 20) more lines)" }
}

# A refused or failed hooks installer: a warning now and a closing notice at the end of the run.
# Returns 0 (the run goes on).
function Write-HooksWarning {
    param([string]$Hint, [string]$Why)
    Say "step C: WARNING: git hooks are NOT installed on Windows ($Why); commits from this clone will be blocked or unguarded until that is fixed. $Hint"
    $script:HooksWarning = "git hooks are NOT installed on Windows ($Why); commits from this clone will be blocked or unguarded until that is fixed (see the step C warning above)"
    return 0
}

# Step C hooks part when the repo ships ops/install-git-hooks.sh. Returns 0 or 3. Commit
# hooks are not needed to provision WSL, so an installer refusal or failure only warns (now,
# and again in a closing notice at the end of the run) and the run continues; a missing Git
# for Windows bash is a missing precondition and exits 3.
function Invoke-HooksInstallerFlow {
    foreach ($n in (Get-HookEnvOverrides)) {
        Say "step C: warning: $n is set in your environment; the repo's git hooks refuse it (any LEFTHOOK* variable except LEFTHOOK_VERBOSE and LEFTHOOK_QUIET, and SKIP_HOOKS), so commits are blocked until it is unset"
    }
    $bash = Resolve-GitBash
    if (-not $bash) {
        Say 'step C: Git for Windows bash was not found (the WindowsApps and WSL bash are never used); install Git for Windows, then re-run'
        return 3
    }
    $hint = 'ops/install-git-hooks.sh refuses a linked worktree, a foreign core.hooksPath, a missing git or lefthook, git older than 2.31, or a HEAD without ops/githooks; read its output above, fix that, then re-run'
    Start-Wait 'step C: checking the git hooks with ops/install-git-hooks.sh --check (a few seconds)'
    $chk = Invoke-HooksInstaller -Bash $bash -Mode 'check'
    Write-InstallerOutput $chk
    if ($chk.Code -eq 0) {
        Say 'step C: git hooks intact (ops/install-git-hooks.sh --check)'
        return 0
    }
    if ($chk.Code -ne 1) {
        return (Write-HooksWarning $hint "ops/install-git-hooks.sh --check exited $($chk.Code), expected 0 or 1")
    }
    if ($script:Dry) {
        Say "step C: git hooks are not intact (--check exit 1); would run: bash ops/install-git-hooks.sh (Git for Windows bash: $bash), then --check again"
        return 0
    }
    Start-Wait 'step C: installing the git hooks with ops/install-git-hooks.sh (a few seconds)'
    $inst = Invoke-HooksInstaller -Bash $bash -Mode 'install'
    Write-InstallerOutput $inst
    if ($inst.Code -ne 0) {
        return (Write-HooksWarning $hint "ops/install-git-hooks.sh exited $($inst.Code)")
    }
    Start-Wait 'step C: checking the git hooks again with ops/install-git-hooks.sh --check (a few seconds)'
    $chk = Invoke-HooksInstaller -Bash $bash -Mode 'check'
    Write-InstallerOutput $chk
    if ($chk.Code -ne 0) {
        return (Write-HooksWarning $hint "the installer ran but --check still exits $($chk.Code)")
    }
    Say 'step C: git hooks installed and intact'
    return 0
}

# ---------------------------------------------------------------- step C

# Real-run winget install of the tools the caller found missing. Each entry is
# @{ Name; Id; VersionArgs }; $Step is the label in every message ("step $Step: ...").
# Returns 0 installed and found on PATH, 1 failed or still not found, 3 source agreements
# needed (a human decision). The caller does the probe and the dry-run lines.
function Install-WingetTools {
    param([string]$Step, [object[]]$Tools)
    foreach ($c in $Tools) {
        Start-Wait "step ${Step}: installing $($c.Id) with winget (can take several minutes)"
        $w = Invoke-Winget -Id $c.Id
        if ($w.Code -ne 0) {
            $text = "$($w.Out)`n$($w.Err)"
            if ($text -match '(?i)source agreements?|accept-source-agreements') {
                Say "step ${Step}: winget needs its source agreements accepted first; that is your decision. To accept them and install, run:"
                Say "step ${Step}: winget $((Get-WingetInstallArgs $c.Id) -join ' ') --accept-source-agreements"
                return 3
            }
            Say "step ${Step}: winget install $($c.Id) exited $($w.Code): $(Get-FirstLine $text)"
            if ($w.Code -eq 124) { Say "step ${Step}: child installers may still be running; wait for them to finish before re-running" }
            return 1
        }
    }
    Update-SessionPath
    $still = $false
    foreach ($c in $Tools) {
        if ($null -eq (Get-ToolVersion -Name $c.Name -VersionArgs $c.VersionArgs)) {
            Say "step ${Step}: $($c.Name) is still not found after the install; open a new PowerShell and re-run"
            $still = $true
        }
    }
    if ($still) { return 1 }
    return 0
}

# Returns 0 done, 1 failed, 3 human step. Never elevated (the caller checks).
function Invoke-CommitTooling {
    Update-SessionPath
    $missing = @()
    foreach ($c in $CommitTools) {
        $v = Get-ToolVersion -Name $c.Name -VersionArgs $c.VersionArgs
        if ($null -eq $v) { Say "step C: $($c.Name) absent"; $missing += $c } else { Say "step C: $($c.Name) $v" }
    }
    if ($missing.Count -gt 0) {
        if ($script:Dry) {
            foreach ($c in $missing) { Say "step C: would run: winget $((Get-WingetInstallArgs $c.Id) -join ' ')" }
        } else {
            $rc = Install-WingetTools -Step 'C' -Tools $missing
            if ($rc -ne 0) { return $rc }
        }
    }
    if (-not (Test-RepoGitDir)) {
        Say "step C: $RepoRoot\.git is not a directory; hooks skipped"
        return 0
    }
    if (Test-HooksInstaller) { return (Invoke-HooksInstallerFlow) }
    $hp = Get-HooksPath
    if ($hp -like 'unavailable*') {
        Say "step C: cannot read git config core.hooksPath ($hp); install Git for Windows, then re-run"
        return 3
    }
    if ($hp) {
        Say "step C: core.hooksPath is set to '$hp'; hooks left untouched"
        return 0
    }
    if (Test-LefthookHooks) {
        Say 'step C: lefthook hooks already installed'
        return 0
    }
    $foreign = @(Get-ForeignHooks)
    if ($foreign.Count -gt 0) {
        Say "step C: lefthook install will rename these existing hooks to <name>.old: $($foreign -join ', ')"
    }
    if ($script:Dry) {
        Say "step C: would run: lefthook install (in $RepoRoot)"
        return 0
    }
    Start-Wait 'step C: running lefthook install (a few seconds)'
    $l = Invoke-Lefthook
    if ($l.Code -ne 0) {
        Say "step C: lefthook install exited $($l.Code): $(Get-FirstLine "$($l.Out)`n$($l.Err)")"
        return 1
    }
    if (-not (Test-LefthookHooks)) { Say 'step C: lefthook install ran but .git\hooks\pre-commit has no lefthook hook'; return 1 }
    Say 'step C: lefthook hooks installed'
    return 0
}
# ---------------------------------------------------------------- step S (ADR-0016)

# Seams of step S. Each is the only caller of its native command.
function Get-EnvScopes {
    param([string]$Name)
    return @{
        Process = [Environment]::GetEnvironmentVariable($Name, 'Process')
        User = [Environment]::GetEnvironmentVariable($Name, 'User')
        Machine = [Environment]::GetEnvironmentVariable($Name, 'Machine')
    }
}

# The home directory Git Bash resolves, as a Windows path, or $null.
function Get-GitBashHome {
    param([string]$Bash)
    $r = Invoke-Native -ExePath $Bash -Arguments @('-c', 'cygpath -w ~') -TimeoutSeconds 30
    if ($r.Code -ne 0) { return $null }
    $l = Get-FirstLine $r.Out
    if ($l) { return $l.Trim() }
    return $null
}

# Returns @{Code; Out; Err}.
function Invoke-Jq {
    param([string[]]$Arguments)
    $exe = Resolve-Program 'jq'
    if (-not $exe) { return @{ Code = 127; Out = ''; Err = 'unavailable: jq not found' } }
    return (Invoke-Native -ExePath $exe -Arguments $Arguments -TimeoutSeconds 60)
}

# Runs the installed status line once under Git Bash, as Claude Code does.
function Invoke-StatusLineRender {
    param([string]$Bash, [string]$PayloadPath)
    return (Invoke-Native -ExePath $Bash -Arguments @('-c', 'STATUSLINE_GIT_TTL=0 ~/.claude/statusline.sh < "$1"', '_', $PayloadPath) -TimeoutSeconds 30)
}

# The template's statusLine object (ConvertFrom-Json is not on the static allowlist).
function Get-TemplateStatusLine {
    param([string]$Path)
    return ((Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json).statusLine
}

function Get-BytesSha256 {
    param([byte[]]$Bytes)
    $h = [Security.Cryptography.SHA256]::Create()
    try { return (($h.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $h.Dispose() }
}

# Writes a new file; throws when it already exists (FileMode.CreateNew), so it never overwrites.
function Write-NewFile {
    param([string]$Path, [byte[]]$Bytes)
    $fs = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $fs.Write($Bytes, 0, $Bytes.Length) } finally { $fs.Dispose() }
}

function Test-ReparsePoint {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return [bool]((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Test-ReadOnlyFile {
    param([string]$Path)
    return [bool]((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReadOnly)
}

# Opt-in step S: the repo status line for Claude Code on native Windows. Returns 0, 1 or 3.
# Order: refusals, repo contract, tools, decide (reads only), backup, script, settings, render.
# Nothing under %USERPROFILE%\.claude is written before the current files are saved to $B.
function Invoke-ClaudeStatusLine {
    if (Test-IsAdmin) { Say 'step S: elevated; re-run non-elevated (the status line belongs to this user)'; return 3 }
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    $S = Join-Path $claudeDir 'settings.json'
    $P = Join-Path $claudeDir 'statusline.sh'
    $T = Join-Path $RepoRoot 'home\.chezmoitemplates\claude\settings.json'
    $SRC = Join-Path $RepoRoot 'home\dot_claude\executable_statusline.sh'
    $B = Join-Path (Join-Path $script:StateRoot 'claude') "$(Get-UtcStamp)-$PID"

    # refusals: nothing is written
    $cc = Get-EnvScopes 'CLAUDE_CONFIG_DIR'
    foreach ($k in @('Process', 'User', 'Machine')) {
        if ($cc[$k]) {
            Say "step S: CLAUDE_CONFIG_DIR is set ($k scope); Claude Code does not use $claudeDir then, so nothing was changed"
            return 3
        }
    }
    foreach ($p in @($claudeDir, $S, $P)) {
        if (Test-ReparsePoint $p) { Say "step S: $p is a reparse point (link); refusing to write through it"; return 3 }
    }

    # repo contract
    if (-not (Test-Path -LiteralPath $T -PathType Leaf) -or -not (Test-Path -LiteralPath $SRC -PathType Leaf)) {
        Say "step S: the repo files are missing ($T, $SRC)"
        return 1
    }
    if ([IO.File]::ReadAllText($T).Contains('{{')) { Say "step S: $T contains a template action; step S needs plain JSON"; return 1 }
    try {
        $tpl = Get-TemplateStatusLine $T
    } catch {
        Say "step S: cannot parse $T`: $($_.Exception.Message)"
        return 1
    }
    if (-not $tpl -or $tpl.type -ne 'command' -or $tpl.command -ne '~/.claude/statusline.sh') {
        Say "step S: the template statusLine is not a command running ~/.claude/statusline.sh; step S owns that exact value"
        return 1
    }
    $srcBytes = [IO.File]::ReadAllBytes($SRC)
    if ($srcBytes -contains 13) { Say "step S: $SRC has CR bytes; it must keep LF line endings"; return 1 }
    $srcHash = Get-BytesSha256 $srcBytes

    # tools
    $bash = Resolve-GitBash
    if (-not $bash) {
        Say 'step S: Git for Windows bash was not found (the WindowsApps and WSL bash are never used); install Git for Windows, then re-run'
        return 3
    }
    $gh = Get-GitBashHome $bash
    if (-not $gh) { Say "step S: could not read the home directory of $bash"; return 1 }
    if ($gh.TrimEnd('\', '/').ToLowerInvariant() -ne ([string]$env:USERPROFILE).TrimEnd('\', '/').ToLowerInvariant()) {
        Say "step S: Git Bash home is '$gh' but USERPROFILE is '$env:USERPROFILE'; ~/.claude would differ, so nothing was changed"
        return 3
    }
    $cb = Get-EnvScopes 'CLAUDE_CODE_GIT_BASH_PATH'
    foreach ($k in @('Process', 'User', 'Machine')) {
        if ($cb[$k]) { Say "step S: CLAUDE_CODE_GIT_BASH_PATH is set ($k scope): $($cb[$k]); Claude Code uses this bash" }
    }
    Update-SessionPath
    $jqv = Get-ToolVersion -Name 'jq' -VersionArgs @('--version')
    $jqKnown = $true
    if ($null -eq $jqv) {
        if ($script:Dry) {
            Say "step S: jq absent; would run: winget $((Get-WingetInstallArgs 'jqlang.jq') -join ' ')"
            $jqKnown = $false
        } else {
            Say 'step S: jq absent'
            $rc = Install-WingetTools -Step 'S' -Tools @(@{ Name = 'jq'; Id = 'jqlang.jq'; VersionArgs = @('--version') })
            if ($rc -ne 0) { return $rc }
            Say 'step S: jq installed; sessions started earlier do not see it, so reopen Windows Terminal before starting claude'
            $jqv = Get-ToolVersion -Name 'jq' -VersionArgs @('--version')
        }
    }
    if ($jqKnown) {
        if ($jqv -notmatch '^jq-(\d+\.\d+)' -or [version]$Matches[1] -lt [version]'1.7') {
            Say "step S: jq must be 1.7 or newer, found '$jqv' (jq on PATH: $(Resolve-Program 'jq'))"
            return 3
        }
        Say "step S: $jqv"
    }

    # decide what needs writing (reads only; in a real run only $B is created)
    $needScript = (-not (Test-Path -LiteralPath $P)) -or ((Get-Sha256 $P) -ne $srcHash)
    $haveS = Test-Path -LiteralPath $S
    $needSettings = $true
    $snap = $S
    $snapHash = $null
    $settingsBytes = $null
    $replacedS = $false
    $replacedP = $false
    $pHint = $null
    $payload = Join-Path $B 'payload.json'
    $created = $false
    try {
        if (-not $script:Dry) {
            [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $B))
            try { [void](New-Item -ItemType Directory -Path $B) } catch { Say "step S: backup folder $B already exists or cannot be created"; return 1 }
            $created = $true
        }
        if ($haveS) {
            try { $settingsBytes = [IO.File]::ReadAllBytes($S) } catch { Say "step S: cannot read $S"; return 3 }
            $off = 0
            if ($settingsBytes.Length -ge 3 -and $settingsBytes[0] -eq 0xEF -and $settingsBytes[1] -eq 0xBB -and $settingsBytes[2] -eq 0xBF) { $off = 3 }
            try {
                $enc = New-Object Text.UTF8Encoding -ArgumentList $false, $true
                [void]$enc.GetString($settingsBytes, $off, $settingsBytes.Length - $off)
            } catch {
                $why = 'not UTF-8'
                if ($settingsBytes.Length -ge 2 -and (($settingsBytes[0] -eq 0xFF -and $settingsBytes[1] -eq 0xFE) -or ($settingsBytes[0] -eq 0xFE -and $settingsBytes[1] -eq 0xFF))) { $why = 'not UTF-8 (UTF-16?)' }
                Say "step S: $S is $why; nothing was changed"
                return 3
            }
            $snapHash = Get-BytesSha256 $settingsBytes
            if ($created) {
                # The saved default settings: exact bytes, before anything is written to $S.
                Write-NewFile -Path (Join-Path $B 'settings.json') -Bytes $settingsBytes
                $snap = Join-Path $B 'settings.json'
            }
            if ($jqKnown) {
                $v = Invoke-Jq @('-e', '-s', 'length == 1 and (.[0] | type == "object")', $snap)
                if ($v.Code -eq 2) { Say "step S: cannot read $S"; return 3 }
                if (@(1, 4, 5) -contains $v.Code) { Say "step S: $S is not one JSON object; nothing was changed (fix or move it, then re-run)"; return 3 }
                if ($v.Code -ne 0) { Say "step S: jq exited $($v.Code) validating $S`: $(Get-FirstLine $v.Err)"; return 1 }
                $cur = Invoke-Jq @('-e', '--slurpfile', 't', $T, '.statusLine == $t[0].statusLine', $snap)
                if ($cur.Code -eq 0) { $needSettings = $false }
                elseif ($cur.Code -ne 1) { Say "step S: jq exited $($cur.Code) comparing statusLine: $(Get-FirstLine $cur.Err)"; return 1 }
                else {
                    $old = Invoke-Jq @('-r', '.statusLine.command // empty', $snap)
                    $oc = Get-FirstLine $old.Out
                    if ($oc) { Say "step S: replacing the existing statusLine (command: $oc); the old value is kept in the backup" }
                    else { Say 'step S: adding or replacing the statusLine key; the old file is kept in the backup' }
                }
            }
        }
        if (-not $jqKnown) { Say 'step S: settings.json state is unknown without jq' }

        # write access: only for existing targets that need writing
        if ($needScript -and (Test-Path -LiteralPath $P) -and (Test-ReadOnlyFile $P)) { Say "step S: $P is read-only; clear the read-only attribute, then re-run"; return 3 }
        if ($needSettings -and $haveS -and (Test-ReadOnlyFile $S)) { Say "step S: $S is read-only; clear the read-only attribute, then re-run"; return 3 }

        if ($script:Dry) {
            if ($needScript) { Say "step S: would install $SRC as $P (LF, backup of the old file first)" } else { Say "step S: $P is current" }
            if ($needSettings) {
                if ($haveS) { Say "step S: would save $S to $B\settings.json, then set only the statusLine key" }
                else { Say "step S: would create $S with only the statusLine key" }
            } else { Say "step S: $S statusLine is current" }
            Say 'step S: would render the status line once under Git Bash to check it'
            return 0
        }

        # real run
        $targets = @()
        if ($needScript) { $targets += $P }
        if ($needSettings) { $targets += $S }
        if ($targets.Count -gt 0) { Say "step S: close running Windows Claude Code sessions first; writing: $($targets -join ', ')" }
        [void](New-Item -ItemType Directory -Force -Path $claudeDir)

        if ($needScript) {
            $tmp = "$P.app-configs-tmp-$PID"
            $tmpMade = $false
            try {
                if (Test-Path -LiteralPath $P) { [IO.File]::Copy($P, (Join-Path $B 'statusline.sh'), $false) }
                Write-NewFile -Path $tmp -Bytes $srcBytes
                $tmpMade = $true
                if ((Get-Sha256 $tmp) -ne $srcHash) { throw 'the temp copy does not match the repo script' }
                if (Test-Path -LiteralPath $P) { [IO.File]::Replace($tmp, $P, [NullString]::Value) } else { Move-Item -LiteralPath $tmp -Destination $P }
                $replacedP = $true
            } catch {
                Say "step S: could not install $P`: $($_.Exception.Message)"
                if ($tmpMade -and (Test-Path -LiteralPath $tmp)) { Remove-Item -LiteralPath $tmp }
                return 1
            }
            Say "step S: installed $P"
            if (Test-Path -LiteralPath (Join-Path $B 'statusline.sh')) {
                $pHint = "step S: previous statusline.sh saved as $B\statusline.sh (restore with Copy-Item -LiteralPath '$($B.Replace("'", "''"))\statusline.sh' -Destination '$($P.Replace("'", "''"))' -Force)"
                Say $pHint
            }
        } else {
            Say "step S: $P is current"
        }

        if ($needSettings) {
            $tmp = "$S.app-configs-tmp-$PID"
            $tmpMade = $false
            try {
                if ($haveS) {
                    $m = Invoke-Jq @('--binary', '--slurpfile', 't', $T, '.statusLine = $t[0].statusLine', $snap)
                    if ($m.Code -ne 0) { throw "jq exited $($m.Code): $(Get-FirstLine $m.Err)" }
                    Write-NewFile -Path $tmp -Bytes ([Text.Encoding]::UTF8.GetBytes([string]$m.Out))
                    $tmpMade = $true
                    $chk = Invoke-Jq @('-e', '-s', '--slurpfile', 'o', $snap, '--slurpfile', 't', $T, 'length == 1 and (.[0].statusLine == $t[0].statusLine) and ((.[0] | del(.statusLine)) == ($o[0] | del(.statusLine)))', $tmp)
                    if ($chk.Code -ne 0) { throw 'the merged file failed verification (statusLine or another key differs)' }
                    if ((Get-Sha256 $S) -ne $snapHash) { throw 'settings.json changed during the run' }
                    [IO.File]::Replace($tmp, $S, [NullString]::Value)
                } else {
                    $m = Invoke-Jq @('--binary', '-n', '--slurpfile', 't', $T, '{statusLine: $t[0].statusLine}')
                    if ($m.Code -ne 0) { throw "jq exited $($m.Code): $(Get-FirstLine $m.Err)" }
                    Write-NewFile -Path $tmp -Bytes ([Text.Encoding]::UTF8.GetBytes([string]$m.Out))
                    $tmpMade = $true
                    $chk = Invoke-Jq @('-e', '-s', '--slurpfile', 't', $T, 'length == 1 and .[0] == {statusLine: $t[0].statusLine}', $tmp)
                    if ($chk.Code -ne 0) { throw 'the new file failed verification' }
                    if (Test-Path -LiteralPath $S) { throw 'settings.json appeared during the run' }
                    Move-Item -LiteralPath $tmp -Destination $S
                }
                $replacedS = $true
            } catch {
                Say "step S: could not write $S`: $($_.Exception.Message); $S is unchanged"
                if ($tmpMade -and (Test-Path -LiteralPath $tmp)) { Remove-Item -LiteralPath $tmp }
                if ($pHint) { Say $pHint }
                return 1
            }
            Say "step S: set the statusLine key in $S"
            if ($haveS) {
                Say "step S: previous settings.json saved as $B\settings.json"
                Say "step S: rollback (one command): Copy-Item -LiteralPath '$($B.Replace("'", "''"))\settings.json' -Destination '$($S.Replace("'", "''"))' -Force"
            } else {
                Say "step S: settings.json did not exist before; rollback: Remove-Item -LiteralPath '$($S.Replace("'", "''"))'"
            }
        } else {
            Say "step S: $S statusLine is current"
        }

        # render check, as Claude Code runs it
        $cwd = ([string]$RepoRoot).Replace('\', '/')
        $json = '{"model":{"display_name":"check"},"workspace":{"current_dir":"' + $cwd + '"}}'
        Write-NewFile -Path $payload -Bytes ([Text.Encoding]::UTF8.GetBytes($json))
        Start-Wait 'step S: rendering the status line once under Git Bash (a few seconds)'
        $r = Invoke-StatusLineRender -Bash $bash -PayloadPath ($payload.Replace('\', '/'))
        $line = Get-FirstLine $r.Out
        if ($r.Code -ne 0 -or -not $line) {
            Say "step S: the render check failed (exit $($r.Code)): $(Get-FirstLine $r.Err); the files above are installed, see the rollback commands"
            return 1
        }
        Say 'step S: done; reopen Windows Terminal, then start claude'
        return 0
    } finally {
        if ($created) {
            if (Test-Path -LiteralPath $payload) { Remove-Item -LiteralPath $payload }
            $bs = Join-Path $B 'settings.json'
            if (-not $replacedS -and (Test-Path -LiteralPath $bs)) { Remove-Item -LiteralPath $bs }
            $bp = Join-Path $B 'statusline.sh'
            if (-not $replacedP -and (Test-Path -LiteralPath $bp)) { Remove-Item -LiteralPath $bp }
            foreach ($d in @($B, (Split-Path -Parent $B))) {
                if ((Test-Path -LiteralPath $d) -and @(Get-ChildItem -LiteralPath $d -Force).Count -eq 0) { Remove-Item -LiteralPath $d }
            }
        }
    }
}

# ---------------------------------------------------------------- export

function Invoke-DistroExport {
    param([string]$Label)
    $dir = Join-Path $StateRoot 'wsl-exports'
    $rx = '^NixOS-' + [regex]::Escape($Label) + '-\d{8}T\d{6}Z\.tar$'
    if (Test-Path -LiteralPath $dir) {
        # Only a finished .tar counts; a .tar.partial is an interrupted export.
        $have = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -match $rx -and $_.Length -gt 0 } | Select-Object -First 1
        if ($have) {
            Say "export '$Label' already exists, skipping: $($have.FullName)"
            return 0
        }
    }
    Write-DryDistroNote
    $u = Invoke-Wsl -User root -Arguments @("$Sw/df", '-B1', '--output=used', '/')
    $usedLine = @(([string]$u.Out) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }) | Select-Object -Last 1
    if ($u.Code -ne 0 -or -not $usedLine) {
        Say 'error: cannot read the used space of the distro (df failed)'
        return 1
    }
    $required = [int64][math]::Ceiling(([double]$usedLine * 1.2) + 1GB)
    $free = Get-FreeBytes $StateRoot
    if ($free -is [string]) {
        Say "error: cannot read free space ($free); required $required bytes"
        return 1
    }
    if ([int64]$free -lt $required) {
        Say "error: not enough free space for the export: required $required bytes, free $free bytes"
        return 1
    }
    $file = Join-Path $dir "NixOS-$Label-$(Get-UtcStamp).tar"
    if ($script:Dry) {
        Say "would export the distro to $file (required $required bytes, free $free bytes)"
        return 0
    }
    [void](New-Item -ItemType Directory -Force -Path $dir)
    # Stale partials of this label come from an interrupted earlier run.
    $prx = $rx.Replace('\.tar$', '\.tar\.partial$')
    Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -match $prx } | Remove-Item -Force
    $part = "$file.partial"
    [void](Invoke-Wsl -Global -Arguments @('--terminate', $Distro))
    Start-Wait "exporting the distro to $file (several minutes for a few GB)"
    $e = Invoke-Wsl -Global -Passthrough -Arguments @('--export', $Distro, $part)
    $size = 0
    if (Test-Path -LiteralPath $part) { $size = (Get-Item -LiteralPath $part).Length }
    if ($e.Code -ne 0 -or $size -le 0) {
        if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
        Say "error: wsl --export failed (exit $($e.Code)); partial file removed"
        return 1
    }
    Move-Item -LiteralPath $part -Destination $file
    Say "exported: $file ($size bytes)"
    Say "test restore: wsl --import NixOS-restore <dir> $file"
    Say "real restore (your decision, never scripted): wsl --unregister NixOS, then wsl --import NixOS <dir> $file"
    return 0
}

# Compares the WSL clone with the Windows repo's main, read-only (git -C, no fetch):
# same | behind (the clone's HEAD is an ancestor of main) | other (rebased, diverged,
# or the clone has commits main lacks). Needs SRC (the Windows repo as seen from WSL)
# and DST (the clone) exported by the caller. A failing git status gives dirty=unknown.
$WslSyncScript = @'
inner=$(cat <<'INNER'
g() { git -c "safe.directory=$SRC" -c "safe.directory=$DST" "$@"; }
src=$(g -C "$SRC" rev-parse --verify -q refs/heads/main)
head=$(g -C "$DST" rev-parse --verify -q HEAD)
branch=$(g -C "$DST" symbolic-ref -q --short HEAD)
if st=$(g -C "$DST" --no-optional-locks status --porcelain 2>/dev/null); then
  dirty=$(printf '%s' "$st" | grep -c .)
else
  dirty=unknown
fi
rel=other
if [ -n "$src" ] && [ "$src" = "$head" ]; then
  rel=same
elif [ -n "$src" ] && [ -n "$head" ] && g -C "$SRC" merge-base --is-ancestor "$head" "$src" 2>/dev/null; then
  rel=behind
fi
printf 'src=%s\nhead=%s\nbranch=%s\ndirty=%s\nrel=%s\n' "$src" "$head" "$branch" "$dirty" "$rel"
INNER
)
if command -v git >/dev/null 2>&1; then
  bash -c "$inner" 2>/dev/null
elif [ -n "$DRY_RUN" ]; then
  echo skipped=1
else
  nix-shell -p git --run "$inner" 2>/dev/null
fi
'@
$WslSyncScript = $WslSyncScript -replace "`r", ''

# Reads the clone's HEAD and branch without git (a dry run on a distro with no git).
# Needs DST exported by the caller.
$WslHeadScript = @'
h=$(cat "$DST/.git/HEAD" 2>/dev/null)
head=
branch=
case "$h" in
  "ref: "*)
    r=${h#ref: }
    branch=${r#refs/heads/}
    if [ -f "$DST/.git/$r" ]; then
      head=$(cat "$DST/.git/$r")
    else
      head=$(awk -v r="$r" '$2 == r { print $1; exit }' "$DST/.git/packed-refs" 2>/dev/null)
    fi ;;
  *) head=$h ;;
esac
printf 'head=%s\nbranch=%s\n' "$head" "$branch"
'@
$WslHeadScript = $WslHeadScript -replace "`r", ''

# @{Code; Src; Head; Branch; Dirty; Rel = same | behind | diverged | unknown | skipped}
# Dirty is -1 when it could not be read.
function Get-CloneSync {
    param([string]$WslRepo, [string]$Clone, [switch]$DryRun)
    $s = "export SRC=$(Quote-Sh $WslRepo) DST=$(Quote-Sh $Clone)`n"
    if ($DryRun) { $s += "export DRY_RUN=1`n" }
    $s += $WslSyncScript
    Start-Wait "step 6: comparing the clone with the Windows main$(if (-not $DryRun) { ' (nix-shell -p git may fetch git first)' })"
    $r = Invoke-WslScript -Script $s -Name 'sync'
    $o = @{ Code = $r.Code; Src = ''; Head = ''; Branch = ''; Dirty = -1; Rel = 'unknown' }
    $rel = ''
    $skipped = $false
    foreach ($l in (([string]$r.Out) -split "`n")) {
        $x = $l.Trim()
        if ($x -eq 'skipped=1') { $skipped = $true }
        elseif ($x -match '^src=(.*)$') { $o.Src = $Matches[1] }
        elseif ($x -match '^head=(.*)$') { $o.Head = $Matches[1] }
        elseif ($x -match '^branch=(.*)$') { $o.Branch = $Matches[1] }
        elseif ($x -match '^dirty=(\d+)$') { $o.Dirty = [int]$Matches[1] }
        elseif ($x -match '^rel=(.*)$') { $rel = $Matches[1] }
    }
    # An unreadable git status is unknown, never "clean".
    if ($r.Code -eq 0 -and $o.Src -and $o.Head -and $o.Dirty -ge 0) {
        if ($rel -eq 'same' -or $rel -eq 'behind') { $o.Rel = $rel } else { $o.Rel = 'diverged' }
    }
    if ($skipped) { $o.Rel = 'skipped' }
    return $o
}

# A commit id read from outside (the distro): 40 hex (sha1) or 64 hex (sha256).
function Test-CommitId {
    param([string]$Value)
    return ($Value -cmatch '^[0-9a-f]{40}([0-9a-f]{24})?\z')
}

# Windows git: the Windows repo's main and its relation to a clone HEAD.
# @{Src; Rel = same | behind | diverged | unknown; Why = the cause when unknown}
function Get-WindowsRelation {
    param([string]$Head)
    if (-not (Test-CommitId $Head)) {
        return @{ Src = ''; Rel = 'unknown'; Why = 'the HEAD value read from the distro is not a commit id' }
    }
    $exe = Resolve-Program 'git'
    if (-not $exe) { return @{ Src = ''; Rel = 'unknown'; Why = 'no git on Windows' } }
    $s = Invoke-Native -ExePath $exe -Arguments @('rev-parse', '--verify', '-q', 'refs/heads/main') -WorkingDirectory $RepoRoot -TimeoutSeconds 60
    $src = Get-FirstLine $s.Out
    if ($s.Code -ne 0 -or -not $src) {
        return @{ Src = ''; Rel = 'unknown'; Why = "git rev-parse refs/heads/main failed in the Windows repo (exit $($s.Code))" }
    }
    if ($src -eq $Head) { return @{ Src = $src; Rel = 'same' } }
    $a = Invoke-Native -ExePath $exe -Arguments @('merge-base', '--is-ancestor', $Head, $src) -WorkingDirectory $RepoRoot -TimeoutSeconds 60
    if ($a.Code -eq 0) { return @{ Src = $src; Rel = 'behind' } }
    if ($a.Code -eq 1) { return @{ Src = $src; Rel = 'diverged' } }
    # merge-base failed: a commit the Windows repo does not have cannot be an ancestor of its main
    $c = Invoke-Native -ExePath $exe -Arguments @('cat-file', '-e', "$Head^{commit}") -WorkingDirectory $RepoRoot -TimeoutSeconds 60
    if ($c.Code -eq 1 -or $c.Code -eq 128) { return @{ Src = $src; Rel = 'diverged' } }
    return @{ Src = $src; Rel = 'unknown'; Why = "git merge-base exited $($a.Code) and git cat-file exited $($c.Code)" }
}

# Same shape as Get-CloneSync, for a dry run when the distro has no git yet.
function Get-CloneSyncNoGit {
    param([string]$WslRepo, [string]$Clone)
    $s = "export DST=$(Quote-Sh $Clone)`n" + $WslHeadScript
    $r = Invoke-WslScript -Script $s -Name 'headread'
    $o = @{ Code = $r.Code; Src = ''; Head = ''; Branch = ''; Dirty = -1; Rel = 'unknown'; NoGit = $true; Why = "the clone's HEAD could not be read (exit $($r.Code))" }
    foreach ($l in (([string]$r.Out) -split "`n")) {
        $x = $l.Trim()
        if ($x -match '^head=(.*)$') { $o.Head = $Matches[1] }
        elseif ($x -match '^branch=(.*)$') { $o.Branch = $Matches[1] }
    }
    if ($r.Code -eq 0) {
        if (Test-CommitId $o.Head) {
            $w = Get-WindowsRelation -Head $o.Head
            $o.Src = $w.Src
            $o.Rel = $w.Rel
            $o.Why = $w.Why
        } else {
            $o.Why = 'the HEAD value read from the distro is not a commit id'
        }
    }
    return $o
}

function Get-ShortSha {
    param([string]$Sha)
    if ($Sha.Length -gt 12) { return $Sha.Substring(0, 12) }
    return $Sha
}

# Step 6 for an existing clone: bring it up to the Windows repo's main, or stop with a
# clear message. Never resets, moves or deletes. In a dry run nothing is pulled; the
# same decision and exit code are reported, except where the answer depends on state a
# dry run cannot read (it says so and returns 0). Returns 0, 1 or 3.
function Resolve-CloneSync {
    param([string]$WslRepo, [string]$Clone, [string]$GateFile)
    $sync = Get-CloneSync -WslRepo $WslRepo -Clone $Clone -DryRun:$script:Dry
    $noGit = $false
    if ($sync.Rel -eq 'skipped') {
        $noGit = $true
        Say "step 6: git is not installed in the distro yet; comparing without it (the clone's HEAD is read from .git and the ancestry is checked with Windows git; local changes cannot be checked)"
        $sync = Get-CloneSyncNoGit -WslRepo $WslRepo -Clone $Clone
    }
    $src12 = Get-ShortSha $sync.Src
    $head12 = Get-ShortSha $sync.Head
    # The advice must work when pasted into PowerShell on NixOS: a bare --exec program is not on
    # the exec PATH there, so it runs through the root shell (-- sh -lc). The clone path comes from the
    # validated username (^[a-z_][a-z0-9_-]*$), so it needs no quoting inside the single quotes.
    # A move, never a delete: the clone can hold gitignored files that git status does
    # not show (for example home/.chezmoidata/personal.yaml, seeded by install.sh).
    $stamp = Get-UtcStamp
    $recovery = "if you want a fresh clone, move this one aside: wsl -d NixOS -u root -- sh -lc 'mv $Clone $Clone.old-$stamp', then re-run (the clone is recreated from main). Do not delete it: it can hold gitignored files such as home/.chezmoidata/personal.yaml that git status does not show. This script never resets, moves or deletes it. If the gitignored home/.chezmoidata/personal.yaml exists in the moved folder (it stays there), after the re-run copy it into the new clone as the default user, so the new folder and file are yours (this overwrites the one install.sh seeded from the example): wsl -d NixOS -- sh -lc 'test -f $Clone.old-$stamp/home/.chezmoidata/personal.yaml && mkdir -p $Clone/home/.chezmoidata && cp -p $Clone.old-$stamp/home/.chezmoidata/personal.yaml $Clone/home/.chezmoidata/personal.yaml', then run this script again so install.sh applies it"
    if ($sync.Rel -eq 'unknown') {
        if ($noGit) {
            $why = $sync.Why
            if (-not $why) { $why = 'no git usable on Windows' }
            Say "step 6: the clone cannot be compared ($why; the distro has no git either); a real run may exit 0 or 1 here, which a dry run cannot tell"
            return 0
        }
        Say "step 6: cannot compare the clone with the Windows repo's main (exit $($sync.Code), or git status failed); fix that and re-run"
        return 1
    }
    if ($sync.Rel -eq 'same') {
        Say "step 6: clone is up to date ($head12)$(if ($noGit) { ' (local changes were not checked)' })"
    } elseif ($sync.Rel -eq 'diverged') {
        $dirtyNote = ''
        if ($sync.Dirty -gt 0) { $dirtyNote = " and has $($sync.Dirty) local changes" }
        Say "step 6: the clone is at $head12$dirtyNote but the Windows repo's main is $src12, which is not a descendant of it (rebased or diverged history); $recovery"
        return 1
    } elseif ($sync.Dirty -gt 0) {
        Say "step 6: the clone is at $head12 but the Windows repo's main is $src12, and the clone has local changes ($($sync.Dirty) entries in git status --porcelain); commit or stash them there, or $recovery"
        return 1
    } elseif ($sync.Branch -ne 'main') {
        $on = if ($sync.Branch) { "branch '$($sync.Branch)'" } else { 'a detached HEAD' }
        Say "step 6: the clone is behind ($head12 -> $src12) but it is on $on, not main, so a pull would not update main; check out main there, or $recovery"
        return 1
    } else {
        if ($script:Dry) {
            Say "step 6: would fast-forward the clone ($head12 -> $src12) from $WslRepo (main)$(if ($noGit) { '; a real run exits 1 instead if the clone has local changes, which cannot be checked here' })"
            return 0
        }
        Start-Wait "step 6: the clone is behind ($head12 -> $src12); fast-forwarding it from $WslRepo (main), under a minute"
        $pull = Invoke-WslScript -Name 'pull' -Passthrough -Script @"
export SRC=$(Quote-Sh $WslRepo) DST=$(Quote-Sh $Clone)
nix-shell -p git --run 'git -c safe.directory="`$SRC" -c safe.directory="`$DST" -C "`$DST" pull --ff-only "`$SRC" main'
"@
        if ($pull.Code -ne 0) {
            Say "step 6: git pull --ff-only exited $($pull.Code); the clone stays at $head12 (Windows main: $src12); fix it by hand or $recovery"
            return 1
        }
        $sync = Get-CloneSync -WslRepo $WslRepo -Clone $Clone
        if ($sync.Rel -ne 'same') {
            Say "step 6: after the pull the clone is still not at the Windows main ($src12); $recovery"
            return 1
        }
        Say "step 6: clone fast-forwarded to $(Get-ShortSha $sync.Head)"
    }
    if (-not (Test-InWsl -User root -Arguments @("$Sw/test", '-f', $GateFile))) {
        Say 'step 6: wsl.nix is in the Windows working tree but not in its committed main; commit it, then re-run'
        return 3
    }
    return 0
}

# Printed when step 9 leaves the distro in an unexpected state.
function Write-Step9Recovery {
    Say "step 9: recovery: restore from the before-setup export $StateRoot\wsl-exports\NixOS-before-setup-<UTC>.tar"
    Say 'step 9: to test it: wsl --import NixOS-restore <dir> <tar>; to replace NixOS: wsl --unregister NixOS, then wsl --import NixOS <dir> <tar> (a human decision, never scripted)'
    Say 'step 9: or roll the system back: wsl -d NixOS -u root -- bash -lc ''nixos-rebuild --rollback boot'', then wsl --terminate NixOS and start it again'
}

# ---------------------------------------------------------------- main

function Invoke-BootstrapRun {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [switch]$DryRun,
        [switch]$EnableSystemRestore,
        [string]$Export,
        [string]$Report,
        [switch]$ToolsOnly,
        [switch]$ClaudeStatusLine,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
    )
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Dry = [bool]$DryRun
    $script:DryDistroNoted = $false
    $script:Prefix = if ($DryRun) { '[bootstrap][dry-run]' } else { '[bootstrap]' }
    $script:StartUtc = [datetime]::UtcNow
    # The environment may change between runs of a long-lived host (tests).
    $script:StateRoot = Join-Path $env:LOCALAPPDATA 'app-configs'

    # arguments
    $hasExport = $PSBoundParameters.ContainsKey('Export')
    $hasReport = $PSBoundParameters.ContainsKey('Report')
    if ($Rest) { Say "error: unexpected arguments: $($Rest -join ' ')"; return 2 }
    if ($hasExport -and $hasReport) { Say 'error: -Export and -Report cannot be combined'; return 2 }
    if (($hasExport -or $hasReport) -and $EnableSystemRestore) {
        Say 'error: -EnableSystemRestore cannot be combined with -Export or -Report'
        return 2
    }
    if ($ToolsOnly -and ($hasExport -or $hasReport -or $EnableSystemRestore)) {
        Say 'error: -ToolsOnly cannot be combined with -Export, -Report or -EnableSystemRestore'
        return 2
    }
    if ($ClaudeStatusLine -and ($ToolsOnly -or $hasExport -or $hasReport -or $EnableSystemRestore)) {
        Say 'error: -ClaudeStatusLine cannot be combined with -ToolsOnly, -Export, -Report or -EnableSystemRestore'
        return 2
    }
    foreach ($pair in @(@('Export', $Export, $hasExport), @('Report', $Report, $hasReport))) {
        if ($pair[2] -and $pair[1] -cnotmatch '^[a-z0-9][a-z0-9-]{0,39}$') {
            Say "error: -$($pair[0]) label must match ^[a-z0-9][a-z0-9-]{0,39}$"
            return 2
        }
    }

    if ($ClaudeStatusLine) { return (Invoke-ClaudeStatusLine) }

    if ($ToolsOnly) {
        if (Test-IsAdmin) { Say 'step C: elevated; re-run non-elevated (winget installs for this user)'; return 3 }
        return (Invoke-CommitTooling)
    }

    try {
        $user = Get-NixUser -Root $RepoRoot
    } catch {
        Say "error: cannot read the username from nix\vars\default.nix: $($_.Exception.Message)"
        return 1
    }
    $clone = "/home/$user/app-configs"
    $elevated = [bool](Test-IsAdmin)

    if ($script:Dry) {
        Say "probe os: $(Format-Probe (Get-OsInfo))"
        Say "probe elevated: $elevated"
        $a = Get-WslAppx
        Say "probe appx: $(if ($null -eq $a) { 'absent' } else { $a })"
        if ($null -ne $a -and $a -notlike 'unavailable*') {
            $v = Get-WslVersion
            Say "probe wsl --version: exit $($v.Code) version $(if ($v.Version) { $v.Version } else { 'unknown' })"
        } else {
            Say 'probe wsl --version: skipped (no Appx package; wsl.exe is not run)'
        }
        Say "probe optional-features: $(Format-Probe (Get-OptionalFeatureStates))"
        $rp = Get-RestorePoints
        if ($rp -is [string]) { Say "probe restore-points: $rp" }
        else { Say "probe restore-points: $(@($rp).Count) point(s)" }
    }

    # on-demand modes
    if ($hasReport -or $hasExport) {
        if ($elevated) { Say 'error: elevated; re-run non-elevated as the same user'; return 3 }
        if ($hasReport) {
            if ($script:Dry) { Say "would write the WSL and Windows reports labelled '$Report'"; return 0 }
            Write-BothReports -Label $Report -User $user
            return 0
        }
        if (-not (Test-WslPackage)) { Say 'error: WSL is not installed (no Appx package); nothing to export'; return 1 }
        if ((Get-DistroList) -notcontains $Distro) { Say "error: distro $Distro not found; nothing to export"; return 1 }
        return (Invoke-DistroExport -Label $Export)
    }

    if ($elevated) {
        Say 'step C: skipped (elevated run); run non-elevated for the commit tooling'
    } else {
        $c = Invoke-CommitTooling
        if ($c -ne 0) { return $c }
    }

    $arch = Get-OsArch
    if ($arch -ne 'X64') {
        Say "error: Windows architecture is '$arch'; this bootstrap supports x64 only (the pinned NixOS-WSL asset is x64)"
        return 1
    }

    # step 0
    if (Test-RebootPending) {
        Say 'step 0: reboot pending (CBS RebootPending); restart from Settings > Windows Update > Restart now (a plain restart or a shutdown may not clear it), then re-run'
        return 3
    }
    Say 'step 0: no reboot pending'
    if ($elevated -and -not $script:Dry) {
        $hs = Join-Path $StateRoot 'host-snapshots'
        $haveBefore = (Test-Path -LiteralPath $hs) -and
            @(Get-ChildItem -LiteralPath $hs -Directory | Where-Object { $_.Name -match '^\d{8}T\d{6}Z-before$' }).Count -gt 0
        if (-not $haveBefore) {
            $d = Write-WindowsReport -Label 'before'
            Say "step 0: Windows report (before): $(Join-Path $d 'windows.txt')"
        }
    }

    # step 1
    $appx = Get-WslAppx
    $appxPresent = ($appx -is [string]) -and ($appx -notlike 'unavailable*')
    if ($appxPresent) {
        $ver = Get-WslVersion
        if ($ver.Code -ne 0) { Say "step 1: Appx package $appx present but wsl --version exited $($ver.Code)" }
    } else {
        $ver = @{ Code = 1; Version = $null; Out = '' }
        Say 'step 1: WSL Appx package absent (wsl.exe is not run)'
    }
    $installed = $appxPresent -and ($ver.Code -eq 0)
    if (-not $installed) {
        if (-not $elevated) { Say 'step 1: WSL is not installed; run elevated'; return 3 }
        if ($script:Dry) {
            Say 'step 1: would reuse or create a restore point, run wsl --install --no-distribution, then stop for a reboot'
            return 3
        }
        $points = Get-RestorePoints
        $recent = $null
        if ($points -isnot [string]) {
            $recent = @($points) | Where-Object { $_ -and $_.Created -gt [datetime]::UtcNow.AddHours(-24) } | Select-Object -First 1
        }
        if ($recent) {
            Say "step 1: reusing restore point from $($recent.Created.ToString('o'))"
        } else {
            Say 'step 1: creating a restore point (can take a minute)'
            $res = New-RestorePoint 'app-configs: before WSL install'
            if (-not $res.Ok) {
                if (-not $EnableSystemRestore) {
                    Say "step 1: cannot create a restore point: $($res.Error); re-run with -EnableSystemRestore to enable System Restore on C:\"
                    return 3
                }
                Say 'step 1: enabling System Restore on C:\ (can take a minute)'
                $en = Enable-SystemRestore 'C:\'
                if (-not $en.Ok) { Say "step 1: cannot enable System Restore: $($en.Error)"; return 1 }
                Say 'step 1: creating a restore point again (can take a minute)'
                $res = New-RestorePoint 'app-configs: before WSL install'
                if (-not $res.Ok) { Say "step 1: restore point failed after enabling System Restore: $($res.Error)"; return 1 }
            }
            $after = Get-RestorePoints
            $fresh = $null
            if ($after -isnot [string]) {
                $fresh = @($after) | Where-Object { $_ -and $_.Created -gt $script:StartUtc } | Select-Object -First 1
            }
            if (-not $fresh) { Say 'step 1: no restore point newer than this run exists; not installing WSL'; return 1 }
            Say 'step 1: restore point created'
        }
        Start-Wait 'step 1: running wsl --install --no-distribution (a few minutes; a UAC or progress window may appear)'
        $w = Invoke-Wsl -Global -Passthrough -Arguments @('--install', '--no-distribution')
        if ($w.Code -ne 0) { Say "step 1: wsl --install exited $($w.Code)"; return 1 }
        Say 'step 1: WSL installed; reboot, then re-run in a normal PowerShell'
        return 3
    }
    Say "step 1: WSL already installed ($($ver.Version))"
    if ($elevated) { Say 'step 1: re-run non-elevated as the same user'; return 3 }

    # step 2
    if ($null -eq $ver.Version -or $ver.Version -lt $MinWslVersion) {
        if ($script:Dry) {
            Say "step 2: would run wsl --update (found $(if ($ver.Version) { $ver.Version } else { 'unknown' }), need $MinWslVersion)"
        } else {
            Start-Wait "step 2: updating WSL, a few minutes (found $(if ($ver.Version) { $ver.Version } else { 'unknown' }), need $MinWslVersion)"
            [void](Invoke-Wsl -Global -Passthrough -Arguments @('--update'))
            $ver = Get-WslVersion
            if ($null -eq $ver.Version -or $ver.Version -lt $MinWslVersion) {
                Say "step 2: WSL is still older than $MinWslVersion after wsl --update"
                return 1
            }
        }
    } else {
        Say "step 2: WSL $($ver.Version) is new enough"
    }

    # step 3
    $known = (Get-DistroList) -contains $Distro
    $virt = $false
    if ($known) {
        Say "step 3: $Distro already imported"
    } else {
        $file = Join-Path (Join-Path $StateRoot 'downloads') "nixos-wsl-$NixosWslTag.wsl"
        $installDir = Join-Path (Join-Path $StateRoot 'wsl') $Distro
        if ($script:Dry) {
            Say "step 3: would download $NixosWslUrl, verify sha256 $NixosWslSha256, and import into $installDir"
            $virt = $true
        } else {
            [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file))
            [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $installDir))
            $reuse = (Test-Path -LiteralPath $file) -and ((Get-Sha256 $file) -eq $NixosWslSha256)
            if ($reuse) {
                Say "step 3: reusing verified download $file"
            } else {
                Say "step 3: downloading $NixosWslUrl"
                try {
                    Invoke-Download -Url $NixosWslUrl -OutFile $file
                } catch {
                    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
                    Say "step 3: download failed: $($_.Exception.Message)"
                    return 1
                }
                $got = Get-Sha256 $file
                if ($got -ne $NixosWslSha256) {
                    Remove-Item -LiteralPath $file -Force
                    Say "step 3: sha256 mismatch (expected $NixosWslSha256, got $got); file deleted"
                    return 1
                }
            }
            Start-Wait "step 3: importing $Distro with wsl --import (a minute or two)"
            $imp = Invoke-Wsl -Global -Passthrough -Arguments @('--import', $Distro, $installDir, $file, '--version', '2')
            if ($imp.Code -ne 0) { Say "step 3: wsl --import exited $($imp.Code)"; return 1 }
            Say "step 3: imported $Distro"
        }
    }

    # step 4
    if ($virt) {
        Say 'step 4: would run nix-channel --update if nixpkgs is not on the channel path'
    } else {
        Write-DryDistroNote
        $ch = Invoke-WslScript -Name 'channel' -User root -Script 'nix-instantiate --find-file nixpkgs >/dev/null 2>&1'
        if ($ch.Code -eq 0) {
            Say 'step 4: nixpkgs channel present'
        } elseif ($script:Dry) {
            Say 'step 4: would run nix-channel --update as root'
        } else {
            Start-Wait 'step 4: running nix-channel --update as root (can take a few minutes)'
            $u = Invoke-Wsl -User root -Passthrough -Arguments @("$Sw/nix-channel", '--update')
            if ($u.Code -ne 0) { Say "step 4: nix-channel --update exited $($u.Code)"; return 1 }
        }
    }

    # step 5
    if ($virt) {
        Say 'step 5: would check systemd as PID 1 and WSLInterop'
    } else {
        $f = Get-DistroFacts
        if ($f.Comm -ne 'systemd' -or $f.Interop -ne 'present') {
            Say "step 5: need systemd as PID 1 and WSLInterop; found PID 1 '$($f.Comm)', WSLInterop $($f.Interop)"
            return 1
        }
        Say 'step 5: systemd is PID 1 and WSLInterop exists'
    }

    # step 6: gate on the Windows repo first, then the clone
    if (-not (Test-RepoGitDir)) {
        Say "step 6: $RepoRoot\.git is not a directory (a worktree or missing); run from the main clone"
        return 1
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'nix\modules\nixos\wsl.nix'))) {
        Say 'step 6: next: land the desktop-first commits (D0) on origin, then git pull --ff-only in this Windows clone and re-run'
        return 3
    }
    Say 'step 6: wsl.nix present in the Windows repo (gate passed)'
    if ($virt) {
        Say "step 6: would read the origin of $RepoRoot (nix-shell -p git; skipped in a dry run), then clone it to $clone"
    } elseif ($script:Dry) {
        $wslRepo = Get-WslPath $RepoRoot
        if (-not $wslRepo) { Say "step 6: wslpath could not convert $RepoRoot"; return 1 }
        if (-not (Test-InWsl -User root -Arguments @("$Sw/test", '-d', "$clone/.git"))) {
            Say "step 6: would read the origin of $RepoRoot (nix-shell -p git; skipped in a dry run), then clone it to $clone"
        } else {
            $rc = Resolve-CloneSync -WslRepo $wslRepo -Clone $clone -GateFile "$clone/nix/modules/nixos/wsl.nix"
            if ($rc -ne 0) { return $rc }
        }
    } else {
        $wslRepo = Get-WslPath $RepoRoot
        if (-not $wslRepo) { Say "step 6: wslpath could not convert $RepoRoot"; return 1 }
        $readOrigin = @"
export R=$(Quote-Sh $wslRepo)
url=`$(nix-shell -p git --run 'git config -f "`$R/.git/config" remote.origin.url' 2>/dev/null)
printf 'origin=%s\n' "`$url"
"@
        $o = Invoke-WslScript -Script $readOrigin -Name 'origin'
        $origin = ''
        foreach ($l in (([string]$o.Out) -split "`n")) {
            if ($l.Trim() -match '^origin=(.*)$') { $origin = Hide-UrlUserInfo $Matches[1].Trim() }
        }
        if ($origin -eq '') {
            Say "step 6: $RepoRoot has no usable remote.origin.url; add one (git remote add origin <url>) and re-run"
            return 1
        }
        $have = Test-InWsl -User root -Arguments @("$Sw/test", '-d', "$clone/.git")
        $gateFile = "$clone/nix/modules/nixos/wsl.nix"
        if (-not $have) {
            # The default user may no longer be nixos (a later run, a removed user).
            $ownerFacts = Get-DistroFacts
            $owner = $ownerFacts.User
            if ($ownerFacts.Code -ne 0 -or -not $owner) { Say 'step 6: cannot read the default user of NixOS'; return 1 }
            [void](Invoke-Wsl -User root -Arguments @("$Sw/mkdir", '-p', $clone))
            $own = Invoke-Wsl -User root -Arguments @("$Sw/chown", "${owner}:users", $clone)
            if ($own.Code -ne 0) { Say "step 6: chown of $clone exited $($own.Code)"; return 1 }
            $cloneScript = @"
export SRC=$(Quote-Sh $wslRepo) DST=$(Quote-Sh $clone) URL=$(Quote-Sh $origin)
cd /tmp
nix-shell -p git --run 'git -c safe.directory="`$SRC" clone -b main "`$SRC" "`$DST" && git -C "`$DST" remote set-url origin "`$URL"'
"@
            Start-Wait "step 6: cloning $wslRepo to $clone as $owner (under a minute; longer if nix-shell must fetch git)"
            $c = Invoke-WslScript -Script $cloneScript -Name 'clone' -User $owner -Passthrough
            if ($c.Code -ne 0) { Say "step 6: clone exited $($c.Code)"; return 1 }
            Say "step 6: cloned to $clone, origin $origin"
            if (-not (Test-InWsl -User root -Arguments @("$Sw/test", '-f', $gateFile))) {
                Say 'step 6: wsl.nix is in the Windows working tree but not in its committed main; commit it, then re-run'
                return 3
            }
        } else {
            $cur = Invoke-WslScript -Name 'cloneorigin' -Script @"
export DST=$(Quote-Sh $clone)
url=`$(nix-shell -p git --run 'git -c safe.directory="`$DST" -C "`$DST" config remote.origin.url' 2>/dev/null)
printf 'origin=%s\n' "`$url"
"@
            $curUrl = ''
            foreach ($l in (([string]$cur.Out) -split "`n")) {
                if ($l.Trim() -match '^origin=(.*)$') { $curUrl = Hide-UrlUserInfo $Matches[1].Trim() }
            }
            if ($curUrl.StartsWith('/mnt/')) {
                $fix = Invoke-WslScript -Name 'setorigin' -Script @"
export DST=$(Quote-Sh $clone) URL=$(Quote-Sh $origin)
nix-shell -p git --run 'git -c safe.directory="`$DST" -C "`$DST" remote set-url origin "`$URL"'
"@
                if ($fix.Code -ne 0) { Say "step 6: setting the clone origin exited $($fix.Code)"; return 1 }
                Say "step 6: clone origin set to $origin"
            } else {
                Say "step 6: clone exists at $clone; origin left unchanged"
            }
            $rc = Resolve-CloneSync -WslRepo $wslRepo -Clone $clone -GateFile $gateFile
            if ($rc -ne 0) { return $rc }
        }
    }

    # step 7a / 7b
    if ($virt) {
        Say 'step 7: would write the before-setup WSL report and export the distro (before-setup)'
    } else {
        $hasSnap = (Invoke-WslScript -Name 'hassnap' -User root -Script $WslHasSnapScript).Code -eq 0
        if ($hasSnap) {
            Say 'step 7a: before-setup WSL report exists'
        } elseif ($script:Dry) {
            Say 'step 7a: would write the before-setup WSL report'
        } else {
            $d = Write-WslReport -Label 'before-setup' -User $user
            if (-not $d) { Say 'step 7a: the before-setup WSL report failed'; return 1 }
            Say "step 7a: WSL report (before-setup): $d"
        }
        $rc = Invoke-DistroExport -Label 'before-setup'
        if ($rc -ne 0) { return $rc }
    }

    # step 9: the system layer is applied on every run (setup is idempotent and
    # rebuilds the system, so a new commit's system changes always take effect)
    if ($script:Dry) {
        Say "step 9: would apply the system layer (system-setup.sh --apply as root, idempotent, rebuilds NixOS), restart the distro only if the default user is not $user or app-configs-wsl.nix is missing, and chown /home/$user if its owner is not $user"
    } else {
        Start-Wait "step 9: applying the system layer (idempotent: system-setup.sh --apply as root, rebuilds NixOS; minutes, up to 30 or more on the first run)"
        $s = Invoke-Wsl -User root -Passthrough -Arguments @("$Sw/env", "USER_NAME=$user", "$Sw/bash", '-lc', "exec bash $clone/ops/system-setup.sh --apply")
        if ($s.Code -ne 0) {
            # ops/system-setup.sh exit codes: on the switch path 4 (units failed) and 2 (the activate
            # script failed after the profile moved) both mean "the new generation is at least partly
            # activated and the new /etc/nixos files are kept"; the script exits with that same code.
            # For any other non-zero code the outcome is only in its own output: older versions exit 1
            # for an activated switch with failed units (and restore the files), the legacy non-ng
            # nixos-rebuild reports an activation failure as 1, and 126, 127 or 130 (Ctrl+C) say
            # nothing about the state. So nothing is claimed about activation or the files there.
            if ($s.Code -eq 4 -or $s.Code -eq 2) {
                Say "step 9: system-setup.sh exited $($s.Code): the new generation is (at least partly) activated (exit 4: some units failed; exit 2: the activation script failed after the profile moved) and the new /etc/nixos files are kept because they match the running system. Check the failed units: wsl -d NixOS -u root -- sh -lc 'systemctl --failed'; roll back only if the system is broken (the rollback command and the restore-from-backup hint are printed in its output above); re-run this script once the cause is fixed"
            } else {
                Say "step 9: system-setup.sh exited $($s.Code): the outcome is in its output above. If it shows 'a nixos-rebuild switch had started', the new generation may be active (older versions of system-setup.sh exit 1 for an activated switch with failed units and then restore the files). Check the failed units: wsl -d NixOS -u root -- sh -lc 'systemctl --failed'; fix the cause and re-run this script"
            }
            return 1
        }
        $f = Get-DistroFacts
        $hasCfg = Test-InWsl -User root -Arguments @("$Sw/test", '-f', '/etc/nixos/app-configs-wsl.nix')
        if ($f.User -ne $user -or -not $hasCfg) {
            Say "step 9: restarting the distro so the new default user takes effect (default user '$($f.User)', want '$user')"
            [void](Invoke-Wsl -Global -Arguments @('--terminate', $Distro))
            [void](Invoke-Wsl -User root -Arguments @("$Sw/true"))
            [void](Invoke-Wsl -Global -Arguments @('--terminate', $Distro))
            $ch = Invoke-Wsl -User root -Arguments @("$Sw/chown", '-R', "${user}:users", "/home/$user")
            if ($ch.Code -ne 0) { Say "step 9: chown exited $($ch.Code)"; Write-Step9Recovery; return 1 }
            $f = Get-DistroFacts
            $hasCfg = Test-InWsl -User root -Arguments @("$Sw/test", '-f', '/etc/nixos/app-configs-wsl.nix')
            if ($f.User -ne $user -or -not $hasCfg) {
                Say "step 9: after setup the default user is '$($f.User)' (want '$user'), app-configs-wsl.nix present: $hasCfg"
                Write-Step9Recovery
                return 1
            }
        } else {
            # A chown that failed or was interrupted on an earlier run must not be skipped now. The find
            # stays on one filesystem (-xdev); chown -R, which fixes what the find reports, does descend
            # into mounts below /home, so a mount point there is repaired but never checked.
            Start-Wait "step 9: checking that everything under /home/$user is owned by $user (a moment on a big home)"
            $own = Invoke-Wsl -User root -TimeoutSeconds 300 -Arguments @("$Sw/find", "/home/$user", '-xdev', '!', '-user', $user, '-print', '-quit')
            $first = Get-FirstLine $own.Out
            if ($own.Code -ne 0 -or $first) {
                $why = if ($first) { "$first is not owned by $user" } else { "the ownership of /home/$user could not be verified (find exit $($own.Code))" }
                Say "step 9: $why; running chown -R"
                $ch = Invoke-Wsl -User root -Arguments @("$Sw/chown", '-R', "${user}:users", "/home/$user")
                if ($ch.Code -ne 0) { Say "step 9: chown exited $($ch.Code)"; Write-Step9Recovery; return 1 }
                Say "step 9: system layer applied; ownership of /home/$user repaired, no restart needed"
            } else {
                Say "step 9: system layer applied; no restart needed (default user $user, app-configs-wsl.nix present, ownership correct)"
            }
        }
    }

    # step 11
    if ($script:Dry) {
        Say "step 11: would check systemd, WSLInterop and the default user $user"
    } else {
        $f = Get-DistroFacts
        if ($f.Comm -ne 'systemd' -or $f.Interop -ne 'present' -or $f.User -ne $user) {
            Say "step 11: expected systemd, WSLInterop and user '$user'; found PID 1 '$($f.Comm)', WSLInterop $($f.Interop), user '$($f.User)'"
            return 1
        }
        Say "step 11: systemd, WSLInterop and user $user confirmed"
    }

    # step 12
    if ($script:Dry) {
        Say "step 12: would run ops/install.sh as $user in $clone, then write the after-install reports"
        return 0
    }
    Start-Wait "step 12: running ops/install.sh as $user (20 minutes or more); it is interactive: answer the profile and selection prompts that appear (none if a selection is already saved); it can also stay silent for minutes, for example during home-manager switch, which is not a freeze"
    $i = Invoke-Wsl -User $user -Cd $clone -Passthrough -Arguments @("$Sw/bash", '-lc', 'exec bash ops/install.sh')
    if ($i.Code -ne 0) {
        Say "ops/install.sh exited $($i.Code)"
        Say 'on a re-run the one-time steps that finished (download, import, report, export) are skipped, and the idempotent steps 6 and 9 run again; fix the cause, then run this script again'
        return 1
    }
    Write-BothReports -Label 'after-install' -User $user
    Say 'step 12b: done. Next: add the SSH key to GitHub, fill personal.yaml, log in to the tools, then run sys-readiness'
    return 0
}

# The run itself, then a closing notice if the git hooks could not be installed (the exit
# code is the run's own).
function Invoke-Bootstrap {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [switch]$DryRun,
        [switch]$EnableSystemRestore,
        [string]$Export,
        [string]$Report,
        [switch]$ToolsOnly,
        [switch]$ClaudeStatusLine,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
    )
    $script:HooksWarning = $null
    $rc = Invoke-BootstrapRun @PSBoundParameters
    if ($script:HooksWarning) { Say "NOTICE: $script:HooksWarning" }
    return [int]$rc
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-Bootstrap @PSBoundParameters) }
