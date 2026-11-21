# Tests for ops\windows\bootstrap.ps1. Plain PowerShell 5.1, no Pester.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\windows\bootstrap.tests.ps1
# Every system seam is replaced by a stub that throws unless a test stubs it, so
# nothing here touches WSL, winget, the registry, restore points or the network.
$ErrorActionPreference = 'Stop'

$TestsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $TestsDir)) 'ops\windows\bootstrap.ps1'
$ScriptPath = (Resolve-Path $ScriptPath).Path

$OrigLocalAppData = $env:LOCALAPPDATA
$TestTmp = Join-Path ([IO.Path]::GetTempPath()) ('bootstrap-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Force -Path $TestTmp)

. $ScriptPath
$RealInvokeNative = ${function:Invoke-Native}
$RealGetToolVersion = ${function:Get-ToolVersion}
$RealGetHooksPath = ${function:Get-HooksPath}
$RealGetWindowsRelation = ${function:Get-WindowsRelation}
$RealResolveGitBash = ${function:Resolve-GitBash}
$RealInvokeHooksInstaller = ${function:Invoke-HooksInstaller}
$RealGetHookEnvOverrides = ${function:Get-HookEnvOverrides}
$RealTestLefthookHooks = ${function:Test-LefthookHooks}
$RealInvokeWinget = ${function:Invoke-Winget}
$RealInvokeLefthook = ${function:Invoke-Lefthook}
$RealUpdateSessionPath = ${function:Update-SessionPath}
$RealResolveProgram = ${function:Resolve-Program}
$RealInvokeWslRaw = ${function:Invoke-WslRaw}
$RealGetWingetList = ${function:Get-WingetList}
$RealGetForeignHooks = ${function:Get-ForeignHooks}
$RealInvokeDownload = ${function:Invoke-Download}
$RealGetSha256 = ${function:Get-Sha256}
$RealInvokeJq = ${function:Invoke-Jq}
$RealGetTemplateStatusLine = ${function:Get-TemplateStatusLine}
$RealInvokeStatusLineRender = ${function:Invoke-StatusLineRender}
$OrigRepoRoot = $RepoRoot

# Keep the harness output clean: the script logs through Write-Host.
$script:HostOut = New-Object 'System.Collections.Generic.List[string]'
function Write-Host { [void]$script:HostOut.Add(($args -join ' ')) }

# ---------------------------------------------------------------- harness

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0
$script:AllLog = New-Object 'System.Collections.Generic.List[string]'
$script:SkipList = New-Object 'System.Collections.Generic.List[string]'
$script:Calls = New-Object 'System.Collections.Generic.List[object]'
$script:Raw = New-Object 'System.Collections.Generic.List[object]'
$script:Bodies = @{}

$Sigs = @{
    'Invoke-WslRaw'        = '[string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds'
    'Invoke-Download'      = '[string]$Url, [string]$OutFile'
    'Get-Sha256'           = '[string]$Path'
    'New-RestorePoint'     = '[string]$Description'
    'Enable-SystemRestore' = '[string]$Drive'
    'Get-FreeBytes'        = '[string]$Path'
    'Get-WindowsRelation'  = '[string]$Head'
    'Invoke-HooksInstaller' = '[string]$Bash, [string]$Mode'
    'Invoke-Native'        = '[string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory, [int]$HeartbeatSeconds'
    'Get-ToolVersion'      = '[string]$Name, [string[]]$VersionArgs'
    'Resolve-Program'      = '[string]$Name'
    'Invoke-Winget'        = '[string]$Id'
    'Get-EnvScopes'        = '[string]$Name'
    'Get-GitBashHome'      = '[string]$Bash'
    'Invoke-Jq'            = '[string[]]$Arguments'
    'Invoke-StatusLineRender' = '[string]$Bash, [string]$PayloadPath'
    'Get-TemplateStatusLine' = '[string]$Path'
}

function Reset-Stubs {
    $script:Calls.Clear()
    $script:Raw.Clear()
    $script:Bodies = @{}
    foreach ($n in $SeamNames) {
        $sig = ''
        if ($Sigs.ContainsKey($n)) { $sig = $Sigs[$n] }
        $script:Bodies[$n] = [scriptblock]::Create("throw 'unstubbed: $n'")
        $code = "param($sig) `$script:Calls.Add([pscustomobject]@{ Name = '$n'; Args = `$PSBoundParameters; Log = `$(if (`$script:LogLines) { `$script:LogLines.Count } else { 0 }) }); & `$script:Bodies['$n'] @PSBoundParameters"
        Set-Item -Path "function:script:$n" -Value ([scriptblock]::Create($code))
    }
}

function Stub {
    param([string]$Name, [scriptblock]$Body)
    $script:Bodies[$Name] = $Body
}

function New-TestEnv {
    param([string]$UserLine = '  username = "tester";')
    $script:T = Join-Path $TestTmp ([guid]::NewGuid().ToString('N'))
    $lad = Join-Path $script:T 'lad'
    $repo = Join-Path $script:T 'repo'
    [void](New-Item -ItemType Directory -Force -Path $lad)
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $repo 'nix\vars'))
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $repo 'nix\modules\nixos'))
    [IO.File]::WriteAllText((Join-Path $repo 'nix\vars\default.nix'), "let`n$UserLine`nin { }`n")
    [IO.File]::WriteAllText((Join-Path $repo 'nix\modules\nixos\wsl.nix'), '{ }')
    $env:LOCALAPPDATA = $lad
    $script:RepoRoot = $repo
    $script:Lad = $lad
    $script:State = Join-Path $lad 'app-configs'
}

function Get-LadItems {
    return @(Get-ChildItem -LiteralPath $script:Lad -Recurse -Force)
}

function Assert-True {
    param($Cond, [string]$Msg)
    if (-not $Cond) { throw "assertion failed: $Msg" }
}

function Assert-Eq {
    param($Actual, $Expected, [string]$Msg)
    if ("$Actual" -ne "$Expected") { throw "assertion failed: $Msg (expected '$Expected', got '$Actual')" }
}

function Get-Log { return ($script:LogLines -join "`n") }

function Assert-Log {
    param([string]$Pattern)
    Assert-True ((Get-Log) -match $Pattern) "log matches /$Pattern/; log was:`n$(Get-Log)"
}

function Run-Boot {
    param([hashtable]$Params = @{})
    $r = @(Invoke-Bootstrap @Params)
    if ($r.Count -ne 1 -or $r[0] -isnot [int]) { throw "Invoke-Bootstrap returned $($r.Count) values: $($r -join '|')" }
    return $r[0]
}

function Get-RawText { return @($script:Raw | ForEach-Object { $_.A -join ' ' }) }

function Find-Raw {
    param([string]$Pattern)
    $t = @(Get-RawText)
    $hits = @()
    for ($i = 0; $i -lt $t.Count; $i++) { if ($t[$i] -match $Pattern) { $hits += $i } }
    return $hits
}

function Get-ScriptText {
    param($RawCall)
    $a = $RawCall.A
    $i = [array]::IndexOf($a, '/bin/sh')
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($a[$i + 4]))
}

function Get-ScriptCalls {
    param([string]$Name)
    return @($script:Raw | Where-Object { ($_.A -join ' ') -match "app-configs-$Name-" })
}

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        New-TestEnv
        Reset-Stubs
        & $Body
        if ($script:LogLines) { $script:AllLog.AddRange($script:LogLines) }
        $script:Pass++
        [Console]::WriteLine("PASS $Name")
    } catch {
        if ($_.Exception.Message -like 'SKIP: *') {
            $script:Skip++
            [void]$script:SkipList.Add("$Name : $($_.Exception.Message.Substring(6))")
            [Console]::WriteLine("SKIP $Name : $($_.Exception.Message.Substring(6))")
        } else {
            $script:Fail++
            [Console]::WriteLine("FAIL $Name : $($_.Exception.Message)")
        }
    }
}

# ---------------------------------------------------------------- fake WSL

function New-WslState {
    return @{
        Version = '2.6.1.0'; VersionCode = 0; UpdateFails = $false; InstallWslCode = 0
        Distros = @('NixOS'); ImportCode = 0; ExportCode = 0; ExportBytes = 10
        ChannelOk = $true; Comm = 'systemd'; Interop = 'present'; User = 'tester'
        HasClone = $true; CloneOrigin = 'https://github.com/example/app-configs.git'
        RepoOrigin = 'https://github.com/example/app-configs.git'
        HasGate = $true; SrcHasGate = $true; SrcSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; HeadSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; Dirty = 0; Rel = 'same'; SyncCode = 0; SyncSkipped = $false; Branch = 'main'; DirtyUnknown = $false; OwnerHome = 'tester'; OwnerClone = 'tester'; ChownCode = 0; FindCode = 0; PendingUser = ''; PullCode = 0; ReportCode = 0; ReportOut = ''; Banner = ''; FactsCode = 0; HasCfg = $true; HasSnap = $true; Used = 1000000
        SysSetupCode = 0; SysSetupNoEffect = $false; InstallCode = 0
    }
}

$FakeWsl = {
    param([string[]]$a, [bool]$pt)
    $W = $script:W
    if ($a[0] -ne '-d') {
        switch ($a[0]) {
            '--version' { return @{ Code = $W.VersionCode; Out = "WSL version: $($W.Version)`nKernel version: 6.6.0" } }
            '--list' {
                if ($a[1] -eq '--quiet') { return @{ Code = 0; Out = ($W.Distros -join "`r`n") } }
                return @{ Code = 0; Out = '  NAME STATE VERSION' }
            }
            '--update' { if (-not $W.UpdateFails) { $W.Version = '2.6.1.0' }; return @{ Code = 0; Out = $null } }
            '--install' { return @{ Code = $W.InstallWslCode; Out = $null } }
            '--import' {
                if ($W.ImportCode -eq 0) { $W.Distros = @('NixOS') }
                return @{ Code = $W.ImportCode; Out = $null }
            }
            '--terminate' {
                if ($W.PendingUser) { $W.User = $W.PendingUser; $W.PendingUser = '' }
                return @{ Code = 0; Out = '' }
            }
            '--export' {
                if ($W.ExportBytes -ge 0) { [IO.File]::WriteAllBytes($a[2], (New-Object byte[] $W.ExportBytes)) }
                return @{ Code = $W.ExportCode; Out = $null }
            }
        }
        return @{ Code = 1; Out = "fake: unknown $($a -join ' ')" }
    }
    $i = [array]::IndexOf($a, '--exec')
    $e = @($a[($i + 1)..($a.Count - 1)])
    $sw = '/run/current-system/sw/bin'
    $ok = @{ Code = 0; Out = '' }
    $bool = { param($b) if ($b) { return @{ Code = 0; Out = '' } } else { return @{ Code = 1; Out = '' } } }
    if ($e[0] -eq '/bin/wslpath') { return @{ Code = 0; Out = '/mnt/c/fixture-repo' } }
    if ($e[0] -eq '/bin/sh') {
        if ($e[2] -match 'app-configs-(\w+)-') {
            switch ($Matches[1]) {
                'facts' { return @{ Code = $W.FactsCode; Out = "$($W.Banner)comm=$($W.Comm)`ninterop=$($W.Interop)`nuser=$($W.User)" } }
                'origin' { return @{ Code = 0; Out = "$($W.Banner)noise`norigin=$($W.RepoOrigin)" } }
                'cloneorigin' { return @{ Code = 0; Out = "$($W.Banner)origin=$($W.CloneOrigin)" } }
                'clone' { $W.HasClone = $true; $W.HasGate = $W.SrcHasGate; return $ok }
                'pull' {
                    if ($W.PullCode -eq 0) { $W.HasGate = $W.SrcHasGate; $W.HeadSha = $W.SrcSha; $W.Rel = 'same' }
                    return @{ Code = $W.PullCode; Out = $null }
                }
                'sync' {
                    if ($W.SyncSkipped) { return @{ Code = 0; Out = "$($W.Banner)skipped=1" } }
                    return @{ Code = $W.SyncCode; Out = "$($W.Banner)src=$($W.SrcSha)`nhead=$($W.HeadSha)`nbranch=$($W.Branch)`ndirty=$(if ($W.DirtyUnknown) { 'unknown' } else { $W.Dirty })`nrel=$($W.Rel)" }
                }
                'headread' { return @{ Code = 0; Out = "$($W.Banner)head=$($W.HeadSha)`nbranch=$($W.Branch)" } }
                'channel' { return (& $bool $W.ChannelOk) }
                'hassnap' { return (& $bool $W.HasSnap) }
                'setorigin' { return $ok }
                'report' {
                    $ro = "/var/lib/app-configs/host-snapshots/20260101T000000Z-$($e[5])"
                    if ($W.ReportOut) { $ro = $W.ReportOut }
                    return @{ Code = $W.ReportCode; Out = "$($W.Banner)$ro" }
                }
            }
        }
    }
    switch ($e[0]) {
        "$sw/nix-channel" { $W.ChannelOk = $true; return $ok }
        "$sw/test" {
            if ($e[2] -like '*/.git') { return (& $bool $W.HasClone) }
            if ($e[2] -like '*/wsl.nix') { return (& $bool $W.HasGate) }
            if ($e[2] -like '*/app-configs-wsl.nix') { return (& $bool $W.HasCfg) }
        }
        "$sw/df" { return @{ Code = 0; Out = "Used`n$($W.Used)" } }
        "$sw/mkdir" { return $ok }
        "$sw/chown" {
            if ($e[1] -eq '-R') {
                if ($W.ChownCode -eq 0) { $W.OwnerHome = 'tester'; $W.OwnerClone = 'tester' }
                return @{ Code = $W.ChownCode; Out = '' }
            }
            return $ok
        }
        "$sw/find" {
            $bad = ''
            if ($W.OwnerHome -ne 'tester') { $bad = '/home/tester/.profile' } elseif ($W.OwnerClone -ne 'tester') { $bad = '/home/tester/app-configs/x' }
            return @{ Code = $W.FindCode; Out = $bad }
        }
        "$sw/true" { return $ok }
        "$sw/env" {
            if ($W.SysSetupCode -eq 0 -and -not $W.SysSetupNoEffect) { $W.PendingUser = 'tester'; $W.HasCfg = $true }
            return @{ Code = $W.SysSetupCode; Out = $null }
        }
        "$sw/bash" { return @{ Code = $W.InstallCode; Out = $null } }
    }
    return @{ Code = 1; Out = "fake: unknown $($e -join ' ')" }
}

function Initialize-Happy {
    $script:Elev = $false
    $script:Reboot = $false
    $script:Appx = '1.0'
    $script:Points = @()
    $script:W = New-WslState
    Stub 'Test-IsAdmin' { $script:Elev }
    Stub 'Test-RebootPending' { $script:Reboot }
    Stub 'Get-WslAppx' { $script:Appx }
    Stub 'Get-OsInfo' { 'Windows 11 Test build 1' }
    Stub 'Get-OsArch' { 'X64' }
    $script:Tools = @{ chezmoi = 'chezmoi version v2.50.0'; gitleaks = '8.18.0'; lefthook = '1.7.0' }
    $script:HooksOk = $true
    $script:HooksPath = ''
    $script:WingetResult = @{ Code = 0; Out = 'ok'; Err = '' }
    $script:WingetInstalls = $true
    $script:LefthookCode = 0
    $script:LefthookNoEffect = $false
    Stub 'Get-ToolVersion' {
        param([string]$Name, [string[]]$VersionArgs)
        if ($script:HiddenUntilMerge -contains $Name -and -not $script:PathMerged) { return $null }
        $script:Tools[$Name]
    }
    Stub 'Invoke-Winget' {
        param([string]$Id)
        if ($script:WingetResult.Code -eq 0 -and $script:WingetInstalls) {
            $script:Tools[($CommitTools | Where-Object { $_.Id -eq $Id }).Name] = 'installed 1.0'
        }
        $script:WingetResult
    }
    $script:PathMerged = $false
    $script:HiddenUntilMerge = @()
    $script:Foreign = @()
    Stub 'Update-SessionPath' { $script:PathMerged = $true }
    Stub 'Resolve-Program' { param([string]$Name) "C:\fake\$Name.exe" }
    Stub 'Get-ForeignHooks' { @($script:Foreign) }
    Stub 'Test-LefthookHooks' { $script:HooksOk }
    Stub 'Get-HooksPath' { $script:HooksPath }
    Stub 'Invoke-Lefthook' {
        if ($script:LefthookCode -eq 0 -and -not $script:LefthookNoEffect) { $script:HooksOk = $true }
        @{ Code = $script:LefthookCode; Out = ''; Err = 'boom' }
    }
    Stub 'Get-OptionalFeatureStates' { @('Microsoft-Windows-Subsystem-Linux=Enabled', 'VirtualMachinePlatform=Enabled') }
    Stub 'Get-RestorePoints' { , @($script:Points) }
    Stub 'Get-FreeBytes' { [int64]1TB }
    Stub 'Get-WingetList' { 'winget raw list' }
    Stub 'Get-PathEntries' { @{ Machine = @('C:\machine'); User = @('C:\user') } }
    Stub 'Test-RepoGitDir' { $true }
    Stub 'Get-UtcStamp' { '20260101T000000Z' }
    $script:WinRel = @{ Src = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; Rel = 'same' }
    Stub 'Get-WindowsRelation' { param([string]$Head) $script:WinRel }
    $script:Installer = $false
    $script:InstallerBash = 'C:/Git/bin/bash.exe'
    $script:CheckSeq = @(0)
    $script:CheckN = 0
    $script:CheckOut = 'check out'
    $script:InstallCode = 0
    $script:HookEnv = @()
    Stub 'Test-HooksInstaller' { $script:Installer }
    Stub 'Resolve-GitBash' { $script:InstallerBash }
    Stub 'Get-HookEnvOverrides' { @($script:HookEnv) }
    Stub 'Invoke-HooksInstaller' {
        param([string]$Bash, [string]$Mode)
        if ($Mode -eq 'check') {
            $c = $script:CheckSeq[[math]::Min($script:CheckN, $script:CheckSeq.Count - 1)]
            $script:CheckN++
            return @{ Code = $c; Out = $script:CheckOut; Err = '' }
        }
        @{ Code = $script:InstallCode; Out = 'install out'; Err = '' }
    }
    Stub 'Invoke-WslRaw' {
        param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds)
        $script:Raw.Add([pscustomobject]@{ A = $Arguments; Pt = [bool]$Passthrough; Timeout = $TimeoutSeconds; Log = $(if ($script:LogLines) { $script:LogLines.Count } else { 0 }) })
        & $FakeWsl $Arguments ([bool]$Passthrough)
    }
}

function Get-SeamCalls {
    param([string]$Name)
    return @($script:Calls | Where-Object { $_.Name -eq $Name })
}

# ---------------------------------------------------------------- static

# The S1 allowlist of built-ins; the boundary R1 meta-test reuses it.
$S1Safe = @('ForEach-Object', 'Where-Object', 'Select-Object', 'Sort-Object', 'Join-Path', 'Split-Path',
    'Test-Path', 'Get-ChildItem', 'Get-Item', 'New-Item', 'Move-Item', 'Remove-Item', 'New-Object', 'Write-Host')

Test-Case 'S1 allowlist: every other command sits inside a seam function' {
    $tokens = $null; $errs = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errs)
    Assert-Eq $errs.Count 0 'parse errors'
    $defined = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name })
    # Built-ins that only touch the local file system or the console, anywhere.
    $safe = $S1Safe
    $hits = $ast.FindAll({
        param($n)
        if ($n -is [Management.Automation.Language.CommandAst]) {
            $c = $n.GetCommandName()
            if (-not $c) { return $true }
            return ($defined -notcontains $c -and $safe -notcontains $c)
        }
        return ($n -is [Management.Automation.Language.StringConstantExpressionAst] -and
            ($n.Value -eq 'wsl.exe' -or $n.Value -like '*HKLM:*')) -or
        (($n -is [Management.Automation.Language.StringConstantExpressionAst] -or $n -is [Management.Automation.Language.ExpandableStringExpressionAst]) -and $n.Value -match '\\wsl\.exe$')
    }, $true)
    $natives = $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Invoke-Native' }, $true)
    Assert-True ($natives.Count -ge 5) 'Invoke-Native callers found (wsl, winget, git, lefthook, tool versions)'
    foreach ($h in $natives) {
        $p = $h.Parent
        while ($p -and $p -isnot [Management.Automation.Language.FunctionDefinitionAst]) { $p = $p.Parent }
        Assert-True ($SeamNames -contains $p.Name) "Invoke-Native at line $($h.Extent.StartLineNumber) is in '$($p.Name)', not a seam"
    }
    Assert-True ($hits.Count -ge 8) "found commands needing a seam ($($hits.Count))"
    foreach ($h in $hits) {
        $p = $h.Parent
        while ($p -and $p -isnot [Management.Automation.Language.FunctionDefinitionAst]) { $p = $p.Parent }
        $fn = if ($p) { $p.Name } else { '<top level>' }
        $dynamic = ($h -is [Management.Automation.Language.CommandAst] -and -not $h.GetCommandName())
        if ($dynamic) {
            Assert-Eq $fn 'Get-ReportSection' "dynamic call '$($h.Extent.Text)' at line $($h.Extent.StartLineNumber)"
        } else {
            Assert-True ($SeamNames -contains $fn) "'$($h.Extent.Text)' at line $($h.Extent.StartLineNumber) is in '$fn', not a seam"
        }
    }
}

Test-Case 'S2 both files are ASCII only' {
    foreach ($f in @($ScriptPath, $PSCommandPath)) {
        $bytes = [IO.File]::ReadAllBytes($f)
        $bad = @($bytes | Where-Object { $_ -gt 127 }).Count
        Assert-Eq $bad 0 "non-ASCII bytes in $f"
    }
}

Test-Case 'S3 UserRegex literal' {
    $text = [IO.File]::ReadAllText($ScriptPath)
    Assert-True ($text.Contains('$UserRegex = ''^ *username = "([^"]+)";''')) 'literal present'
}

# ---------------------------------------------------------------- cases

Test-Case '1a reboot pending stops at step 0 and writes nothing' {
    Initialize-Happy
    $script:Reboot = $true
    $script:Elev = $true
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log '(?m)^\[bootstrap\] step 0: reboot pending \(CBS RebootPending\); restart from Settings > Windows Update > Restart now \(a plain restart or a shutdown may not clear it\), then re-run'
    Assert-Eq (Get-LadItems).Count 0 'files'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call'
}

Test-Case '1b reboot pending under dry-run' {
    Initialize-Happy
    $script:Reboot = $true
    Assert-Eq (Run-Boot @{ DryRun = $true }) 3 'exit'
    Assert-Log '^\[bootstrap\]\[dry-run\] probe os: Windows 11 Test'
    Assert-Log 'probe elevated: False'
    Assert-Log 'probe appx: 1.0'
    Assert-Log 'probe wsl --version: exit 0 version 2.6.1.0'
    Assert-Log 'probe optional-features: Microsoft-Windows-Subsystem-Linux=Enabled'
    Assert-Log 'probe restore-points: 0 point'
    Assert-Log 'step 0: reboot pending'
    Assert-Eq (Get-LadItems).Count 0 'files'
}

function Initialize-NotInstalled {
    Initialize-Happy
    $script:Appx = $null
    $script:W.Distros = @()
    $script:NewRpCalls = 0
    $script:NewRpResults = @(@{ Ok = $true; Error = '' })
    Stub 'New-RestorePoint' {
        param([string]$Description)
        $r = $script:NewRpResults[[math]::Min($script:NewRpCalls, $script:NewRpResults.Count - 1)]
        $script:NewRpCalls++
        if ($r.Ok) { $script:Points = @([pscustomobject]@{ Created = [datetime]::UtcNow.AddSeconds(30); Description = $Description }) }
        $r
    }
    Stub 'Enable-SystemRestore' { param([string]$Drive) @{ Ok = $true; Error = '' } }
}

Test-Case '2a not installed, not elevated -> 3 run elevated' {
    Initialize-NotInstalled
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'step 1: .*run elevated'
    Assert-Eq @(Find-Raw 'install').Count 0 'no install'
    Assert-Eq (Get-LadItems).Count 0 'files'
}

Test-Case '2b elevated, recent restore point reused, wsl --install, reboot' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:Points = @([pscustomobject]@{ Created = [datetime]::UtcNow.AddHours(-1); Description = 'x' })
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 0 'no new point'
    Assert-Log 'reusing restore point'
    Assert-Log 'reboot, then re-run in a normal PowerShell'
    $i = @(Find-Raw '^--install --no-distribution$')
    Assert-Eq $i.Count 1 'wsl --install call'
    Assert-True $script:Raw[$i[0]].Pt 'wsl --install is passthrough'
    $before = @(Get-ChildItem -LiteralPath (Join-Path $script:State 'host-snapshots') -Directory)
    Assert-Eq $before.Count 1 'one before report'
    Assert-True ($before[0].Name -match '-before$') 'before label'
}

Test-Case '2c elevated, old point -> new restore point created and confirmed' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:Points = @([pscustomobject]@{ Created = [datetime]::UtcNow.AddDays(-2); Description = 'old' })
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 1 'one new point'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint')[0].Args['Description'] 'app-configs: before WSL install' 'description'
    Assert-Eq @(Find-Raw '^--install --no-distribution$').Count 1 'install'
}

Test-Case '2d restore point fails without -EnableSystemRestore -> 3 with the error' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:NewRpResults = @(@{ Ok = $false; Error = 'System Restore is disabled' })
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'System Restore is disabled'
    Assert-Eq @(Get-SeamCalls 'Enable-SystemRestore').Count 0 'not enabled'
    Assert-Eq @(Find-Raw 'install').Count 0 'no install'
}

Test-Case '2e -EnableSystemRestore enables C:\ and retries once' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:NewRpResults = @(@{ Ok = $false; Error = 'disabled' }, @{ Ok = $true; Error = '' })
    Assert-Eq (Run-Boot @{ EnableSystemRestore = $true }) 3 'exit'
    $en = @(Get-SeamCalls 'Enable-SystemRestore')
    Assert-Eq $en.Count 1 'enable call'
    Assert-Eq $en[0].Args['Drive'] 'C:\' 'drive'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 2 'retry'
    Assert-Eq @(Find-Raw '^--install --no-distribution$').Count 1 'install'
}

Test-Case '2f retry fails -> 1' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:NewRpResults = @(@{ Ok = $false; Error = 'disabled' })
    Assert-Eq (Run-Boot @{ EnableSystemRestore = $true }) 1 'exit'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 2 'exactly one retry'
    Assert-Eq @(Find-Raw 'install').Count 0 'no install'
}

Test-Case '2g enabling fails -> 1' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:NewRpResults = @(@{ Ok = $false; Error = 'disabled' })
    Stub 'Enable-SystemRestore' { param([string]$Drive) @{ Ok = $false; Error = 'nope' } }
    Assert-Eq (Run-Boot @{ EnableSystemRestore = $true }) 1 'exit'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 1 'no retry'
}

Test-Case '2h confirmation missing -> 1, no install' {
    Initialize-NotInstalled
    $script:Elev = $true
    Stub 'New-RestorePoint' {
        param([string]$Description)
        $script:Points = @([pscustomobject]@{ Created = [datetime]::UtcNow.AddDays(-3); Description = 'old' })
        @{ Ok = $true; Error = '' }
    }
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'no restore point newer than this run'
    Assert-Eq @(Find-Raw 'install').Count 0 'no install'
}

Test-Case '2i wsl --install fails -> 1' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:W.InstallWslCode = 5
    Assert-Eq (Run-Boot @{}) 1 'exit'
}

Test-Case '2j installed + elevated -> 3 re-run non-elevated' {
    Initialize-Happy
    $script:Elev = $true
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 're-run non-elevated as the same user'
    Assert-Eq @(Find-Raw '^-d').Count 0 'no distro call'
}

Test-Case '2k -Report and -Export refuse when elevated' {
    Initialize-Happy
    $script:Elev = $true
    Assert-Eq (Run-Boot @{ Report = 'x' }) 3 'report'
    Assert-Eq (Run-Boot @{ Export = 'x' }) 3 'export'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call'
    Assert-Eq (Get-LadItems).Count 0 'files'
}

Test-Case '2l Appx present but wsl --version exit 1 counts as not installed' {
    Initialize-NotInstalled
    $script:Appx = '1.0'
    $script:W.VersionCode = 1
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'step 1: .*run elevated'
}

Test-Case '3a old WSL triggers wsl --update then proceeds' {
    Initialize-Happy
    $script:W.Version = '2.0.9.0'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $u = @(Find-Raw '^--update$')
    Assert-Eq $u.Count 1 'update call'
    Assert-True $script:Raw[$u[0]].Pt 'update is passthrough'
}

Test-Case '3b still low after update -> 1' {
    Initialize-Happy
    $script:W.Version = '2.0.9.0'
    $script:W.UpdateFails = $true
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'still older'
    Assert-Eq @(Find-Raw '^--import').Count 0 'stopped before import'
}

function Initialize-Download {
    Initialize-Happy
    $script:W.Distros = @()
    $script:Dl = $false
    Stub 'Invoke-Download' {
        param([string]$Url, [string]$OutFile)
        $script:Dl = $true
        [IO.File]::WriteAllBytes($OutFile, (New-Object byte[] 4))
    }
    Stub 'Get-Sha256' { param([string]$Path) $script:Hash }
    $script:Hash = $NixosWslSha256
    $script:DlFile = Join-Path (Join-Path (Join-Path $script:Lad 'app-configs') 'downloads') "nixos-wsl-$NixosWslTag.wsl"
}

Test-Case '4a an existing download with a matching hash is reused; exact --import args' {
    Initialize-Download
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:DlFile))
    [IO.File]::WriteAllBytes($script:DlFile, (New-Object byte[] 4))
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Download').Count 0 'no download'
    $imp = @($script:Raw | Where-Object { $_.A[0] -eq '--import' })
    Assert-Eq $imp.Count 1 'one import'
    $want = @('--import', 'NixOS', (Join-Path (Join-Path $script:State 'wsl') 'NixOS'), $script:DlFile, '--version', '2')
    Assert-Eq ($imp[0].A -join '|') ($want -join '|') 'import args'
}

Test-Case '4b a hash mismatch deletes the file and exits 1' {
    Initialize-Download
    $script:Hash = 'bad'
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-True $script:Dl 'downloaded'
    Assert-True (-not (Test-Path -LiteralPath $script:DlFile)) 'file deleted'
    Assert-Eq @(Find-Raw '^--import').Count 0 'no import'
}

Test-Case '4c a missing download is fetched from the pinned URL and imported' {
    Initialize-Download
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $d = @(Get-SeamCalls 'Invoke-Download')
    Assert-Eq $d.Count 1 'download'
    Assert-Eq $d[0].Args['Url'] $NixosWslUrl 'url'
    Assert-Eq $d[0].Args['OutFile'] $script:DlFile 'outfile'
    Assert-Eq @(Find-Raw '^--import').Count 1 'import'
}

Test-Case '4d a failed import -> 1' {
    Initialize-Download
    $script:W.ImportCode = 9
    Assert-Eq (Run-Boot @{}) 1 'exit'
}

Test-Case '5a nixpkgs channel present: no nix-channel --update' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Find-Raw 'nix-channel').Count 0 'no update'
    $p = @(Get-ScriptCalls 'channel')
    Assert-Eq $p.Count 1 'probe through the login environment'
    Assert-True (($p[0].A -join ' ') -match '-u root') 'as root'
    Assert-True ((Get-ScriptText $p[0]).Contains('nix-instantiate --find-file nixpkgs')) 'probe'
}

Test-Case '5b nixpkgs channel missing: nix-channel --update as root' {
    Initialize-Happy
    $script:W.ChannelOk = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $u = @(Find-Raw 'nix-channel --update')
    Assert-Eq $u.Count 1 'update'
    Assert-Log 'running nix-channel --update'
    Assert-True ((Get-RawText)[$u[0]] -match '-u root') 'as root'
}

Test-Case '6a systemd not PID 1 -> 1' {
    Initialize-Happy
    $script:W.Comm = 'init'
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log "found PID 1 'init'"
    Assert-Eq @(Get-ScriptCalls 'origin').Count 0 'stopped before step 6'
}

Test-Case '6b WSLInterop missing -> 1' {
    Initialize-Happy
    $script:W.Interop = 'absent'
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'WSLInterop absent'
}

Test-Case '7a clone as nixos, origin set from the Windows repo' {
    Initialize-Happy
    $script:W.HasClone = $false
    $script:W.User = 'nixos'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $m = @(Find-Raw 'sw/bin/mkdir -p /home/tester/app-configs')
    $c = @(Find-Raw 'sw/bin/chown nixos:users /home/tester/app-configs')
    $cl = @(Get-ScriptCalls 'clone')
    Assert-Eq $m.Count 1 'mkdir'
    Assert-Eq $c.Count 1 'chown'
    Assert-Eq $cl.Count 1 'clone call'
    Assert-True ($m[0] -lt $c[0]) 'mkdir before chown'
    Assert-True (($cl[0].A -join ' ') -match '-d NixOS -u nixos --exec /bin/sh') 'clone runs as nixos'
    Assert-True $cl[0].Pt 'clone is passthrough'
    $s = Get-ScriptText $cl[0]
    Assert-True ($s.Contains("SRC='/mnt/c/fixture-repo'")) 'source is the wslpath'
    Assert-True ($s.Contains("DST='/home/tester/app-configs'")) 'destination'
    Assert-True ($s.Contains('URL=''https://github.com/example/app-configs.git''')) 'origin url'
    Assert-True ($s.Contains('nix-shell -p git')) 'git from nix-shell'
    Assert-True ($s -match 'clone .*&& git -C .* remote set-url origin') 'clone then set-url'
    Assert-True ($s.Contains('git -c safe.directory="$SRC" clone -b main "$SRC" "$DST"')) 'exact safe.directory path'
    Assert-True (-not $s.Contains('safe.directory=*')) 'no wildcard'
    $o = @(Get-ScriptCalls 'origin')
    Assert-True (-not (($o[0].A -join ' ') -match '-u ')) 'the Windows origin is read without root'
}

Test-Case '7f origin userinfo is stripped everywhere; a quote in the url is quoted safely' {
    Initialize-Happy
    $script:W.HasClone = $false
    $script:W.RepoOrigin = "https://user:s3cret@github.com/o/it's.git"
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $cc = @(Get-ScriptCalls 'clone')
    $s = Get-ScriptText $cc[0]
    Assert-True ($s.Contains('URL=''https://github.com/o/it''\''''s.git''')) 'userinfo gone, quote escaped'
    Assert-True (-not $s.Contains('s3cret')) 'no password in the script'
    Assert-True (-not ((Get-Log) -match 's3cret|user:')) 'no credentials in the log'
    Assert-Eq (Hide-UrlUserInfo 'git@github.com:o/r.git') 'git@github.com:o/r.git' 'scp style untouched'
    Assert-Eq (Hide-UrlUserInfo 'ssh://git@host/r.git') 'ssh://host/r.git' 'ssh userinfo stripped'
}

Test-Case '7a2 a fresh clone runs as and is owned by the current default user, not a hardcoded nixos' {
    Initialize-Happy
    $script:W.HasClone = $false
    $script:W.User = 'tester'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Find-Raw 'sw/bin/chown tester:users /home/tester/app-configs').Count 1 'owner is the default user'
    Assert-Eq @(Find-Raw 'sw/bin/chown nixos:users').Count 0 'not nixos'
    $cl = @(Get-ScriptCalls 'clone')
    Assert-Eq $cl.Count 1 'clone call'
    Assert-True (($cl[0].A -join ' ') -match '-d NixOS -u tester --exec /bin/sh') 'clone runs as the default user'
    Assert-Log 'step 6: cloning .* to /home/tester/app-configs as tester'
    Reset-Stubs; Initialize-Happy
    $script:W.HasClone = $false
    $script:W.FactsCode = 1
    Assert-Eq (Run-Boot @{}) 1 'unreadable default user'
    Assert-Eq @(Get-ScriptCalls 'clone').Count 0 'no clone without a known user'
}

Test-Case '7b a /mnt origin of an existing clone is corrected' {
    Initialize-Happy
    $script:W.CloneOrigin = '/mnt/c/fixture-repo'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $s = @(Get-ScriptCalls 'setorigin')
    Assert-Eq $s.Count 1 'setorigin call'
    Assert-True ((Get-ScriptText $s[0]).Contains('remote set-url origin')) 'set-url'
    Assert-True (-not (($s[0].A -join ' ') -match '-u ')) 'as the default user'
    Assert-Eq @(Get-ScriptCalls 'clone').Count 0 'no clone'
}

Test-Case '7c a GitHub origin of an existing clone is untouched' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-ScriptCalls 'setorigin').Count 0 'no setorigin'
    Assert-Eq @(Get-ScriptCalls 'clone').Count 0 'no clone'
    Assert-Log 'origin left unchanged'
}

Test-Case '7d a Windows repo without an origin url -> 1' {
    Initialize-Happy
    $script:W.RepoOrigin = ''
    $script:W.HasClone = $false
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Eq @(Get-ScriptCalls 'clone').Count 0 'no clone'
}

Test-Case '7e .git as a file (worktree) -> 1' {
    Initialize-Happy
    Stub 'Test-RepoGitDir' { $false }
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'not a directory'
    Assert-Eq @(Get-ScriptCalls 'origin').Count 0 'stopped before reading origin'
}

Test-Case '8a before-setup WSL report is written once' {
    Initialize-Happy
    $script:W.HasSnap = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $r = @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'before-setup' })
    Assert-Eq $r.Count 1 'before-setup report'
    $ls = @(Find-Raw 'app-configs-hassnap-')
    Assert-Eq $ls.Count 1 'one existence check'
    Assert-True ((Get-RawText)[$ls[0]] -match '-u root') 'checked as root, independent of the default user'
    Assert-True ($ls[0] -lt @(Find-Raw 'app-configs-report-')[0]) 'checked before writing'
    $rep = @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'before-setup' })
    Assert-True (($rep[0].A -join ' ') -match '-u root') 'report runs as root'
    Assert-True (@(Get-RawText | Where-Object { $_ -match 'app-configs-facts-' }).Count -ge 1) 'default user read for the per-user facts'
    # second run: snapshot exists
    Reset-Stubs; Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit 2'
    Assert-Eq @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'before-setup' }).Count 0 'not rewritten'
}

Test-Case '8b export once: terminate then export; second run skips' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $t = @(Find-Raw '^--terminate NixOS$')
    $e = @(Find-Raw '^--export NixOS ')
    Assert-Eq $e.Count 1 'one export'
    Assert-True ($t[0] -lt $e[0]) 'terminate first'
    $f = @(Get-ChildItem -LiteralPath (Join-Path $script:State 'wsl-exports') -Filter 'NixOS-before-setup-*.tar')
    Assert-Eq $f.Count 1 'export file'
    Assert-Log 'wsl --import NixOS-restore'
    Assert-Log 'wsl --unregister NixOS, then wsl --import NixOS'
    Assert-Eq @(Get-ChildItem -LiteralPath (Join-Path $script:State 'wsl-exports') -Filter '*.partial').Count 0 'no partial left'
    Assert-Eq @(Find-Raw '^--export NixOS .*\.tar\.partial$').Count 1 'exported to a .partial name first'
    $script:Raw.Clear()
    Assert-Eq (Run-Boot @{}) 0 'exit 2'
    Assert-Eq @(Find-Raw '^--export').Count 0 'no second export'
    Assert-Log 'already exists, skipping'
}

Test-Case '8c not enough free space -> 1, nothing exported' {
    Initialize-Happy
    $script:W.Used = 100000000000
    Stub 'Get-FreeBytes' { param([string]$Path) [int64]10000000000 }
    Assert-Eq (Run-Boot @{}) 1 'exit'
    $need = [int64]([math]::Ceiling(100000000000 * 1.2 + 1GB))
    Assert-Log "required $need bytes, free 10000000000 bytes"
    Assert-Eq @(Find-Raw '^--export').Count 0 'no export'
}

Test-Case '8d failed export removes the partial file; so does an empty one' {
    Initialize-Happy
    $script:W.ExportCode = 1
    Assert-Eq (Run-Boot @{}) 1 'exit'
    $dir = Join-Path $script:State 'wsl-exports'
    Assert-Eq @(Get-ChildItem -LiteralPath $dir -File).Count 0 'partial removed'
    $script:W.ExportCode = 0
    $script:W.ExportBytes = 0
    Assert-Eq (Run-Boot @{}) 1 'exit empty'
    Assert-Eq @(Get-ChildItem -LiteralPath $dir -File).Count 0 'empty file removed'
}

Test-Case '8e -Export <label> works on demand and keeps one file per label' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{ Export = 'before-docker' }) 0 'exit'
    $dir = Join-Path $script:State 'wsl-exports'
    Assert-Eq @(Get-ChildItem -LiteralPath $dir -Filter 'NixOS-before-docker-*.tar').Count 1 'file'
    $script:Raw.Clear()
    Assert-Eq (Run-Boot @{ Export = 'before-docker' }) 0 'exit 2'
    Assert-Eq @(Find-Raw '^--export').Count 0 'skipped'
}

Test-Case '9 gate missing -> 3 with the D0 message' {
    Initialize-Happy
    Remove-Item -LiteralPath (Join-Path $script:RepoRoot 'nix\modules\nixos\wsl.nix')
    $script:W.HasClone = $false
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'step 6: next: land the desktop-first commits \(D0\) on origin, then git pull --ff-only in this Windows clone and re-run'
    Assert-True (-not ((Get-Log) -match 'git bundle')) 'the old bundle advice is gone'
    Assert-Eq @(Find-Raw 'sw/bin/env').Count 0 'no system-setup'
    Assert-Eq @(Get-ScriptCalls 'clone').Count 0 'gate is checked before cloning'
    Assert-Eq @(Find-Raw 'sw/bin/mkdir').Count 0 'nothing created in WSL'
    Assert-Eq @(Find-Raw '^--export').Count 0 'no export before the gate'
}

Test-Case '9b a clone behind the Windows main is fast-forwarded from the Windows repo' {
    Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $p = @(Get-ScriptCalls 'pull')
    Assert-Eq $p.Count 1 'one pull'
    Assert-True $p[0].Pt 'pull is passthrough'
    Assert-True (-not (($p[0].A -join ' ') -match '-u ')) 'as the clone owner (default user)'
    $s = Get-ScriptText $p[0]
    Assert-True ($s.Contains("SRC='/mnt/c/fixture-repo'")) 'source is the Windows repo'
    Assert-True ($s.Contains('pull --ff-only "$SRC" main')) 'ff-only from main'
    Assert-True ($s.Contains('safe.directory="$SRC"') -and $s.Contains('safe.directory="$DST"')) 'exact safe.directory paths'
    Assert-True (-not $s.Contains('safe.directory=*')) 'no wildcard'
    Assert-Eq @(Get-ScriptCalls 'clone').Count 0 'no clone'
}

Test-Case '9c a failing pull -> 1; an uncommitted wsl.nix -> 3' {
    Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.HasGate = $false
    $script:W.PullCode = 128
    Assert-Eq (Run-Boot @{}) 1 'diverged'
    Assert-Log 'git pull --ff-only exited 128'
    Assert-Eq @(Find-Raw 'system-setup').Count 0 'stopped'
    $script:W.PullCode = 0
    $script:W.SrcHasGate = $false
    $script:W.Rel = 'behind'
    Assert-Eq (Run-Boot @{}) 3 'pulled but still missing'
    Assert-Log 'not in its committed main'
}

Test-Case '9d a fresh clone that still lacks wsl.nix -> 3' {
    Initialize-Happy
    $script:W.HasClone = $false
    $script:W.SrcHasGate = $false
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'not in its committed main'
    Assert-Eq @(Find-Raw '^--export').Count 0 'no export'
}

Test-Case '9e a clone that has wsl.nix is not pulled' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull'
}

Test-Case '10a step 9 order: sys-setup, restart sequence, chown' {
    Initialize-Happy
    $script:W.User = 'nixos'
    $script:W.HasCfg = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $s = @(Find-Raw 'sw/bin/env USER_NAME=tester /run/current-system/sw/bin/bash -lc exec bash /home/tester/app-configs/ops/system-setup.sh --apply$')
    Assert-Eq $s.Count 1 'system-setup'
    Assert-True ((Get-RawText)[$s[0]] -match '-u root') 'as root'
    Assert-True $script:Raw[$s[0]].Pt 'passthrough'
    $tr = @(Find-Raw '-u root --exec /run/current-system/sw/bin/true$')
    $ch = @(Find-Raw 'sw/bin/chown -R tester:users /home/tester$')
    Assert-Eq $tr.Count 1 'wake up'
    Assert-Eq $ch.Count 1 'chown'
}

Test-Case '10b step 9 restart sequence indices' {
    Initialize-Happy
    $script:W.User = 'nixos'
    $script:W.HasCfg = $false
    $script:W.ExportBytes = 10
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $s = @(Find-Raw 'system-setup.sh --apply')[0]
    $tr = @(Find-Raw 'sw/bin/true$')[0]
    $ch = @(Find-Raw 'sw/bin/chown -R')[0]
    $term = @(Find-Raw '^--terminate NixOS$' | Where-Object { $_ -gt $s })
    Assert-Eq $term.Count 2 'two terminates after setup'
    Assert-True ($s -lt $term[0] -and $term[0] -lt $tr -and $tr -lt $term[1] -and $term[1] -lt $ch) 'order setup, -t, true, -t, chown'
}

Test-Case '10c everything already in place: system-setup still runs, without a restart' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Find-Raw 'system-setup').Count 1 'runs once'
}

Test-Case '10d system-setup failing -> 1; no effect after setup -> 1' {
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false; $script:W.SysSetupCode = 4
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Eq @(Find-Raw 'sw/bin/chown -R').Count 0 'stopped'
    $script:W.SysSetupCode = 0; $script:W.SysSetupNoEffect = $true
    Assert-Eq (Run-Boot @{}) 1 'exit no effect'
    Assert-Log "default user is 'nixos'"
    Assert-Log 'step 9: recovery: restore from the before-setup export .*NixOS-before-setup-<UTC>\.tar'
    Assert-Log 'wsl --import NixOS-restore <dir> <tar>; to replace NixOS: wsl --unregister NixOS, then wsl --import NixOS <dir> <tar> \(a human decision, never scripted\)'
    Assert-Log 'wsl -d NixOS -u root -- bash -lc ''nixos-rebuild --rollback boot'', then wsl --terminate NixOS'
}

Test-Case '10e the recovery hint also covers a wrong or empty default user and a failed chown' {
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    $script:W.SysSetupNoEffect = $true
    Assert-Eq (Run-Boot @{}) 1 'wrong user, marker missing'
    Assert-Log 'step 9: recovery:'
    Reset-Stubs; Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    Stub 'Invoke-WslRaw' {
        param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds)
        $script:Raw.Add([pscustomobject]@{ A = $Arguments; Pt = [bool]$Passthrough; Timeout = $TimeoutSeconds; Log = $script:LogLines.Count })
        if (($Arguments -join ' ') -match 'sw/bin/chown -R') { return @{ Code = 1; Out = ''; Err = 'denied' } }
        & $FakeWsl $Arguments ([bool]$Passthrough)
    }
    Assert-Eq (Run-Boot @{}) 1 'chown fails'
    Assert-Log 'step 9: chown exited 1'
    Assert-Log 'step 9: recovery:'
    Reset-Stubs; Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'a healthy run prints no recovery text'
    Assert-True (-not ((Get-Log) -match 'recovery')) 'no recovery hint when nothing failed'
}

Test-Case '11 install.sh exit 7 -> 1 with "exited 7"' {
    Initialize-Happy
    $script:W.InstallCode = 7
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'ops/install.sh exited 7'
    Assert-Log 'on a re-run the one-time steps that finished \(download, import, report, export\) are skipped, and the idempotent steps 6 and 9 run again'
    Assert-Eq @(Find-Raw 'after-install').Count 0 'no after-install report'
}

Test-Case '12 every distro call names -d NixOS; steps 9 and 12 are passthrough' {
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $global = @('--version', '--list', '--update', '--install', '--import', '--terminate', '--export', '--status', '--shutdown')
    foreach ($c in $script:Raw) {
        if ($global -contains $c.A[0]) { continue }
        Assert-True ($c.A[0] -eq '-d' -and $c.A[1] -eq 'NixOS') "call without -d NixOS: $($c.A -join ' ')"
    }
    $inst = @($script:Raw | Where-Object { ($_.A -join ' ') -match 'ops/install.sh$' })
    Assert-Eq $inst.Count 1 'install.sh call'
    Assert-True $inst[0].Pt 'install.sh is passthrough'
    Assert-Eq ($inst[0].A -join ' ') '-d NixOS -u tester --cd /home/tester/app-configs --exec /run/current-system/sw/bin/bash -lc exec bash ops/install.sh' 'install.sh args'
    $sys = @($script:Raw | Where-Object { ($_.A -join ' ') -match 'system-setup.sh' })
    Assert-True $sys[0].Pt 'system-setup is passthrough'
    foreach ($n in @('channel', 'hassnap', 'facts', 'origin')) {
        $c = @(Get-ScriptCalls $n)
        Assert-True ($c.Count -ge 1 -and -not $c[0].Pt) "$n is a capture call"
    }
}

Test-Case '13a Windows report: exact sections, no env leak, winget failure recorded' {
    Initialize-Happy
    $env:BOOTSTRAP_CANARY = 'canary-123'
    try {
        Stub 'Get-WingetList' { throw 'winget exploded' }
        Assert-Eq (Run-Boot @{ Report = 'snap' }) 0 'exit'
    } finally { Remove-Item Env:\BOOTSTRAP_CANARY -ErrorAction SilentlyContinue }
    $f = Join-Path $script:State 'host-snapshots\20260101T000000Z-snap\windows.txt'
    Assert-True (Test-Path -LiteralPath $f) 'windows.txt exists'
    $t = [IO.File]::ReadAllText($f)
    $heads = @([regex]::Matches($t, '(?m)^== (.+) ==$') | ForEach-Object { $_.Groups[1].Value })
    Assert-Eq ($heads -join ',') 'run,os,reboot-pending,wsl,optional-features,system-restore,disk-free-c,winget,path,commit-tooling' 'sections'
    Assert-True (-not $t.Contains('canary-123')) 'canary absent'
    Assert-True ($t -match '(?s)== winget ==\nunavailable: winget exploded') 'winget unavailable'
    Assert-True ($t -match 'machine: C:\\machine') 'machine path'
    Assert-True ($t -match 'user: C:\\user') 'user path'
    Assert-True ($t -match 'elevated: False') 'elevated line'
}

Test-Case '13b the before report: elevated non-dry only, once' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'normal run'
    $hs = Join-Path $script:State 'host-snapshots'
    Assert-Eq @(Get-ChildItem -LiteralPath $hs -Directory | Where-Object { $_.Name -match '-before$' }).Count 0 'none when not elevated'
    $script:Elev = $true
    Assert-Eq (Run-Boot @{ DryRun = $true }) 3 'dry elevated returns the real code'
    Assert-Eq @(Get-ChildItem -LiteralPath $hs -Directory | Where-Object { $_.Name -match '-before$' }).Count 0 'none on dry-run'
    Assert-Eq (Run-Boot @{}) 3 'elevated run'
    Assert-Eq @(Get-ChildItem -LiteralPath $hs -Directory | Where-Object { $_.Name -match '-before$' }).Count 1 'written'
    $script:Tick = 0
    Stub 'Get-UtcStamp' { $script:Tick++; "20260102T00000${script:Tick}Z" }
    Assert-Eq (Run-Boot @{}) 3 'elevated run 2'
    Assert-Eq @(Get-ChildItem -LiteralPath $hs -Directory | Where-Object { $_.Name -match '-before$' }).Count 1 'still one'
}

Test-Case '14a dry-run, distro absent and nothing done: no mutating seam, nothing written' {
    Initialize-Happy
    $script:W.Distros = @()
    $script:W.Version = '2.0.0.0'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'exit'
    Assert-Eq (Get-LadItems).Count 0 'no file or dir under LOCALAPPDATA'
    foreach ($n in @('Invoke-Download', 'New-RestorePoint', 'Enable-SystemRestore', 'Get-Sha256')) {
        Assert-Eq @(Get-SeamCalls $n).Count 0 "$n not called"
    }
    foreach ($c in $script:Raw) {
        Assert-True (@('--version', '--list') -contains $c.A[0]) "only read-only wsl calls: $($c.A -join ' ')"
    }
    Assert-Log '(?m)^\[bootstrap\]\[dry-run\] step 2: would run wsl --update'
    Assert-Log 'step 3: would download'
    Assert-Log 'step 12: would run ops/install.sh'
}

Test-Case '14b dry-run, distro present but every WSL step not done' {
    Initialize-Happy
    $script:W.ChannelOk = $false; $script:W.HasClone = $false; $script:W.HasSnap = $false
    $script:W.HasCfg = $false; $script:W.User = 'nixos'; $script:W.Version = '2.0.0.0'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'exit'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
    $bad = 'nix-channel|sw/bin/mkdir|sw/bin/chown|sw/bin/true|sw/bin/env|ops/install.sh|^--(update|export|import|install|terminate)|app-configs-(clone|setorigin|report|pull)-'
    Assert-Eq @(Find-Raw $bad).Count 0 'no mutating wsl call'
    Assert-Log 'step 4: would run nix-channel'
    Assert-Log 'step 6: would read the origin of .* \(nix-shell -p git; skipped in a dry run\)'
    Assert-Eq @(Find-Raw 'app-configs-(origin|cloneorigin)-').Count 0 'no nix-shell origin read in a dry run'
    $noteAt = -1
    for ($k = 0; $k -lt $script:LogLines.Count; $k++) { if ($script:LogLines[$k] -match 'dry run: starting NixOS for read-only probes') { if ($noteAt -ge 0) { throw 'the note appears twice' }; $noteAt = $k } }
    Assert-True ($noteAt -ge 0) 'the distro-start note is printed'
    $firstProbe = @($script:Raw | Where-Object { $_.A[0] -eq '-d' })[0]
    Assert-True ($noteAt -lt $firstProbe.Log) 'the note comes before the first in-distro probe'
    Assert-Log 'step 7a: would write'
    Assert-Log 'would export'
    Assert-Log 'step 9: would apply the system layer'
}

Test-Case '14c dry-run not installed, elevated -> 3, nothing written or created' {
    Initialize-NotInstalled
    $script:Elev = $true
    Assert-Eq (Run-Boot @{ DryRun = $true }) 3 'exit'
    Assert-Log 'step 1: would reuse or create a restore point'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 0 'no restore point'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
}

Test-Case '14d dry-run gate missing -> 3' {
    Initialize-Happy
    $script:W.Distros = @()
    Remove-Item -LiteralPath (Join-Path $script:RepoRoot 'nix\modules\nixos\wsl.nix')
    Assert-Eq (Run-Boot @{ DryRun = $true }) 3 'exit'
    Assert-Log 'step 6: next: land the desktop-first commits'
}

Test-Case '15a good labels are accepted' {
    foreach ($l in @('before-docker', 'a1', 'a', ('a' * 40))) {
        Reset-Stubs; Initialize-Happy
        Assert-Eq (Run-Boot @{ DryRun = $true; Report = $l }) 0 "report $l"
        Assert-Eq (Run-Boot @{ DryRun = $true; Export = $l }) 0 "export $l"
    }
}

Test-Case '15b bad labels -> 2 before anything runs' {
    $bad = @('Before', '-x', 'a b', '../x', '', ('a' * 41), '-', 'a_b')
    foreach ($l in $bad) {
        Assert-Eq (Run-Boot @{ Report = $l }) 2 "report '$l'"
        Assert-Eq (Run-Boot @{ Export = $l }) 2 "export '$l'"
    }
    Assert-Eq $script:Calls.Count 0 'no seam called'
}

Test-Case '15c switch conflicts and stray arguments -> 2' {
    Assert-Eq (Run-Boot @{ Export = 'a'; Report = 'b' }) 2 'export+report'
    Assert-Eq (Run-Boot @{ Export = 'a'; EnableSystemRestore = $true }) 2 'export+restore'
    Assert-Eq (Run-Boot @{ Report = 'a'; EnableSystemRestore = $true }) 2 'report+restore'
    Assert-Eq (Run-Boot @{ Rest = @('stray') }) 2 'stray'
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; Export = 'a' }) 2 'tools-only+export'
    Assert-Eq $script:Calls.Count 0 'no seam called'
}

Test-Case '16 -Report: one capture call carrying the fixed script; elevated refuses' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{ Report = 'check-1' }) 0 'exit'
    $cap = @($script:Raw | Where-Object { ($_.A -join ' ') -match 'app-configs-report-' })
    Assert-Eq $cap.Count 1 'one capture call'
    Assert-True (-not $cap[0].Pt) 'capture, not passthrough'
    Assert-Eq (Get-ScriptText $cap[0]) $WslReportScript 'decoded script is the fixed one'
    $a = $cap[0].A
    Assert-Eq ($a[($a.Count - 4)..($a.Count - 1)] -join '|') 'check-1|tester|/home/tester/app-configs|tester' 'script args (label, user, repo, default user)'
    Assert-True (($a -join ' ') -match '-d NixOS -u root --exec') 'runs as root'
    Assert-True ($WslReportScript.Contains('base=/var/lib/app-configs/host-snapshots') -and $WslReportScript.Contains('final=$base/$stamp-$label')) 'fixed location'
    Assert-True (-not $WslReportScript.Contains("`r")) 'LF only'
    foreach ($f in @('host.txt', 'system.txt', 'user.txt', 'systemd.txt', 'interop.txt', 'nix.txt', 'hm.txt', 'mise.txt', 'timers.txt', 'selection.txt', 'git.txt', 'readiness.txt')) {
        Assert-True ($WslReportScript.Contains($f)) "script writes $f"
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $script:State 'host-snapshots\20260101T000000Z-check-1\windows.txt')) 'windows.txt'
    Assert-Log 'WSL report \(check-1\): /var/lib/app-configs/host-snapshots/'
}

Test-Case '17a username: CRLF and indented fixtures' {
    New-TestEnv -UserLine "  username = `"crlf-user`";"
    $p = Join-Path $script:RepoRoot 'nix\vars\default.nix'
    [IO.File]::WriteAllText($p, "let`r`n    username = `"crlf-user`";`r`n  other = 1;`r`nin { }`r`n")
    Assert-Eq (Get-NixUser -Root $script:RepoRoot) 'crlf-user' 'crlf'
    [IO.File]::WriteAllText($p, "{ username = `"x`"; }`n`nusername = `"deep`";`n")
    Assert-Eq (Get-NixUser -Root $script:RepoRoot) 'deep' 'only line-start matches count'
    Initialize-Happy
    [IO.File]::WriteAllText($p, "let`r`n    username = `"crlf-user`";`r`nin { }`r`n")
    Assert-Eq (Run-Boot @{ Report = 'x' }) 0 'exit'
    $cap = @($script:Raw | Where-Object { ($_.A -join ' ') -match 'app-configs-report-' })
    Assert-True ($cap[0].A -contains 'crlf-user') 'user passed to the report'
}

Test-Case '17b username: two matches, none, commented, invalid -> 1' {
    Initialize-Happy
    $p = Join-Path $script:RepoRoot 'nix\vars\default.nix'
    [IO.File]::WriteAllText($p, "username = `"a`";`n  username = `"b`";`n")
    Assert-Eq (Run-Boot @{}) 1 'two matches'
    [IO.File]::WriteAllText($p, "let`nin { }`n")
    Assert-Eq (Run-Boot @{}) 1 'none'
    [IO.File]::WriteAllText($p, "# username = `"a`";`n")
    Assert-Eq (Run-Boot @{}) 1 'commented out'
    [IO.File]::WriteAllText($p, "username = `"Bad Name`";`n")
    Assert-Eq (Run-Boot @{}) 1 'invalid name'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call'
}

function Invoke-ScriptFile {
    param([string[]]$ScriptArgs)
    $ErrorActionPreference = 'Continue'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs 2>&1
    return @{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

Test-Case 'F2 real -File binding: stray positionals and conflicts exit 2 before any probe' {
    foreach ($case in @(@('-DryRun', 'dryrun'), @('-DryRun', 'stray'), @('-DryRun', '-Export', 'a', '-Report', 'b'), @('-DryRun', '-Report', 'Bad'), @('-DryRun', '-Export', 'a', '-EnableSystemRestore'))) {
        $r = Invoke-ScriptFile $case
        Assert-Eq $r.Code 2 "powershell -File bootstrap.ps1 $($case -join ' ') -> exit; output: $($r.Out)"
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Lad 'app-configs'))) 'nothing written'
}

Test-Case 'F2 real -File binding: -Export with no value is a PowerShell binding error (exit 1, cannot be 2)' {
    $r = Invoke-ScriptFile @('-DryRun', '-Export')
    Assert-Eq $r.Code 1 'exit'
    Assert-True ($r.Out -match 'Export') 'names the parameter'
}

Test-Case 'F3 an interrupted export leaves only a .partial; the retry replaces it and spares other labels' {
    Initialize-Happy
    $dir = Join-Path $script:State 'wsl-exports'
    [void](New-Item -ItemType Directory -Force -Path $dir)
    [IO.File]::WriteAllBytes((Join-Path $dir 'NixOS-keep-20250101T000000Z.tar.partial'), (New-Object byte[] 5))
    [IO.File]::WriteAllBytes((Join-Path $dir 'NixOS-keep-two-20250101T000000Z.tar.partial'), (New-Object byte[] 5))
    Assert-Eq (Run-Boot @{ Export = 'keep' }) 0 'exit'
    Assert-Eq @(Find-Raw '^--export NixOS .*\.tar\.partial$').Count 1 'the partial did not count as done'
    $names = @(Get-ChildItem -LiteralPath $dir -File | ForEach-Object { $_.Name } | Sort-Object)
    Assert-Eq ($names -join ',') 'NixOS-keep-20260101T000000Z.tar,NixOS-keep-two-20250101T000000Z.tar.partial' 'only the own label partial is replaced'
}

Test-Case 'F7 dry-run returns the real exit code in every mode' {
    Initialize-Happy
    $script:W.Distros = @()
    Assert-Eq (Run-Boot @{ DryRun = $true; Export = 'x' }) 1 'export, distro absent'
    $script:Elev = $true
    Assert-Eq (Run-Boot @{ DryRun = $true; Export = 'x' }) 3 'export, elevated'
    Assert-Eq (Run-Boot @{ DryRun = $true; Report = 'x' }) 3 'report, elevated'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 3 'installed + elevated'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
}

Test-Case 'F11 ConvertTo-ArgString follows the Windows quoting rules' {
    Assert-Eq (ConvertTo-ArgString @('plain', 'a b')) 'plain "a b"' 'plain and space'
    Assert-Eq (ConvertTo-ArgString @('')) '""' 'empty'
    Assert-Eq (ConvertTo-ArgString @('a"b')) '"a\"b"' 'quote'
    Assert-Eq (ConvertTo-ArgString @('C:\x y\')) '"C:\x y\\"' 'trailing backslash'
    Assert-Eq (ConvertTo-ArgString @('a\"b')) '"a\\\"b"' 'backslash before quote'
    Assert-Eq (ConvertTo-ArgString @('C:\x\y')) 'C:\x\y' 'backslashes alone'
    Assert-Eq (ConvertTo-ArgString @('a\\"b c')) '"a\\\\\"b c"' 'two backslashes before a quote'
}

Test-Case 'N2 wslpath: stderr noise is ignored, only a stdout path counts' {
    Initialize-Happy
    Stub 'Invoke-WslRaw' {
        param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds)
        @{ Code = 0; Out = "/mnt/c/x/repo"; Err = 'UtilTranslatePathList: Failed to translate C:\nope' }
    }
    Assert-Eq (Get-WslPath 'C:\x\repo') '/mnt/c/x/repo' 'stdout path'
    Stub 'Invoke-WslRaw' {
        param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds)
        @{ Code = 0; Out = "warning: noise
/mnt/c/y
"; Err = '' }
    }
    Assert-Eq (Get-WslPath 'C:\y') '/mnt/c/y' 'noise on stdout skipped'
    Stub 'Invoke-WslRaw' {
        param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds)
        @{ Code = 0; Out = ''; Err = 'UtilTranslatePathList: Failed' }
    }
    Assert-True ($null -eq (Get-WslPath 'C:\z')) 'stderr alone is no path'
}

Test-Case 'N6 the real capture keeps stdout and stderr apart and kills a hung process' {
    $a = @('-NoProfile', '-Command', '[Console]::Out.Write(''to-out''); [Console]::Error.Write(''to-err''); exit 3')
    $r = & $RealInvokeNative -Arguments $a -ExePath 'powershell.exe'
    Assert-Eq $r.Code 3 'exit code'
    Assert-Eq $r.Out 'to-out' 'stdout'
    Assert-Eq $r.Err 'to-err' 'stderr'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $h = & $RealInvokeNative -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 60') -ExePath 'powershell.exe' -TimeoutSeconds 2
    Assert-Eq $h.Code 124 'timeout code'
    Assert-True ($h.Err -match 'timed out after 2 s') 'timeout reported'
    Assert-True ($sw.Elapsed.TotalSeconds -lt 30) 'returned promptly'
    $m = & $RealInvokeNative -Arguments @('x') -ExePath 'no-such-exe-bootstrap-test'
    Assert-Eq $m.Code 127 'missing exe'
    Assert-True ($m.Err -match '^unavailable:') 'missing exe reported'
}

function Initialize-Missing {
    param([string[]]$Names)
    Initialize-Happy
    foreach ($n in $Names) { $script:Tools[$n] = $null }
}

$ExpectedWinget = @('install', '--id', 'evilmartians.lefthook', '--exact', '--source', 'winget', '--accept-package-agreements', '--disable-interactivity')

Test-Case 'C1 all tools present and hooks installed: no winget, no lefthook, versions logged' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'no lefthook install'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 1 'PATH merged once, at the start, no reload after'
    Assert-Log 'step C: chezmoi chezmoi version v2.50.0'
    Assert-Log 'step C: gitleaks 8.18.0'
    Assert-Log 'step C: lefthook hooks already installed'
}

Test-Case 'C2 one tool missing: the exact winget args, PATH reloaded, tool re-probed' {
    Initialize-Missing @('lefthook')
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $w = @(Get-SeamCalls 'Invoke-Winget')
    Assert-Eq $w.Count 1 'one winget call'
    Assert-Eq $w[0].Args['Id'] 'evilmartians.lefthook' 'id'
    Assert-Eq ((Get-WingetInstallArgs 'evilmartians.lefthook') -join ' ') ($ExpectedWinget -join ' ') 'exact args'
    Assert-True (-not (($ExpectedWinget -join ' ') -match 'accept-source-agreements')) 'never --accept-source-agreements'
    $names = @($script:Calls | ForEach-Object { $_.Name })
    $iw = [array]::IndexOf($names, 'Invoke-Winget')
    $ip = [array]::LastIndexOf($names, 'Update-SessionPath')
    Assert-True ($iw -ge 0 -and $ip -gt $iw) 'PATH merged again after the install'
    $first = [array]::IndexOf($names, 'Update-SessionPath')
    Assert-True ($first -ge 0 -and $first -lt [array]::IndexOf($names, 'Get-ToolVersion')) 'PATH merged before the first probe'
    Assert-Log 'step C: lefthook absent'
}

Test-Case 'C2b all three missing are installed with their pinned ids' {
    Initialize-Missing @('chezmoi', 'gitleaks', 'lefthook')
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $ids = @(Get-SeamCalls 'Invoke-Winget' | ForEach-Object { $_.Args['Id'] })
    Assert-Eq ($ids -join ',') 'twpayne.chezmoi,Gitleaks.Gitleaks,evilmartians.lefthook' 'ids'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 2 'merged at the start and after the installs'
}

Test-Case 'C3 a source agreement is needed: exit 3, the command is printed, nothing else runs' {
    Initialize-Missing @('lefthook')
    $script:WingetResult = @{ Code = 1; Out = ''; Err = 'Source agreements were not accepted' }
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'step C: winget install --id evilmartians.lefthook --exact --source winget --accept-package-agreements --disable-interactivity --accept-source-agreements'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 1 'no merge after a failed install'
    Assert-Eq @(Find-Raw '.').Count 0 'no WSL call'
    Assert-Eq @(Get-SeamCalls 'Test-RebootPending').Count 0 'before the reboot check'
}

Test-Case 'C3b other winget failures and a timeout -> 1' {
    Initialize-Missing @('gitleaks')
    $script:WingetResult = @{ Code = 1; Out = 'No package found'; Err = '' }
    Assert-Eq (Run-Boot @{}) 1 'failure'
    Assert-Log 'winget install Gitleaks.Gitleaks exited 1: No package found'
    Reset-Stubs; Initialize-Missing @('gitleaks')
    $script:WingetResult = @{ Code = 124; Out = ''; Err = 'unavailable: timed out after 1200 s (process killed)' }
    Assert-Eq (Run-Boot @{}) 1 'timeout'
    Assert-Log 'timed out after 1200 s'
    Assert-Log 'child installers may still be running'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 1 'no merge after a failed install'
}

Test-Case 'C4 still missing after the install and the PATH reload -> 1' {
    Initialize-Missing @('chezmoi')
    $script:WingetInstalls = $false
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 2 'merge at the start and after the install'
    Assert-Log 'step C: chezmoi is still not found after the install'
    Assert-Eq @(Find-Raw '.').Count 0 'no WSL call'
}

Test-Case 'C4b Install-WingetTools: the given step label, one tool, return codes 0, 1 and 3' {
    $jq = @(@{ Name = 'jq'; Id = 'jqlang.jq'; VersionArgs = @('--version') })
    Initialize-Happy
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Tools['jq'] = $null
    Stub 'Invoke-Winget' {
        param([string]$Id)
        if ($script:WingetResult.Code -eq 0 -and $script:WingetInstalls) { $script:Tools['jq'] = 'jq-1.7.1' }
        $script:WingetResult
    }
    $r = @(Install-WingetTools -Step 'S' -Tools $jq)
    Assert-True ($r.Count -eq 1 -and $r[0] -is [int]) 'one int returned'
    Assert-Eq $r[0] 0 'installed and found'
    Assert-Eq (@(Get-SeamCalls 'Invoke-Winget' | ForEach-Object { $_.Args['Id'] }) -join ',') 'jqlang.jq' 'one winget call, the pinned id'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 1 'PATH merged once after the install'
    Assert-Log '^\[bootstrap\] step S: installing jqlang\.jq with winget \(can take several minutes\)$'
    Assert-True (-not ((Get-Log) -match 'step C')) 'no step C label'

    Reset-Stubs; Initialize-Happy
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:WingetResult = @{ Code = 1; Out = ''; Err = 'Source agreements were not accepted' }
    Assert-Eq (Install-WingetTools -Step 'S' -Tools $jq) 3 'source agreements'
    Assert-Log 'step S: winget needs its source agreements accepted first'
    Assert-Log 'step S: winget install --id jqlang\.jq --exact --source winget --accept-package-agreements --disable-interactivity --accept-source-agreements'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 0 'no merge after a failed install'

    Reset-Stubs; Initialize-Happy
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:WingetResult = @{ Code = 124; Out = ''; Err = 'unavailable: timed out after 1200 s (process killed)' }
    Assert-Eq (Install-WingetTools -Step 'S' -Tools $jq) 1 'timeout'
    Assert-Log 'step S: winget install jqlang\.jq exited 124: unavailable: timed out'
    Assert-Log 'step S: child installers may still be running'

    Reset-Stubs; Initialize-Happy
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Tools['jq'] = $null
    $script:WingetInstalls = $false
    Assert-Eq (Install-WingetTools -Step 'S' -Tools $jq) 1 'still missing'
    Assert-Log 'step S: jq is still not found after the install; open a new PowerShell and re-run'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 1 'merged once, then re-probed'
    Assert-True (-not ((Get-Log) -match 'step C')) 'no step C label'
}

Test-Case 'C5 step C runs before the reboot check' {
    Initialize-Missing @('lefthook')
    $script:Reboot = $true
    Assert-Eq (Run-Boot @{}) 3 'exit from step 0'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 1 'installed while a reboot is pending'
    Assert-Log 'step 0: reboot pending'
    Assert-Eq @(Find-Raw '^-d').Count 0 'no distro call'
}

Test-Case 'C6 elevated runs skip step C with a message' {
    Initialize-Missing @('lefthook')
    $script:Elev = $true
    Assert-Eq (Run-Boot @{}) 3 'exit (installed + elevated)'
    Assert-Log 'step C: skipped \(elevated run\)'
    Assert-True (-not ((Get-Log) -match 'step C: lefthook absent')) 'no step C probe lines'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget'
}

Test-Case 'C7 -DryRun: probes and would-run lines only' {
    Initialize-Missing @('lefthook', 'gitleaks')
    $script:HooksOk = $false
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'no lefthook'
    Assert-Eq @(Get-SeamCalls 'Update-SessionPath').Count 1 'only the start merge (environment only)'
    Assert-Log '\[dry-run\] step C: would run: winget install --id Gitleaks.Gitleaks --exact --source winget --accept-package-agreements --disable-interactivity'
    Assert-Log '\[dry-run\] step C: would run: winget install --id evilmartians.lefthook'
    Assert-Log '\[dry-run\] step C: would run: lefthook install'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
}

Test-Case 'C8 hooks: missing -> lefthook install once; failure or no effect -> 1' {
    Initialize-Happy
    $script:HooksOk = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 1 'installed once'
    Assert-Log 'step C: lefthook hooks installed'
    Reset-Stubs; Initialize-Happy
    $script:HooksOk = $false; $script:LefthookCode = 1
    Assert-Eq (Run-Boot @{}) 1 'install fails'
    Assert-Log 'lefthook install exited 1'
    Reset-Stubs; Initialize-Happy
    $script:HooksOk = $false; $script:LefthookNoEffect = $true
    Assert-Eq (Run-Boot @{}) 1 'no hook after install'
    Assert-Log 'has no lefthook hook'
}

Test-Case 'C9 core.hooksPath set: hooks untouched; unreadable: 3; no .git directory: skipped' {
    Initialize-Happy
    $script:HooksOk = $false
    $script:HooksPath = '.githooks'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'not touched'
    Assert-Log "core.hooksPath is set to '.githooks'; hooks left untouched"
    Reset-Stubs; Initialize-Happy
    $script:HooksPath = 'unavailable: git exited 127'
    Assert-Eq (Run-Boot @{}) 3 'git unreadable'
    Assert-Log 'cannot read git config core.hooksPath'
    Reset-Stubs; Initialize-Happy
    Stub 'Test-RepoGitDir' { $false }
    $script:HooksOk = $false
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'tools only, worktree'
    Assert-Log 'hooks skipped'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'no install'
}

Test-Case 'C10 -ToolsOnly stops after step C: no reboot check, no WSL call, no username read' {
    Initialize-Happy
    $script:Reboot = $true
    $script:Appx = $null
    Remove-Item -LiteralPath (Join-Path $script:RepoRoot 'nix\vars\default.nix')
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Test-RebootPending').Count 0 'no reboot check'
    Assert-Eq @(Get-SeamCalls 'Get-WslAppx').Count 0 'no appx probe'
    Assert-Eq @(Find-Raw '.').Count 0 'no WSL call'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
}

Test-Case 'C11 -ToolsOnly exit codes: 3 source agreement, 1 still missing, 3 elevated, dry-run' {
    Initialize-Missing @('lefthook')
    $script:WingetResult = @{ Code = 1; Out = 'source agreements'; Err = '' }
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 3 'agreement'
    Reset-Stubs; Initialize-Missing @('lefthook')
    $script:WingetInstalls = $false
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 1 'still missing'
    Reset-Stubs; Initialize-Missing @('lefthook')
    $script:Elev = $true
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 3 'elevated'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget when elevated'
    Reset-Stubs; Initialize-Missing @('lefthook')
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; DryRun = $true }) 0 'dry-run'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget in dry-run'
    Assert-Log '\[dry-run\] step C: would run: winget install --id evilmartians.lefthook'
}

Test-Case 'C12 -ToolsOnly conflicts -> 2' {
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; Export = 'a' }) 2 'export'
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; Report = 'a' }) 2 'report'
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; EnableSystemRestore = $true }) 2 'restore'
    Assert-Eq $script:Calls.Count 0 'no seam called'
}

Test-Case 'C13 the Windows report has a commit-tooling section' {
    Initialize-Happy
    $script:Tools['gitleaks'] = $null
    $script:HooksOk = $false
    Assert-Eq (Run-Boot @{ Report = 'tools' }) 0 'exit'
    $t = [IO.File]::ReadAllText((Join-Path $script:State 'host-snapshots\20260101T000000Z-tools\windows.txt'))
    Assert-True ($t -match '(?s)== commit-tooling ==\nchezmoi: chezmoi version v2.50.0\ngitleaks: absent\nlefthook: 1.7.0\nhooks installed: no\ncore.hooksPath: unset') 'section content'
    $script:HooksOk = $true; $script:HooksPath = '.githooks'
    Assert-Eq (Run-Boot @{ Report = 'tools2' }) 0 'exit 2'
    $t = [IO.File]::ReadAllText((Join-Path $script:State 'host-snapshots\20260101T000000Z-tools2\windows.txt'))
    Assert-True ($t -match 'hooks installed: yes\ncore.hooksPath: \.githooks') 'hooks yes, path set'
}

Test-Case 'C14 the real tool seams build the right commands (Invoke-Native stubbed)' {
    Stub 'Resolve-Program' { param([string]$Name) "C:/r/$Name.exe" }
    $script:NativeCalls = @()
    Stub 'Invoke-Native' {
        param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory)
        $script:NativeCalls += , @{ Exe = $ExePath; Args = $Arguments; Timeout = $TimeoutSeconds; Wd = $WorkingDirectory }
        $script:NativeResult
    }
    $script:NativeResult = @{ Code = 0; Out = ''; Err = '' }
    [void](& $RealInvokeWinget -Id 'twpayne.chezmoi')
    $c = $script:NativeCalls[-1]
    Assert-Eq $c.Exe 'C:/r/winget.exe' 'winget exe, resolved'
    Assert-Eq ($c.Args -join ' ') 'install --id twpayne.chezmoi --exact --source winget --accept-package-agreements --disable-interactivity' 'winget args'
    Assert-Eq $c.Timeout 1200 'winget gets 20 minutes'
    [void](& $RealInvokeLefthook)
    $c = $script:NativeCalls[-1]
    Assert-Eq $c.Exe 'C:/r/lefthook.exe' 'lefthook exe, resolved'
    Assert-Eq ($c.Args -join ' ') 'install' 'lefthook args'
    Assert-Eq $c.Wd $script:RepoRoot 'in the repo'
    $script:NativeResult = @{ Code = 1; Out = ''; Err = '' }
    Assert-Eq (& $RealGetHooksPath) '' 'unset'
    $c = $script:NativeCalls[-1]
    Assert-Eq "$($c.Exe) $($c.Args -join ' ')" 'C:/r/git.exe config core.hooksPath' 'git args'
    $script:NativeResult = @{ Code = 0; Out = ".githooks`n"; Err = '' }
    Assert-Eq (& $RealGetHooksPath) '.githooks' 'set'
    $script:NativeResult = @{ Code = 127; Out = ''; Err = 'unavailable: no git' }
    Assert-True ((& $RealGetHooksPath) -like 'unavailable*') 'git missing'
    $script:NativeResult = @{ Code = 0; Out = "tool 1.2.3`nmore"; Err = '' }
    Assert-Eq (& $RealGetToolVersion -Name 'powershell' -VersionArgs @('--version')) 'tool 1.2.3' 'first version line of an existing command'
    $script:NativeResult = @{ Code = 2; Out = ''; Err = '' }
    Assert-True ((& $RealGetToolVersion -Name 'powershell' -VersionArgs @('--version')) -like 'unavailable*') 'failing version command'
}

Test-Case 'C15 Test-LefthookHooks reads .git\hooks\pre-commit' {
    Assert-True (-not (& $RealTestLefthookHooks)) 'no hook file'
    $hooks = Join-Path $script:RepoRoot '.git\hooks'
    [void](New-Item -ItemType Directory -Force -Path $hooks)
    [IO.File]::WriteAllText((Join-Path $hooks 'pre-commit'), "#!/bin/sh`necho other tool`n")
    Assert-True (-not (& $RealTestLefthookHooks)) 'a foreign hook does not count'
    [IO.File]::WriteAllText((Join-Path $hooks 'pre-commit'), "#!/bin/sh`ncall_lefthook run pre-commit`n")
    Assert-True (& $RealTestLefthookHooks) 'a lefthook hook counts'
}

Test-Case 'C16 Update-SessionPath appends the missing Machine and User entries and keeps the rest' {
    $old = $env:Path
    try {
        $m = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ })
        $env:Path = 'C:\only-in-this-process;' + $m[0].ToUpperInvariant() + '\'
        & $RealUpdateSessionPath
        $parts = @($env:Path -split ';')
        Assert-Eq $parts[0] 'C:\only-in-this-process' 'process entries kept, in front'
        Assert-True ($parts.Count -ge 2) 'entries present'
        foreach ($e in $m) {
            Assert-True (@($parts | Where-Object { $_.TrimEnd('\').ToLowerInvariant() -eq [Environment]::ExpandEnvironmentVariables($e).TrimEnd('\').ToLowerInvariant() }).Count -eq 1) "Machine entry present exactly once: $e"
        }
        $before = $env:Path
        & $RealUpdateSessionPath
        Assert-Eq $env:Path $before 'idempotent'
    } finally { $env:Path = $old }
}
Test-Case 'C17 tools on the registry PATH but not on the inherited PATH: merged first, no winget' {
    Initialize-Happy
    $script:HiddenUntilMerge = @('chezmoi', 'gitleaks', 'lefthook')
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget'
    Assert-Log 'step C: gitleaks 8.18.0'
    Reset-Stubs; Initialize-Happy
    $script:HiddenUntilMerge = @('gitleaks')
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; DryRun = $true }) 0 'dry-run uses the merged PATH too'
    Assert-Log 'step C: gitleaks 8.18.0'
    Assert-True (-not ((Get-Log) -match 'would run: winget')) 'nothing to install'
}

Test-Case 'C18 elevated report does not execute the tools or git' {
    Initialize-Happy
    $script:Elev = $true
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Eq @(Get-SeamCalls 'Get-ToolVersion').Count 0 'no tool executed'
    Assert-Eq @(Get-SeamCalls 'Get-HooksPath').Count 0 'git not executed'
    $d = @(Get-ChildItem -LiteralPath (Join-Path $script:State 'host-snapshots') -Directory)
    $t = [IO.File]::ReadAllText((Join-Path $d[0].FullName 'windows.txt'))
    Assert-True ($t.Contains("chezmoi: skipped (elevated); path: C:\fake\chezmoi.exe`n")) 'path only'
    Assert-True ($t.Contains('core.hooksPath: skipped (elevated)')) 'git skipped'
    Assert-True ($t.Contains('hooks installed: yes')) 'file check still done'
}

Test-Case 'C19 existing foreign hooks are listed before lefthook install renames them' {
    Initialize-Happy
    $script:HooksOk = $false
    $script:Foreign = @('pre-commit', 'commit-msg')
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step C: lefthook install will rename these existing hooks to <name>.old: pre-commit, commit-msg'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 1 'then installs'
    Reset-Stubs; Initialize-Happy
    $script:HooksOk = $false
    $script:Foreign = @('pre-push')
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; DryRun = $true }) 0 'dry-run'
    Assert-Log 'rename these existing hooks to <name>.old: pre-push'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'dry-run does not install'
    Reset-Stubs; Initialize-Happy
    $script:HooksOk = $false
    Assert-Eq (Run-Boot @{}) 0 'none'
    Assert-True (-not ((Get-Log) -match 'will rename')) 'nothing listed when there is nothing to rename'
}

Test-Case 'C20 Get-ForeignHooks: only unsampled, non-lefthook hooks named in .lefthook.yml' {
    $hooks = Join-Path $script:RepoRoot '.git\hooks'
    [void](New-Item -ItemType Directory -Force -Path $hooks)
    [IO.File]::WriteAllText((Join-Path $hooks 'pre-commit'), "#!/bin/sh`necho mine`n")
    [IO.File]::WriteAllText((Join-Path $hooks 'pre-commit.sample'), "#!/bin/sh`n")
    [IO.File]::WriteAllText((Join-Path $hooks 'commit-msg'), "#!/bin/sh`nlefthook run commit-msg`n")
    [IO.File]::WriteAllText((Join-Path $hooks 'pre-push'), "#!/bin/sh`necho push`n")
    [IO.File]::WriteAllText((Join-Path $hooks 'update'), "#!/bin/sh`necho not a lefthook hook`n")
    Assert-Eq (@(& $RealGetForeignHooks) -join ',') 'pre-commit,pre-push' 'foreign hooks'
}

Test-Case 'C20b Get-ForeignHooks knows exactly the top-level hook keys of .lefthook.yml' {
    $yml = [IO.File]::ReadAllText((Join-Path $OrigRepoRoot '.lefthook.yml'))
    $keys = @([regex]::Matches($yml, '(?m)^([a-z][a-z-]*):') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
    Assert-True ($keys.Count -ge 1) 'keys found in .lefthook.yml'
    $hooks = Join-Path $script:RepoRoot '.git\hooks'
    [void](New-Item -ItemType Directory -Force -Path $hooks)
    foreach ($k in $keys) { [IO.File]::WriteAllText((Join-Path $hooks $k), "#!/bin/sh`necho foreign`n") }
    Assert-Eq ((@(& $RealGetForeignHooks) | Sort-Object) -join ',') ($keys -join ',') 'hook names in Get-ForeignHooks match .lefthook.yml'
    Assert-Eq ($keys -join ',') 'commit-msg,post-merge,pre-commit,pre-push' 'the four hooks the T2 review checked'
}

Test-Case 'C21 programs are resolved to full paths before Invoke-Native' {
    $script:NativeCalls = @()
    Stub 'Invoke-Native' {
        param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory)
        $script:NativeCalls += , @{ Exe = $ExePath; Args = $Arguments; Timeout = $TimeoutSeconds }
        @{ Code = 0; Out = 'out'; Err = '' }
    }
    Stub 'Resolve-Program' { param([string]$Name) "C:\resolved\$Name.exe" }
    [void](& $RealInvokeWinget -Id 'twpayne.chezmoi')
    [void](& $RealInvokeLefthook)
    [void](& $RealGetHooksPath)
    [void](& $RealGetToolVersion -Name 'chezmoi' -VersionArgs @('--version'))
    [void](& $RealGetWingetList)
    Assert-Eq (($script:NativeCalls | ForEach-Object { $_.Exe }) -join ',') 'C:\resolved\winget.exe,C:\resolved\lefthook.exe,C:\resolved\git.exe,C:\resolved\chezmoi.exe,C:\resolved\winget.exe' 'bare names resolved'
    Assert-Eq $script:NativeCalls[4].Timeout 120 'winget list is bounded'
    Assert-Eq ($script:NativeCalls[4].Args -join ' ') 'list --source winget --disable-interactivity' 'winget list args'
    [void](& $RealInvokeWslRaw -Arguments @('--version'))
    Assert-Eq $script:NativeCalls[5].Exe "$env:SystemRoot\System32\wsl.exe" 'wsl.exe by its system path'
    Stub 'Resolve-Program' { param([string]$Name) $null }
    $script:NativeCalls = @()
    Assert-Eq (& $RealInvokeWinget -Id 'x').Code 127 'winget not found'
    Assert-Eq (& $RealInvokeLefthook).Code 127 'lefthook not found'
    Assert-True ((& $RealGetHooksPath) -like 'unavailable*') 'git not found'
    Assert-True ($null -eq (& $RealGetToolVersion -Name 'chezmoi' -VersionArgs @('--version'))) 'tool not found'
    Assert-True ((& $RealGetWingetList) -like 'unavailable*') 'winget list without winget'
    Assert-Eq $script:NativeCalls.Count 0 'nothing executed without a resolved path'
    Stub 'Invoke-Native' {
        param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory)
        @{ Code = 5; Out = ''; Err = 'bad' }
    }
    Stub 'Resolve-Program' { param([string]$Name) 'C:\x\winget.exe' }
    Assert-True ((& $RealGetWingetList) -like 'unavailable: winget exit 5*') 'winget list failure'
}

Test-Case 'C22 the real Resolve-Program returns a full path or $null' {
    $p = & $RealResolveProgram -Name 'powershell'
    Assert-True ([IO.Path]::IsPathRooted($p) -and $p -like '*.exe') 'rooted .exe'
    Assert-True ($null -eq (& $RealResolveProgram -Name 'no-such-program-bootstrap-test')) 'absent'
}
function Get-LogBefore {
    param([int]$Idx)
    if ($Idx -le 0) { return '' }
    return $script:LogLines[$Idx - 1]
}

function Assert-Announced {
    param($Call, [string]$Regex, [string]$What)
    Assert-True ($null -ne $Call) "${What}: the call happened"
    $line = Get-LogBefore $Call.Log
    Assert-True ($line -match $Regex) "${What}: the log line before the call was '$line', want /$Regex/"
}

function Get-RawCall {
    param([string]$Pattern)
    return @($script:Raw | Where-Object { ($_.A -join ' ') -match $Pattern })[0]
}

Test-Case 'T50-1 step C announces each winget install and the lefthook install before they run' {
    Initialize-Missing @('lefthook')
    $script:HooksOk = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced @(Get-SeamCalls 'Invoke-Winget')[0] 'step C: installing evilmartians.lefthook with winget \(can take several minutes\)' 'winget'
    Assert-Announced @(Get-SeamCalls 'Invoke-Lefthook')[0] 'step C: running lefthook install' 'lefthook install'
}

Test-Case 'T50-2 step 1 announces the restore point, System Restore and wsl --install' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:NewRpResults = @(@{ Ok = $false; Error = 'disabled' }, @{ Ok = $true; Error = '' })
    Assert-Eq (Run-Boot @{ EnableSystemRestore = $true }) 3 'exit'
    $np = @(Get-SeamCalls 'New-RestorePoint')
    Assert-Announced $np[0] 'step 1: creating a restore point \(can take a minute\)' 'restore point'
    Assert-Announced $np[1] 'creating a restore point again' 'retry'
    Assert-Announced @(Get-SeamCalls 'Enable-SystemRestore')[0] 'enabling System Restore on C:\\ \(can take a minute\)' 'enable'
    Assert-Announced (Get-RawCall '^--install --no-distribution$') 'step 1: running wsl --install --no-distribution \(a few minutes' 'wsl --install'
}

Test-Case 'T50-3 steps 2, 3 and 4 announce the update, download, import and channel update' {
    Initialize-Download
    $script:W.Version = '2.0.0.0'
    $script:W.ChannelOk = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced (Get-RawCall '^--update$') 'step 2: updating WSL, a few minutes' 'wsl --update'
    Assert-Announced @(Get-SeamCalls 'Invoke-Download')[0] 'step 3: downloading https://' 'download'
    Assert-Announced (Get-RawCall '^--import ') 'step 3: importing NixOS with wsl --import \(a minute or two\)' 'wsl --import'
    Assert-Announced (Get-RawCall 'nix-channel --update') 'step 4: running nix-channel --update as root' 'nix-channel'
}

Test-Case 'T50-4 steps 6, 7, 9 and 12 announce the clone, the report, the export, sys-setup and install.sh' {
    Initialize-Happy
    $script:W.HasClone = $false
    $script:W.HasSnap = $false
    $script:W.User = 'nixos'
    $script:W.HasCfg = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced @(Get-ScriptCalls 'clone')[0] 'step 6: cloning /mnt/c/fixture-repo' 'clone'
    $rep = @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'before-setup' })
    Assert-Announced $rep[0] 'writing the WSL report \(before-setup\); can take up to a minute' 'before-setup report'
    Assert-Announced (Get-RawCall '^--export ') 'exporting the distro to .*several minutes' 'wsl --export'
    Assert-Announced (Get-RawCall 'system-setup.sh --apply$') 'step 9: applying the system layer \(idempotent: system-setup.sh --apply as root, rebuilds NixOS' 'system-setup'
    Assert-True ((Get-Log) -match 'step 9: restarting the distro') 'restart announced'
    Assert-Announced (Get-RawCall 'ops/install.sh$') 'step 12: running ops/install.sh as tester \(20 minutes or more\); it is interactive' 'install.sh'
    $after = @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'after-install' })
    Assert-Announced $after[0] 'writing the WSL report \(after-install\)' 'after-install report'
}

Test-Case 'T50-4b a finished run points to the manual checklist; a dry run does not' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $want = "^\[bootstrap\] auto setup finished\. .*open $([regex]::Escape($script:RepoRoot))\\docs\\platforms\\windows\\setup\.md, section 'Manual steps after auto setup', and work through its checklist$"
    Assert-True ($script:LogLines[$script:LogLines.Count - 1] -match $want) "the last line points to the checklist; last line was: $($script:LogLines[$script:LogLines.Count - 1])"
    Reset-Stubs; Initialize-Happy
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'dry run'
    Assert-True (-not ((Get-Log) -match 'Manual steps after auto setup')) 'a dry run does not print the checklist pointer'
}

Test-Case 'T50-5 the pull announces itself' {
    Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced @(Get-ScriptCalls 'pull')[0] 'step 6: the clone is behind \(bbbbbbbbbbbb -> aaaaaaaaaaaa\); fast-forwarding it from' 'pull'
}

Test-Case 'T50-6 every step prints a line, including the ones with nothing to do' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $want = @('step C: lefthook hooks already installed', 'step 0: no reboot pending', 'step 1: WSL already installed \(2\.6\.1\.0\)',
        'step 2: WSL 2\.6\.1\.0 is new enough', 'step 3: NixOS already imported', 'step 4: nixpkgs channel present',
        'step 5: systemd is PID 1', 'step 6: wsl\.nix present in the Windows repo \(gate passed\)',
        'step 7a: before-setup WSL report exists', 'step 9: system layer applied; no restart needed', 'step 11: systemd', 'step 12: running ops/install\.sh')
    $pos = -1
    foreach ($w in $want) {
        $i = -1
        for ($k = 0; $k -lt $script:LogLines.Count; $k++) { if ($script:LogLines[$k] -match $w) { $i = $k; break } }
        Assert-True ($i -gt $pos) "line /$w/ appears, after the previous step's line (index $i, previous $pos)"
        $pos = $i
    }
}

Test-Case 'T50-7 no wsl.exe call when the Appx package is absent' {
    Initialize-Happy
    $script:Appx = $null
    Assert-Eq (Run-Boot @{}) 3 'normal run'
    Assert-Log 'step 1: WSL Appx package absent \(wsl.exe is not run\)'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call in a normal run'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 3 'dry-run'
    Assert-Log 'probe wsl --version: skipped \(no Appx package'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call in a dry run'
    Assert-Eq (Run-Boot @{ Export = 'x' }) 1 'export'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call for -Export'
    Assert-Eq (Run-Boot @{ Report = 'x' }) 0 'report'
    Assert-Eq @(Find-Raw '.').Count 0 'no wsl call for -Report'
    Assert-Log 'warning: WSL report \(x\) not written'
    $w = [IO.File]::ReadAllText((Join-Path $script:State 'host-snapshots\20260101T000000Z-x\windows.txt'))
    Assert-True ($w.Contains("appx: absent`nwsl: absent (no Appx package)")) 'the report records it'
}

Test-Case 'T50-8 elevated with the Appx package absent only runs the install' {
    Initialize-NotInstalled
    $script:Elev = $true
    $script:Points = @([pscustomobject]@{ Created = [datetime]::UtcNow.AddHours(-1); Description = 'x' })
    Assert-Eq (Run-Boot @{}) 3 'exit'
    foreach ($c in $script:Raw) { Assert-Eq $c.A[0] '--install' "only the install call: $($c.A -join ' ')" }
    $d = @(Get-ChildItem -LiteralPath (Join-Path $script:State 'host-snapshots') -Directory)
    $w = [IO.File]::ReadAllText((Join-Path $d[0].FullName 'windows.txt'))
    Assert-True ($w.Contains('wsl: absent (no Appx package)')) 'before report'
}

Test-Case 'T50-9 the heartbeat: a line at least every interval, labelled, for capture, passthrough and timeouts' {
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Prefix = '[t]'
    $script:WaitLabel = 'step X: testing a slow thing'
    $r = & $RealInvokeNative -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 4; [Console]::Out.Write(''done'')') -HeartbeatSeconds 1
    Assert-Eq $r.Code 0 'exit'
    Assert-Eq $r.Out 'done' 'stdout'
    $beats = @($script:LogLines | Where-Object { $_ -match '^\[t\] still running: step X: testing a slow thing \(\d+ s elapsed\)$' })
    Assert-True ($beats.Count -ge 2) "at least two labelled beats in 4 s, got $($beats.Count)"
    Assert-True ($null -eq $script:WaitLabel) 'the label is used once'
    $script:LogLines.Clear()
    [void](& $RealInvokeNative -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 3') -HeartbeatSeconds 1)
    Assert-True (@($script:LogLines | Where-Object { $_ -match 'still running: powershell.exe \(' }).Count -ge 1) 'no label: the program name'
    $script:LogLines.Clear()
    $p = & $RealInvokeNative -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 3') -Passthrough -HeartbeatSeconds 1
    Assert-Eq $p.Code 0 'passthrough exit'
    Assert-Eq @($script:LogLines | Where-Object { $_ -match 'still running' }).Count 0 'no heartbeat lines for passthrough calls'
    $script:LogLines.Clear()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $h = & $RealInvokeNative -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 60') -TimeoutSeconds 3 -HeartbeatSeconds 1
    Assert-Eq $h.Code 124 'timeout still enforced'
    Assert-True ($sw.Elapsed.TotalSeconds -lt 30) 'prompt'
    Assert-True (@($script:LogLines | Where-Object { $_ -match 'still running' }).Count -ge 1) 'beats before the timeout'
    $script:LogLines = $null
}

Test-Case 'T50-10 download progress text and the real download with a size line' {
    Assert-Eq (Format-DownloadProgress -Got 120MB -Total 600MB -Seconds 60) 'downloaded 120 MB of 600 MB (20%), 60 s elapsed' 'with total'
    Assert-Eq (Format-DownloadProgress -Got 5MB -Total $null -Seconds 30) 'downloaded 5 MB, 30 s elapsed' 'without total'
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Prefix = '[t]'
    $src = Join-Path $script:T 'src.bin'
    [IO.File]::WriteAllBytes($src, (New-Object byte[] 4096))
    $dst = Join-Path $script:T 'dst.bin'
    & $RealInvokeDownload -Url ([Uri]$src).AbsoluteUri -OutFile $dst -ProgressSeconds 5
    Assert-Eq (Get-Item -LiteralPath $dst).Length 4096 'file downloaded'
    Assert-True (@($script:LogLines | Where-Object { $_ -match 'step 3: download size (unknown|\d+ MB); progress every 5 s' }).Count -eq 1) 'size line'
    $failed = $false
    try { & $RealInvokeDownload -Url ([Uri](Join-Path $script:T 'nope.bin')).AbsoluteUri -OutFile (Join-Path $script:T 'x.bin') -ProgressSeconds 5 } catch { $failed = $true }
    Assert-True $failed 'a failed download throws'
    Assert-Eq @(Get-Job).Count 0 'no leftover job after a download or a failed download'
    $script:LogLines = $null
}

Test-Case 'T50-11 the one-time wait label cannot attach to a later call' {
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Prefix = '[t]'
    Start-Wait 'step X: something'
    Say 'an unrelated line'
    Assert-True ($null -eq $script:WaitLabel) 'a later Say drops the label'
    Stub 'Resolve-Program' { param([string]$Name) $null }
    Start-Wait 'step C: installing x with winget'
    $r = & $RealInvokeWinget -Id 'x'
    Assert-Eq $r.Code 127 'winget not found'
    Assert-True ($null -eq $script:WaitLabel) 'an early return drops the label'
    Start-Wait 'step C: running lefthook install'
    $r = & $RealInvokeLefthook
    Assert-Eq $r.Code 127 'lefthook not found'
    Assert-True ($null -eq $script:WaitLabel) 'an early return drops the label (lefthook)'
    $script:LogLines.Clear()
    [void](& $RealInvokeNative -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 3') -HeartbeatSeconds 1)
    Assert-True (@($script:LogLines | Where-Object { $_ -match 'still running: powershell.exe \(' }).Count -ge 1) 'a later capture shows its own name, not a stale label'
    $script:LogLines = $null
}
function Get-GitBash {
    $p = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}

function Invoke-GitBashScript {
    param([string]$Text)
    $file = Join-Path $script:T ('t' + [guid]::NewGuid().ToString('N') + '.sh')
    [IO.File]::WriteAllText($file, ($Text -replace "`r", ''), (New-Object Text.UTF8Encoding($false)))
    & (Get-GitBash) ($file -replace '\\', '/') | Out-Null
    return $LASTEXITCODE
}

Test-Case 'R1 the report script writes a .partial dir, marks it .complete last, then renames it' {
    $s = $WslReportScript
    Assert-True ($s.Contains('dir=$final.partial')) 'works in a .partial dir'
    Assert-True ($s.Contains('touch "$dir/.complete"' + "`n" + 'mv "$dir" "$final" || exit 1')) 'marker, then rename'
    Assert-True ($s.TrimEnd().EndsWith('printf ''%s\n'' "$final"')) 'prints the final dir last'
    Assert-True ($s.IndexOf('# end stale-cleanup') -lt $s.IndexOf('dir=$final.partial')) 'cleanup runs first'
}

Test-Case 'R2 stale cleanup: incomplete and .partial dirs of the label go, complete ones and other labels stay' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    $base = Join-Path $script:T 'snap'
    foreach ($d in @('20250101T000000Z-before-setup', '20250102T000000Z-before-setup', '20250103T000000Z-before-setup.partial',
            '20250104T000000Z-other', '20250105T000000Z-x-before-setup', '20250106T000000Z-other.partial')) {
        [void](New-Item -ItemType Directory -Force -Path (Join-Path $base $d))
    }
    [IO.File]::WriteAllText((Join-Path $base '20250102T000000Z-before-setup\.complete'), '')
    $m = [regex]::Match($WslReportScript, '(?s)base=/var/lib/app-configs/host-snapshots\n.*?# end stale-cleanup')
    Assert-True $m.Success 'cleanup block found'
    $block = 'label=before-setup' + "`n" + ($m.Value -replace '(?m)^base=.*$', ('base=' + ($base -replace '\\', '/')))
    Assert-Eq (Invoke-GitBashScript $block) 0 'block runs'
    $left = @(Get-ChildItem -LiteralPath $base -Directory | ForEach-Object { $_.Name } | Sort-Object)
    Assert-Eq ($left -join ',') '20250102T000000Z-before-setup,20250104T000000Z-other,20250105T000000Z-x-before-setup,20250106T000000Z-other.partial' 'only this label stale dirs removed'
}

Test-Case 'R3 the existence probe counts only complete reports' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    $base = Join-Path $script:T 'snap2'
    $bfwd = $base -replace '\\', '/'
    $probe = $WslHasSnapScript.Replace('/var/lib/app-configs/host-snapshots', $bfwd)
    Assert-True ($probe -ne $WslHasSnapScript) 'path substituted'
    [void](New-Item -ItemType Directory -Force -Path $base)
    Assert-Eq (Invoke-GitBashScript $probe) 1 'no report'
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $base '20250101T000000Z-before-setup'))
    Assert-Eq (Invoke-GitBashScript $probe) 1 'an incomplete leftover does not count'
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $base '20250103T000000Z-before-setup.partial'))
    Assert-Eq (Invoke-GitBashScript $probe) 1 'a .partial dir does not count'
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $base '20250102T000000Z-other'))
    [IO.File]::WriteAllText((Join-Path $base '20250102T000000Z-other\.complete'), '')
    Assert-Eq (Invoke-GitBashScript $probe) 1 'another label does not count'
    [IO.File]::WriteAllText((Join-Path $base '20250101T000000Z-before-setup\.complete'), '')
    Assert-Eq (Invoke-GitBashScript $probe) 0 'a complete report counts'
}

Test-Case 'R4 step 7a uses the marker-aware probe, and a stale report is rewritten' {
    Initialize-Happy
    $script:W.HasSnap = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $h = @(Get-ScriptCalls 'hassnap')
    Assert-Eq (Get-ScriptText $h[0]) $WslHasSnapScript 'the probe script'
    Assert-Eq @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'before-setup' }).Count 1 'the report is written again'
}

Test-Case 'R5 runuser: no shell option after the user; every capu command has stdin from /dev/null' {
    $s = $WslReportScript
    Assert-True ($s.Contains('runuser -u "$du" -- /run/current-system/sw/bin/bash -lc "')) 'runuser -u USER -- bash -lc'
    Assert-True ($s.Contains('</dev/null 2>&1')) 'stdin from /dev/null'
    Assert-True (-not ($s -match 'runuser\s+-l')) 'no runuser -l (its options would reach the login shell)'
    Assert-True (-not ($s -match 'runuser[^\n]* -s ')) 'no -s option'
}

Test-Case 'R6 captures close stdin: a child that reads it gets EOF at once' {
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Prefix = '[t]'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = & $RealInvokeNative -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', '$s = [Console]::In.ReadToEnd(); [Console]::Out.Write(''len='' + $s.Length)') -TimeoutSeconds 30
    Assert-Eq $r.Code 0 'exit'
    Assert-Eq $r.Out 'len=0' 'EOF on stdin'
    Assert-True ($sw.Elapsed.TotalSeconds -lt 25) 'no wait for input'
    $script:LogLines = $null
}

Test-Case 'R7 every console line starts with a carriage return' {
    $script:LogLines = New-Object 'System.Collections.Generic.List[string]'
    $script:Prefix = '[t]'
    Assert-Eq (Format-ConsoleLine '[t] x') "`r[t] x" 'format'
    $script:HostOut.Clear()
    Say 'hello'
    Assert-Eq $script:HostOut[0] "`r[t] hello" 'Say writes CR first'
    Assert-Eq $script:LogLines[0] '[t] hello' 'the log keeps the plain line'
    $script:LogLines = $null
}

Test-Case 'R8 the report capture has a 300 s limit and a clear timeout message' {
    Initialize-Happy
    $script:W.HasSnap = $false
    $script:W.ReportCode = 124
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'warning: the WSL report \(before-setup\) timed out after 300 s; wsl.exe was stopped, but the in-distro report may still be running'
    $rep = @(Get-ScriptCalls 'report' | Where-Object { $_.A -contains 'before-setup' })
    Assert-Eq $rep[0].Timeout 300 'report timeout'
    $others = @($script:Raw | Where-Object { ($_.A -join ' ') -notmatch 'app-configs-report-' })
    Assert-True (@($others | Where-Object { $_.Timeout -ne 0 }).Count -eq 0) 'other calls keep the default'
}
function Invoke-GitBashCapture {
    param([string]$Text)
    $file = Join-Path $script:T ('c' + [guid]::NewGuid().ToString('N') + '.sh')
    [IO.File]::WriteAllText($file, ($Text -replace "`r", ''), (New-Object Text.UTF8Encoding($false)))
    $out = & (Get-GitBash) ($file -replace '\\', '/')
    return @{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

Test-Case 'R9 the report sanity check: interrupted or failed per-user sections never pass' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    $m = [regex]::Match($WslReportScript, '(?s)# begin sanity-check.*?# end sanity-check')
    Assert-True $m.Success 'sanity-check block found'
    $d = (Join-Path $script:T 'rep') -replace '\\', '/'
    [void](New-Item -ItemType Directory -Force -Path $d)
    $repoDir = (Join-Path $script:T 'repo') -replace '\\', '/'
    $good = "uid=1000(nixos) gid=100(users)`n"
    $run = {
        param($idrc, $detrc, $repoPath, $userTxt)
        [IO.File]::WriteAllText("$d/user.txt", $userTxt)
        Remove-Item -LiteralPath "$d/report-status.txt" -ErrorAction SilentlyContinue
        Invoke-GitBashCapture ("id_rc=$idrc`ndetect_rc=$detrc`nrepo=$repoPath`ndir=$d`n" + $m.Value + "`necho passed`n")
    }
    $r = & $run '0' '0' $repoDir $good
    Assert-Eq $r.Code 0 'all good'
    Assert-True ($r.Out -match 'passed') 'continues'
    $r = & $run '130' '0' $repoDir $good
    Assert-Eq $r.Code 3 'runuser interrupted (130)'
    Assert-True ($r.Out -match ("incomplete: " + [regex]::Escape($d)) -and $r.Out -match 'failed: id \(exit 130\)') 'names the partial dir and the failure'
    Assert-True (-not ($r.Out -match 'passed')) 'stops before marking complete'
    Assert-True ([IO.File]::ReadAllText("$d/report-status.txt") -match 'per-user sections failed') 'status file'
    $r = & $run '0' '0' $repoDir "Interrupt`n"
    Assert-Eq $r.Code 3 'id output without uid= (banner or garbage only)'
    $r = & $run '0' '130' $repoDir $good
    Assert-Eq $r.Code 3 'detect-host interrupted'
    Assert-True ($r.Out -match 'detect-host \(exit 130\)') 'names detect-host'
    $r = & $run '' '0' $repoDir $good
    Assert-Eq $r.Code 3 'no id exit code'
    Assert-True ($r.Out -match 'exit none') 'reports none'
    $r = & $run '0' '' ($repoDir + '-absent') $good
    Assert-Eq $r.Code 0 'no clone yet: detect-host is not required'
}

Test-Case 'R10 an incomplete (user sections failed) report is a warning for the caller, never a path' {
    Initialize-Happy
    $script:W.HasSnap = $false
    $script:W.ReportCode = 3
    $script:W.ReportOut = "incomplete: /var/lib/app-configs/host-snapshots/20260101T000000Z-before-setup.partial`nfailed: id (exit 130)"
    Assert-Eq (Run-Boot @{}) 1 'step 7a fails'
    Assert-Log 'warning: the WSL report \(before-setup\) is INCOMPLETE, its per-user sections failed \(failed: id \(exit 130\)\); kept for inspection \(incomplete: /var/lib/app-configs/host-snapshots/20260101T000000Z-before-setup.partial\)'
    Assert-Log 'step 7a: the before-setup WSL report failed'
    Assert-Eq @(Find-Raw '^--export').Count 0 'nothing exported after a bad report'
    Reset-Stubs; Initialize-Happy
    $script:W.ReportCode = 3
    $script:W.ReportOut = "incomplete: /x.partial`nfailed: id (exit 130)"
    Assert-Eq (Run-Boot @{ Report = 'chk' }) 0 '-Report only warns'
    Assert-Log 'is INCOMPLETE'
}

Test-Case 'R11 the login banner does not break any parse (facts, origin, report dir)' {
    Initialize-Happy
    $script:W.HasSnap = $false
    $script:W.HasClone = $false
    $script:W.Banner = "Welcome to your new NixOS-WSL system!`n`nPlease run sudo nix-channel --update now.`nNote: this message will disappear after you rebuild.`n"
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step 5: systemd is PID 1 and WSLInterop exists'
    Assert-Log 'step 11: systemd, WSLInterop and user tester confirmed'
    Assert-Log 'step 6: cloned to /home/tester/app-configs, origin https://github.com/example/app-configs.git'
    Assert-Log '(?m)step 7a: WSL report \(before-setup\): /var/lib/app-configs/host-snapshots/20260101T000000Z-before-setup$'
}

Test-Case 'R14 repo scripts run in a non-login shell started from a login shell (no bash -l <script>)' {
    $text = [IO.File]::ReadAllText($ScriptPath)
    Assert-True (-not ($text -match "'-l',\s*(\`"\`$clone/ops|'ops/)")) 'no bash -l with a repo script as its argument'
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $sys = @($script:Raw | Where-Object { ($_.A -join ' ') -match 'system-setup.sh' })
    Assert-Eq ($sys[0].A -join ' ') '-d NixOS -u root --exec /run/current-system/sw/bin/env USER_NAME=tester /run/current-system/sw/bin/bash -lc exec bash /home/tester/app-configs/ops/system-setup.sh --apply' 'system-setup args'
    $i = $sys[0].A.Count - 1
    Assert-Eq $sys[0].A[$i] 'exec bash /home/tester/app-configs/ops/system-setup.sh --apply' 'one -c argument'
    $inst = @($script:Raw | Where-Object { ($_.A -join ' ') -match 'ops/install.sh$' })
    Assert-Eq $inst[0].A[$inst[0].A.Count - 1] 'exec bash ops/install.sh' 'install.sh runs via exec in a non-login bash'
    Assert-True $inst[0].Pt 'install.sh stays passthrough'
}

Test-Case 'R12 wsl is always called with --exec, never with a bare -- (the default shell would expand variables early)' {
    $tokens = $null; $errs = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errs)
    $bare = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq '--' }, $true))
    Assert-Eq $bare.Count 0 "no '--' argument in the script's wsl argument lists"
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false; $script:W.HasClone = $false; $script:W.HasSnap = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $global = @('--version', '--list', '--update', '--install', '--import', '--terminate', '--export', '--status', '--shutdown')
    foreach ($c in $script:Raw) {
        if ($global -contains $c.A[0]) { continue }
        $x = [array]::IndexOf($c.A, '--exec')
        Assert-True ($x -ge 2) "a distro call has --exec: $($c.A -join ' ')"
        Assert-True (-not (@($c.A[0..$x]) -contains '--')) "no bare -- before --exec: $($c.A -join ' ')"
    }
}

Test-Case 'R13 Ctrl+C (a stopped pipeline) returns promptly, kills only the child it started and says so' {
    $pidFile = Join-Path $script:T 'child.pid'
    $ps = [powershell]::Create()
    # The child writes its own $pid (single-quoted, so the runspace does not expand it).
    $inner = '$pid | Set-Content -LiteralPath ''' + $pidFile + '''; Start-Sleep -Seconds 120'
    $cmd = ". '$ScriptPath'; `$null = Invoke-Native -ExePath 'powershell.exe' -Arguments @('-NoProfile', '-Command', '" + ($inner -replace "'", "''") + "') -TimeoutSeconds 300"
    [void]$ps.AddScript($cmd)
    $h = $ps.BeginInvoke()
    $childPid = 0
    for ($k = 0; $k -lt 100 -and $childPid -eq 0; $k++) {
        Start-Sleep -Milliseconds 300
        if (Test-Path -LiteralPath $pidFile) { try { $childPid = [int]((Get-Content -LiteralPath $pidFile -Raw).Trim()) } catch { $childPid = 0 } }
    }
    Assert-True ($childPid -gt 0 -and $childPid -ne $PID) 'the child started (and is not this process)'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ps.Stop()
    Assert-True ($sw.Elapsed.TotalSeconds -lt 5) "Stop() returned in $([int]$sw.Elapsed.TotalSeconds) s"
    $gone = $false
    for ($k = 0; $k -lt 20 -and -not $gone; $k++) {
        if (-not (Get-Process -Id $childPid -ErrorAction SilentlyContinue)) { $gone = $true } else { Start-Sleep -Milliseconds 250 }
    }
    Assert-True $gone 'the child process is gone'
    $info = (@($ps.Streams.Information) | ForEach-Object { [string]$_.MessageData }) -join "`n"
    Assert-True ($info -match "interrupted: powershell.exe; stopping the process this script started \(PID $childPid\)") "says what was interrupted: [$info]"
    $ps.Dispose()
}
Test-Case 'S6a the clone is compared with the Windows main: up to date, nothing pulled' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step 6: clone is up to date \(aaaaaaaaaaaa\)'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull'
    $sy = @(Get-ScriptCalls 'sync')
    Assert-True ($sy.Count -ge 1 -and -not (($sy[0].A -join ' ') -match '-u ')) 'read-only compare as the default user'
}

Test-Case 'S6b the clone is behind the Windows main: announced, fast-forwarded, verified' {
    Initialize-Happy
    $script:W.Rel = 'behind'
    $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step 6: the clone is behind \(bbbbbbbbbbbb -> aaaaaaaaaaaa\); fast-forwarding it from /mnt/c/fixture-repo \(main\)'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 1 'one pull'
    Assert-Eq @(Get-ScriptCalls 'sync').Count 2 'compared before and after the pull'
    Assert-Log 'step 6: clone fast-forwarded to aaaaaaaaaaaa'
}

Test-Case 'S6c a diverged or rebased clone -> 1 with both commits and the recovery, nothing changed' {
    Initialize-Happy
    $script:W.Rel = 'other'
    $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'step 6: the clone is at bbbbbbbbbbbb but the Windows repo''s main is aaaaaaaaaaaa, which is not a descendant of it \(rebased or diverged history\)'
    Assert-Log 'if you want a fresh clone, move this one aside: wsl -d NixOS -u root -- sh -lc ''mv /home/tester/app-configs /home/tester/app-configs.old-20260101T000000Z'', then re-run'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull'
    Assert-Eq @(Find-Raw 'sw/bin/env').Count 0 'system-setup not reached'
    foreach ($c in @($script:Raw | Where-Object { $_.A -contains '/bin/sh' })) {
        $txt = Get-ScriptText $c
        Assert-True (-not ($txt -match 'rm -rf|reset|clean -f|branch -D')) "no destructive command in a script: $txt"
    }
    Assert-Eq @(Find-Raw ' --exec /run/current-system/sw/bin/rm ').Count 0 'no direct rm call'
}

Test-Case 'S6d a clone with local changes -> 1 (unless it is already up to date)' {
    Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.Dirty = 3
    Assert-Eq (Run-Boot @{}) 1 'behind and dirty'
    Assert-Log 'the clone has local changes \(3 entries in git status --porcelain\); commit or stash them there, or if you want a fresh clone, move this one aside'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull over local changes'
    Reset-Stubs; Initialize-Happy
    $script:W.Rel = 'other'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.Dirty = 1
    Assert-Eq (Run-Boot @{}) 1 'diverged and dirty'
    Assert-Log 'and has 1 local changes but the Windows repo''s main is aaaaaaaaaaaa, which is not a descendant'
    Reset-Stubs; Initialize-Happy
    $script:W.Dirty = 2
    Assert-Eq (Run-Boot @{}) 0 'up to date: local changes do not matter'
}

Test-Case 'S6e an unreadable comparison -> 1; a missing wsl.nix after the sync -> 3' {
    Initialize-Happy
    $script:W.SyncCode = 1
    Assert-Eq (Run-Boot @{}) 1 'cannot compare'
    Assert-Log 'step 6: cannot compare the clone with the Windows repo''s main \(exit 1, or git status failed\)'
    Reset-Stubs; Initialize-Happy
    $script:W.HasGate = $false
    Assert-Eq (Run-Boot @{}) 3 'up to date but no wsl.nix in main'
    Assert-Log 'not in its committed main'
}

Test-Case 'S6f the real compare script, run against real git repos (Git Bash)' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    $git = (Get-Command git -ErrorAction SilentlyContinue)
    if (-not $git) { throw 'SKIP: git not found' }
    $src = Join-Path $script:T 'gsrc'
    $dst = Join-Path $script:T 'gdst'
    $c = @('-c', 'user.name=t', '-c', 'user.email=t@t')
    [void](New-Item -ItemType Directory -Force -Path $src)
    & git -C $src init -q -b main
    [IO.File]::WriteAllText((Join-Path $src 'a'), "1`n")
    & git -C $src add a; & git -C $src @c commit -q -m one
    & git clone -q $src $dst
    $sf = $src -replace '\\', '/'; $df = $dst -replace '\\', '/'
    $run = {
        $s = "export SRC='$sf' DST='$df'`n" + $WslSyncScript.Replace('nix-shell -p git --run "$inner"', 'bash -c "$inner"')
        Assert-True ($s.Contains('command -v git')) 'uses the system git when present'
        $o = Invoke-GitBashCapture $s
        $h = @{}
        foreach ($l in ($o.Out -split "`n")) { if ($l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() } }
        $h
    }
    $r = & $run
    Assert-Eq $r.rel 'same' 'same'
    Assert-Eq $r.dirty '0' 'clean'
    Assert-True ($r.src -match '^[0-9a-f]{40}$' -and $r.src -eq $r.head) 'both shas'
    [IO.File]::WriteAllText((Join-Path $src 'a'), "2`n")
    & git -C $src @c commit -q -am two
    $r = & $run
    Assert-Eq $r.rel 'behind' 'the clone is behind main'
    [IO.File]::WriteAllText((Join-Path $dst 'untracked'), 'x')
    $r = & $run
    Assert-Eq $r.dirty '1' 'an untracked file counts as a local change'
    Remove-Item -LiteralPath (Join-Path $dst 'untracked')
    & git -C $dst pull -q --ff-only
    $r = & $run
    Assert-Eq $r.rel 'same' 'same again after the pull'
    # a rebased main: same content, new commit ids
    & git -C $src @c commit -q --amend -m 'two rebased' --date '2000-01-01T00:00:00'
    $r = & $run
    Assert-Eq $r.rel 'other' 'a rebased main is not a descendant of the clone head'
    # a clone with its own commit
    & git -C $dst fetch -q origin main 2>$null
    & git -C $dst reset -q --hard FETCH_HEAD
    [IO.File]::WriteAllText((Join-Path $dst 'b'), 'mine')
    & git -C $dst add b; & git -C $dst @c commit -q -m mine
    $r = & $run
    Assert-Eq $r.rel 'other' 'the clone has commits main lacks'
}

Test-Case 'S9a step 9 runs system-setup on every run and restarts only when needed' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $env1 = @(Find-Raw 'sw/bin/env USER_NAME=tester')
    Assert-Eq $env1.Count 1 'system-setup ran although everything was in place'
    Assert-Log 'step 9: system layer applied; no restart needed \(default user tester, app-configs-wsl.nix present, ownership correct\)'
    $after = @(Find-Raw '^--terminate NixOS$' | Where-Object { $_ -gt $env1[0] })
    Assert-Eq $after.Count 0 'no terminate after system-setup'
    Assert-Eq @(Find-Raw 'sw/bin/chown -R').Count 0 'no chown'
    Assert-Eq @(Find-Raw '-u root --exec /run/current-system/sw/bin/true$').Count 0 'no wake-up'
    Reset-Stubs; Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    Assert-Eq (Run-Boot @{}) 0 'exit with a pending user change'
    Assert-Log 'step 9: restarting the distro so the new default user takes effect \(default user ''nixos'', want ''tester''\)'
    Assert-Eq @(Find-Raw 'sw/bin/chown -R tester:users').Count 1 'chown after the restart'
    Reset-Stubs; Initialize-Happy
    $script:W.HasCfg = $false; $script:W.SysSetupNoEffect = $true
    Assert-Eq (Run-Boot @{}) 1 'user right but the marker still missing'
    Assert-Log 'app-configs-wsl.nix present: False'
    Assert-Log 'step 9: recovery:'
}

Test-Case 'S9b step 9 announces the setup before it runs; a failing setup stops the run' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced (Get-RawCall 'system-setup.sh --apply$') 'step 9: applying the system layer \(idempotent: system-setup.sh --apply as root, rebuilds NixOS' 'system-setup'
    Reset-Stubs; Initialize-Happy
    $script:W.SysSetupCode = 4
    Assert-Eq (Run-Boot @{}) 1 'setup fails'
    Assert-Log 'step 9: system-setup.sh exited 4'
    Assert-Eq @(Find-Raw 'ops/install.sh$').Count 0 'install.sh not reached'
}

Test-Case 'N1 no login shell in the script can exit with nounset on' {
    $text = [IO.File]::ReadAllText($ScriptPath)
    # A login shell sources /etc/bash_logout when it exits; with nounset on that file fails
    # (__ETC_BASHLOGOUT_SOURCED: unbound variable). So no in-distro text may turn nounset
    # on in a login shell, and SHELLOPTS must never be exported.
    Assert-True (-not ($text -match '(?i)\bset\s+-[a-z]*u')) 'no set -u / set -eu / set -euo in any in-distro script'
    Assert-True (-not ($text -match '(?i)nounset')) 'no set -o nounset'
    Assert-True (-not ($text -match 'SHELLOPTS|BASHOPTS')) 'no exported shell options'
    Assert-True (-not ($text -match "bash\s+-[a-z]*l[a-z]*u|bash\s+-[a-z]*u[a-z]*l")) 'no bash -lu'
    # every repo script is started by exec from the login shell, so no login shell outlives it
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    foreach ($c in $script:Raw) {
        $joined = $c.A -join ' '
        if ($joined -match 'system-setup.sh|ops/install.sh') {
            Assert-True ($joined -match 'bash -lc exec bash ') "repo script runs via exec in a non-login bash: $joined"
        }
    }
}

Test-Case 'S6g a dry run compares an existing clone the same way and returns the real code' {
    Initialize-Happy
    $script:W.Rel = 'other'; $script:W.HeadSha = 'c8fe21b5d2b84cd8b8c6727492bd61b6f447dab5'; $script:W.SrcSha = 'b1391bfe0c17d815e1d13bc9bb34efc831be914e'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 1 'diverged: the same exit code as a real run'
    Assert-Log '\[dry-run\] step 6: the clone is at c8fe21b5d2b8 but the Windows repo''s main is b1391bfe0c17, which is not a descendant of it \(rebased or diverged history\)'
    Assert-Log 'wsl -d NixOS -u root -- sh -lc ''mv /home/tester/app-configs /home/tester/app-configs.old-20260101T000000Z'', then re-run \(the clone is recreated from main\)'
    $sy = @(Get-ScriptCalls 'sync')
    Assert-Eq $sy.Count 1 'one compare'
    Assert-True ((Get-ScriptText $sy[0]).Contains('export DRY_RUN=1')) 'the dry run never downloads git'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'nothing pulled'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
    Reset-Stubs; Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'behind'
    Assert-Log '\[dry-run\] step 6: would fast-forward the clone \(bbbbbbbbbbbb -> aaaaaaaaaaaa\) from /mnt/c/fixture-repo \(main\)'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull in a dry run'
    Reset-Stubs; Initialize-Happy
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'up to date'
    Assert-Log '\[dry-run\] step 6: clone is up to date \(aaaaaaaaaaaa\)'
    Reset-Stubs; Initialize-Happy
    $script:W.SyncSkipped = $true
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'git not installed yet'
    Assert-Log '\[dry-run\] step 6: git is not installed in the distro yet; comparing without it'
    Reset-Stubs; Initialize-Happy
    $script:W.HasClone = $false
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'no clone yet'
    Assert-Log '\[dry-run\] step 6: would read the origin of .* \(nix-shell -p git; skipped in a dry run\), then clone it to /home/tester/app-configs'
    Assert-Eq @(Get-ScriptCalls 'sync').Count 0 'nothing to compare'
}

Test-Case 'S6h the recovery is a move, never a delete, and names the ignored files' {
    Initialize-Happy
    $script:W.Rel = 'other'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'if you want a fresh clone, move this one aside: wsl -d NixOS -u root -- sh -lc ''mv /home/tester/app-configs /home/tester/app-configs.old-20260101T000000Z'', then re-run \(the clone is recreated from main\)'
    Assert-Log 'Do not delete it: it can hold gitignored files such as home/.chezmoidata/personal.yaml that git status does not show\. This script never resets, moves or deletes it'
    Assert-True (-not ((Get-Log) -match 'rm -rf')) 'no rm -rf advice anywhere'
}

Test-Case 'S6i divergence is checked before dirtiness, and both are named' {
    Initialize-Happy
    $script:W.Rel = 'other'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.Dirty = 4
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'step 6: the clone is at bbbbbbbbbbbb and has 4 local changes but the Windows repo''s main is aaaaaaaaaaaa, which is not a descendant of it'
}

Test-Case 'S6j a behind clone is pulled only when HEAD is on main' {
    Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.Branch = 'feature'
    Assert-Eq (Run-Boot @{}) 1 'on another branch'
    Assert-Log 'step 6: the clone is behind \(bbbbbbbbbbbb -> aaaaaaaaaaaa\) but it is on branch ''feature'', not main, so a pull would not update main'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull'
    Reset-Stubs; Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.Branch = ''
    Assert-Eq (Run-Boot @{}) 1 'detached HEAD'
    Assert-Log 'but it is on a detached HEAD, not main'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'no pull'
    Reset-Stubs; Initialize-Happy
    $script:W.Rel = 'behind'; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq (Run-Boot @{}) 0 'on main: pulled'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 1 'one pull'
}

Test-Case 'S6k an unreadable git status is unknown, never clean' {
    Initialize-Happy
    $script:W.DirtyUnknown = $true
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'cannot compare the clone with the Windows repo''s main \(exit 0, or git status failed\)'
}

Test-Case 'S6l the compare is announced before it runs' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced @(Get-ScriptCalls 'sync')[0] 'step 6: comparing the clone with the Windows main \(nix-shell -p git may fetch git first\)' 'compare'
    Reset-Stubs; Initialize-Happy
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'dry run'
    Assert-Announced @(Get-ScriptCalls 'sync')[0] 'step 6: comparing the clone with the Windows main$' 'dry-run compare'
}

Test-Case 'S6m a dry run on a distro without git compares through Windows git and returns the real code where it can' {
    Initialize-Happy
    $script:W.SyncSkipped = $true
    $script:W.HeadSha = 'c8fe21b5d2b84cd8b8c6727492bd61b6f447dab5'
    $script:WinRel = @{ Src = 'b1391bfe0c17d815e1d13bc9bb34efc831be914e'; Rel = 'diverged' }
    Assert-Eq (Run-Boot @{ DryRun = $true }) 1 'diverged: the real code'
    Assert-Log '\[dry-run\] step 6: git is not installed in the distro yet; comparing without it'
    Assert-Log 'the clone is at c8fe21b5d2b8 but the Windows repo''s main is b1391bfe0c17, which is not a descendant of it'
    Assert-Eq @(Get-SeamCalls 'Get-WindowsRelation')[0].Args['Head'] 'c8fe21b5d2b84cd8b8c6727492bd61b6f447dab5' 'Windows git got the clone HEAD'
    Assert-Eq @(Get-ScriptCalls 'headread').Count 1 'HEAD read without git'
    Assert-Eq @(Get-ScriptCalls 'pull').Count 0 'nothing pulled'
    Reset-Stubs; Initialize-Happy
    $script:W.SyncSkipped = $true
    $script:WinRel = @{ Src = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; Rel = 'same' }
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'same'
    Assert-Log 'step 6: clone is up to date \(aaaaaaaaaaaa\) \(local changes were not checked\)'
    Reset-Stubs; Initialize-Happy
    $script:W.SyncSkipped = $true; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    $script:WinRel = @{ Src = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; Rel = 'behind' }
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'behind'
    Assert-Log 'would fast-forward the clone \(bbbbbbbbbbbb -> aaaaaaaaaaaa\) from /mnt/c/fixture-repo \(main\); a real run exits 1 instead if the clone has local changes, which cannot be checked here'
    Reset-Stubs; Initialize-Happy
    $script:W.SyncSkipped = $true; $script:W.HeadSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; $script:W.Branch = 'feature'
    $script:WinRel = @{ Src = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; Rel = 'behind' }
    Assert-Eq (Run-Boot @{ DryRun = $true }) 1 'behind on another branch: the real code'
    Reset-Stubs; Initialize-Happy
    $script:W.SyncSkipped = $true
    $script:WinRel = @{ Src = ''; Rel = 'unknown'; Why = 'no git on Windows' }
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'no usable Windows git'
    Assert-Log 'step 6: the clone cannot be compared \(no git on Windows; the distro has no git either\); a real run may exit 0 or 1 here, which a dry run cannot tell'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
}

Test-Case 'S6n Get-WindowsRelation with Windows git (Invoke-Native stubbed)' {
    $script:NR = @{ rev = @{ Code = 0; Out = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`n"; Err = '' }; anc = @{ Code = 0; Out = ''; Err = '' } }
    Stub 'Resolve-Program' { param([string]$Name) 'C:/g/git.exe' }
    Stub 'Invoke-Native' {
        param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory, [int]$HeartbeatSeconds)
        if ($Arguments[0] -eq 'rev-parse') { $script:NR.rev } else { $script:NR.anc }
    }
    $r = & $RealGetWindowsRelation -Head 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Eq "$($r.Rel)/$($r.Src)" 'same/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' 'same'
    $r = & $RealGetWindowsRelation -Head 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    Assert-Eq $r.Rel 'behind' 'ancestor'
    $script:NR.anc = @{ Code = 1; Out = ''; Err = '' }
    Assert-Eq (& $RealGetWindowsRelation -Head 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa').Rel 'diverged' 'not an ancestor'
    $script:NR.anc = @{ Code = 128; Out = ''; Err = 'fatal' }
    Assert-Eq (& $RealGetWindowsRelation -Head 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa').Rel 'diverged' 'merge-base failed and the commit is absent (cat-file also fails)'
    $script:NR.rev = @{ Code = 1; Out = ''; Err = '' }
    Assert-Eq (& $RealGetWindowsRelation -Head 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa').Rel 'unknown' 'no main'
    Stub 'Resolve-Program' { param([string]$Name) $null }
    Assert-Eq (& $RealGetWindowsRelation -Head 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa').Rel 'unknown' 'no git on Windows'
}

Test-Case 'S6o the head-read script works on loose refs, packed refs and a detached HEAD (real git, Git Bash)' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'SKIP: git not found' }
    $repo = Join-Path $script:T 'hr'
    [void](New-Item -ItemType Directory -Force -Path $repo)
    $c = @('-c', 'user.name=t', '-c', 'user.email=t@t')
    & git -C $repo init -q -b main
    [IO.File]::WriteAllText((Join-Path $repo 'a'), "1`n")
    & git -C $repo add a; & git -C $repo @c commit -q -m one
    $sha = (& git -C $repo rev-parse HEAD).Trim()
    $run = {
        $o = Invoke-GitBashCapture ("export DST='" + ($repo -replace '\\', '/') + "'`n" + $WslHeadScript)
        $h = @{}
        foreach ($l in ($o.Out -split "`n")) { if ($l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() } }
        $h
    }
    $r = & $run
    Assert-Eq "$($r.head)/$($r.branch)" "$sha/main" 'loose ref'
    & git -C $repo pack-refs --all
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo '.git\refs\heads\main'))) 'the loose ref is gone'
    $r = & $run
    Assert-Eq "$($r.head)/$($r.branch)" "$sha/main" 'packed ref'
    & git -C $repo checkout -q --detach
    $r = & $run
    Assert-Eq "$($r.head)/$($r.branch)" "$sha/" 'detached HEAD'
}

Test-Case 'T1 the sync script: a dry run never reaches nix-shell, a real run does (Git Bash, git off PATH)' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    $stubDir = Join-Path $script:T 'stub'
    [void](New-Item -ItemType Directory -Force -Path $stubDir)
    [IO.File]::WriteAllText((Join-Path $stubDir 'nix-shell'), "#!/bin/sh`necho called > `"`$MARK`"`necho src=stub`n")
    $msys = { param($p) $q = $p -replace '\\', '/'; if ($q -match '^([A-Za-z]):(.*)$') { '/' + $Matches[1].ToLower() + $Matches[2] } else { $q } }
    $mark = Join-Path $script:T 'nixshell.mark'
    $pre = "chmod +x '" + (& $msys (Join-Path $stubDir 'nix-shell')) + "'`nexport PATH='" + (& $msys $stubDir) + ":/usr/bin:/bin'`nexport MARK='" + (& $msys $mark) + "' SRC=/s DST=/d`n"
    $probe = Invoke-GitBashCapture ($pre + "command -v git >/dev/null 2>&1 && echo HAVEGIT || echo NOGIT`n")
    if ($probe.Out -match 'HAVEGIT') { throw 'SKIP: git is on the minimal PATH of Git Bash here' }
    # dry run, no git: skipped, the stub is never called
    $o = Invoke-GitBashCapture ($pre + "export DRY_RUN=1`n" + $WslSyncScript)
    Assert-True ($o.Out -match 'skipped=1') "dry run skips: [$($o.Out)]"
    Assert-True (-not (Test-Path -LiteralPath $mark)) 'nix-shell was not called in a dry run'
    # real run, no git: the stub (nix-shell) is called
    $o = Invoke-GitBashCapture ($pre + $WslSyncScript)
    Assert-True (Test-Path -LiteralPath $mark) 'nix-shell was called in a real run'
    Assert-True ($o.Out -match 'src=stub') 'its output is passed through'
}

Test-Case 'S9c a chown that failed on an earlier run is repaired on the next run (no restart)' {
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false
    $script:W.OwnerHome = 'nixos'; $script:W.OwnerClone = 'nixos'
    $script:W.ChownCode = 1
    Assert-Eq (Run-Boot @{}) 1 'first run: the restart happens, the chown fails'
    Assert-Log 'step 9: chown exited 1'
    Assert-Log 'step 9: recovery:'
    # the restart already applied the new default user and the config file exists
    $script:W.ChownCode = 0
    $script:Raw.Clear()
    Assert-Eq (Run-Boot @{}) 0 'second run'
    Assert-Log 'step 9: /home/tester/.profile is not owned by tester; running chown -R'
    Assert-Log 'step 9: system layer applied; ownership of /home/tester repaired, no restart needed'
    Assert-Eq @(Find-Raw 'sw/bin/chown -R tester:users /home/tester$').Count 1 'chown ran'
    Assert-Eq @(Find-Raw '^--terminate NixOS$' | Where-Object { $_ -gt (@(Find-Raw 'sw/bin/env USER_NAME=tester')[0]) }).Count 0 'no restart'
    Assert-Eq $script:W.OwnerHome 'tester' 'owner fixed'
    # third run: everything right, no chown
    $script:Raw.Clear()
    Assert-Eq (Run-Boot @{}) 0 'third run'
    Assert-Eq @(Find-Raw 'sw/bin/chown -R').Count 0 'nothing to repair'
    Assert-Log 'no restart needed \(default user tester, app-configs-wsl.nix present, ownership correct\)'
}

Test-Case 'S9d a failing repair chown stops the run with the recovery hint' {
    Initialize-Happy
    $script:W.OwnerClone = 'nixos'
    $script:W.ChownCode = 1
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'step 9: chown exited 1'
    Assert-Log 'step 9: recovery:'
    Assert-Eq @(Find-Raw 'ops/install.sh$').Count 0 'install.sh not reached'
}

Test-Case 'S6p Get-WindowsRelation: invalid values, an absent commit and the causes (Invoke-Native stubbed)' {
    $script:NCalls = 0
    $script:NR = @{ rev = @{ Code = 0; Out = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`n"; Err = '' }; anc = @{ Code = 128; Out = ''; Err = 'fatal' }; cat = @{ Code = 128; Out = ''; Err = 'fatal' } }
    Stub 'Resolve-Program' { param([string]$Name) 'C:/g/git.exe' }
    Stub 'Invoke-Native' {
        param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory, [int]$HeartbeatSeconds)
        $script:NCalls++
        switch ($Arguments[0]) { 'rev-parse' { $script:NR.rev } 'merge-base' { $script:NR.anc } default { $script:LastCat = $Arguments; $script:NR.cat } }
    }
    $good = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    foreach ($bad in @('--output=x', '-x', 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'abc', ($good + 'g'), '', 'refs/heads/main')) {
        $r = & $RealGetWindowsRelation -Head $bad
        Assert-Eq $r.Rel 'unknown' "invalid '$bad'"
        Assert-True ($r.Why -match 'not a commit id') "cause for '$bad'"
    }
    Assert-Eq $script:NCalls 0 'Windows git is never called with an unvalidated value'
    $r = & $RealGetWindowsRelation -Head $good
    Assert-Eq $r.Rel 'diverged' 'merge-base failed and the commit is absent: diverged'
    Assert-Eq ($script:LastCat -join ' ') "cat-file -e $good^{commit}" 'the object is checked'
    $script:NR.cat = @{ Code = 1; Out = ''; Err = '' }
    Assert-Eq (& $RealGetWindowsRelation -Head $good).Rel 'diverged' 'cat-file exit 1 is absent too'
    $script:NR.cat = @{ Code = 0; Out = ''; Err = '' }
    $r = & $RealGetWindowsRelation -Head $good
    Assert-Eq $r.Rel 'unknown' 'the commit exists but merge-base failed'
    Assert-True ($r.Why -match 'git merge-base exited 128 and git cat-file exited 0') "cause: $($r.Why)"
    $script:NR.cat = @{ Code = 127; Out = ''; Err = 'unavailable' }
    Assert-Eq (& $RealGetWindowsRelation -Head $good).Rel 'unknown' 'cat-file could not run'
    $script:NR.rev = @{ Code = 128; Out = ''; Err = '' }
    $r = & $RealGetWindowsRelation -Head $good
    Assert-True ($r.Why -match 'rev-parse refs/heads/main failed in the Windows repo \(exit 128\)') 'no main'
    Stub 'Resolve-Program' { param([string]$Name) $null }
    Assert-Eq (& $RealGetWindowsRelation -Head $good).Why 'no git on Windows' 'no git'
}

Test-Case 'S6q Get-WindowsRelation against a real repo: a commit the Windows repo lacks is diverged' {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'SKIP: git not found' }
    $win = Join-Path $script:T 'wr1'; $other = Join-Path $script:T 'wr2'
    $c = @('-c', 'user.name=t', '-c', 'user.email=t@t')
    foreach ($r in @($win, $other)) { [void](New-Item -ItemType Directory -Force -Path $r); & git -C $r init -q -b main }
    [IO.File]::WriteAllText((Join-Path $win 'a'), "1`n")
    & git -C $win add a; & git -C $win @c commit -q -m one
    $first = (& git -C $win rev-parse HEAD).Trim()
    [IO.File]::WriteAllText((Join-Path $win 'a'), "2`n")
    & git -C $win @c commit -q -am two
    $second = (& git -C $win rev-parse HEAD).Trim()
    [IO.File]::WriteAllText((Join-Path $other 'z'), "x`n")
    & git -C $other add z; & git -C $other @c commit -q -m foreign
    $foreign = (& git -C $other rev-parse HEAD).Trim()
    $script:RepoRoot = $win
    Stub 'Invoke-Native' { param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory, [int]$HeartbeatSeconds) & $RealInvokeNative @PSBoundParameters }
    Stub 'Resolve-Program' { param([string]$Name) & $RealResolveProgram -Name $Name }
    Assert-Eq (& $RealGetWindowsRelation -Head $second).Rel 'same' 'same'
    Assert-Eq (& $RealGetWindowsRelation -Head $first).Rel 'behind' 'an ancestor'
    $r = & $RealGetWindowsRelation -Head $foreign
    Assert-Eq $r.Rel 'diverged' 'a commit absent from the Windows repo'
    Assert-Eq $r.Src $second 'the Windows main is reported'
}

Test-Case 'S6r the head-read script compares packed-ref names exactly, and a bad HEAD value never reaches Windows git' {
    if (-not (Get-GitBash)) { throw 'SKIP: Git Bash not found' }
    $dst = Join-Path $script:T 'hr2'
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $dst '.git'))
    $one = '1' * 40; $two = '2' * 40; $three = '3' * 40
    [IO.File]::WriteAllText((Join-Path $dst '.git\packed-refs'), "# pack-refs with: peeled fully-peeled sorted`n$one refs/heads/aXb`n$two refs/heads/a.b`n^$three`n$three refs/heads/we[ir]d+`n")
    $run = {
        param($headFile)
        [IO.File]::WriteAllText((Join-Path $dst '.git\HEAD'), $headFile)
        $o = Invoke-GitBashCapture ("export DST='" + ($dst -replace '\\', '/') + "'`n" + $WslHeadScript)
        $h = @{}
        foreach ($l in ($o.Out -split "`n")) { if ($l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() } }
        $h
    }
    $r = & $run "ref: refs/heads/a.b`n"
    Assert-Eq $r.head $two 'a.b is not a regex: aXb must not match'
    Assert-Eq $r.branch 'a.b' 'branch'
    $r = & $run "ref: refs/heads/we[ir]d+`n"
    Assert-Eq $r.head $three 'regex characters in the ref name are literal'
    $r = & $run "ref: refs/heads/missing`n"
    Assert-Eq $r.head '' 'an unknown ref gives no head'
    # a HEAD value that is not a commit id: the dry run stops before Windows git
    Reset-Stubs; Initialize-Happy
    $script:W.SyncSkipped = $true
    $script:W.HeadSha = '--output=x'
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'dry run'
    Assert-Eq @(Get-SeamCalls 'Get-WindowsRelation').Count 0 'Windows git was not asked'
    Assert-Log 'step 6: the clone cannot be compared \(the HEAD value read from the distro is not a commit id; the distro has no git either\)'
}

Test-Case 'S9e a partly finished chown (only the clone is wrong) is repaired' {
    Initialize-Happy
    $script:W.OwnerClone = 'nixos'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step 9: /home/tester/app-configs/x is not owned by tester; running chown -R'
    Assert-Eq @(Find-Raw 'sw/bin/chown -R tester:users /home/tester$').Count 1 'chown ran'
    Assert-Eq $script:W.OwnerClone 'tester' 'repaired'
    $f = @($script:Raw | Where-Object { $_.A -contains '!' })
    Assert-Eq $f.Count 1 'one find'
    Assert-Eq ($f[0].A -join ' ') '-d NixOS -u root --exec /run/current-system/sw/bin/find /home/tester -xdev ! -user tester -print -quit' 'find command, as root'
    Assert-Eq $f[0].Timeout 300 'bounded'
    Assert-Announced $f[0] 'step 9: checking that everything under /home/tester is owned by tester \(a moment on a big home\)' 'announced'
}

Test-Case 'S9f an ownership check that cannot run repairs by chown' {
    Initialize-Happy
    $script:W.FindCode = 1
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step 9: the ownership of /home/tester could not be verified \(find exit 1\); running chown -R'
}

Test-Case 'A1 the recovery advice is one pasteable line that works on NixOS-WSL: -- sh -lc, shell-safe paths' {
    Initialize-Happy
    $script:W.Rel = 'other'; $script:W.HeadSha = ('b' * 40)
    Assert-Eq (Run-Boot @{}) 1 'exit'
    $m = [regex]::Match((Get-Log), "wsl -d NixOS -u root -- sh -lc '([^']*)'")
    Assert-True $m.Success 'the advice has the form wsl -d NixOS -u root -- sh -lc ''<command>'''
    Assert-Eq $m.Groups[1].Value 'mv /home/tester/app-configs /home/tester/app-configs.old-20260101T000000Z' 'the inner command'
    # the inner command survives PowerShell and the default shell unquoted: only safe characters
    Assert-True ($m.Groups[1].Value -match '^mv [A-Za-z0-9_./-]+ [A-Za-z0-9_./-]+$') 'no space, quote or shell metacharacter in either path'
    Assert-True (-not ((Get-Log) -match '--exec (mv|rm)')) 'no --exec with a bare coreutil'
}

Test-Case 'A2 every internal distro call names its program by absolute path (no bare-PATH lookup)' {
    Initialize-Happy
    $script:W.User = 'nixos'; $script:W.HasCfg = $false; $script:W.HasClone = $false; $script:W.HasSnap = $false
    $script:W.OwnerHome = 'nixos'
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $global = @('--version', '--list', '--update', '--install', '--import', '--terminate', '--export', '--status', '--shutdown')
    $n = 0
    foreach ($c in $script:Raw) {
        if ($global -contains $c.A[0]) { continue }
        $x = [array]::IndexOf($c.A, '--exec')
        Assert-True ($x -ge 0) "has --exec: $($c.A -join ' ')"
        Assert-True ($c.A[$x + 1].StartsWith('/')) "the program after --exec is an absolute path: $($c.A -join ' ')"
        $n++
    }
    Assert-True ($n -ge 10) "checked $n distro calls"
}

Test-Case 'A3 no message in the script advises --exec with a relative program' {
    $text = [IO.File]::ReadAllText($ScriptPath)
    foreach ($m in [regex]::Matches($text, '(?i)\bwsl\b[^\r\n]*?--exec\s+(\S+)')) {
        Assert-True ($m.Groups[1].Value.StartsWith('/') -or $m.Groups[1].Value.StartsWith('$')) "advised --exec program must be absolute: $($m.Value)"
    }
    Assert-True (-not ($text -match 'wsl [^\r\n]*--exec (mv|rm|ls|cp|cat)\b')) 'no --exec coreutil advice'
}

function Get-WslProgramViolations {
    param($Ast)
    # Every Invoke-Wsl / Test-InWsl call with an -Arguments @(...) list (and no -Global) must
    # start that list with an absolute program: a '/...' literal or "$Sw/...". Returns
    # @{Checked; Violations}.
    $checked = 0
    $viol = @()
    $calls = $Ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and @('Invoke-Wsl', 'Test-InWsl') -contains $n.GetCommandName() }, $true)
    foreach ($c in $calls) {
        $els = @($c.CommandElements)
        $isGlobal = @($els | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'Global' }).Count -gt 0
        if ($isGlobal) { continue }
        for ($i = 0; $i -lt $els.Count - 1; $i++) {
            if ($els[$i] -is [Management.Automation.Language.CommandParameterAst] -and $els[$i].ParameterName -eq 'Arguments' -and $els[$i + 1] -is [Management.Automation.Language.ArrayExpressionAst]) {
                $stmt = $els[$i + 1].SubExpression.Statements[0]
                $first = $stmt.PipelineElements[0].Expression
                if ($first -is [Management.Automation.Language.ArrayLiteralAst]) { $first = $first.Elements[0] }
                $checked++
                $ok = $false
                if ($first -is [Management.Automation.Language.StringConstantExpressionAst] -and $first.Value.StartsWith('/')) { $ok = $true }
                if ($first -is [Management.Automation.Language.ExpandableStringExpressionAst] -and $first.Extent.Text.StartsWith('"$Sw/')) { $ok = $true }
                if (-not $ok) { $viol += "line $($c.Extent.StartLineNumber): $($first.Extent.Text)" }
            }
        }
    }
    return @{ Checked = $checked; Violations = $viol }
}

Test-Case 'A2s every Invoke-Wsl and Test-InWsl argument list in the script starts with an absolute program (static)' {
    $tokens = $null; $errs = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errs)
    $r = Get-WslProgramViolations $ast
    Assert-True ($r.Checked -ge 15) "walked $($r.Checked) argument lists"
    Assert-Eq $r.Violations.Count 0 "relative program in: $($r.Violations -join '; ')"
    # the mutants: a relative find, and a relative test, must be caught by this very check
    $text = [IO.File]::ReadAllText($ScriptPath)
    foreach ($mut in @(@('"$Sw/find"', "'find'"), @('@("$Sw/test", ''-d'', "$clone/.git")', '@(''test'', ''-d'', "$clone/.git")'))) {
        Assert-True ($text.Contains($mut[0])) "mutation target exists: $($mut[0])"
        $t2 = $null; $e2 = $null
        $ast2 = [Management.Automation.Language.Parser]::ParseInput($text.Replace($mut[0], $mut[1]), [ref]$t2, [ref]$e2)
        $r2 = Get-WslProgramViolations $ast2
        Assert-True ($r2.Violations.Count -ge 1) "the mutant $($mut[1]) is flagged"
    }
}

Test-Case 'N1b Test-CommitId rejects a trailing newline' {
    $a = 'a' * 40
    Assert-True (Test-CommitId $a) 'a plain commit id'
    Assert-True (-not (Test-CommitId ($a + "`n"))) 'a trailing newline (the dollar anchor would accept it)'
    Assert-True (-not (Test-CommitId ($a + "`r`n"))) 'a trailing CRLF'
    Assert-True (Test-CommitId ('a' * 64)) 'a sha256 id'
}

Test-Case 'R3a step 9 failure hints depend on the system-setup exit code' {
    foreach ($code in @(4, 2)) {
        Reset-Stubs; Initialize-Happy
        $script:W.SysSetupCode = $code
        Assert-Eq (Run-Boot @{}) 1 "exit $code"
        Assert-Log "step 9: system-setup.sh exited ${code}: the new generation is \(at least partly\) activated \(exit 4: some units failed; exit 2: the activation script failed after the profile moved\) and the new /etc/nixos files are kept because they match the running system\."
        Assert-Log 'Check the failed units: wsl -d NixOS -u root -- sh -lc ''systemctl --failed''; roll back only if the system is broken \(the rollback command and the restore-from-backup hint are printed in its output above\); re-run this script once the cause is fixed'
        Assert-True (-not ((Get-Log) -match 'step 9: recovery:')) 'the restore-from-export hint is for the wrong-user paths only'
        Assert-True (-not ((Get-Log) -match 'failed before activation')) "exit $code is not a before-activation failure"
        Assert-Eq @(Find-Raw 'ops/install.sh$').Count 0 'install.sh not reached'
    }
    foreach ($code in @(1, 3, 100, 130, 126, 127)) {
        Reset-Stubs; Initialize-Happy
        $script:W.SysSetupCode = $code
        Assert-Eq (Run-Boot @{}) 1 "exit $code"
        Assert-Log "step 9: system-setup.sh exited ${code}: the outcome is in its output above\. If it shows 'a nixos-rebuild switch had started', the new generation may be active \(older versions of system-setup.sh exit 1 for an activated switch with failed units and then restore the files\)\. Check the failed units: wsl -d NixOS -u root -- sh -lc 'systemctl --failed'; fix the cause and re-run this script"
        Assert-True (-not ((Get-Log) -match 'failed before activation|at least partly|are kept')) "nothing is claimed as fact for exit $code"
        Assert-True (-not ((Get-Log) -match 'step 9: recovery:')) 'no restore-from-export hint'
        Assert-Eq @(Find-Raw 'ops/install.sh$').Count 0 'install.sh not reached'
    }
}
Test-Case 'R3b step 12 announces prompts and silent phases; its failure line is accurate for re-runs' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Announced (Get-RawCall 'ops/install.sh$') 'step 12: running ops/install.sh as tester \(20 minutes or more\); it is interactive: answer the profile and selection prompts that appear \(none if a selection is already saved\); it can also stay silent for minutes, for example during home-manager switch, which is not a freeze' 'install.sh'
    Reset-Stubs; Initialize-Happy
    $script:W.InstallCode = 3
    Assert-Eq (Run-Boot @{}) 1 'failure'
    Assert-Log 'ops/install.sh exited 3'
    Assert-Log 'on a re-run the one-time steps that finished \(download, import, report, export\) are skipped, and the idempotent steps 6 and 9 run again; fix the cause, then run this script again'
    Assert-True (-not ((Get-Log) -match 'finished steps are skipped on a re-run:')) 'the old wording is gone'
    $beats = @($script:HostOut | Where-Object { $_ -match 'still running' })
    Assert-Eq $beats.Count 0 'no heartbeat lines around the interactive step'
}

function Get-InstallerCalls {
    return @($script:Calls | Where-Object { $_.Name -eq 'Invoke-HooksInstaller' })
}

Test-Case 'H1 installer present and --check exits 0: hooks intact, nothing is installed' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(0)
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'exit (tools only: the Windows report also reads core.hooksPath)'
    Assert-Log 'step C: git hooks intact \(ops/install-git-hooks.sh --check\)'
    $c = @(Get-InstallerCalls)
    Assert-Eq $c.Count 1 'one call'
    Assert-Eq $c[0].Args['Mode'] 'check' 'check only'
    Assert-Eq $c[0].Args['Bash'] 'C:/Git/bin/bash.exe' 'Git for Windows bash'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'lefthook install is not used'
    Assert-Eq @(Get-SeamCalls 'Get-HooksPath').Count 0 'core.hooksPath is left to the installer'
}

Test-Case 'H2 --check exits 1: install, then --check again' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1, 0)
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $c = @(Get-InstallerCalls)
    Assert-Eq (($c | ForEach-Object { $_.Args['Mode'] }) -join ',') 'check,install,check' 'order'
    Assert-Announced $c[1] 'step C: installing the git hooks with ops/install-git-hooks.sh \(a few seconds\)' 'install announced'
    Assert-Announced $c[0] 'step C: checking the git hooks with ops/install-git-hooks.sh --check' 'first check announced'
    Assert-Announced $c[2] 'step C: checking the git hooks again' 'second check announced'
    Assert-Log 'step C: git hooks installed and intact'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'lefthook install is not used'
}

Test-Case 'H3 the installer fails: output and a clear warning, the run continues, a closing notice ends it' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1); $script:InstallCode = 1
    Assert-Eq (Run-Boot @{}) 0 'the run still succeeds: hooks are not needed to provision WSL'
    Assert-Log 'step C: installer: install out'
    Assert-Log 'step C: WARNING: git hooks are NOT installed on Windows \(ops/install-git-hooks.sh exited 1\); commits from this clone will be blocked or unguarded until that is fixed\. ops/install-git-hooks.sh refuses a linked worktree, a foreign core.hooksPath, a missing git or lefthook, git older than 2.31, or a HEAD without ops/githooks; read its output above, fix that, then re-run'
    Assert-Eq @(Get-InstallerCalls).Count 2 'no second --check after a failed install'
    Assert-Log 'step 0: no reboot pending'
    Assert-Log 'step 12: running ops/install.sh'
    Assert-True ($script:LogLines[$script:LogLines.Count - 1] -match '^\[bootstrap\] NOTICE: git hooks are NOT installed on Windows \(ops/install-git-hooks.sh exited 1\); commits from this clone will be blocked or unguarded until that is fixed \(see the step C warning above\)$') 'the last line of the run is the closing notice'
}

Test-Case 'H4 --check still failing after the install, or an unexpected --check code: warning and continue' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1, 1)
    Assert-Eq (Run-Boot @{}) 0 'still not intact'
    Assert-Log 'WARNING: git hooks are NOT installed on Windows \(the installer ran but --check still exits 1\)'
    Assert-True ($script:LogLines[$script:LogLines.Count - 1] -match 'NOTICE: git hooks are NOT installed on Windows') 'closing notice'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(127)
    Assert-Eq (Run-Boot @{}) 0 'check 127'
    Assert-Log 'WARNING: git hooks are NOT installed on Windows \(ops/install-git-hooks.sh --check exited 127, expected 0 or 1\)'
    Assert-Eq @(Get-InstallerCalls).Count 1 'nothing installed on an unexpected code'
    Assert-Log 'step 12: running ops/install.sh'
}

Test-Case 'H13 -ToolsOnly and dry runs: the warning does not change the exit code; healthy runs have no notice' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1); $script:InstallCode = 1
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'tools only'
    Assert-True ($script:LogLines[$script:LogLines.Count - 1] -match 'NOTICE: git hooks are NOT installed') 'closing notice after -ToolsOnly'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1)
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'dry run with hooks not intact'
    Assert-True (-not ((Get-Log) -match 'NOTICE')) 'a dry run that only reports "would run" has no notice'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(0)
    Assert-Eq (Run-Boot @{}) 0 'healthy'
    Assert-True (-not ((Get-Log) -match 'NOTICE|WARNING: git hooks')) 'no notice when the hooks are intact'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:InstallerBash = $null
    Assert-Eq (Run-Boot @{}) 3 'no Git bash keeps exit 3'
    Assert-True (-not ((Get-Log) -match 'NOTICE')) 'no notice: the run stopped on a missing precondition'
}

Test-Case 'H14 installer output is shown even on exit 0, and a Start-Wait precedes each --check' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(0); $script:CheckOut = 'warning: the pre-push hook is stale'
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'exit'
    Assert-Log 'step C: installer: warning: the pre-push hook is stale'
    Assert-Log 'step C: git hooks intact'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(0); $script:CheckOut = ''
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'exit with no output'
    Assert-True (-not ((Get-Log) -match 'step C: installer:')) 'nothing is printed when there is no output'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1, 0)
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'install flow'
    $c = @(Get-InstallerCalls)
    Assert-Announced $c[0] 'step C: checking the git hooks with ops/install-git-hooks.sh --check \(a few seconds\)' 'first check'
    Assert-Announced $c[2] 'step C: checking the git hooks again with ops/install-git-hooks.sh --check \(a few seconds\)' 'second check'
}

Test-Case 'H5 no Git for Windows bash: a clear message, exit 3, nothing is run' {
    Initialize-Happy
    $script:Installer = $true; $script:InstallerBash = $null
    Assert-Eq (Run-Boot @{}) 3 'exit'
    Assert-Log 'step C: Git for Windows bash was not found \(the WindowsApps and WSL bash are never used\); install Git for Windows, then re-run'
    Assert-Eq @(Get-InstallerCalls).Count 0 'no installer call'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'no lefthook fallback'
}

Test-Case 'H6 installer absent (today''s main): the lefthook path is unchanged' {
    Initialize-Happy
    $script:Installer = $false; $script:HooksOk = $false
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 1 'lefthook install runs as before'
    Assert-Eq @(Get-InstallerCalls).Count 0 'the installer is not touched'
    Assert-Eq @(Get-SeamCalls 'Resolve-GitBash').Count 0 'no bash lookup'
}

Test-Case 'H7 dry run: only --check, and what a real run would do' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1)
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; DryRun = $true }) 0 'exit'
    Assert-Eq (($script:Calls | Where-Object { $_.Name -eq 'Invoke-HooksInstaller' } | ForEach-Object { $_.Args['Mode'] }) -join ',') 'check' 'check only'
    Assert-Log '\[dry-run\] step C: git hooks are not intact \(--check exit 1\); would run: bash ops/install-git-hooks.sh \(Git for Windows bash: C:/Git/bin/bash.exe\), then --check again'
    Reset-Stubs; Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(0)
    Assert-Eq (Run-Boot @{ ToolsOnly = $true; DryRun = $true }) 0 'intact'
    Assert-Log '\[dry-run\] step C: git hooks intact'
}

Test-Case 'H8 environment variables the hooks refuse are named in a warning, not a failure' {
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(0); $script:HookEnv = @('LEFTHOOK', 'SKIP_HOOKS')
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Log 'step C: warning: LEFTHOOK is set in your environment; the repo''s git hooks refuse it'
    Assert-Log 'step C: warning: SKIP_HOOKS is set in your environment'
    $saved = @{}
    foreach ($n in @('LEFTHOOK', 'LEFTHOOK_VERBOSE', 'LEFTHOOK_QUIET', 'LEFTHOOK_EXCLUDE', 'SKIP_HOOKS')) { $saved[$n] = [Environment]::GetEnvironmentVariable($n); [Environment]::SetEnvironmentVariable($n, '1') }
    try {
        $got = @(& $RealGetHookEnvOverrides | Sort-Object)
        Assert-Eq ($got -join ',') 'LEFTHOOK,LEFTHOOK_EXCLUDE,SKIP_HOOKS' 'LEFTHOOK_VERBOSE and LEFTHOOK_QUIET are allowed'
    } finally {
        foreach ($n in $saved.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n]) }
    }
}

Test-Case 'H9 the script never uninstalls lefthook or unsets the hooks path' {
    $text = [IO.File]::ReadAllText($ScriptPath)
    Assert-True (-not ($text -match '(?i)lefthook\s+uninstall')) 'no lefthook uninstall anywhere'
    Assert-True (-not ($text -match '(?i)core\.hooksPath\s+--unset|--unset\s+core\.hooksPath|config\s+--unset')) 'no unset of the hooks path'
    Assert-True (-not ($text -match 'Remove-Item[^\r\n]*(hooks|app-configs-hooks)')) 'nothing removes the hooks directory'
    Initialize-Happy
    $script:Installer = $true; $script:CheckSeq = @(1, 0)
    Assert-Eq (Run-Boot @{}) 0 'exit'
    Assert-Eq @(Get-SeamCalls 'Invoke-Lefthook').Count 0 'lefthook is not run with the installer present'
}

Test-Case 'H10 Resolve-GitBash derives bash from the git install and never uses the WSL launcher' {
    $root = Join-Path $script:T 'gfw'
    $saved = $env:ProgramFiles
    $env:ProgramFiles = Join-Path $script:T 'no-programfiles'
    try {
        # (a) cmd\git.exe next to bin\bash.exe
        foreach ($p in @('Git\cmd', 'Git\bin')) { [void](New-Item -ItemType Directory -Force -Path (Join-Path $root $p)) }
        [IO.File]::WriteAllText((Join-Path $root 'Git\cmd\git.exe'), 'x'); [IO.File]::WriteAllText((Join-Path $root 'Git\bin\bash.exe'), 'x')
        Stub 'Resolve-Program' { param([string]$Name) if ($Name -eq 'git') { Join-Path $root 'Git\cmd\git.exe' } else { 'C:\Windows\System32\bash.exe' } }
        Assert-Eq (& $RealResolveGitBash) (Join-Path $root 'Git\bin\bash.exe') 'bin\bash.exe'
        Assert-Eq @($script:Calls | Where-Object { $_.Name -eq 'Resolve-Program' -and $_.Args['Name'] -eq 'bash' }).Count 0 'the PATH bash is never resolved'
        # (b) mingw64\bin\git.exe, bash under usr\bin
        foreach ($p in @('G2\mingw64\bin', 'G2\usr\bin')) { [void](New-Item -ItemType Directory -Force -Path (Join-Path $root $p)) }
        [IO.File]::WriteAllText((Join-Path $root 'G2\mingw64\bin\git.exe'), 'x'); [IO.File]::WriteAllText((Join-Path $root 'G2\usr\bin\bash.exe'), 'x')
        Stub 'Resolve-Program' { param([string]$Name) Join-Path $root 'G2\mingw64\bin\git.exe' }
        Assert-True ($null -eq (& $RealResolveGitBash)) 'usr\bin\bash.exe alone is never used (no sed, dirname or mktemp without a login shell)'
        [void](New-Item -ItemType Directory -Force -Path (Join-Path $root 'G2\bin')); [IO.File]::WriteAllText((Join-Path $root 'G2\bin\bash.exe'), 'x')
        Assert-Eq (& $RealResolveGitBash) (Join-Path $root 'G2\bin\bash.exe') 'git under mingw64\bin: the install root bin\bash.exe'
        # (c) a git under WindowsApps (or System32) is never accepted
        foreach ($p in @('WindowsApps\G3\cmd', 'WindowsApps\G3\bin')) { [void](New-Item -ItemType Directory -Force -Path (Join-Path $root $p)) }
        [IO.File]::WriteAllText((Join-Path $root 'WindowsApps\G3\cmd\git.exe'), 'x'); [IO.File]::WriteAllText((Join-Path $root 'WindowsApps\G3\bin\bash.exe'), 'x')
        Stub 'Resolve-Program' { param([string]$Name) Join-Path $root 'WindowsApps\G3\cmd\git.exe' }
        Assert-True ($null -eq (& $RealResolveGitBash)) 'a WindowsApps bash is rejected'
        # (d) no git at all
        Stub 'Resolve-Program' { param([string]$Name) $null }
        Assert-True ($null -eq (& $RealResolveGitBash)) 'no git, no bash'
        # (e) the ProgramFiles install is the fallback
        $env:ProgramFiles = Join-Path $root 'PF'
        [void](New-Item -ItemType Directory -Force -Path (Join-Path $root 'PF\Git\bin')); [IO.File]::WriteAllText((Join-Path $root 'PF\Git\bin\bash.exe'), 'x')
        Assert-Eq (& $RealResolveGitBash) (Join-Path $root 'PF\Git\bin\bash.exe') 'ProgramFiles\Git fallback'
    } finally { $env:ProgramFiles = $saved }
}

Test-Case 'H11 the installer runs with the resolved bash, from the repo root, with the script as a relative path' {
    $script:NativeCalls = @()
    Stub 'Invoke-Native' {
        param([string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory, [int]$HeartbeatSeconds)
        $script:NativeCalls += , @{ Exe = $ExePath; Args = $Arguments; Wd = $WorkingDirectory; Timeout = $TimeoutSeconds }
        @{ Code = 0; Out = ''; Err = '' }
    }
    [void](& $RealInvokeHooksInstaller -Bash 'C:/Git/bin/bash.exe' -Mode 'check')
    [void](& $RealInvokeHooksInstaller -Bash 'C:/Git/bin/bash.exe' -Mode 'install')
    Assert-Eq (($script:NativeCalls | ForEach-Object { $_.Exe }) -join ',') 'C:/Git/bin/bash.exe,C:/Git/bin/bash.exe' 'never a bare bash'
    Assert-Eq ($script:NativeCalls[0].Args -join ' ') 'ops/install-git-hooks.sh --check' 'check args'
    Assert-Eq ($script:NativeCalls[1].Args -join ' ') 'ops/install-git-hooks.sh' 'install args'
    Assert-Eq $script:NativeCalls[0].Wd $script:RepoRoot 'cwd is the repo root'
    Assert-Eq $script:NativeCalls[0].Timeout 300 'bounded'
}

Test-Case 'H12 a linked worktree (.git is a file) never reaches the installer' {
    Initialize-Happy
    $script:Installer = $true
    Stub 'Test-RepoGitDir' { $false }
    Assert-Eq (Run-Boot @{ ToolsOnly = $true }) 0 'tools only'
    Assert-Log 'hooks skipped'
    Assert-Eq @(Get-InstallerCalls).Count 0 'no installer call'
}

Test-Case 'B1 the diverged-clone advice tells how to get personal.yaml back into the new clone (default user, fish-safe)' {
    Initialize-Happy
    $script:W.Rel = 'other'; $script:W.HeadSha = ('b' * 40)
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'If the gitignored home/.chezmoidata/personal.yaml exists in the moved folder \(it stays there\), after the re-run copy it into the new clone as the default user, so the new folder and file are yours \(this overwrites the one install.sh seeded from the example\): wsl -d NixOS -- sh -lc ''test -f /home/tester/app-configs.old-20260101T000000Z/home/.chezmoidata/personal.yaml && mkdir -p /home/tester/app-configs/home/.chezmoidata && cp -p /home/tester/app-configs.old-20260101T000000Z/home/.chezmoidata/personal.yaml /home/tester/app-configs/home/.chezmoidata/personal.yaml'', then run this script again so install.sh applies it'
    $m = [regex]::Match((Get-Log), "wsl -d NixOS -- sh -lc '([^']*)'")
    Assert-True $m.Success 'the default-user form: wsl -d NixOS -- sh -lc ''...'''
    $p = '[A-Za-z0-9_./-]+'
    Assert-True ($m.Groups[1].Value -match "^test -f $p && mkdir -p $p && cp -p $p $p$") 'only safe characters: no dollar sign, quote or backtick (the default user''s shell is fish)'
    Assert-True (-not ($m.Value -match '-u root')) 'not run as root, so nothing in the new clone ends up root-owned'
    Assert-True (-not ((Get-Log) -match 'personal\.yaml:|cat .*personal')) 'only the name is printed, never contents'
}
Test-Case 'F14 non-x64 Windows is refused with exit 1' {
    Initialize-Happy
    Stub 'Get-OsArch' { 'Arm64' }
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log "architecture is 'Arm64'"
    Stub 'Get-OsArch' { 'unavailable: nope' }
    Assert-Eq (Run-Boot @{ DryRun = $true }) 1 'unknown architecture'
    Assert-Eq @(Find-Raw '^-d').Count 0 'no distro call'
    Assert-Eq (Get-LadItems).Count 0 'nothing written'
}

Test-Case 'T3 UTF-16 with NULs, a BOM and localized output are parsed' {
    $u16 = { param($s) (($s.ToCharArray() | ForEach-Object { "$_" + [char]0 }) -join '') }
    $bom = [string][char]0xFEFF
    $script:Canned = $null
    Stub 'Invoke-WslRaw' {
        param([string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds)
        @{ Code = 0; Out = $script:Canned }
    }
    $script:Canned = & $u16 "Version de WSL : 2.6.1.0`r`nVersion du noyau : 6.6"
    Assert-Eq (Get-WslVersion).Version '2.6.1.0' 'French, UTF-16'
    $script:Canned = $bom + "WSL-Version: 2.4.4`r`nKernelversion: 6.6"
    Assert-Eq (Get-WslVersion).Version '2.4.4' 'German, BOM'
    $script:Canned = & $u16 "$bom$bom`r`n"
    Assert-True ($null -eq (Get-WslVersion).Version) 'no version found stays unknown'
    $script:Canned = & $u16 ($bom + "Ubuntu`r`nNixOS`r`n`r`n")
    Assert-True ((Get-DistroList) -contains 'NixOS') 'distro list from UTF-16 with BOM and CRLF'
    $script:Canned = "NixOS-old`r`nnixos2"
    Assert-True ((Get-DistroList) -notcontains 'NixOS') 'exact match only'
    $r = Invoke-Wsl -Global -Arguments @('--version')
    Assert-True (-not $r.Out.Contains([string][char]0)) 'NULs stripped'
}

Test-Case 'T4a the before-setup report failing -> 1, nothing exported' {
    Initialize-Happy
    $script:W.HasSnap = $false
    $script:W.ReportCode = 1
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Log 'before-setup WSL report failed'
    Assert-Eq @(Find-Raw '^--export').Count 0 'no export'
}

Test-Case 'T4b -Report with a failed WSL capture warns and still writes windows.txt' {
    Initialize-Happy
    $script:W.ReportCode = 1
    Assert-Eq (Run-Boot @{ Report = 'x1' }) 0 'exit'
    Assert-Log 'warning: WSL report \(x1\) not written'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:State 'host-snapshots\20260101T000000Z-x1\windows.txt')) 'windows.txt'
    $script:W.FactsCode = 1
    $script:Raw.Clear()
    Assert-Eq (Run-Boot @{ Report = 'x2' }) 0 'exit, distro unreachable'
    Assert-Eq @(Find-Raw 'app-configs-report-').Count 0 'no report capture without default user facts'
}

Test-Case 'T4c Get-RestorePoints unavailable: nothing reused, confirmation fails -> 1' {
    Initialize-NotInstalled
    $script:Elev = $true
    Stub 'Get-RestorePoints' { 'unavailable: needs elevation' }
    Assert-Eq (Run-Boot @{}) 1 'exit'
    Assert-Eq @(Get-SeamCalls 'New-RestorePoint').Count 1 'tried to create one'
    Assert-Log 'no restore point newer than this run'
    Assert-Eq @(Find-Raw 'install').Count 0 'no install'
    $d = @(Get-ChildItem -LiteralPath (Join-Path $script:State 'host-snapshots') -Directory)
    $t = [IO.File]::ReadAllText((Join-Path $d[0].FullName 'windows.txt'))
    Assert-True ($t -match "(?s)== system-restore ==\nunavailable: needs elevation") 'report records unavailable'
}

Test-Case 'F6 WSL scripts use mktemp, quoted expansions and a cleanup trap' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{}) 0 'exit'
    $c = @(Get-ScriptCalls 'facts')
    $sh = $c[0].A[([array]::IndexOf($c[0].A, '-c') + 1)]
    Assert-True ($sh.Contains('f=$(mktemp /tmp/app-configs-facts-XXXXXX) || exit 1')) 'mktemp'
    Assert-True ($sh.Contains('trap ''rm -f "$f"'' EXIT')) 'trap'
    Assert-True ($sh.Contains('printf %s "$b" | base64 -d > "$f" && bash -l "$f" "$@" </dev/null')) 'quoted'
    Assert-True ($sh.StartsWith('PATH=/run/current-system/sw/bin:$PATH;')) 'explicit PATH'
}

# ---------------------------------------------------------------- step S (-ClaudeStatusLine, ADR-0016)

$SlTemplate = '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh","padding":2,"refreshInterval":5},"model":"opus","hooks":{"x":1}}'
$SlScriptText = "#!/usr/bin/env bash`necho statusline`n"
$SlJqFound = [bool](& $RealResolveProgram 'jq')
# CRLF, an old statusLine with an extra key, a non-ASCII escape, a big integer and 1.0.
$SlOriginal = "{`r`n  `"theme`": `"dark`",`r`n  `"statusLine`": {`"type`":`"command`",`"command`":`"old.sh`",`"hideX`":true},`r`n  `"name`": `"J\u00f6rg`", `"big`": 12345678901234567890, `"one`": 1.0,`r`n  `"env`": {`"A`":`"1`"}`r`n}`r`n"

function Get-TreeHashes {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    return @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Sort-Object FullName | ForEach-Object { "$($_.FullName)|$((Get-FileHash -LiteralPath $_.FullName).Hash)" })
}

# Suite guard: the real profile's settings.json and statusline.sh, and the real backup root, must
# be the same after the suite as now.
$RealUserProfile = $env:USERPROFILE
# Only the two named files are looked at (never enumerate the real .claude: it holds credentials).
function Get-FileState {
    param([string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'absent' }
        return (Get-FileHash -LiteralPath $Path).Hash
    } catch {
        return 'unreadable'
    }
}
$SlGuardBefore = @((Get-FileState (Join-Path $RealUserProfile '.claude\settings.json')), (Get-FileState (Join-Path $RealUserProfile '.claude\statusline.sh')))
$SlGuardStateBefore = Test-Path -LiteralPath (Join-Path $OrigLocalAppData 'app-configs\claude')

function Initialize-SL {
    param($Settings = $SlOriginal)
    Initialize-Happy
    $script:SlUP = Join-Path $script:T 'up'
    $script:SlCD = Join-Path $script:SlUP '.claude'
    [void](New-Item -ItemType Directory -Force -Path $script:SlCD)
    $env:USERPROFILE = $script:SlUP
    $script:SlS = Join-Path $script:SlCD 'settings.json'
    $script:SlP = Join-Path $script:SlCD 'statusline.sh'
    $script:SlB = Join-Path (Join-Path $script:State 'claude') "20260101T000000Z-$PID"
    $script:SlT = Join-Path $script:RepoRoot 'home\.chezmoitemplates\claude\settings.json'
    $script:SlSrc = Join-Path $script:RepoRoot 'home\dot_claude\executable_statusline.sh'
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:SlT))
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:SlSrc))
    [IO.File]::WriteAllText($script:SlT, $SlTemplate)
    [IO.File]::WriteAllText($script:SlSrc, $SlScriptText)
    if ($null -ne $Settings) { [IO.File]::WriteAllText($script:SlS, $Settings) }
    $script:SlCfg = $null
    $script:SlHome = $script:SlUP
    $script:SlJqV = 'jq-1.8.2'
    $script:SlRender = @{ Code = 0; Out = 'row'; Err = '' }
    $script:SlRenderCalls = New-Object 'System.Collections.Generic.List[object]'
    $script:SlBackupAtMerge = $null
    Stub 'Get-EnvScopes' { param([string]$Name) @{ Process = $(if ($Name -eq 'CLAUDE_CONFIG_DIR') { $script:SlCfg } else { $null }); User = $null; Machine = $null } }
    Stub 'Get-GitBashHome' { param([string]$Bash) $script:SlHome }
    Stub 'Get-ToolVersion' { param([string]$Name, [string[]]$VersionArgs) $script:SlJqV }
    Stub 'Get-Sha256' $RealGetSha256
    Stub 'Resolve-Program' $RealResolveProgram
    Stub 'Invoke-Native' $RealInvokeNative
    Stub 'Get-TemplateStatusLine' $RealGetTemplateStatusLine
    Stub 'Invoke-Jq' {
        param([string[]]$Arguments)
        if ($Arguments -contains '--binary' -and $null -eq $script:SlBackupAtMerge) {
            $script:SlBackupAtMerge = (Test-Path -LiteralPath (Join-Path $script:SlB 'settings.json'))
        }
        & $RealInvokeJq @PSBoundParameters
    }
    Stub 'Invoke-StatusLineRender' {
        param([string]$Bash, [string]$PayloadPath)
        $script:SlRenderCalls.Add(@{ Bash = $Bash; Payload = $PayloadPath })
        $script:SlRender
    }
}

function Test-SL {
    param([string]$Name, [scriptblock]$Body, [switch]$NeedsJq)
    $sb = {
        $savedUP = $env:USERPROFILE
        try {
            if ($NeedsJq -and -not $SlJqFound) { throw 'SKIP: jq is not on PATH' }
            & $Body
        } finally {
            $env:USERPROFILE = $savedUP
        }
    }.GetNewClosure()
    Test-Case $Name $sb
}

# 0 when statusLine equals the template's and every other key equals the original's by value.
function Test-SlMerged {
    param([string]$Original)
    $o = Join-Path $script:T 'orig.json'
    [IO.File]::WriteAllText($o, $Original)
    $r = & $RealInvokeJq @('-e', '--slurpfile', 'o', $o, '--slurpfile', 't', $script:SlT, '(.statusLine == $t[0].statusLine) and ((del(.statusLine)) == ($o[0] | del(.statusLine)))', $script:SlS)
    return $r.Code
}

Test-SL 'SL1 -ClaudeStatusLine cannot combine with another mode -> 2, nothing called' {
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; ToolsOnly = $true }) 2 'tools-only'
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; Export = 'a' }) 2 'export'
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; Report = 'a' }) 2 'report'
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; EnableSystemRestore = $true }) 2 'restore'
    Assert-Eq $script:Calls.Count 0 'no seam called'
}

Test-SL 'SL2 refusals write nothing: elevated, CLAUDE_CONFIG_DIR, Git Bash home mismatch, no Git Bash' {
    Initialize-SL
    $before = @(Get-TreeHashes $script:T)
    $script:Elev = $true
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 'elevated'
    $script:Elev = $false
    $script:SlCfg = 'D:\other'
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 'CLAUDE_CONFIG_DIR'
    $script:SlCfg = $null
    $script:SlHome = 'C:\Users\someone-else'
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 'home mismatch'
    $script:SlHome = $script:SlUP
    $script:InstallerBash = $null
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 'no Git Bash'
    Assert-Eq (@(Get-TreeHashes $script:T) -join "`n") ($before -join "`n") 'tree unchanged'
}

Test-SL 'SL2b Git Bash home equal to USERPROFILE ignoring case and a trailing slash or backslash passes the home check' {
    Initialize-SL
    $up = $script:SlUP
    foreach ($h in @(($up + '\'), ($up + '/'), $up.ToUpperInvariant())) {
        Reset-Stubs
        Initialize-SL
        $script:SlHome = $h
        Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; DryRun = $true }) 0 "home '$h'"
        Assert-Log 'would render'
    }
} -NeedsJq

Test-SL 'SL3 -DryRun prints "would" lines and writes nothing (settings and script both need changes)' {
    Initialize-SL
    [IO.File]::WriteAllText($script:SlP, 'old script')
    $b1 = @(Get-TreeHashes $script:T)
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; DryRun = $true }) 0 'exit'
    Assert-Eq (@(Get-TreeHashes $script:T) -join "`n") ($b1 -join "`n") 'no file added, removed or changed (profile, state, repo)'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:State 'claude'))) 'no backup folder in a dry run'
    Assert-Log 'would install .* as .*statusline.sh'
    Assert-Log 'would save .* to .*settings.json, then set only the statusLine key'
    Assert-Log 'would render'
    Assert-Eq @(Get-SeamCalls 'Invoke-StatusLineRender').Count 0 'no render in a dry run'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget'
} -NeedsJq

Test-SL 'SL4 -DryRun without jq: would run winget, settings unknown, exit 0, nothing written' {
    Initialize-SL
    $script:SlJqV = $null
    $b1 = @(Get-TreeHashes $script:T)
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; DryRun = $true }) 0 'exit'
    Assert-Log 'would run: winget install --id jqlang.jq'
    Assert-Log 'state is unknown without jq'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 0 'no winget in a dry run'
    Assert-Eq (@(Get-TreeHashes $script:T) -join "`n") ($b1 -join "`n") 'nothing written'
}

Test-SL 'SL5 backup exists before the write; only statusLine changes; script is LF and equals the repo script' {
    Initialize-SL
    $origBytes = [IO.File]::ReadAllBytes($script:SlS)
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'exit'
    Assert-Eq $script:SlBackupAtMerge $true 'the byte-exact backup existed when jq produced the merge'
    $bk = Join-Path $script:SlB 'settings.json'
    Assert-True (Test-Path -LiteralPath $bk) 'backup kept after a change'
    Assert-Eq (Get-BytesSha256 ([IO.File]::ReadAllBytes($bk))) (Get-BytesSha256 $origBytes) 'backup is byte-identical to the original (CRLF kept)'
    Assert-Eq (Test-SlMerged $SlOriginal) 0 'statusLine equals the template; every other key equal by value'
    $now = [IO.File]::ReadAllText($script:SlS)
    Assert-True (-not $now.Contains('old.sh') -and -not $now.Contains('hideX')) 'the old statusLine is replaced exactly, not merged'
    Assert-True (-not $now.Contains('"model"') -and -not $now.Contains('"hooks"')) 'no other template key is copied'
    $pb = [IO.File]::ReadAllBytes($script:SlP)
    Assert-True (-not ($pb -contains 13)) 'no CR in the installed script'
    Assert-Eq (Get-BytesSha256 $pb) (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlSrc))) 'script equals the repo script'
    Assert-Log 'replacing the existing statusLine \(command: old.sh\)'
    Assert-Log 'rollback \(one command\): Copy-Item'
    Assert-Eq $script:SlRenderCalls.Count 1 'rendered once'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:SlB 'payload.json'))) 'payload removed'
    Assert-Eq @(Get-ChildItem -LiteralPath $script:SlCD -Force | Where-Object { $_.Name -like '*app-configs-tmp*' }).Count 0 'no temp file left'
} -NeedsJq

Test-SL 'SL6 the printed rollback command restores the original settings.json byte for byte' {
    Initialize-SL
    $origHash = Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'exit'
    Assert-True ((Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))) -ne $origHash) 'settings changed by the run'
    $line = @($script:LogLines | Where-Object { $_ -match 'rollback \(one command\): ' })
    Assert-Eq $line.Count 1 'one rollback line'
    $cmd = $line[0].Substring($line[0].IndexOf('Copy-Item'))
    Invoke-Expression $cmd
    Assert-Eq (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))) $origHash 'restored'
} -NeedsJq

Test-SL 'SL7 a second run changes nothing, makes no new backup and says current' {
    Initialize-SL
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'first run'
    $profile1 = @(Get-TreeHashes $script:SlUP)
    $backups1 = @(Get-ChildItem -LiteralPath (Join-Path $script:State 'claude') -Directory).Count
    Stub 'Get-UtcStamp' { '20260101T000001Z' }
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'second run'
    Assert-Eq (@(Get-TreeHashes $script:SlUP) -join "`n") ($profile1 -join "`n") 'profile unchanged'
    Assert-Eq @(Get-ChildItem -LiteralPath (Join-Path $script:State 'claude') -Directory).Count $backups1 'no new backup folder'
    Assert-Log 'statusline.sh is current'
    Assert-Log 'statusLine is current'
} -NeedsJq

Test-SL 'SL8 absent settings.json is created with only statusLine; no backup is kept; rollback is a delete' {
    Initialize-SL -Settings $null
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'exit'
    $r = & $RealInvokeJq @('-e', '--slurpfile', 't', $script:SlT, '. == {statusLine: $t[0].statusLine}', $script:SlS)
    Assert-Eq $r.Code 0 'only statusLine'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:State 'claude'))) 'nothing to back up, folder removed'
    Assert-Log 'did not exist before; rollback: Remove-Item'
} -NeedsJq

Test-SL 'SL9 existing statusLine already current: settings untouched, only a changed script is backed up' {
    Initialize-SL -Settings ('{"keep":1,"statusLine":{"type":"command","command":"~/.claude/statusline.sh","padding":2,"refreshInterval":5}}')
    [IO.File]::WriteAllText($script:SlP, 'edited locally')
    $h = Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'exit'
    Assert-Eq (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))) $h 'settings.json byte-identical'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:SlB 'settings.json'))) 'no settings backup when nothing changes there'
    Assert-Eq ([IO.File]::ReadAllText((Join-Path $script:SlB 'statusline.sh'))) 'edited locally' 'old script saved'
    Assert-Eq (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlP))) (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlSrc))) 'script replaced'
} -NeedsJq

Test-SL 'SL10 invalid settings.json (garbage, empty, two documents, array, UTF-16) exits 3, unchanged, no backup' {
    $cases = @(
        @{ N = 'garbage'; B = [Text.Encoding]::UTF8.GetBytes('{not json') },
        @{ N = 'empty'; B = [byte[]]@() },
        @{ N = 'two documents'; B = [Text.Encoding]::UTF8.GetBytes('{"a":1}{"b":2}') },
        @{ N = 'array'; B = [Text.Encoding]::UTF8.GetBytes('[1]') },
        @{ N = 'utf-16'; B = [Text.Encoding]::Unicode.GetPreamble() + [Text.Encoding]::Unicode.GetBytes('{"a":1}') },
        @{ N = 'invalid utf-8'; B = [byte[]]@(0x7B, 0xFF, 0x7D) }
    )
    foreach ($c in $cases) {
        Reset-Stubs
        Initialize-SL -Settings $null
        [IO.File]::WriteAllBytes($script:SlS, $c.B)
        Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 $c.N
        Assert-Eq (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))) (Get-BytesSha256 $c.B) "$($c.N): unchanged"
        Assert-True (-not (Test-Path -LiteralPath $script:SlP)) "$($c.N): script not installed"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:State 'claude'))) "$($c.N): no backup folder left"
    }
} -NeedsJq

Test-SL 'SL11 a UTF-8 BOM is accepted and the rewritten file has none' {
    Initialize-SL -Settings $null
    [IO.File]::WriteAllBytes($script:SlS, ([byte[]]@(0xEF, 0xBB, 0xBF)) + [Text.Encoding]::UTF8.GetBytes('{"keep":true}'))
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'exit'
    $b = [IO.File]::ReadAllBytes($script:SlS)
    Assert-True ($b[0] -ne 0xEF) 'no BOM'
    Assert-Eq (Test-SlMerged '{"keep":true}') 0 'merged'
} -NeedsJq

Test-SL 'SL12 read-only settings.json that needs writing exits 3 in both modes, unchanged, no backup' {
    Initialize-SL
    $h = Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))
    Set-ItemProperty -LiteralPath $script:SlS -Name IsReadOnly -Value $true
    try {
        Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true; DryRun = $true }) 3 'dry-run'
        Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 'real'
        Assert-Eq (Get-BytesSha256 ([IO.File]::ReadAllBytes($script:SlS))) $h 'unchanged'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:State 'claude'))) 'no backup folder left'
        Assert-True (-not (Test-Path -LiteralPath $script:SlP)) 'script not installed'
    } finally {
        Set-ItemProperty -LiteralPath $script:SlS -Name IsReadOnly -Value $false
    }
} -NeedsJq

Test-SL 'SL13 render failure exits 1 and keeps the backup and the rollback hint' {
    Initialize-SL
    $script:SlRender = @{ Code = 1; Out = ''; Err = 'jq: not found' }
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 1 'exit'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:SlB 'settings.json')) 'backup kept'
    Assert-Log 'render check failed \(exit 1\): jq: not found'
} -NeedsJq

Test-SL 'SL14 a template that is not plain JSON or has another command exits 1 before any write' {
    Initialize-SL
    [IO.File]::WriteAllText($script:SlT, '{"statusLine":{"type":"command","command":"{{ .x }}"}}')
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 1 'template action'
    [IO.File]::WriteAllText($script:SlT, '{"statusLine":{"type":"command","command":"other.sh"}}')
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 1 'other command'
    Assert-True (-not (Test-Path -LiteralPath $script:SlP)) 'script not installed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:State 'claude'))) 'no backup folder'
}

Test-SL 'SL15 jq below 1.7 exits 3; a missing jq in a real run installs it through winget' {
    Initialize-SL
    $script:SlJqV = 'jq-1.6'
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 3 'old jq'
    Reset-Stubs; Initialize-SL
    $script:SlJqV = $null
    Stub 'Invoke-Winget' { param([string]$Id) $script:SlJqV = 'jq-1.8.2'; @{ Code = 0; Out = 'ok'; Err = '' } }
    Assert-Eq (Run-Boot @{ ClaudeStatusLine = $true }) 0 'installed'
    Assert-Eq @(Get-SeamCalls 'Invoke-Winget').Count 1 'winget once'
    Assert-Log 'installing jqlang.jq with winget'
} -NeedsJq

Test-SL 'SL17 real Git Bash renders the current repo statusline script (temp HOME, nothing written outside temp)' {
    Stub 'Resolve-Program' $RealResolveProgram
    $bash = & $RealResolveGitBash
    if (-not $bash) { throw 'SKIP: Git for Windows bash not found' }
    $hd = Join-Path $script:T 'home17'
    $cd = Join-Path $hd '.claude'
    [void](New-Item -ItemType Directory -Force -Path $cd)
    $src = Join-Path $OrigRepoRoot 'home\dot_claude\executable_statusline.sh'
    [IO.File]::WriteAllBytes((Join-Path $cd 'statusline.sh'), [IO.File]::ReadAllBytes($src))
    $payload = Join-Path $script:T 'payload17.json'
    $cwd = $script:T.Replace('\', '/')
    [IO.File]::WriteAllText($payload, '{"model":{"display_name":"check"},"workspace":{"current_dir":"' + $cwd + '"}}')
    $savedHome = $env:HOME
    $savedUP = $env:USERPROFILE
    try {
        $env:HOME = $hd
        $env:USERPROFILE = $hd
        Stub 'Invoke-Native' $RealInvokeNative
        $r = & $RealInvokeStatusLineRender -Bash $bash -PayloadPath $payload.Replace('\', '/')
        Assert-Eq $r.Code 0 "render exit (stderr: $($r.Err))"
        Assert-True ([bool]([string]$r.Out).Trim()) 'at least one non-empty output line'
        Remove-Item -LiteralPath (Join-Path $cd 'statusline.sh')
        $r2 = & $RealInvokeStatusLineRender -Bash $bash -PayloadPath $payload.Replace('\', '/')
        Assert-True ($r2.Code -ne 0) 'a missing installed script makes the render check fail'
    } finally {
        $env:HOME = $savedHome
        $env:USERPROFILE = $savedUP
    }
}

Test-SL 'SL16 the default run never mentions or runs step S' {
    Initialize-Happy
    Assert-Eq (Run-Boot @{ DryRun = $true }) 0 'default dry-run'
    Assert-Eq @(Get-SeamCalls 'Invoke-Jq').Count 0 'no jq'
    Assert-Eq @(Get-SeamCalls 'Get-EnvScopes').Count 0 'no step S probe'
    Assert-True ((Get-Log) -notmatch 'step S') 'no step S line'
}

# ---------------------------------------------------------------- done

Test-Case 'Z1 across the whole suite, every advised wsl command that uses --exec or -- names a program proven to resolve' {
    $lines = @($script:AllLog)
    Assert-True ($lines.Count -gt 100) "collected $($lines.Count) log lines from the suite"
    $advice = 0
    foreach ($l in $lines) {
        foreach ($m in [regex]::Matches($l, '\bwsl\b[^\r\n]*?\s--exec\s+(\S+)')) {
            $advice++
            Assert-True $m.Groups[1].Value.StartsWith('/') "advised --exec program must be absolute: $($m.Value)"
        }
        foreach ($m in [regex]::Matches($l, '\bwsl\b[^\r\n]*?\s-d NixOS -- (\S+)')) {
            $advice++
            Assert-True (@('sh', 'bash') -contains $m.Groups[1].Value) "advised program after -- must be sh or bash: $($m.Value)"
        }
        foreach ($m in [regex]::Matches($l, '\bwsl\b[^\r\n]*?\s-u root -- (\S+)')) {
            $advice++
            Assert-True (@('sh', 'bash') -contains $m.Groups[1].Value) "advised program after -- must be sh or bash (proven to resolve): $($m.Value)"
        }
    }
    Assert-True ($advice -ge 3) "the suite produced $advice advised wsl commands with a program (mv recovery, rollback)"
}

# ---------------------------------------------------------------- ADR-0020 boundary rules (T-0055 T2)
# Static checker for step W, as specified in ADR-0020 "Boundary rules". The ADR is the
# contract. The ids BR0..BR10 and BR-real are the ADR's R1..R10 (BRn tests Rn); the R
# prefix belongs to the report-script tests above. The rules apply to the functions in
# $BoundaryScope and their nested scriptblocks. Step W does not exist yet, so the real
# maps are empty and the rules are proven on a fixture model of step W plus seeded
# defects (inject one defect into a copy, assert it is caught; negative seeds assert a
# legal form is not flagged). The checker only reads source text (the syntax tree); the
# only session reads are the cmdlet metadata lookups used by R1 meta-tests and R9.
# R5 SCRIPT-STATE: $BoundaryScriptReads lists the only $script: variables step W may read;
# any write, element write, ++/-- or method call through a $script: or $global: root is
# a violation (the mutable-state ban).
$BoundaryScope = @()
$CommandOwners = @{}
$BoundaryCommon = @{}
$BoundarySwitches = @('Raw', 'RegisterByFamilyName')
$BoundaryTypeAllow = @('string', 'char', 'bool', 'boolean', 'byte', 'int', 'int32', 'long', 'int64', 'object', 'array',
    'void', 'switch', 'hashtable', 'ordered', 'pscustomobject', 'datetime', 'bitconverter', 'io.path',
    'text.utf8encoding', 'collections.generic.list')
$BoundaryEntries = @('Invoke-WindowsSnapshot', 'Invoke-WindowsSettings', 'Invoke-WindowsRollback')
$BoundaryEntrySwitch = @{ 'Invoke-WindowsSnapshot' = 'WindowsSnapshot'; 'Invoke-WindowsSettings' = 'WindowsSettings'; 'Invoke-WindowsRollback' = 'WindowsRollback' }
$BoundaryEntryParams = @('Label', 'SetupProfile', 'DryRun', 'MachineWide', 'RemoveApps', 'DisableTeamsStartup')
$BoundaryDispatcher = 'Invoke-BootstrapRun'
$BoundarySwitchNames = @('WindowsSnapshot', 'WindowsSettings', 'WindowsRollback', 'MachineWide', 'RemoveApps', 'DisableTeamsStartup')
$BoundaryScriptReads = @('RepoRoot')
$BoundaryTrusted = @('Say', 'Get-UtcStamp', 'Test-IsAdmin', 'Write-NewFile', 'Get-RestorePoints', 'New-RestorePoint', 'Invoke-Native', 'Resolve-Program')
$BoundaryWriters = @('Set-UserRegistryValue', 'Remove-UserAppxPackage', 'Register-UserAppxPackage', 'Set-MachinePolicyValue', 'Set-ServiceStart', 'Set-TaskEnabled')
$BoundaryOwnedMembers = @('GetValue', 'GetValueKind', 'GetValueNames', 'GetSubKeyNames')
$BoundaryR3Commands = @(
    'Invoke-Expression', 'Invoke-Command', 'Invoke-Item', 'Invoke-WebRequest', 'Invoke-RestMethod', 'Start-Process',
    'Stop-Process', 'Start-Job', 'Add-Type', 'Import-Module', 'New-Module', 'New-PSDrive', 'Set-Alias', 'New-Alias',
    'Get-Command', 'Get-Variable', 'Set-Variable', 'New-Variable', 'Set-Item', 'Clear-Item', 'Clear-ItemProperty',
    'Copy-Item', 'Copy-ItemProperty', 'Move-Item', 'Move-ItemProperty', 'Rename-Item', 'Rename-ItemProperty',
    'Set-Acl', 'Set-CimInstance', 'New-CimInstance', 'Remove-CimInstance', 'Invoke-CimMethod', 'Get-WmiObject',
    'Invoke-WmiMethod', 'Set-WmiInstance', 'Register-ScheduledTask', 'Set-ScheduledTask', 'Unregister-ScheduledTask',
    'Get-AppxProvisionedPackage', 'Add-AppxProvisionedPackage', 'Remove-AppxProvisionedPackage',
    'Enable-WindowsOptionalFeature', 'Disable-WindowsOptionalFeature', 'Set-ExecutionPolicy', 'Restart-Computer',
    'Set-Content', 'Add-Content', 'Out-File')
$BoundaryR3Members = @(
    'OpenSubKey', 'OpenBaseKey', 'OpenRemoteBaseKey', 'FromHandle', 'CreateSubKey', 'DeleteSubKey', 'DeleteSubKeyTree',
    'DeleteValue', 'SetValue', 'SetAccessControl', 'Flush',
    'Invoke', 'InvokeReturnAsIs', 'InvokeWithContext', 'InvokeMember', 'InvokeScript', 'InvokeProvider', 'InvokeCommand',
    'SessionState', 'NewScriptBlock', 'CreateInstance', 'CreateDelegate', 'DynamicInvoke',
    'Assembly', 'DefinedTypes', 'ExportedTypes', 'Module', 'DeclaredMethods', 'DeclaredFields', 'TypeHandle',
    'GetMethod', 'GetMethods', 'GetProperty', 'GetProperties', 'GetField', 'GetFields', 'GetMember', 'GetMembers',
    'GetConstructor', 'GetConstructors', 'GetNestedType', 'GetNestedTypes', 'GetInterface', 'GetInterfaces',
    'GetEvent', 'GetEvents', 'GetTypes', 'GetTypeFromProgID', 'GetTypeFromCLSID')
$BoundaryAutoVars = @('_', 'PSItem', 'null', 'true', 'false', 'Matches', 'PID', 'PSCmdlet', 'ExecutionContext', 'Host',
    'MyInvocation', 'PSBoundParameters', 'args', 'input', 'Profile', 'PSDefaultParameterValues', 'Error', 'ErrorView',
    'EnabledExperimentalFeatures', 'Event', 'EventArgs', 'EventSubscriber', 'ForEach', 'HOME', 'IsCoreCLR', 'IsLinux',
    'IsMacOS', 'IsWindows', 'LASTEXITCODE', 'NestedPromptLevel', 'PSCommandPath', 'PSCulture', 'PSEdition', 'PSHOME',
    'PSScriptRoot', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'PWD', 'Sender', 'ShellId', 'StackTrace', 'switch',
    'this', 'ConsoleFileName', 'MaximumHistoryCount', 'OFS', 'PSEmailServer', 'PSSessionApplicationName',
    'PSSessionConfigurationName', 'PSSessionOption', 'Transcript', 'Home', 'Args', 'LastExitCode')
$BoundarySpecialVars = @('_', 'PSItem', 'null', 'true', 'false', 'Matches', 'PID')
$BoundaryMaxParams = @{
    'Set-Service'           = @('Name', 'StartupType', 'ErrorAction')
    'Stop-Service'          = @('Name', 'ErrorAction')
    'Start-Service'         = @('Name', 'ErrorAction')
    'Disable-ScheduledTask' = @('TaskPath', 'TaskName', 'ErrorAction')
    'Enable-ScheduledTask'  = @('TaskPath', 'TaskName', 'ErrorAction')
    'Get-ScheduledTask'     = @('TaskPath', 'TaskName', 'ErrorAction')
    'Get-CimInstance'       = @('ClassName', 'Filter', 'Property', 'ErrorAction')
    'Get-AppxPackage'       = @('Name', 'ErrorAction')
    'Remove-AppxPackage'    = @('Package', 'ErrorAction')
    'Add-AppxPackage'       = @('RegisterByFamilyName', 'MainPackage', 'ErrorAction')
}
$BoundaryR2Regex = '(?i)(?<![A-Za-z0-9_])(?:HKCU|HKLM|HKCR|HKU|HKCC)(?=[:\\])|HKEY_[A-Z_]+|Registry::'
$BoundaryR5PrefixRegex = '(?i)^(alias|function|variable|env|cert|wsman):'
$BoundaryR8Regex1 = '(?i)(?:^|[\s"''\\/=])(?:reg|regedit|schtasks|sc|wsl|cmd|powershell|pwsh)\.(?:exe|com)(?=$|[\s"'';|&])'
$BoundaryR8Regex2 = '(?i)^\s*(?:reg|regedit|schtasks|sc|wsl|cmd|powershell|pwsh)\s*$'
$BoundaryKeyRegex = '^(?:[A-Z][A-Za-z]*-[A-Z][A-Za-z]*|\.[A-Za-z]+|HK(?:CU|LM):\\)$'

$BtFn = [Management.Automation.Language.FunctionDefinitionAst]
$BtCmd = [Management.Automation.Language.CommandAst]
$BtVar = [Management.Automation.Language.VariableExpressionAst]
$BtStr = [Management.Automation.Language.StringConstantExpressionAst]
$BtExp = [Management.Automation.Language.ExpandableStringExpressionAst]
$BtMem = [Management.Automation.Language.MemberExpressionAst]
$BtInv = [Management.Automation.Language.InvokeMemberExpressionAst]
$BtTypeExp = [Management.Automation.Language.TypeExpressionAst]
$BtTypeCon = [Management.Automation.Language.TypeConstraintAst]
$BtParen = [Management.Automation.Language.ParenExpressionAst]
$BtPipe = [Management.Automation.Language.PipelineAst]
$BtArr = [Management.Automation.Language.ArrayExpressionAst]
$BtArrLit = [Management.Automation.Language.ArrayLiteralAst]
$BtSb = [Management.Automation.Language.ScriptBlockExpressionAst]
$BtConst = [Management.Automation.Language.ConstantExpressionAst]
$BtParam = [Management.Automation.Language.CommandParameterAst]

$script:BExt = @{}
$script:BMeta = @{}

function Get-BMapKey {
    param($Map, [string]$Key)
    foreach ($k in $Map.Keys) { if ($k -ceq $Key) { return $k } }
    return $null
}

function Get-BNearestFn {
    param($Node)
    $p = $Node
    while ($p) {
        if ($p -is $BtFn) { return $p.Name }
        $p = $p.Parent
    }
    return $null
}

function Test-BInScope {
    param($Node, $Scope)
    $p = $Node
    while ($p) {
        # a nested scriptblock is not a function: the walk passes through it (R10)
        if ($p -is $BtFn -and ($Scope -ccontains $p.Name)) { return $true }
        $p = $p.Parent
    }
    return $false
}

function Test-BExternalCmdlet {
    param([string]$Name)
    if ($script:BExt.ContainsKey($Name)) { return $script:BExt[$Name] }
    $r = $false
    $c = @(Get-Command -Name $Name -CommandType Cmdlet, Function -ErrorAction SilentlyContinue)
    if ($c.Count -gt 0 -and $c[0].Name -ceq $Name -and $c[0].ModuleName) { $r = $true }
    $script:BExt[$Name] = $r
    return $r
}

function Get-BMeta {
    param([string]$Name, [string]$Prefix)
    $ck = "$Name|$Prefix"
    if ($script:BMeta.ContainsKey($ck)) { return $script:BMeta[$ck] }
    $arg = $env:SystemRoot
    if ($Prefix) { $arg = $Prefix }
    $c = @(Get-Command -Name $Name -CommandType Cmdlet, Function -ArgumentList $arg -ErrorAction SilentlyContinue)
    $r = $null
    if ($c.Count -gt 0 -and $c[0].ModuleName) { $r = $c[0].Parameters }
    $script:BMeta[$ck] = $r
    return $r
}

function Get-BCallInfo {
    param($Cmd, $Switches)
    $named = New-Object 'System.Collections.Generic.List[object]'
    $valueless = New-Object 'System.Collections.Generic.List[string]'
    $pos = 0
    $splat = $false
    $els = $Cmd.CommandElements
    $i = 1
    while ($i -lt $els.Count) {
        $e = $els[$i]
        if ($e -is $BtParam) {
            $pn = $e.ParameterName
            if ($null -ne $e.Argument) {
                [void]$named.Add(@{ Name = $pn; Arg = $e.Argument })
            } elseif ($Switches -ccontains $pn) {
                [void]$named.Add(@{ Name = $pn; Arg = $null })
            } elseif (($i + 1) -lt $els.Count -and $els[$i + 1] -isnot $BtParam) {
                [void]$named.Add(@{ Name = $pn; Arg = $els[$i + 1] })
                $i++
            } else {
                [void]$named.Add(@{ Name = $pn; Arg = $null })
                [void]$valueless.Add($pn)
            }
        } elseif ($e -is $BtVar -and $e.Splatted) {
            $splat = $true
        } else {
            $pos++
        }
        $i++
    }
    return @{ Named = $named; Positional = $pos; Splat = $splat; Valueless = $valueless }
}

function Get-BArg {
    param($Info, [string]$Name)
    foreach ($x in $Info.Named) { if ($x.Name -ceq $Name) { return $x } }
    return $null
}

function Get-BAssignLeaves {
    # every assignment target on the left side: through casts and array literals (multiple assignment)
    param($Expr)
    if ($Expr -is [Management.Automation.Language.ConvertExpressionAst]) { return @(Get-BAssignLeaves $Expr.Child) }
    if ($Expr -is $BtParen) {
        # a parenthesised target is the same target: unwrap a single expression statement, otherwise keep the paren as an unsupported leaf
        $pl = $Expr.Pipeline
        if ($pl -is $BtPipe -and $pl.PipelineElements.Count -eq 1 -and $pl.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
            return @(Get-BAssignLeaves $pl.PipelineElements[0].Expression)
        }
        return @($Expr)
    }
    if ($Expr -is $BtArrLit) {
        $r = @()
        foreach ($e in $Expr.Elements) { $r += @(Get-BAssignLeaves $e) }
        return $r
    }
    return @($Expr)
}

function Get-BAssignVars {
    param($Expr)
    return @(Get-BAssignLeaves $Expr | Where-Object -FilterScript { $_ -is $BtVar })
}

function Get-BPrefixOf {
    # owner function name -> the registry prefix key it owns
    param($Owners)
    $m = @{}
    foreach ($pk in @('HKCU:\', 'HKLM:\')) {
        $ek = Get-BMapKey $Owners $pk
        if ($ek) { foreach ($o in $Owners[$ek].Keys) { $m[$o] = $pk } }
    }
    return $m
}

function Get-BArrayElements {
    param($Expr)
    if ($Expr -isnot $BtArr) { return $null }
    $st = @($Expr.SubExpression.Statements)
    if ($st.Count -eq 0) { return @() }
    if ($st.Count -ne 1 -or $st[0] -isnot $BtPipe -or $st[0].PipelineElements.Count -ne 1) { return $null }
    $ce = $st[0].PipelineElements[0]
    if ($ce -isnot [Management.Automation.Language.CommandExpressionAst]) { return $null }
    if ($ce.Expression -is $BtArrLit) { return @($ce.Expression.Elements) }
    return @($ce.Expression)
}

function Get-BInnerCommand {
    # the single command inside a parenthesised expression, or $null
    param($Expr)
    if ($Expr -isnot $BtParen) { return $null }
    $p = $Expr.Pipeline
    if ($p -isnot $BtPipe -or $p.PipelineElements.Count -ne 1) { return $null }
    $c = $p.PipelineElements[0]
    if ($c -isnot $BtCmd) { return $null }
    return $c
}

function Get-BRootVar {
    # the variable at the root of an index, member or method chain, or $null
    param($Expr)
    $e = $Expr
    while ($e) {
        if ($e -is $BtVar) { return $e }
        if ($e -is [Management.Automation.Language.IndexExpressionAst]) { $e = $e.Target; continue }
        if ($e -is $BtMem) { $e = $e.Expression; continue }
        if ($e -is [Management.Automation.Language.ConvertExpressionAst]) { $e = $e.Child; continue }
        if ($e -is [Management.Automation.Language.SubExpressionAst] -or $e -is $BtArr) {
            $st = @($e.SubExpression.Statements)
            if ($st.Count -eq 1 -and $st[0] -is $BtPipe -and $st[0].PipelineElements.Count -eq 1 -and $st[0].PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) { $e = $st[0].PipelineElements[0].Expression; continue }
        }
        if ($e -is $BtParen) {
            $pl = $e.Pipeline
            if ($pl -is $BtPipe -and $pl.PipelineElements.Count -eq 1 -and $pl.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) { $e = $pl.PipelineElements[0].Expression; continue }
        }
        return $null
    }
    return $null
}

function Test-BScriptRooted {
    param($Expr)
    $rv = Get-BRootVar $Expr
    return ($null -ne $rv -and ($rv.VariablePath.IsScript -or $rv.VariablePath.IsGlobal))
}

function Test-BTypeAllowed {
    param($TypeName, $Allow)
    if ($TypeName -is [Management.Automation.Language.ArrayTypeName]) { return (Test-BTypeAllowed $TypeName.ElementType $Allow) }
    if ($TypeName -is [Management.Automation.Language.GenericTypeName]) {
        if (-not (Test-BTypeAllowed $TypeName.TypeName $Allow)) { return $false }
        foreach ($g in $TypeName.GenericArguments) { if (-not (Test-BTypeAllowed $g $Allow)) { return $false } }
        return $true
    }
    if ($TypeName.AssemblyName) { return $false }
    $norm = ($TypeName.Name -replace '^(?i)System\.', '').ToLowerInvariant()
    return ($Allow -ccontains $norm)
}

function Test-BTypeText {
    # a New-Object TypeName constant, parsed as a type literal
    param([string]$Text, $Allow)
    if ($Text -match '[`,]') { return $false }
    $t = $null; $e = $null
    $a = [Management.Automation.Language.Parser]::ParseInput("[$Text]", [ref]$t, [ref]$e)
    if ($e.Count -ne 0) { return $false }
    $te = $a.Find({ param($n) $n -is $BtTypeExp }, $true)
    if (-not $te) { return $false }
    return (Test-BTypeAllowed $te.TypeName $Allow)
}

function Get-BReachable {
    param($Ast, [string[]]$Start)
    $fns = @{}
    foreach ($f in @($Ast.FindAll({ param($n) $n -is $BtFn }, $true))) { if (-not $fns.ContainsKey($f.Name)) { $fns[$f.Name] = $f } }
    $seen = New-Object 'System.Collections.Generic.List[string]'
    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    foreach ($s in $Start) {
        if ($fns.ContainsKey($s) -and ($BoundaryTrusted -notcontains $s)) {
            $nm = $fns[$s].Name
            if (-not ($seen -ccontains $nm)) { $seen.Add($nm); $queue.Enqueue($nm) }
        }
    }
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        foreach ($c in @($fns[$cur].Body.FindAll({ param($n) $n -is $BtCmd }, $true))) {
            $nm = $c.GetCommandName()
            if ($nm -and $fns.ContainsKey($nm) -and ($BoundaryTrusted -notcontains $nm)) {
                $dn = $fns[$nm].Name
                if (-not ($seen -ccontains $dn)) { $seen.Add($dn); $queue.Enqueue($dn) }
            }
        }
    }
    return @($seen)
}

function Get-BDispatcherInfo {
    param($Ast)
    $problems = New-Object 'System.Collections.Generic.List[string]'
    $branches = New-Object 'System.Collections.Generic.List[object]'
    $d = $Ast.Find({ param($n) $n -is $BtFn -and $n.Name -ceq $BoundaryDispatcher }, $true)
    $params = @()
    if ($Ast.ParamBlock) { $params += @($Ast.ParamBlock.Parameters) }
    foreach ($f in @($Ast.FindAll({ param($n) $n -is $BtFn -and ($n.Name -ceq $BoundaryDispatcher -or $n.Name -ceq 'Invoke-Bootstrap') }, $true))) {
        if ($f.Body.ParamBlock) { $params += @($f.Body.ParamBlock.Parameters) }
    }
    $declared = @()
    foreach ($p in $params) {
        $pn = $p.Name.VariablePath.UserPath
        foreach ($sw in $BoundarySwitchNames) { if ($pn -ieq $sw -and -not ($declared -contains $sw)) { $declared += $sw } }
    }
    if (-not $d) {
        [void]$problems.Add("dispatcher $BoundaryDispatcher not found (fail closed)")
        return @{ Found = $false; Problems = $problems; Branches = @(); Declared = $declared }
    }
    foreach ($if in @($d.FindAll({ param($n) $n -is [Management.Automation.Language.IfStatementAst] }, $true))) {
        foreach ($cl in $if.Clauses) {
            $ment = @()
            foreach ($vx in @($cl.Item1.FindAll({ param($n) $n -is $BtVar }, $true))) {
                # the switch counts only when it is read positively: not under -not or !
                $neg = $false
                $pp = $vx.Parent
                while ($pp) {
                    if ($pp -is [Management.Automation.Language.UnaryExpressionAst] -and @('Not', 'Exclaim') -contains $pp.TokenKind.ToString()) { $neg = $true }
                    if ($pp -eq $cl.Item1) { break }
                    $pp = $pp.Parent
                }
                if ($neg) { continue }
                foreach ($sw in $BoundarySwitchNames) { if ($vx.VariablePath.UserPath -ieq $sw -and -not ($ment -contains $sw)) { $ment += $sw } }
            }
            if ($ment.Count -eq 0) { continue }
            [void]$branches.Add(@{ Body = $cl.Item2; Mentions = $ment; Line = $cl.Item1.Extent.StartLineNumber })
            $cx = $cl.Item1
            if ($cx -is $BtPipe -and $cx.PipelineElements.Count -eq 1 -and $cx.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) { $cx = $cx.PipelineElements[0].Expression }
            $okCond = $false
            $cur = $cx
            while ($cur -is [Management.Automation.Language.BinaryExpressionAst] -and $cur.Operator.ToString() -eq 'And') { $cur = $cur.Left }
            if ($cur -is $BtVar -and ($BoundarySwitchNames -contains $cur.VariablePath.UserPath)) { $okCond = $true }
            if (-not $okCond) {
                [void]$problems.Add("branch at line $($cl.Item1.Extent.StartLineNumber): the condition must be a bare switch or '`$Switch -and ...': $($cl.Item1.Extent.Text)")
            }
            # every statement is one entry-point or Say command, or a return of one (or of a constant)
            $okCmd = {
                param($x)
                if ($x -isnot $BtCmd) { return $false }
                $xn = $x.GetCommandName()
                return ($xn -and (($BoundaryEntries -ccontains $xn) -or $xn -ceq 'Say'))
            }
            foreach ($st in @($cl.Item2.Statements)) {
                $good = $false
                if ($st -is $BtPipe -and $st.PipelineElements.Count -eq 1 -and (& $okCmd $st.PipelineElements[0])) { $good = $true }
                if ($st -is [Management.Automation.Language.ReturnStatementAst]) {
                    $rp = $st.Pipeline
                    if ($null -eq $rp) { $good = $true }
                    elseif ($rp -is $BtPipe -and $rp.PipelineElements.Count -eq 1) {
                        $re = $rp.PipelineElements[0]
                        if (& $okCmd $re) { $good = $true }
                        elseif ($re -is [Management.Automation.Language.CommandExpressionAst] -and $re.Expression -is $BtConst) { $good = $true }
                    }
                }
                if (-not $good) {
                    [void]$problems.Add("branch at line $($cl.Item1.Extent.StartLineNumber) has a statement other than an entry-point call, Say or return: $($st.Extent.Text)")
                }
            }
            if (@($cl.Item2.FindAll({ param($n) $n -is $BtMem }, $true)).Count -gt 0) {
                [void]$problems.Add("branch at line $($cl.Item1.Extent.StartLineNumber) contains a member access")
            }
            foreach ($c in @($cl.Item2.FindAll({ param($n) $n -is $BtCmd }, $true))) {
                $cn = $c.GetCommandName()
                if (-not $cn -or (($BoundaryEntries -ccontains $cn) -eq $false -and $cn -cne 'Say')) {
                    [void]$problems.Add("branch at line $($cl.Item1.Extent.StartLineNumber) calls '$($c.Extent.Text)' (only entry points and Say)")
                }
            }
        }
    }
    foreach ($sw in $declared) {
        $has = $false
        foreach ($b in $branches) { if ($b.Mentions -contains $sw) { $has = $true } }
        if (-not $has) { [void]$problems.Add("W switch -$sw is declared but has no branch in $BoundaryDispatcher") }
    }
    return @{ Found = $true; Problems = $problems; Branches = $branches.ToArray(); Declared = $declared }
}

function Get-BPinProblems {
    # R6 value pins for Invoke-Native and Resolve-Program; returns messages
    param($Cmd, [string]$Fn, $Switches)
    $m = New-Object 'System.Collections.Generic.List[string]'
    $name = $Cmd.GetCommandName()
    $info = Get-BCallInfo $Cmd $Switches
    if ($info.Positional -gt 0 -or $info.Splat -or $info.Valueless.Count -gt 0) { [void]$m.Add("$name has positional, splatted or valueless arguments") }
    if ($name -ceq 'Resolve-Program') {
        $inner = $Cmd.Parent
        $ok = $false
        if ($inner -is $BtPipe -and $inner.Parent -is $BtParen -and $inner.Parent.Parent -is $BtCmd) {
            $outer = $inner.Parent.Parent
            if ($outer.GetCommandName() -ceq 'Invoke-Native' -and (Get-BInnerCommand $inner.Parent) -eq $Cmd) { $ok = $true }
        }
        if (-not $ok) { [void]$m.Add('Resolve-Program is allowed only inline as the -ExePath of the pinned git call') }
        if ($Fn -cne 'Test-WindowsSettingsCommitted') { [void]$m.Add("Resolve-Program is not pinned in '$Fn'") }
        $a = Get-BArg $info 'Name'
        if ($info.Named.Count -ne 1 -or -not $a -or $a.Arg -isnot $BtStr -or $a.Arg.Value -cne 'git.exe') { [void]$m.Add("Resolve-Program must be exactly -Name 'git.exe'") }
        return @($m)
    }
    # Invoke-Native
    $pinned = ($Fn -ceq 'Get-DeviceJoinState' -or $Fn -ceq 'Test-WindowsSettingsCommitted')
    if (-not $pinned) { [void]$m.Add("Invoke-Native is not pinned in '$Fn'"); return @($m) }
    $want = @('ExePath', 'Arguments')
    if ($Fn -ceq 'Test-WindowsSettingsCommitted') { $want += 'WorkingDirectory' }
    foreach ($x in $info.Named) {
        if (-not (($want -ccontains $x.Name) -or $x.Name -ceq 'TimeoutSeconds')) { [void]$m.Add("Invoke-Native parameter -$($x.Name) is not part of the pinned form") }
    }
    foreach ($w in $want) { if (-not (Get-BArg $info $w)) { [void]$m.Add("Invoke-Native pinned form needs -$w") } }
    $t = Get-BArg $info 'TimeoutSeconds'
    if ($t -and ($t.Arg -isnot $BtConst -or $t.Arg.Value -isnot [int])) { [void]$m.Add('-TimeoutSeconds must be an int constant') }
    $exe = Get-BArg $info 'ExePath'
    $args1 = Get-BArg $info 'Arguments'
    $els = $null
    if ($args1) { $els = Get-BArrayElements $args1.Arg }
    if ($Fn -ceq 'Get-DeviceJoinState') {
        $jc = $null
        if ($exe) { $jc = Get-BInnerCommand $exe.Arg }
        $okJoin = $false
        if ($jc -and $jc.GetCommandName() -ceq 'Join-Path') {
            $ji = Get-BCallInfo $jc $Switches
            $jp = Get-BArg $ji 'Path'
            $jch = Get-BArg $ji 'ChildPath'
            if ($ji.Named.Count -eq 2 -and $ji.Positional -eq 0 -and -not $ji.Splat -and $jp -and $jch -and
                $jp.Arg -is $BtVar -and $jp.Arg.VariablePath.UserPath -ieq 'env:SystemRoot' -and
                $jch.Arg -is $BtStr -and $jch.Arg.Value -ceq 'System32\dsregcmd.exe') { $okJoin = $true }
        }
        if (-not $okJoin) { [void]$m.Add("-ExePath must be exactly (Join-Path -Path `$env:SystemRoot -ChildPath 'System32\dsregcmd.exe')") }
        if ($null -eq $els -or $els.Count -ne 1 -or $els[0] -isnot $BtStr -or $els[0].Value -cne '/status') { [void]$m.Add("-Arguments must be exactly @('/status')") }
        return @($m)
    }
    # Test-WindowsSettingsCommitted
    $rc = $null
    if ($exe) { $rc = Get-BInnerCommand $exe.Arg }
    if (-not $rc -or $rc.GetCommandName() -cne 'Resolve-Program') { [void]$m.Add("-ExePath must be exactly (Resolve-Program -Name 'git.exe')") }
    $wd = Get-BArg $info 'WorkingDirectory'
    if ($wd -and ($wd.Arg -isnot $BtVar -or $wd.Arg.VariablePath.UserPath -cne 'script:RepoRoot')) { [void]$m.Add('-WorkingDirectory must be exactly $script:RepoRoot') }
    $form1 = @('ls-files', '--error-unmatch', '--')
    $form2 = @('diff', '--quiet', '--no-ext-diff', '--no-textconv', 'HEAD', '--')
    $okArr = $false
    if ($null -ne $els) {
        foreach ($form in @($form1, $form2)) {
            if ($els.Count -ne ($form.Count + 1)) { continue }
            $match = $true
            for ($k = 0; $k -lt $form.Count; $k++) {
                if ($els[$k] -isnot $BtStr -or $els[$k].Value -cne $form[$k]) { $match = $false }
            }
            $last = $els[$form.Count]
            if ($match -and (($last -is $BtVar -and -not $last.Splatted) -or $last -is $BtStr)) { $okArr = $true }
        }
    }
    if (-not $okArr) { [void]$m.Add("-Arguments must be exactly @('ls-files', '--error-unmatch', '--', <path>) or @('diff', '--quiet', '--no-ext-diff', '--no-textconv', 'HEAD', '--', <path>)") }
    return @($m)
}

function Test-BInlineJoin {
    param($Arg, [string]$Prefix, $Switches)
    $c = Get-BInnerCommand $Arg
    if (-not $c -or $c.GetCommandName() -cne 'Join-Path') { return $false }
    $i = Get-BCallInfo $c $Switches
    $p = Get-BArg $i 'Path'
    $ch = Get-BArg $i 'ChildPath'
    return ($i.Named.Count -eq 2 -and $i.Positional -eq 0 -and -not $i.Splat -and $p -and $ch -and
        $p.Arg -is $BtStr -and $p.Arg.Value -ceq $Prefix)
}

function Get-BoundaryViolations {
    param($Ast, $Maps)
    $v = New-Object 'System.Collections.Generic.List[string]'
    $owners = $Maps.Owners
    $common = $Maps.Common
    $scope = @($Maps.Scope)
    $switches = @($Maps.Switches)
    $allow = @($Maps.TypeAllow)
    $used = New-Object 'System.Collections.Generic.HashSet[string]'
    $Maps['Used'] = $used
    $all = @($Ast.FindAll({ param($n) $true }, $true))
    $funcs = @($all | Where-Object -FilterScript { $_ -is $BtFn })
    $defined = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $funcs) { [void]$defined.Add($f.Name) }

    $prefixOf = Get-BPrefixOf $owners

    $wseams = @()
    foreach ($k in $owners.Keys) {
        if ($defined.Contains($k) -and ($BoundaryTrusted -notcontains $k) -and $k -match '^[A-Z][A-Za-z]*-[A-Z][A-Za-z]*$') { $wseams += $k }
    }

    # assignment targets and locals (R5)
    $targetSet = New-Object 'System.Collections.Generic.HashSet[object]'
    foreach ($n in $all) {
        if ($n -is [Management.Automation.Language.AssignmentStatementAst]) {
            foreach ($t in @(Get-BAssignVars $n.Left)) { [void]$targetSet.Add($t) }
        } elseif ($n -is [Management.Automation.Language.UnaryExpressionAst]) {
            if (@('PostfixPlusPlus', 'PostfixMinusMinus', 'PlusPlus', 'MinusMinus') -contains $n.TokenKind.ToString()) {
                foreach ($t in @(Get-BAssignVars $n.Child)) { [void]$targetSet.Add($t) }
            }
        } elseif ($n -is [Management.Automation.Language.ForEachStatementAst]) {
            [void]$targetSet.Add($n.Variable)
        } elseif ($n -is [Management.Automation.Language.ParameterAst]) {
            [void]$targetSet.Add($n.Name)
        }
    }
    $locals = @{}
    foreach ($t in $targetSet) {
        $vp = $t.VariablePath
        if ($vp.IsDriveQualified -or $vp.IsGlobal -or $vp.IsScript) { continue }
        $fn = Get-BNearestFn $t
        if (-not $fn) { continue }
        if (-not $locals.ContainsKey($fn)) { $locals[$fn] = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase) }
        [void]$locals[$fn].Add(($vp.UserPath -replace '^(?i)(local|private):', ''))
    }

    $dispatcher = Get-BDispatcherInfo $Ast
    foreach ($pm in $dispatcher.Problems) { [void]$v.Add("R1 line 0: $pm") }
    $entryOk = New-Object 'System.Collections.Generic.HashSet[object]'
    foreach ($b in $dispatcher.Branches) {
        foreach ($c in @($b.Body.FindAll({ param($n) $n -is $BtCmd }, $true))) {
            $cn = $c.GetCommandName()
            if ($cn -and $BoundaryEntrySwitch.ContainsKey($cn) -and ($b.Mentions -contains $BoundaryEntrySwitch[$cn])) { [void]$entryOk.Add($c) }
        }
    }

    foreach ($n in $all) {
        $line = $n.Extent.StartLineNumber

        # whole script: using statements, type definitions
        if ($n -is [Management.Automation.Language.UsingStatementAst]) { [void]$v.Add("R4 line ${line}: using statement") }
        if ($n -is [Management.Automation.Language.TypeDefinitionAst]) { [void]$v.Add("R4 line ${line}: type definition") }

        # whole script: function definitions
        if ($n -is $BtFn) {
            $nm = $n.Name
            $top = ($n.Parent -is [Management.Automation.Language.NamedBlockAst] -and $n.Parent.Parent -eq $Ast)
            $reqOnce = ($scope -ccontains $nm) -or ($prefixOf.ContainsKey($nm)) -or ($wseams -ccontains $nm)
            foreach ($k in $owners.Keys) { if ($owners[$k].Keys -ccontains $nm) { $reqOnce = $true } }
            $isTrusted = ($BoundaryTrusted -contains $nm) -or ($BoundaryEntries -contains $nm)
            if (($reqOnce -or $isTrusted) -and -not $top) { [void]$v.Add("R1 line ${line}: function '$nm' is not defined at top level") }
            if ($reqOnce -or $isTrusted) {
                $cnt = @($funcs | Where-Object -FilterScript { $_.Name -ceq $nm -or $_.Name -ieq $nm }).Count
                if ($cnt -gt 1) { [void]$v.Add("R1 line ${line}: function '$nm' is defined $cnt times") }
            }
            if ($BoundaryR3Commands -contains $nm) { [void]$v.Add("R1 line ${line}: script function '$nm' is named like an R3 command") }
            foreach ($mp in @($owners, $common)) {
                foreach ($k in $mp.Keys) {
                    if ($k -ieq $nm -and $k -match '^[A-Z][A-Za-z]*-[A-Z][A-Za-z]*$' -and ($BoundaryTrusted -notcontains $k) -and (Test-BExternalCmdlet $k)) {
                        [void]$v.Add("R1 line ${line}: script function '$nm' is named like the external cmdlet key '$k'")
                    }
                }
            }
            if ($BoundaryEntries -contains $nm) {
                foreach ($p in @($n.Body.ParamBlock.Parameters)) {
                    if ($BoundaryEntryParams -notcontains $p.Name.VariablePath.UserPath) { [void]$v.Add("R5 line ${line}: entry point '$nm' parameter `$$($p.Name.VariablePath.UserPath) does not mirror a switch name") }
                }
            }
        }

        # whole script: W seam callers and entry-point callers
        if ($n -is $BtCmd) {
            $cn0 = $n.GetCommandName()
            if ($cn0) {
                foreach ($ws in $wseams) {
                    if ($ws -ieq $cn0) {
                        $ownerKey = Get-BMapKey $owners $ws
                        $fn0 = Get-BNearestFn $n
                        $isOwner = $false
                        foreach ($o in $owners[$ownerKey].Keys) { if ($fn0 -and $o -ceq $fn0) { $isOwner = $true } }
                        if (-not $isOwner) { [void]$v.Add("R1 line ${line}: seam '$cn0' is called in '$fn0', which is not one of its owners") }
                    }
                }
                foreach ($en in $BoundaryEntries) {
                    if ($en -ieq $cn0 -and -not $entryOk.Contains($n)) { [void]$v.Add("R1 line ${line}: entry point '$cn0' is called outside its dispatcher branch") }
                }
            }
        }

        if (-not (Test-BInScope $n $scope)) { continue }
        $fnName = Get-BNearestFn $n

        # R10
        if ($n -is $BtFn -and $n.Parent) {
            $pp = $n.Parent
            while ($pp) {
                if ($pp -is $BtFn -and ($scope -ccontains $pp.Name)) { [void]$v.Add("R10 line ${line}: function definition '$($n.Name)' inside scope function '$($pp.Name)'"); break }
                $pp = $pp.Parent
            }
        }
        if ($n -is [Management.Automation.Language.AttributeAst]) { [void]$v.Add("R4 line ${line}: attribute [$($n.TypeName.Name)] in scope") }

        # strings: R2, R5 prefixes, R8
        if ($n -is $BtStr -or $n -is $BtExp) {
            $sv = $n.Value
            if ($sv -match $BoundaryR2Regex) {
                $exact = ($n -is $BtStr -and ($sv -ceq 'HKCU:\' -or $sv -ceq 'HKLM:\'))
                if (-not $exact) {
                    [void]$v.Add("R2 line ${line}: registry literal in '$sv'")
                } else {
                    $pk2 = Get-BMapKey $owners $sv
                    if ($pk2 -and $fnName -and ($owners[$pk2].Keys -ccontains $fnName)) { [void]$used.Add("$pk2|$fnName") }
                    else { [void]$v.Add("R2 line ${line}: '$sv' used outside the owners of that prefix ('$fnName')") }
                }
            }
            if ($sv -match $BoundaryR5PrefixRegex) { [void]$v.Add("R5 line ${line}: provider or drive prefix in '$sv'") }
            if ($sv -match $BoundaryR8Regex1 -or $sv -match $BoundaryR8Regex2) { [void]$v.Add("R8 line ${line}: executable name in '$sv'") }
        }

        # variables: R5
        if ($n -is $BtVar) {
            $vp = $n.VariablePath
            $isT = $targetSet.Contains($n)
            if ($vp.IsDriveQualified) {
                if ($vp.DriveName -ieq 'env') {
                    if ($isT) { [void]$v.Add("R5 line ${line}: assignment to `$$($vp.UserPath)") }
                } else {
                    [void]$v.Add("R5 line ${line}: drive-qualified variable `$$($vp.UserPath)")
                }
            } elseif ($vp.IsGlobal) {
                [void]$v.Add("R5 line ${line}: `$$($vp.UserPath)")
            } elseif ($vp.IsScript) {
                if ($isT) { [void]$v.Add("R5 line ${line}: assignment to `$$($vp.UserPath)") }
                elseif (-not ($BoundaryScriptReads -ccontains ($vp.UserPath -replace '^(?i)script:', ''))) { [void]$v.Add("R5 line ${line}: `$$($vp.UserPath) is not on `$BoundaryScriptReads") }
            } else {
                $vn = ($vp.UserPath -replace '^(?i)(local|private):', '')
                if ($isT) {
                    if ($vn -ine 'null' -and (($BoundaryAutoVars -contains $vn) -or $vn -like '*Preference')) { [void]$v.Add("R5 line ${line}: local `$$vn is named like an automatic or preference variable") }
                } elseif ($BoundarySpecialVars -contains $vn) {
                    # allowed
                } elseif (-not ($fnName -and $locals.ContainsKey($fnName) -and $locals[$fnName].Contains($vn))) {
                    [void]$v.Add("R5 line ${line}: unqualified variable `$$vn is not a local of '$fnName'")
                }
            }
        }

        # types: R4
        if ($n -is $BtTypeExp -or $n -is $BtTypeCon) {
            if (-not (Test-BTypeAllowed $n.TypeName $allow)) { [void]$v.Add("R4 line ${line}: type [$($n.TypeName.FullName)] is not on the allowlist") }
        }
        if ($n -is [Management.Automation.Language.BinaryExpressionAst] -and @('Is', 'IsNot', 'As') -contains $n.Operator.ToString()) {
            if ($n.Right -isnot $BtTypeExp) { [void]$v.Add("R4 line ${line}: right side of -$($n.Operator) must be a type literal") }
        }

        # R3 (e), (f)
        if ($n -is [Management.Automation.Language.AssignmentStatementAst]) {
            foreach ($lf in @(Get-BAssignLeaves $n.Left)) {
                if (($lf -is [Management.Automation.Language.IndexExpressionAst] -or $lf -is $BtMem) -and (Test-BScriptRooted $lf)) { [void]$v.Add("R5 line ${line}: SCRIPT-STATE: assignment through a `$script: or `$global: root: $($lf.Extent.Text)") }
                if ($lf -is $BtMem) { [void]$v.Add("R3 line ${line}: assignment to a member") }
                elseif ($lf -isnot $BtVar -and $lf -isnot [Management.Automation.Language.IndexExpressionAst]) { [void]$v.Add("R5 line ${line}: unsupported assignment target shape: $($lf.Extent.Text)") }
            }
        }
        if ($n -is [Management.Automation.Language.UnaryExpressionAst]) {
            if (@('PostfixPlusPlus', 'PostfixMinusMinus', 'PlusPlus', 'MinusMinus') -contains $n.TokenKind.ToString()) {
                foreach ($lf in @(Get-BAssignLeaves $n.Child)) {
                    if (($lf -is [Management.Automation.Language.IndexExpressionAst] -or $lf -is $BtMem) -and (Test-BScriptRooted $lf)) { [void]$v.Add("R5 line ${line}: SCRIPT-STATE: ++ or -- through a `$script: or `$global: root: $($lf.Extent.Text)") }
                    if ($lf -is $BtMem) { [void]$v.Add("R3 line ${line}: ++ or -- on a member") }
                    elseif ($lf -isnot $BtVar -and $lf -isnot [Management.Automation.Language.IndexExpressionAst]) { [void]$v.Add("R5 line ${line}: unsupported ++ or -- operand shape: $($lf.Extent.Text)") }
                }
            }
        }
        if ($n -is [Management.Automation.Language.FileRedirectionAst]) { [void]$v.Add("R3 line ${line}: file redirection") }
        if ($n -is [Management.Automation.Language.DataStatementAst]) { [void]$v.Add("R3 line ${line}: data statement") }

        # members: R3 (c), (d), R10, owned members (R1)
        if ($n -is $BtMem) {
            $mem = $n.Member
            if ($mem -isnot $BtStr) {
                [void]$v.Add("R3 line ${line}: non-constant member name")
            } else {
                $mname = $mem.Value
                if (($BoundaryR3Members -contains $mname) -or $mname -like 'GetRuntime*') { [void]$v.Add("R3 line ${line}: banned member .$mname") }
                if ($n -is $BtInv) {
                    $margs = @()
                    if ($n.Arguments) { $margs = @($n.Arguments) }
                    if ($mname -ieq 'GetType' -and $margs.Count -gt 0) { [void]$v.Add("R3 line ${line}: GetType with an argument") }
                    if (($mname -ieq 'ForEach' -or $mname -ieq 'Where') -and $margs.Count -gt 0 -and $margs[0] -isnot $BtSb) { [void]$v.Add("R3 line ${line}: .$mname with a non-scriptblock argument") }
                }
                if ($mname -ieq 'SetEnvironmentVariable') { [void]$v.Add("R10 line ${line}: SetEnvironmentVariable") }
                if ($BoundaryOwnedMembers -contains $mname) {
                    $mk = $null
                    foreach ($k in $owners.Keys) { if ($k.StartsWith('.') -and $k.Substring(1) -ieq $mname) { $mk = $k } }
                    if ($mk -and $fnName -and ($owners[$mk].Keys -ccontains $fnName) -and $mname -ceq $mk.Substring(1)) { [void]$used.Add("$mk|$fnName") }
                    else { [void]$v.Add("R1 line ${line}: owned member .$mname used in '$fnName', which does not own it") }
                }
            }
            if ($n.Static) {
                if ($n.Expression -isnot $BtTypeExp -or -not (Test-BTypeAllowed $n.Expression.TypeName $allow)) { [void]$v.Add("R3 line ${line}: static member access on a type that is not an R4 type literal") }
            }
        }

        if ($n -is $BtInv -and -not $n.Static -and (Test-BScriptRooted $n.Expression)) { [void]$v.Add("R5 line ${line}: SCRIPT-STATE: method call on a `$script: or `$global: root: .$($n.Member)") }

        if ($n -isnot $BtCmd) { continue }

        # commands
        if ($n.InvocationOperator.ToString() -ne 'Unknown') { [void]$v.Add("R3 line ${line}: invocation operator $($n.InvocationOperator)"); continue }
        $name = $n.GetCommandName()
        if (-not $name) { [void]$v.Add("R1 line ${line}: dynamic command name"); continue }
        if ($BoundaryR3Commands -contains $name) { [void]$v.Add("R3 line ${line}: banned command $name") }
        if ($name -ieq 'Out-Null') { [void]$v.Add("R6 line ${line}: output must be discarded with [void] or `$null =, not Out-Null") }

        $info = Get-BCallInfo $n $switches
        $plist = $null
        $isOwned = $false
        $ok = $false
        $ownerKey = Get-BMapKey $owners $name
        if ($ownerKey) {
            $isOwned = $true
            $own = $null
            foreach ($o in $owners[$ownerKey].Keys) { if ($fnName -and $o -ceq $fnName) { $own = $o } }
            if ($own) { $ok = $true; $plist = $owners[$ownerKey][$own]; [void]$used.Add("$ownerKey|$own") }
            else { [void]$v.Add("R1 line ${line}: '$name' is called in '$fnName', which is not one of its owners") }
        } elseif ($BoundaryEntries -ccontains $name) {
            [void]$v.Add("R1 line ${line}: scope function '$fnName' calls entry point '$name'")
        } elseif ($scope -ccontains $name) {
            $ok = $true
        } else {
            $ck = Get-BMapKey $common $name
            if ($ck) { $ok = $true; $plist = $common[$ck]; [void]$used.Add("common|$ck") }
            elseif ($name -notmatch '-' -and -not $defined.Contains($name)) { [void]$v.Add("R5 line ${line}: '$name' is not a script function and is reported as an alias") }
            else { [void]$v.Add("R1 line ${line}: '$name' is not an exact key of the command map") }
        }

        # R6 splatting for any command
        if ($info.Splat) { [void]$v.Add("R6 line ${line}: $name uses splatting") }

        if ($ok -and $null -ne $plist) {
            $names = @($plist | ForEach-Object -Process { ($_ -split '=', 2)[0] })
            foreach ($x in $info.Named) {
                if (-not ($names -ccontains $x.Name)) { [void]$v.Add("R6 line ${line}: $name parameter -$($x.Name) is not on the allowlist") }
            }
            if ($info.Positional -gt 0) { [void]$v.Add("R6 line ${line}: $name has a positional argument") }
            foreach ($vl in $info.Valueless) { [void]$v.Add("R6 line ${line}: $name parameter -$vl takes no value but is not in `$BoundarySwitches") }
            foreach ($pe in $plist) {
                if ($pe -match '=') {
                    $pn2 = ($pe -split '=', 2)[0]; $pv2 = ($pe -split '=', 2)[1]
                    $a2 = Get-BArg $info $pn2
                    if (-not $a2 -or $a2.Arg -isnot $BtStr -or $a2.Arg.Value -cne $pv2) { [void]$v.Add("R6 line ${line}: $name -$pn2 must be the constant '$pv2'") }
                }
            }
        }
        if ($ok -and $isOwned -and (Test-BExternalCmdlet $name)) {
            $pl = $n.Parent
            if ($pl -isnot $BtPipe -or $pl.PipelineElements[0] -ne $n) { [void]$v.Add("R6 line ${line}: owned cmdlet $name is not first in its pipeline") }
        }
        if ($name -ceq 'ForEach-Object') {
            $a = Get-BArg $info 'Process'
            if ($a -and $a.Arg -isnot $BtSb) { [void]$v.Add("R6 line ${line}: ForEach-Object -Process needs a scriptblock literal") }
        }
        if ($name -ceq 'Where-Object') {
            $a = Get-BArg $info 'FilterScript'
            if ($a -and $a.Arg -isnot $BtSb) { [void]$v.Add("R6 line ${line}: Where-Object -FilterScript needs a scriptblock literal") }
        }
        if ($name -ceq 'Select-Object') {
            $a = Get-BArg $info 'ExpandProperty'
            if ($a) {
                if ($a.Arg -isnot $BtStr -or ($BoundaryR3Members -contains $a.Arg.Value) -or $a.Arg.Value -like 'GetRuntime*') { [void]$v.Add("R6 line ${line}: Select-Object -ExpandProperty needs a constant that is not a banned member") }
            }
        }
        if ($name -ceq 'Get-CimInstance') {
            $a = Get-BArg $info 'ClassName'
            if ($a -and $a.Arg -isnot $BtStr) { [void]$v.Add("R6 line ${line}: Get-CimInstance -ClassName must be a constant") }
        }
        if ($name -ceq 'Invoke-Native' -or $name -ceq 'Resolve-Program') {
            foreach ($pm in @(Get-BPinProblems $n $fnName $switches)) { [void]$v.Add("R6 line ${line}: $pm") }
        }

        # R7
        if ($name -ieq 'New-Object') {
            $tn = Get-BArg $info 'TypeName'
            $bad = ($info.Positional -gt 0 -or $info.Splat -or -not $tn)
            foreach ($x in $info.Named) { if ($x.Name -cne 'TypeName' -and $x.Name -cne 'ArgumentList') { $bad = $true } }
            if ($bad) { [void]$v.Add("R7 line ${line}: New-Object takes only a named -TypeName and an optional -ArgumentList, no positionals, no COM") }
            if ($tn) {
                if ($tn.Arg -isnot $BtStr -or -not (Test-BTypeText $tn.Arg.Value $allow)) { [void]$v.Add("R4 line ${line}: New-Object -TypeName must be a constant, allowlisted type name without backtick or comma") }
            }
        }

        # R2: inline Join-Path in the owners of a prefix key
        if ($prefixOf.ContainsKey($fnName)) {
            $pa = Get-BArg $info 'LiteralPath'
            if (-not $pa -and $name -ceq 'New-Item') { $pa = Get-BArg $info 'Path' }
            if ($pa -and -not (Test-BInlineJoin $pa.Arg $prefixOf[$fnName] $switches)) {
                [void]$v.Add("R2 line ${line}: $name path argument is not written inline as (Join-Path -Path '$($prefixOf[$fnName])' -ChildPath <expr>)")
            }
        }

        # R9: -LiteralPath from metadata
        if ($ok -and ($isOwned -or $plist) -and $name -cne 'New-Item' -and $name -cne 'Join-Path' -and (Test-BExternalCmdlet $name)) {
            $meta = Get-BMeta $name $prefixOf[$fnName]
            if ($null -eq $meta) { [void]$v.Add("R9 line ${line}: no metadata for $name") }
            else {
                $hasLit = $false
                foreach ($k in $meta.Keys) { if ($k -ceq 'LiteralPath') { $hasLit = $true } }
                if ($hasLit) {
                    if (-not (Get-BArg $info 'LiteralPath')) { [void]$v.Add("R9 line ${line}: $name must take -LiteralPath") }
                    if (Get-BArg $info 'Path') { [void]$v.Add("R9 line ${line}: $name must not take -Path") }
                }
            }
        }
    }

    # snapshot reachability: no writer seam
    foreach ($r in @(Get-BReachable $Ast @('Invoke-WindowsSnapshot'))) {
        if ($BoundaryWriters -contains $r) { [void]$v.Add("R1 line 0: writer seam '$r' is reachable from Invoke-WindowsSnapshot") }
    }
    return @($v)
}

function Get-BoundaryScopeProblems {
    param($Ast, $Maps)
    $r = @(Get-BReachable $Ast $BoundaryEntries)
    $p = @()
    foreach ($x in $r) { if (-not (@($Maps.Scope) -ccontains $x)) { $p += "R1: '$x' is reachable from the entry points but is not in `$BoundaryScope" } }
    foreach ($x in @($Maps.Scope)) { if (-not ($r -ccontains $x)) { $p += "R1: `$BoundaryScope names '$x', which is not reachable from the entry points" } }
    return $p
}

function Get-BoundaryMapProblems {
    param($Ast, $Maps, $SeamNames, $S1Safe)
    $p = New-Object 'System.Collections.Generic.List[string]'
    $owners = $Maps.Owners
    $common = $Maps.Common
    $switches = @($Maps.Switches)
    $used = $Maps.Used
    $fnAst = @{}
    foreach ($f in @($Ast.FindAll({ param($n) $n -is $BtFn }, $true))) { if (-not $fnAst.ContainsKey($f.Name)) { $fnAst[$f.Name] = $f } }
    $prefixOf = Get-BPrefixOf $owners

    $nullOk = {
        param($key)
        return ($key.StartsWith('.') -or $key -match '^HK(CU|LM):\\$' -or ($BoundaryTrusted -ccontains $key))
    }
    $checkList = {
        param($key, $owner, $list)
        if ($null -eq $list) {
            if (-not (& $nullOk $key)) { [void]$p.Add("R1: '$key' / '$owner' has a `$null parameter list, allowed only for member keys, prefix keys and trusted helpers") }
            return
        }
        if ($key.StartsWith('.') -or $key -match '^HK(CU|LM):\\$') { [void]$p.Add("R1: '$key' must have a `$null list"); return }
        $pfx = $prefixOf[$owner]
        foreach ($pe in @($list)) {
            $pn = ($pe -split '=', 2)[0]
            $isSwitch = $null
            $found = $false
            if ($fnAst.ContainsKey($key)) {
                $pb = $fnAst[$key].Body.ParamBlock
                if ($pb) {
                    foreach ($pa in $pb.Parameters) {
                        if ($pa.Name.VariablePath.UserPath -ceq $pn) {
                            $found = $true
                            $isSwitch = ($pa.StaticType -eq [switch])
                        }
                    }
                }
            } else {
                $meta = Get-BMeta $key $pfx
                if ($null -eq $meta) { [void]$p.Add("R1: no metadata for '$key' (unresolvable)"); continue }
                foreach ($mk in $meta.Keys) {
                    if ($mk -ceq $pn) { $found = $true; $isSwitch = [bool]$meta[$mk].SwitchParameter }
                }
            }
            if (-not $found) { [void]$p.Add("R1: parameter '$pn' of '$key' is not canonical (exact case, not an alias) in its metadata"); continue }
            if ($isSwitch -ne ($switches -ccontains $pn)) { [void]$p.Add("R1: switch status of '-$pn' of '$key' does not match `$BoundarySwitches") }
        }
        if ($BoundaryMaxParams.ContainsKey($key)) {
            foreach ($pe in @($list)) {
                $pn = ($pe -split '=', 2)[0]
                if (-not ($BoundaryMaxParams[$key] -ccontains $pn)) { [void]$p.Add("R6: '-$pn' of '$key' exceeds the maximum list") }
            }
        }
    }
    foreach ($k in $owners.Keys) {
        if ($k -cnotmatch $BoundaryKeyRegex) { [void]$p.Add("R1: owned key '$k' has a bad grammar") }
        if ($BoundaryR3Commands -contains $k) { [void]$p.Add("R1: owned key '$k' is an R3 command") }
        if (Get-BMapKey $common $k) { [void]$p.Add("R1: key '$k' is both owned and common") }
        foreach ($o in $owners[$k].Keys) {
            if ($o -cnotmatch '^[A-Z][A-Za-z]*-[A-Z][A-Za-z]*$') { [void]$p.Add("R1: owner '$o' of '$k' has a bad grammar") }
            if (-not $used.Contains("$k|$o")) { [void]$p.Add("R1: owner '$o' does not use its key '$k'") }
            & $checkList $k $o $owners[$k][$o]
        }
    }
    foreach ($k in $common.Keys) {
        if ($k -cnotmatch $BoundaryKeyRegex -and ($BoundaryTrusted -cnotcontains $k)) { [void]$p.Add("R1: common key '$k' has a bad grammar") }
        if ($BoundaryR3Commands -contains $k) { [void]$p.Add("R1: common key '$k' is an R3 command") }
        if (-not $used.Contains("common|$k")) { [void]$p.Add("R1: common key '$k' is not used") }
        if (Test-BExternalCmdlet $k) {
            if (-not ($S1Safe -ccontains $k)) { [void]$p.Add("R1: external common key '$k' is not in S1's safe list") }
        }
        & $checkList $k '' $common[$k]
    }
    if ($SeamNames) {
        foreach ($k in $owners.Keys) {
            if ($fnAst.ContainsKey($k) -and ($BoundaryTrusted -notcontains $k) -and $k -match '^[A-Z][A-Za-z]*-[A-Z][A-Za-z]*$' -and -not ($SeamNames -ccontains $k)) { [void]$p.Add("R1: seam '$k' is not in `$SeamNames") }
        }
    }
    return @($p)
}

# ---- fixture: a model of step W that follows the ADR-0020 seam table. It is not the real script.
$BoundaryFixture = @'
function Say { param([string]$Text) }
function Get-UtcStamp { return 'x' }
function Test-IsAdmin { return $false }
function Write-NewFile { param([string]$Path, [byte[]]$Bytes) }
function Get-RestorePoints { return @() }
function New-RestorePoint { param([string]$Description) }
function Invoke-Native { param([string]$ExePath, [string[]]$Arguments, [string]$WorkingDirectory, [int]$TimeoutSeconds) }
function Resolve-Program { param([string]$Name) }

function Assert-WindowsSettingsTarget {
    param([string]$Key, [string]$Name, $Value)
    if (-not $Key -or -not $Name) { throw 'refused' }
}

function Assert-MachineTarget {
    param([string]$Key, [string]$Name, $Value)
    if (-not $Key -or -not $Name) { throw 'refused' }
}

function Get-UserRegistryValue {
    param([string]$Key, [string]$Name)
    $item = Get-Item -LiteralPath (Join-Path -Path 'HKCU:\' -ChildPath $Key) -ErrorAction Stop
    $names = $item.GetValueNames()
    if ($names -notcontains $Name) { return $null }
    $kind = $item.GetValueKind($Name)
    return [pscustomobject]@{ Kind = [string]$kind; Value = $item.GetValue($Name) }
}

function Get-UserRegistryValueNames {
    param([string]$Key)
    $item = Get-Item -LiteralPath (Join-Path -Path 'HKCU:\' -ChildPath $Key) -ErrorAction Stop
    return @($item.GetValueNames())
}

function Set-UserRegistryValue {
    param([string]$Key, [string]$Name, $Value, [string]$Type, [bool]$Remove)
    Assert-WindowsSettingsTarget -Key $Key -Name $Name -Value $Value
    if ($Remove) {
        Remove-ItemProperty -LiteralPath (Join-Path -Path 'HKCU:\' -ChildPath $Key) -Name $Name -ErrorAction Stop
    } else {
        Set-ItemProperty -LiteralPath (Join-Path -Path 'HKCU:\' -ChildPath $Key) -Name $Name -Value $Value -Type $Type -ErrorAction Stop
    }
}

function Get-UserAppxPackage {
    param([string]$Name)
    return @(Get-AppxPackage -Name $Name -ErrorAction Stop)
}

function Remove-UserAppxPackage {
    param([string]$Package)
    Remove-AppxPackage -Package $Package -ErrorAction Stop
}

function Register-UserAppxPackage {
    param([string]$Family)
    Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop
}

function Read-WindowsSettingsFile {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
    return ConvertFrom-Json -InputObject $text
}

function Read-WindowsSettingsCatalogue {
    param([string]$Path)
    return Import-PowerShellDataFile -LiteralPath $Path -ErrorAction Stop
}

function Write-WindowsSettingsFile {
    param([string]$Path, $Data)
    $json = ConvertTo-Json -InputObject $Data -Depth 8
    $list = New-Object -TypeName 'System.Collections.Generic.List[string]'
    [void](New-Item -Path $Path -ItemType Directory -ErrorAction Stop)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    Write-NewFile -Path $Path -Bytes $bytes
}

function Test-WindowsSettingsCommitted {
    param([string]$Path)
    $tracked = Invoke-Native -ExePath (Resolve-Program -Name 'git.exe') -WorkingDirectory $script:RepoRoot -Arguments @('ls-files', '--error-unmatch', '--', $Path)
    $clean = Invoke-Native -ExePath (Resolve-Program -Name 'git.exe') -WorkingDirectory $script:RepoRoot -Arguments @('diff', '--quiet', '--no-ext-diff', '--no-textconv', 'HEAD', '--', $Path) -TimeoutSeconds 60
    return ($tracked.ExitCode -eq 0 -and $clean.ExitCode -eq 0)
}

function Get-MachinePolicyValue {
    param([string]$Key, [string]$Name)
    $item = Get-Item -LiteralPath (Join-Path -Path 'HKLM:\' -ChildPath $Key) -ErrorAction Stop
    $names = $item.GetValueNames()
    if ($names -notcontains $Name) { return $null }
    $kind = $item.GetValueKind($Name)
    return [pscustomobject]@{ Kind = [string]$kind; Value = $item.GetValue($Name) }
}

function Get-ServiceStart {
    param([string]$Name)
    return Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -Property StartMode -ErrorAction Stop
}

function Get-TaskState {
    param([string]$TaskPath, [string]$TaskName)
    return Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
}

function Set-MachinePolicyValue {
    param([string]$Key, [string]$Name, $Value, [string]$Type, [bool]$Remove)
    Assert-MachineTarget -Key $Key -Name $Name -Value $Value
    if ($Remove) {
        Remove-ItemProperty -LiteralPath (Join-Path -Path 'HKLM:\' -ChildPath $Key) -Name $Name -ErrorAction Stop
        Remove-Item -LiteralPath (Join-Path -Path 'HKLM:\' -ChildPath $Key) -ErrorAction Stop
    } else {
        [void](New-Item -Path (Join-Path -Path 'HKLM:\' -ChildPath $Key) -ErrorAction Stop)
        Set-ItemProperty -LiteralPath (Join-Path -Path 'HKLM:\' -ChildPath $Key) -Name $Name -Value $Value -Type $Type -ErrorAction Stop
    }
}

function Set-ServiceStart {
    param([string]$Name, [string]$StartupType)
    Assert-MachineTarget -Key $Name -Name $StartupType
    Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
    Stop-Service -Name $Name -ErrorAction Stop
    Start-Service -Name $Name -ErrorAction Stop
}

function Set-TaskEnabled {
    param([string]$TaskPath, [string]$TaskName, [bool]$Enabled)
    Assert-MachineTarget -Key $TaskPath -Name $TaskName
    if ($Enabled) {
        Enable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    } else {
        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    }
}

function Get-DeviceJoinState {
    $r = Invoke-Native -ExePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\dsregcmd.exe') -Arguments @('/status')
    return $r
}

function Get-DomainMembership {
    return Get-CimInstance -ClassName Win32_ComputerSystem -Property PartOfDomain -ErrorAction Stop | Select-Object -ExpandProperty 'PartOfDomain'
}

function Get-MdmEnrollments {
    $roots = Get-ChildItem -LiteralPath (Join-Path -Path 'HKLM:\' -ChildPath 'SOFTWARE\Microsoft\Enrollments') -ErrorAction Stop
    $ids = $roots | Where-Object -FilterScript { $_.GetValueNames() -contains 'ProviderID' } | ForEach-Object -Process { $_.GetValue('ProviderID') } | Select-Object -First 1
    return @($ids)
}

function Get-EnabledLocalUserCount {
    return @(Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' -Property Name -ErrorAction Stop).Count
}

function Get-ProbeLocal {
    param([string]$Probe)
    # SEED-ANCHOR
    return $Probe
}

function Invoke-WindowsSnapshot {
    param([string]$Label, [switch]$DryRun)
    # SNAP-ANCHOR
    $cat = Read-WindowsSettingsCatalogue -Path $Label
    $snap = Read-WindowsSettingsFile -Path $Label
    $cur = Get-UserRegistryValue -Key $Label -Name $Label
    $curNames = Get-UserRegistryValueNames -Key $Label
    $pkg = Get-UserAppxPackage -Name $Label
    $mval = Get-MachinePolicyValue -Key $Label -Name $Label
    $svc = Get-ServiceStart -Name $Label
    $task = Get-TaskState -TaskPath $Label -TaskName $Label
    $probe = Get-ProbeLocal -Probe $Label
    Write-WindowsSettingsFile -Path $Label -Data $cat
    Say "snapshot $Label"
    return 0
}

function Invoke-WindowsSettings {
    param([string]$Label, [string]$SetupProfile, [switch]$DryRun, [switch]$MachineWide, [switch]$RemoveApps, [switch]$DisableTeamsStartup)
    if ($SetupProfile -cne 'personal' -and $SetupProfile -cne 'work') { return 2 }
    if ($MachineWide -and -not (Test-IsAdmin)) {
        Say 'step W: run elevated: .\ops\windows\bootstrap.ps1 -WindowsSettings x -SetupProfile personal -MachineWide'
        return 3
    }
    $stamp = Get-UtcStamp
    $committed = Test-WindowsSettingsCommitted -Path $Label
    $cat = Read-WindowsSettingsCatalogue -Path $Label
    $snap = Read-WindowsSettingsFile -Path $Label
    $cur = Get-UserRegistryValue -Key $Label -Name $Label
    $curNames = Get-UserRegistryValueNames -Key $Label
    $pkg = Get-UserAppxPackage -Name $Label
    $mval = Get-MachinePolicyValue -Key $Label -Name $Label
    $svc = Get-ServiceStart -Name $Label
    $task = Get-TaskState -TaskPath $Label -TaskName $Label
    $join = Get-DeviceJoinState
    $dom = Get-DomainMembership
    $mdm = Get-MdmEnrollments
    $accounts = Get-EnabledLocalUserCount
    $points = Get-RestorePoints
    $probe = Get-ProbeLocal -Probe $Label
    if ($DryRun) { return 0 }
    New-RestorePoint -Description 'step W'
    Write-WindowsSettingsFile -Path $Label -Data $cat
    Set-UserRegistryValue -Key $Label -Name $Label -Value 1 -Type 'DWord' -Remove $false
    Remove-UserAppxPackage -Package $Label
    Set-MachinePolicyValue -Key $Label -Name $Label -Value 1 -Type 'DWord' -Remove $false
    Set-ServiceStart -Name $Label -StartupType 'Disabled'
    Set-TaskEnabled -TaskPath $Label -TaskName $Label -Enabled $false
    Say "step W: $Label done"
    return 0
}

function Invoke-WindowsRollback {
    param([string]$Label, [switch]$MachineWide)
    $committed = Test-WindowsSettingsCommitted -Path $Label
    $cat = Read-WindowsSettingsCatalogue -Path $Label
    $snap = Read-WindowsSettingsFile -Path $Label
    $cur = Get-UserRegistryValue -Key $Label -Name $Label
    $curNames = Get-UserRegistryValueNames -Key $Label
    $pkg = Get-UserAppxPackage -Name $Label
    $mval = Get-MachinePolicyValue -Key $Label -Name $Label
    $svc = Get-ServiceStart -Name $Label
    $task = Get-TaskState -TaskPath $Label -TaskName $Label
    Set-UserRegistryValue -Key $Label -Name $Label -Value 1 -Type 'DWord' -Remove $true
    Register-UserAppxPackage -Family $Label
    Set-MachinePolicyValue -Key $Label -Name $Label -Value 1 -Type 'DWord' -Remove $true
    Set-ServiceStart -Name $Label -StartupType 'Manual'
    Set-TaskEnabled -TaskPath $Label -TaskName $Label -Enabled $true
    Say "step W: rollback $Label done"
    return 0
}

function Other-Fixture {
    param([string]$Probe)
    $PSDefaultParameterValues = @{}
    & $Probe
    Get-Item -LiteralPath $Probe
    return $Probe
}

function Invoke-BootstrapRun {
    param([string]$WindowsSnapshot, [string]$WindowsSettings, [string]$WindowsRollback, [string]$SetupProfile, [switch]$DryRun, [switch]$MachineWide, [switch]$RemoveApps, [switch]$DisableTeamsStartup)
    if ($WindowsSnapshot) { return Invoke-WindowsSnapshot -Label $WindowsSnapshot -DryRun:$DryRun }
    if ($WindowsSettings) { return Invoke-WindowsSettings -Label $WindowsSettings -SetupProfile $SetupProfile -DryRun:$DryRun -MachineWide:$MachineWide -RemoveApps:$RemoveApps -DisableTeamsStartup:$DisableTeamsStartup }
    if ($WindowsRollback) { return Invoke-WindowsRollback -Label $WindowsRollback -MachineWide:$MachineWide }
    if ($MachineWide) { Say 'step W: -MachineWide needs -WindowsSettings or -WindowsRollback'; return 2 }
    if ($RemoveApps) { Say 'step W: -RemoveApps needs -WindowsSettings'; return 2 }
    if ($DisableTeamsStartup) { Say 'step W: -DisableTeamsStartup needs -WindowsSettings -SetupProfile work'; return 2 }
    return 0
}
'@
$BoundaryFixture = $BoundaryFixture.Replace("`r`n", "`n")

function New-BFixtureMaps {
    $S = 'Invoke-WindowsSnapshot'; $A = 'Invoke-WindowsSettings'; $R = 'Invoke-WindowsRollback'
    $o = @{}
    $add = {
        param($key, $list, $who)
        $o[$key] = @{}
        foreach ($w in $who) { $o[$key][$w] = $list }
    }
    $lit = @('LiteralPath', 'ErrorAction')
    # seams (concrete callers)
    & $add 'Get-UserRegistryValue' @('Key', 'Name') @($S, $A, $R)
    & $add 'Get-UserRegistryValueNames' @('Key') @($S, $A, $R)
    & $add 'Set-UserRegistryValue' @('Key', 'Name', 'Value', 'Type', 'Remove') @($A, $R)
    & $add 'Get-UserAppxPackage' @('Name') @($S, $A, $R)
    & $add 'Remove-UserAppxPackage' @('Package') @($A)
    & $add 'Register-UserAppxPackage' @('Family') @($R)
    & $add 'Read-WindowsSettingsFile' @('Path') @($S, $A, $R)
    & $add 'Read-WindowsSettingsCatalogue' @('Path') @($S, $A, $R)
    & $add 'Write-WindowsSettingsFile' @('Path', 'Data') @($S, $A)
    & $add 'Test-WindowsSettingsCommitted' @('Path') @($A, $R)
    & $add 'Get-MachinePolicyValue' @('Key', 'Name') @($S, $A, $R)
    & $add 'Get-ServiceStart' @('Name') @($S, $A, $R)
    & $add 'Get-TaskState' @('TaskPath', 'TaskName') @($S, $A, $R)
    & $add 'Set-MachinePolicyValue' @('Key', 'Name', 'Value', 'Type', 'Remove') @($A, $R)
    & $add 'Set-ServiceStart' @('Name', 'StartupType') @($A, $R)
    & $add 'Set-TaskEnabled' @('TaskPath', 'TaskName', 'Enabled') @($A, $R)
    & $add 'Get-DeviceJoinState' @() @($A)
    & $add 'Get-DomainMembership' @() @($A)
    & $add 'Get-MdmEnrollments' @() @($A)
    & $add 'Get-EnabledLocalUserCount' @() @($A)
    # cmdlets, members, prefixes
    $reg = @('Get-UserRegistryValue', 'Get-UserRegistryValueNames')
    & $add 'Get-Item' $lit @('Get-UserRegistryValue', 'Get-UserRegistryValueNames', 'Get-MachinePolicyValue')
    & $add '.GetValueNames' $null @('Get-UserRegistryValue', 'Get-UserRegistryValueNames', 'Get-MachinePolicyValue', 'Get-MdmEnrollments')
    & $add '.GetValueKind' $null @('Get-UserRegistryValue', 'Get-MachinePolicyValue')
    & $add '.GetValue' $null @('Get-UserRegistryValue', 'Get-MachinePolicyValue', 'Get-MdmEnrollments')
    & $add 'HKCU:\' $null @('Get-UserRegistryValue', 'Get-UserRegistryValueNames', 'Set-UserRegistryValue')
    & $add 'HKLM:\' $null @('Get-MachinePolicyValue', 'Set-MachinePolicyValue', 'Get-MdmEnrollments')
    & $add 'Set-ItemProperty' @('LiteralPath', 'Name', 'Value', 'Type', 'ErrorAction') @('Set-UserRegistryValue', 'Set-MachinePolicyValue')
    & $add 'Remove-ItemProperty' @('LiteralPath', 'Name', 'ErrorAction') @('Set-UserRegistryValue', 'Set-MachinePolicyValue')
    & $add 'New-Item' @('Path', 'ErrorAction') @('Set-MachinePolicyValue')
    $o['New-Item']['Write-WindowsSettingsFile'] = @('Path', 'ItemType', 'ErrorAction')
    & $add 'Remove-Item' $lit @('Set-MachinePolicyValue')
    & $add 'Get-ChildItem' $lit @('Get-MdmEnrollments')
    & $add 'Get-AppxPackage' @('Name', 'ErrorAction') @('Get-UserAppxPackage')
    & $add 'Remove-AppxPackage' @('Package', 'ErrorAction') @('Remove-UserAppxPackage')
    & $add 'Add-AppxPackage' @('RegisterByFamilyName', 'MainPackage', 'ErrorAction') @('Register-UserAppxPackage')
    & $add 'Get-Content' @('LiteralPath', 'Raw', 'Encoding', 'ErrorAction') @('Read-WindowsSettingsFile')
    & $add 'ConvertFrom-Json' @('InputObject') @('Read-WindowsSettingsFile')
    & $add 'ConvertTo-Json' @('InputObject', 'Depth') @('Write-WindowsSettingsFile')
    & $add 'Import-PowerShellDataFile' $lit @('Read-WindowsSettingsCatalogue')
    & $add 'Get-CimInstance' @('ClassName=Win32_Service', 'Filter', 'Property', 'ErrorAction') @('Get-ServiceStart')
    $o['Get-CimInstance']['Get-DomainMembership'] = @('ClassName=Win32_ComputerSystem', 'Property', 'ErrorAction')
    $o['Get-CimInstance']['Get-EnabledLocalUserCount'] = @('ClassName=Win32_UserAccount', 'Filter', 'Property', 'ErrorAction')
    & $add 'Get-ScheduledTask' @('TaskPath', 'TaskName', 'ErrorAction') @('Get-TaskState')
    & $add 'Set-Service' @('Name', 'StartupType', 'ErrorAction') @('Set-ServiceStart')
    & $add 'Stop-Service' @('Name', 'ErrorAction') @('Set-ServiceStart')
    & $add 'Start-Service' @('Name', 'ErrorAction') @('Set-ServiceStart')
    & $add 'Disable-ScheduledTask' @('TaskPath', 'TaskName', 'ErrorAction') @('Set-TaskEnabled')
    & $add 'Enable-ScheduledTask' @('TaskPath', 'TaskName', 'ErrorAction') @('Set-TaskEnabled')
    # trusted and pinned helpers
    & $add 'Write-NewFile' $null @('Write-WindowsSettingsFile')
    & $add 'Get-RestorePoints' $null @($A)
    & $add 'New-RestorePoint' $null @($A)
    & $add 'Invoke-Native' @('ExePath', 'Arguments', 'TimeoutSeconds') @('Get-DeviceJoinState')
    $o['Invoke-Native']['Test-WindowsSettingsCommitted'] = @('ExePath', 'Arguments', 'WorkingDirectory', 'TimeoutSeconds')
    & $add 'Resolve-Program' @('Name') @('Test-WindowsSettingsCommitted')
    $c = @{
        'Say'             = $null
        'Get-UtcStamp'    = $null
        'Test-IsAdmin'    = $null
        'Join-Path'       = @('Path', 'ChildPath')
        'New-Object'      = @('TypeName', 'ArgumentList')
        'ForEach-Object'  = @('Process')
        'Where-Object'    = @('FilterScript')
        'Select-Object'   = @('First', 'ExpandProperty')
    }
    return @{ Scope = @(); Owners = $o; Common = $c; TypeAllow = $BoundaryTypeAllow; Switches = $BoundarySwitches }
}

$script:BSeeds = @{}
function Add-BSeedCount {
    param([string]$Rule, [bool]$Neg)
    if (-not $script:BSeeds.ContainsKey($Rule)) { $script:BSeeds[$Rule] = @(0, 0) }
    $i = 0
    if ($Neg) { $i = 1 }
    $script:BSeeds[$Rule][$i]++
}

function Get-BText {
    param([string]$Text, $Maps)
    $t = $null; $e = $null
    $a = [Management.Automation.Language.Parser]::ParseInput($Text, [ref]$t, [ref]$e)
    if ($e.Count -ne 0) { throw "seed does not parse: $($e[0].Message)" }
    if (-not $Maps) { $Maps = New-BFixtureMaps }
    $Maps.Scope = @(Get-BReachable $a $BoundaryEntries)
    $v = @(Get-BoundaryViolations $a $Maps)
    return @{ V = $v; Ast = $a; Maps = $Maps }
}

function Edit-BFirst {
    param([string]$Text, [string]$Find, [string]$Rep)
    $i = $Text.IndexOf($Find)
    Assert-True ($i -ge 0) "seed target exists: $Find"
    return $Text.Substring(0, $i) + $Rep + $Text.Substring($i + $Find.Length)
}

function Assert-BCaught {
    param([string]$Rule, [string]$Text, [string]$Label)
    $r = Get-BText $Text
    $hits = @($r.V | Where-Object -FilterScript { $_ -like "$Rule *" })
    Assert-True ($hits.Count -ge 1) "$Rule catches: $Label (violations: $($r.V -join ' | '))"
    Add-BSeedCount $Rule $false
}

function Assert-BInject {
    param([string]$Rule, [string]$Code)
    Assert-BCaught $Rule (Edit-BFirst $BoundaryFixture '# SEED-ANCHOR' $Code) $Code
}

function Assert-BInjectLike {
    param([string]$Rule, [string]$Like, [string]$Code)
    $r = Get-BText (Edit-BFirst $BoundaryFixture '# SEED-ANCHOR' $Code)
    $hits = @($r.V | Where-Object -FilterScript { $_ -like "$Rule *$Like*" })
    Assert-True ($hits.Count -ge 1) "$Rule catches ($Like): $Code (violations: $($r.V -join ' | '))"
    Add-BSeedCount $Rule $false
}

function Assert-BEdit {
    param([string]$Rule, [string]$Find, [string]$Rep)
    Assert-BCaught $Rule (Edit-BFirst $BoundaryFixture $Find $Rep) "$Find -> $Rep"
}

function Assert-BClean {
    param([string]$Rule, [string]$Code)
    $r = Get-BText (Edit-BFirst $BoundaryFixture '# SEED-ANCHOR' $Code)
    Assert-Eq $r.V.Count 0 "negative seed '$Code' is clean: $($r.V -join ' | ')"
    Add-BSeedCount $Rule $true
}

function Get-BMapProblemsFor {
    param($Maps, [string]$Text)
    $r = Get-BText $Text $Maps
    return @(Get-BoundaryMapProblems $r.Ast $r.Maps $null $S1Safe)
}

Test-Case 'BR0 fixture: the clean fixture has no violations and no map problems; the scope is the reachable set; rules apply inside the scope only' {
    $r = Get-BText $BoundaryFixture
    Assert-Eq $r.V.Count 0 "clean fixture: $($r.V -join ' | ')"
    Assert-Eq (@(Get-BoundaryScopeProblems $r.Ast $r.Maps)).Count 0 'scope equals the reachable set'
    Assert-Eq (@(Get-BoundaryMapProblems $r.Ast $r.Maps $null $S1Safe)).Count 0 "map problems: $(@(Get-BoundaryMapProblems $r.Ast $r.Maps $null $S1Safe) -join ' | ')"
    Assert-True (-not ($r.Maps.Scope -ccontains 'Other-Fixture')) 'Other-Fixture is out of scope (it holds defects on purpose)'
    foreach ($w in @('Get-UserRegistryValue', 'Set-ServiceStart', 'Get-ProbeLocal', 'Invoke-WindowsSnapshot', 'Get-DeviceJoinState')) { Assert-True ($r.Maps.Scope -ccontains $w) "$w is in scope" }
    foreach ($w in @('Say', 'Invoke-Native', 'Resolve-Program', 'Write-NewFile', 'Invoke-BootstrapRun')) { Assert-True (-not ($r.Maps.Scope -ccontains $w)) "$w is outside the scope (trusted, pinned or dispatcher)" }
    # the same defects become violations as soon as the function is reachable
    $t = Edit-BFirst $BoundaryFixture '# SEED-ANCHOR' 'Other-Fixture -Probe $Probe'
    Assert-True (@((Get-BText $t).V | Where-Object -FilterScript { $_ -like 'R3 *' }).Count -ge 1) 'Other-Fixture reached: its & is flagged'
    Assert-True (@((Get-BText $t).V | Where-Object -FilterScript { $_ -like 'R5 *' }).Count -ge 1) 'Other-Fixture reached: its $PSDefaultParameterValues is flagged'
    # a scope list that differs from the reachable set is reported
    $r.Maps.Scope = @($r.Maps.Scope | Where-Object -FilterScript { $_ -cne 'Get-ProbeLocal' })
    Assert-True (@(Get-BoundaryScopeProblems $r.Ast $r.Maps).Count -ge 1) 'a missing scope name is reported'
    $r.Maps.Scope = @($r.Maps.Scope) + 'Other-Fixture'
    Assert-True (@(Get-BoundaryScopeProblems $r.Ast $r.Maps).Count -ge 1) 'an extra scope name is reported'
}

Test-Case 'BR1 closed command map: owners, precedence, entry branches, snapshot reachability, pins, meta-tests (seeded)' {
    # a seam called by a function that is not an owner, even inside scope (precedence over "scope function")
    Assert-BEdit 'R1' '    if ($RemoveApps) { Say ''step W: -RemoveApps needs -WindowsSettings''; return 2 }' ''
    Assert-BEdit 'R1' '    if ($DisableTeamsStartup) { Say ''step W: -DisableTeamsStartup needs -WindowsSettings -SetupProfile work''; return 2 }' ''
    Assert-BEdit 'R1' 'if ($RemoveApps) { Say ''step W: -RemoveApps needs -WindowsSettings''; return 2 }' 'if ($RemoveApps) { return Invoke-WindowsSettings -Label ''x'' -SetupProfile ''work'' }'
    Assert-BInject 'R1' 'Remove-UserAppxPackage -Package $Probe'
    Assert-BInject 'R1' 'Get-UserRegistryValue -Key $Probe -Name $Probe'
    Assert-BInject 'R1' 'Get-Item -LiteralPath $Probe'
    Assert-BInject 'R1' 'Invoke-Native -ExePath $Probe'
    Assert-BInject 'R1' 'Unknown-Command $Probe'
    Assert-BInject 'R1' 'Invoke-WindowsRollback -Label $Probe'
    Assert-BInject 'R1' '$x = Other-Unknown'
    # step S (reachable from the snapshot) calls a writer, directly and through a helper
    Assert-BInject 'R1' 'Set-UserRegistryValue -Key $Probe -Name $Probe -Value 1 -Type ''DWord'' -Remove $false'
    Assert-BEdit 'R1' '# SNAP-ANCHOR' 'Set-UserRegistryValue -Key $Label -Name $Label -Value 1 -Type ''DWord'' -Remove $false'
    Assert-BEdit 'R1' '# SNAP-ANCHOR' 'Set-ServiceStart -Name $Label -StartupType ''Disabled'''
    # exact keys: case matters, entry names and dynamic names are rejected
    Assert-BEdit 'R1' 'Set-Service -Name $Name' 'set-service -Name $Name'
    Assert-BEdit 'R1' 'Stop-Service -Name $Name' 'STOP-SERVICE -Name $Name'
    Assert-BEdit 'R1' 'Get-ProbeLocal -Probe $Label' 'get-probelocal -Probe $Label'
    # whole script: seam callers and entry callers outside scope
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Outside-Caller { Get-UserRegistryValue -Key 'a' -Name 'b' }`n") 'a W seam called outside its owners, outside scope'
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Outside-Entry { Invoke-WindowsSnapshot -Label 'a' }`n") 'an entry point called outside its dispatcher branch'
    Assert-BEdit 'R1' 'return Invoke-WindowsRollback -Label $WindowsRollback' 'return Invoke-WindowsSnapshot -Label $WindowsRollback'
    # define-once, top level, no shadowing
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Get-ProbeLocal { }`n") 'a duplicate definition'
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Get-UserRegistryValue { }`n") 'a duplicate seam definition'
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Join-Path { }`n") 'a script function named like an external common key'
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Get-Item { }`n") 'a script function named like an external owned key'
    Assert-BCaught 'R1' ($BoundaryFixture + "`nfunction Set-Item { }`n") 'a script function named like an R3 command'
    Assert-BCaught 'R1' ($BoundaryFixture + "`nif (`$true) { function Say { } }`n") 'a helper defined below top level'
    # dispatcher branches: only entry-point calls, Say and return; the switch must be read positively
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot) { [IO.File]::Delete(''x''); return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'return Invoke-WindowsRollback -Label $WindowsRollback -MachineWide:$MachineWide' 'return [IO.File]::Delete(''x'')'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot) { $q = 1; return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot) { Get-Date; return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot) { Say ([IO.File]::Exists(''x'')); return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'if ($WindowsRollback) {' 'if (-not $WindowsRollback) {'
    Assert-BEdit 'R1' 'if ($WindowsRollback) {' 'if (!$WindowsRollback) {'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot -eq $true) { return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot -or $DryRun) { return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($DryRun -and $WindowsSnapshot) { return Invoke-WindowsSnapshot'
    Assert-BEdit 'R1' 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot -eq $false) { return Invoke-WindowsSnapshot'
    $cond = Get-BText (Edit-BFirst $BoundaryFixture 'if ($WindowsSnapshot) { return Invoke-WindowsSnapshot' 'if ($WindowsSnapshot -and $DryRun) { return Invoke-WindowsSnapshot')
    Assert-Eq $cond.V.Count 0 "a bare switch followed by -and is accepted: $($cond.V -join ' | ')"
    Add-BSeedCount 'R1' $true
    # writer reachability, isolated from the owner rule: the writer is listed as owned by the snapshot side
    foreach ($wcase in @(
            @('Invoke-WindowsSnapshot', '# SNAP-ANCHOR', 'Set-UserRegistryValue -Key $Label -Name $Label -Value 1 -Type ''DWord'' -Remove $false', 'Set-UserRegistryValue', @('Key', 'Name', 'Value', 'Type', 'Remove')),
            @('Invoke-WindowsSnapshot', '# SNAP-ANCHOR', 'Set-ServiceStart -Name $Label -StartupType ''Disabled''', 'Set-ServiceStart', @('Name', 'StartupType')),
            @('Get-ProbeLocal', '# SEED-ANCHOR', 'Remove-UserAppxPackage -Package $Probe', 'Remove-UserAppxPackage', @('Package')))) {
        $wm = New-BFixtureMaps
        $wm.Owners[$wcase[3]][$wcase[0]] = $wcase[4]
        $wr = Get-BText (Edit-BFirst $BoundaryFixture $wcase[1] $wcase[2]) $wm
        Assert-Eq (@($wr.V | Where-Object -FilterScript { $_ -like '*is called in*' })).Count 0 "the owner rule is satisfied for $($wcase[3]) in $($wcase[0])"
        Assert-True (@($wr.V | Where-Object -FilterScript { $_ -like 'R1 *writer seam*reachable from Invoke-WindowsSnapshot*' }).Count -ge 1) "the snapshot writer rule catches $($wcase[3]) via $($wcase[0])"
        Add-BSeedCount 'R1' $false
    }
    # every W seam must be in $SeamNames
    $sr = Get-BText $BoundaryFixture
    $sfn = @($sr.Ast.FindAll({ param($n) $n -is $BtFn }, $true) | ForEach-Object -Process { $_.Name })
    $sn = @($sr.Maps.Owners.Keys | Where-Object -FilterScript { ($sfn -ccontains $_) -and ($BoundaryTrusted -cnotcontains $_) })
    Assert-True ($sn.Count -ge 15) "the fixture has W seams ($($sn.Count))"
    Assert-Eq (@(Get-BoundaryMapProblems $sr.Ast $sr.Maps $sn $S1Safe)).Count 0 'a complete $SeamNames list has no problem'
    Add-BSeedCount 'R1' $true
    foreach ($drop in @('Set-ServiceStart', 'Get-UserRegistryValue', 'Get-DeviceJoinState')) {
        $p = @(Get-BoundaryMapProblems $sr.Ast $sr.Maps @($sn | Where-Object -FilterScript { $_ -cne $drop }) $S1Safe | Where-Object -FilterScript { $_ -like "*$drop*SeamNames*" })
        Assert-True ($p.Count -ge 1) "a seam missing from `$SeamNames is reported: $drop"
        Add-BSeedCount 'R1' $false
    }
    # negative seeds
    Assert-BClean 'R1' 'Say ''x'''
    Assert-BClean 'R1' '$stamp = Get-UtcStamp'
    Assert-BClean 'R1' '$ok = Test-IsAdmin'
    Assert-BClean 'R1' '$probe2 = Join-Path -Path $Probe -ChildPath ''x'''
    # meta-tests on the fixture maps (map mutations)
    $lit2 = @('LiteralPath', 'ErrorAction')
    $mutations = @(
        @('a stale key (never used)', { param($m) $m.Owners['Get-Date'] = @{ 'Get-ProbeLocal' = @('Date') } }),
        @('an owner that does not use its key', { param($m) $m.Owners['Get-Item']['Get-ServiceStart'] = @('LiteralPath', 'ErrorAction') }),
        @('a stale common key', { param($m) $m.Common['Get-Date'] = @('Date') }),
        @('a null list outside member, prefix and trusted keys', { param($m) $m.Owners['Set-Service']['Set-ServiceStart'] = $null }),
        @('a bad key grammar', { param($m) $m.Owners['get item'] = @{ 'Get-ProbeLocal' = @('x') } }),
        @('a key that is both owned and common', { param($m) $m.Common['Get-Item'] = $lit2 }),
        @('an R3 command as a map key', { param($m) $m.Owners['Start-Process'] = @{ 'Get-ProbeLocal' = @('FilePath') } }),
        @('an external common key that is not in the S1 safe list', { param($m) $m.Common['Get-Date'] = @('Date') }),
        @('a non-canonical parameter (case)', { param($m) $m.Owners['Get-Item']['Get-UserRegistryValue'] = @('literalpath', 'ErrorAction') }),
        @('a parameter alias instead of the canonical name', { param($m) $m.Owners['Get-Item']['Get-UserRegistryValue'] = @('PSPath', 'ErrorAction') }),
        @('a switch parameter that is not in $BoundarySwitches', { param($m) $m.Owners['Get-Content']['Read-WindowsSettingsFile'] = @('LiteralPath', 'Raw', 'Encoding', 'ErrorAction', 'Force') }),
        @('a $BoundarySwitches entry that is not a switch', { param($m) $m.Switches = @('Raw', 'RegisterByFamilyName', 'ErrorAction') }),
        @('a non-canonical parameter of a script-function seam', { param($m) $m.Owners['Get-UserRegistryValue']['Invoke-WindowsSnapshot'] = @('key', 'Name') }),
        @('a member key with a non-null list', { param($m) $m.Owners['.GetValue']['Get-UserRegistryValue'] = @('x') }),
        @('an unresolvable cmdlet', { param($m) $m.Owners['Get-Nonexistent'] = @{ 'Get-ProbeLocal' = @('Name') } })
    )
    foreach ($mu in $mutations) {
        $m = New-BFixtureMaps
        & $mu[1] $m
        $p = @(Get-BMapProblemsFor $m $BoundaryFixture | Where-Object -FilterScript { $_ -like 'R1*' })
        Assert-True ($p.Count -ge 1) "map meta-test catches: $($mu[0])"
        Add-BSeedCount 'R1' $false
    }
    # a stale pair in the real direction: remove the only use of a key from the source
    $t = Edit-BFirst $BoundaryFixture '$ids = $roots | Where-Object -FilterScript { $_.GetValueNames() -contains ''ProviderID'' } | ForEach-Object -Process { $_.GetValue(''ProviderID'') } | Select-Object -First 1' '$ids = $roots'
    $p = @(Get-BMapProblemsFor (New-BFixtureMaps) $t | Where-Object -FilterScript { $_ -like 'R1*' })
    Assert-True ($p.Count -ge 1) 'a key whose use was removed from the source is reported as unused'
    Add-BSeedCount 'R1' $false
    # the clean fixture maps pass the same meta-test
    Assert-Eq (@(Get-BMapProblemsFor (New-BFixtureMaps) $BoundaryFixture)).Count 0 'clean maps have no problems'
    Add-BSeedCount 'R1' $true
}

Test-Case 'BR2 registry literals only exactly HKCU:\ and HKLM:\ in their owners, with inline Join-Path path arguments (seeded)' {
    Assert-BEdit 'R2' '(Join-Path -Path ''HKCU:\'' -ChildPath $Key)' '$Key'
    Assert-BEdit 'R2' '(Join-Path -Path ''HKCU:\'' -ChildPath $Key)' '"HKCU:\$Key"'
    Assert-BEdit 'R2' '(Join-Path -Path ''HKCU:\'' -ChildPath $Key)' '(Join-Path ''HKCU:\'' $Key)'
    Assert-BEdit 'R2' '(Join-Path -Path ''HKCU:\'' -ChildPath $Key)' '(Join-Path -Path ''HKLM:\'' -ChildPath $Key)'
    Assert-BEdit 'R2' '(Join-Path -Path ''HKCU:\'' -ChildPath $Key)' '(Join-Path -Path $env:SystemRoot -ChildPath $Key)'
    Assert-BEdit 'R2' '(Join-Path -Path ''HKLM:\'' -ChildPath $Key)' '(Join-Path -Path ''HKCU:\'' -ChildPath $Key)'
    Assert-BInject 'R2' '$p = Join-Path -Path ''HKCU:\'' -ChildPath $Probe'
    Assert-BInject 'R2' '$p = ''HKCU:\Software\x'''
    Assert-BInject 'R2' '$p = "HKCU:\$Probe"'
    Assert-BInject 'R2' '$p = ''HKLM:\SOFTWARE'''
    Assert-BInject 'R2' '$p = ''HKEY_CURRENT_USER\Software'''
    Assert-BInject 'R2' '$p = ''Registry::HKEY_LOCAL_MACHINE'''
    Assert-BInject 'R2' '$p = ''HKU:\.DEFAULT'''
    Assert-BInject 'R2' '$p = ''HKCR:\x'''
    Assert-BInject 'R2' '$p = ''HKCC:\x'''
    Assert-BInject 'R2' '$p = ''hkcu:\x'''
    Assert-BInject 'R2' '$p = ''HKCU:'''
    Assert-BInject 'R2' '$p = ''HKCU:\'''
    # the Set-MachinePolicyValue New-Item -Path rule
    Assert-BEdit 'R2' '[void](New-Item -Path (Join-Path -Path ''HKLM:\'' -ChildPath $Key) -ErrorAction Stop)' '[void](New-Item -Path $Key -ErrorAction Stop)'
    Assert-BEdit 'R2' 'Remove-Item -LiteralPath (Join-Path -Path ''HKLM:\'' -ChildPath $Key)' 'Remove-Item -LiteralPath $Key'
    Assert-BClean 'R2' '$s = ''SOFTWARE\Microsoft\Windows'''
    Assert-BClean 'R2' '$s = ''HKCUx'''
    Assert-BClean 'R2' '$s = ''The HKLM word without a colon'''
}

Test-Case 'BR3 banned commands, operators, members, dynamic access, member assignment, redirection (seeded)' {
    foreach ($c in $BoundaryR3Commands) { Assert-BInject 'R3' $c }
    foreach ($s in @('& $x', '. $x', '& { }', '& ''Set-Service''', '& $Probe', '. $Probe', '& ''x'' $Probe', '. { }')) { Assert-BInject 'R3' $s }
    foreach ($m in $BoundaryR3Members) { Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$null = $o.' + $m) }
    foreach ($m in @('OpenSubKey', 'DeleteValue', 'SetValue', 'GetMethod', 'Invoke', 'InvokeProvider')) { Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$null = $o.' + $m + '($Probe)') }
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$null = $o.GetRuntimeMethods()')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$null = $o.GetType(''x'')')
    Assert-BInject 'R3' ('$t = $Probe' + "`n" + '$null = $t::LocalMachine')
    Assert-BInject 'R3' ('$t = $Probe' + "`n" + '$null = $t::Parse($Probe)')
    Assert-BInject 'R3' '$null = [Microsoft.Win32.Registry]::CurrentUser'
    Assert-BInject 'R3' '$null = [Environment]::MachineName'
    Assert-BInject 'R3' ('$f = $Probe' + "`n" + '$f.IsReadOnly = $true')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$o.IsReadOnly, $y = $true, 1')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$y, $o.IsReadOnly = 1, $true')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '[bool]$o.IsReadOnly, $y = $true, 1')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$o.A, $o.B = 1, 2')
    # parenthesised and nested targets are the same targets; ++ and -- go through the same normalisation
    foreach ($form in @('($o.IsReadOnly) = $true', '[bool]($o.IsReadOnly) = $true', '$y, ($o.IsReadOnly) = 1, $true', '(($o.A)) = 1', '($o.A), ($o.B) = 1, 2', '[int]($o.A), $y = 1, 2', '($o.Count)++', '--($o.Count)', '(($o.Count))++')) {
        Assert-BInject 'R3' ('$o = $Probe' + "`n" + $form)
    }
    foreach ($form in @('($env:Path) = ''x''', '($script:RepoRoot) = ''x''', '$y, ($env:Path) = 1, ''x''', '(($env:Path)) = ''x''', '($global:g) = 1', '[string]($env:Path) = ''x''', '($env:Path)++', '(($script:RepoRoot))++')) {
        Assert-BInject 'R5' $form
    }
    Assert-BClean 'R3' ('$h = @{}' + "`n" + '($h)[''a''] = 1')
    Assert-BClean 'R3' ('$h = @{}' + "`n" + '$h[''a''] = 1')
    Assert-BClean 'R3' ('$y = 1' + "`n" + '($y) = 2')
    Assert-BClean 'R3' ('$y = 1' + "`n" + '$y++')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$o.Count++')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$o.Count--')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '++$o.Count')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$o.Count += 1')
    Assert-BInject 'R3' '''x'' > C:\tmp\o.txt'
    Assert-BInject 'R3' '''x'' >> C:\tmp\o.txt'
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$null = $o.ForEach(''Delete'')')
    Assert-BInject 'R3' ('$o = $Probe' + "`n" + '$null = $o.Where(''x'')')
    Assert-BInject 'R3' ('$o = $Probe; $m = ''Delete''' + "`n" + '$o.$m()')
    Assert-BInject 'R3' ('$o = $Probe; $m = ''Name''' + "`n" + '$null = $o.$m')
    Assert-BInject 'R3' '$d = data { ''x'' }'
    # owned members are R1-owned: a non-owner may not use them
    Assert-BInject 'R1' ('$o = $Probe' + "`n" + '$null = $o.GetValue(''x'')')
    Assert-BInject 'R1' ('$o = $Probe' + "`n" + '$null = $o.GetValueNames()')
    Assert-BInject 'R1' ('$o = $Probe' + "`n" + '$null = $o.getvalue(''x'')')
    # negative seeds
    Assert-BClean 'R3' '$enc = [Text.UTF8Encoding]::new($false)'
    Assert-BClean 'R3' ('$enc = [Text.UTF8Encoding]::new($false)' + "`n" + '$b = $enc.GetBytes(''x'')')
    Assert-BClean 'R3' 'Say ''x'' 2>&1'
    Assert-BClean 'R3' ('$h = @{}' + "`n" + '$h[''k''] = 1')
    Assert-BClean 'R3' ('$l = New-Object -TypeName ''System.Collections.Generic.List[string]''' + "`n" + '$l.Add(''x'')')
    Assert-BClean 'R3' '$n = [IO.Path]::GetFileName($Probe)'
    Assert-BClean 'R3' ('$o = $Probe' + "`n" + '$s = $o.GetEnumerator()')
    Assert-BClean 'R3' ('$o = @(1, 2)' + "`n" + '$c = $o.Count')
    Assert-BClean 'R3' ('$o = @(1, 2)' + "`n" + '$f = $o.ForEach({ $_ })')
    Assert-BClean 'R3' ('$o = $Probe' + "`n" + '$t = $o.GetType()')
    Assert-BClean 'R3' ('$h = @{}' + "`n" + '$h[''a''], $y = 1, 2')
    Assert-BClean 'R3' '$s = [string]::Join('','', @(''a'', ''b''))'
}

Test-Case 'BR4 closed type allowlist, attributes, type definitions, using (seeded)' {
    foreach ($ty in @('wmiclass', 'wmi', 'adsi', 'type', 'scriptblock', 'powershell', 'Environment', 'Microsoft.Win32.Registry', 'IO.File', 'Reflection.Assembly', 'Diagnostics.Process', 'xml', 'regex', 'ref', 'System.Environment', 'Collections.ArrayList')) {
        Assert-BInject 'R4' ('$z = [' + $ty + ']$Probe')
    }
    Assert-BInject 'R4' '$null = [Microsoft.Win32.Registry]::CurrentUser'
    Assert-BInject 'R4' ('$z = $Probe -as ''Microsoft.Win32.Registry''')
    Assert-BInject 'R4' ('$z = $Probe -is ''string''')
    Assert-BInject 'R4' ('$z = $Probe -isnot ''string''')
    Assert-BInject 'R4' ('$z = $Probe -as [type]')
    Assert-BInject 'R4' ('$z = $Probe -is [Microsoft.Win32.Registry]')
    Assert-BInject 'R4' '$l = [Collections.Generic.List[type]]::new()'
    Assert-BInject 'R4' '$l = [Collections.Generic.Dictionary[string, string]]::new()'
    Assert-BInject 'R4' '$l = [Collections.Generic.List[Microsoft.Win32.Registry]]::new()'
    Assert-BInject 'R4' '$l = [type[]]@()'
    Assert-BInject 'R4' '$l = New-Object -TypeName ''System.Collections.Generic.List`1[System.String]'''
    Assert-BInject 'R4' '$l = New-Object -TypeName ''System.Collections.Generic.Dictionary[string,string]'''
    Assert-BInject 'R4' '$l = New-Object -TypeName ''Microsoft.Win32.Registry'''
    Assert-BInject 'R4' '$l = New-Object -TypeName $Probe'
    Assert-BInject 'R4' '$l = New-Object -TypeName "System.Collections.Generic.List[string]$Probe"'
    Assert-BInject 'R4' '$l = New-Object -TypeName ''string[;'''
    Assert-BEdit 'R4' 'param([string]$Probe)' 'param([Parameter()][string]$Probe)'
    Assert-BEdit 'R4' 'param([string]$Probe)' 'param([CmdletBinding()][string]$Probe)'
    Assert-BEdit 'R4' 'param([string]$Probe)' 'param([Microsoft.Win32.Registry]$Probe)'
    Assert-BEdit 'R4' 'param([string]$Probe)' 'param([type]$Probe)'
    Assert-BCaught 'R4' ('using namespace System' + "`n" + $BoundaryFixture) 'using namespace'
    Assert-BCaught 'R4' ('using namespace System.Text' + "`n" + $BoundaryFixture) 'using module'
    Assert-BCaught 'R4' ($BoundaryFixture + "`nclass Evil { }`n") 'a type definition'
    Assert-BCaught 'R4' ($BoundaryFixture + "`nenum Color { Red }`n") 'an enum definition'
    # negative seeds
    Assert-BClean 'R4' '$enc = [Text.UTF8Encoding]::new($false)'
    Assert-BClean 'R4' '$s = [string[]]@(''a'')'
    Assert-BClean 'R4' '$i = [int]''5'''
    Assert-BClean 'R4' '$i = [System.Int32]5'
    Assert-BClean 'R4' '$l = [Collections.Generic.List[string]]::new()'
    Assert-BClean 'R4' '$l = [System.Collections.Generic.List[int]]::new()'
    Assert-BClean 'R4' '$l = [System.Collections.Generic.List[string[]]]::new()'
    Assert-BClean 'R4' '$z = $Probe -is [string]'
    Assert-BClean 'R4' '$z = $Probe -as [int]'
    Assert-BClean 'R4' '$z = [ordered]@{ a = 1 }'
    Assert-BClean 'R4' '$z = [datetime]::UtcNow'
    Assert-BClean 'R4' '$z = [BitConverter]::ToString([byte[]]@(1, 2))'
    Assert-BClean 'R4' '$z = [pscustomobject]@{ a = 1 }'
    Assert-BClean 'R4' '$z = [IO.Path]::GetFileName($Probe)'
    Assert-BClean 'R4' '$z = [hashtable]@{}'
    Assert-BClean 'R4' '$z = [bool]$Probe'
    Assert-BClean 'R4' '$z = [char]65'
    Assert-BClean 'R4' '$z = [long]1'
    Assert-BClean 'R4' '[void]$Probe'
}

Test-Case 'BR5 session state: locals only, no automatic or preference locals, no qualified writes, no prefixes, no aliases (seeded)' {
    Assert-BInject 'R5' '$null = $PSCmdlet.SessionState.InvokeCommand'
    Assert-BInject 'R5' '$z = $RepoRoot'
    Assert-BInject 'R5' '$z = $Unknown'
    Assert-BInject 'R5' '$Profile = 1'
    Assert-BInject 'R5' '$PSDefaultParameterValues = @{ ''*:ErrorAction'' = ''Ignore'' }'
    Assert-BInject 'R5' '$ErrorActionPreference = ''Ignore'''
    Assert-BInject 'R5' '$VerbosePreference = ''Continue'''
    Assert-BInject 'R5' '$Host = 1'
    Assert-BInject 'R5' '$args = 1'
    Assert-BInject 'R5' '$input = 1'
    Assert-BInject 'R5' '$MyInvocation = 1'
    Assert-BInject 'R5' '$ExecutionContext = 1'
    Assert-BInject 'R5' '$PSBoundParameters = 1'
    Assert-BInject 'R5' '$true = 1'
    Assert-BInject 'R5' '$null = $ExecutionContext.SessionState'
    Assert-BInject 'R5' '$null = $global:ExecutionContext'
    Assert-BInject 'R5' '$z = ${C:\x}'
    Assert-BInject 'R5' '$z = ${function:Say}'
    Assert-BInject 'R5' '$z = $variable:Probe'
    Assert-BInject 'R5' '$env:X = 1'
    Assert-BInject 'R5' '$global:y = 1'
    Assert-BInject 'R5' '$z = $global:y'
    Assert-BInject 'R5' '$script:y = 1'
    Assert-BInject 'R5' '$script:y++'
    Assert-BInject 'R5' '$env:Path += ''x'''
    Assert-BInject 'R5' '$z = ''alias:ls'''
    Assert-BInject 'R5' '$z = ''function:Say'''
    Assert-BInject 'R5' '$z = ''variable:Probe'''
    Assert-BInject 'R5' '$z = ''env:Path'''
    Assert-BInject 'R5' '$z = ''cert:\CurrentUser'''
    Assert-BInject 'R5' '$z = ''wsman:localhost'''
    Assert-BInject 'R5' 'gci'
    Assert-BInject 'R5' 'ls'
    Assert-BInject 'R5' '%'
    Assert-BInject 'R5' 'iex'
    Assert-BInject 'R5' 'foreach ($Error in @(1)) { }'
    Assert-BEdit 'R5' 'param([string]$Key, [string]$Name)' 'param([string]$Key, [string]$Name, [string]$Profile)'
    Assert-BEdit 'R5' '$committed = Test-WindowsSettingsCommitted -Path $Label' '$committed = Test-WindowsSettingsCommitted -Path $Other'
    # entry-point parameters mirror the switch names
    Assert-BEdit 'R5' 'param([string]$Label, [switch]$DryRun)' 'param([string]$Label, [switch]$DryRun, [string]$Extra)'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$script:RepoRoot[''x''] = 1'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$script:RepoRoot[''x''] += 1'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$script:RepoRoot[''x'']++'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$null = $script:RepoRoot.Replace(''a'', ''b'')'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$null = $script:RepoRoot.Clear()'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$null = $script:RepoRoot[0].Insert(0, ''x'')'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$global:X[0] = 1'
    Assert-BInjectLike 'R5' 'BoundaryScriptReads' '$z = $script:K'
    Assert-BInjectLike 'R5' 'BoundaryScriptReads' '$null = $script:L.Add(1)'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$null = $( $script:RepoRoot ).Clear()'
    Assert-BInjectLike 'R5' 'SCRIPT-STATE' '$null = @($script:RepoRoot)[0].Clear()'
    Assert-BEdit 'R5' '[switch]$RemoveApps, [switch]$DisableTeamsStartup)' '[switch]$RemoveAppx, [switch]$DisableTeamsStartup)'
    # negative seeds
    Assert-BClean 'R5' ('$h = @{}' + "`n" + '$h[''k''] = 1')
    Assert-BClean 'R5' ('$z = $script:RepoRoot')
    Assert-BClean 'R5' '$z = $script:RepoRoot.Length'
    Assert-BClean 'R5' '$z = [string]::Concat(''a'', ''b'')'
    Assert-BClean 'R5' ('$z = $env:SystemRoot')
    Assert-BClean 'R5' ('$z = $env:LOCALAPPDATA')
    Assert-BClean 'R5' '$z = @(1, 2) | ForEach-Object -Process { $_ }'
    Assert-BClean 'R5' '$z = @(1, 2) | ForEach-Object -Process { $PSItem }'
    Assert-BClean 'R5' '$z = $true -and $false'
    Assert-BClean 'R5' '$z = $PID'
    Assert-BClean 'R5' '$z = ''x'' -match ''y''; $q = $Matches'
    Assert-BClean 'R5' 'foreach ($item in @(1, 2)) { $z = $item }'
    Assert-BClean 'R5' '$a1, $b1 = @(1, 2); $z = $a1 + $b1'
    Assert-BClean 'R5' '$i = 0; $i++'
    Assert-BClean 'R5' '[int]$typed = 1'
    Assert-BClean 'R5' '$f = { param($x1) $x1 }'
    Assert-BClean 'R5' '$DryRun = 1'
    $r5 = Get-BText (Edit-BFirst $BoundaryFixture 'param([string]$Probe)' 'param([string]$Probe, [switch]$DryRun)')
    Assert-Eq $r5.V.Count 0 "a local DryRun parameter is clean: $($r5.V -join ' | ')"
    Add-BSeedCount 'R5' $true
    # $null = ... is the ADR's discard form, also inside an owner
    $owner = Edit-BFirst $BoundaryFixture '    $item = Get-Item -LiteralPath (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -ErrorAction Stop' ('    $null = Get-Item -LiteralPath (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -ErrorAction Stop' + "`n" + '    $item = Get-Item -LiteralPath (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -ErrorAction Stop')
    $r6 = Get-BText $owner
    Assert-Eq $r6.V.Count 0 "a `$null = discard inside an owner is clean: $($r6.V -join ' | ')"
    Add-BSeedCount 'R5' $true
    Assert-BClean 'R5' '$null = $Probe'
}

Test-Case 'BR6 parameters: full names from the owner list, no positionals, switches, pipeline first, value pins, pinned Invoke-Native and Resolve-Program (seeded)' {
    # names
    Assert-BEdit 'R6' '-StartupType $StartupType -ErrorAction Stop' '-StartupT $StartupType -ErrorAction Stop'
    Assert-BEdit 'R6' 'Enable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName' 'Enable-ScheduledTask -TaskPath $TaskPath -taskname $TaskName'
    Assert-BEdit 'R6' 'Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName' 'Disable-ScheduledTask -TaskPath $TaskPath -taskname $TaskName'
    Assert-BEdit 'R6' 'Stop-Service -Name $Name -ErrorAction Stop' 'Stop-Service -Name $Name -EA Stop'
    Assert-BEdit 'R6' 'Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop' 'Set-Service -Name $Name -StartupType $StartupType -Force -ErrorAction Stop'
    Assert-BEdit 'R6' 'Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop' 'Set-Service -Name $Name -StartupType $StartupType -Confirm:$false -ErrorAction Stop'
    Assert-BEdit 'R6' 'Start-Service -Name $Name -ErrorAction Stop' 'Start-Service -Name $Name -PassThru -ErrorAction Stop'
    Assert-BEdit 'R6' '-ClassName Win32_Service' '-Class Win32_Service'
    Assert-BEdit 'R6' '-ClassName Win32_Service' '-ClassName Win32_Service -ComputerName x'
    Assert-BEdit 'R6' '-ClassName Win32_Service' '-ClassName Win32_Process'
    Assert-BEdit 'R6' '-ClassName Win32_Service' '-ClassName $Name'
    Assert-BEdit 'R6' 'return Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop' 'return Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop -Verbose'
    Assert-BEdit 'R6' 'Get-AppxPackage -Name $Name -ErrorAction Stop' 'Get-AppxPackage -Name $Name -AllUsers -ErrorAction Stop'
    Assert-BEdit 'R6' 'Remove-AppxPackage -Package $Package -ErrorAction Stop' 'Remove-AppxPackage -Package $Package -AllUsers -ErrorAction Stop'
    Assert-BEdit 'R6' 'Remove-AppxPackage -Package $Package -ErrorAction Stop' 'Remove-AppxPackage -Package $Package -User $Package -ErrorAction Stop'
    Assert-BEdit 'R6' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop' 'Add-AppxPackage -Path $Family -ErrorAction Stop'
    Assert-BEdit 'R6' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -Register $Family -ErrorAction Stop'
    Assert-BEdit 'R6' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -DependencyPath $Family -ErrorAction Stop'
    Assert-BEdit 'R6' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ForceApplicationShutdown -ErrorAction Stop'
    Assert-BEdit 'R6' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop' 'Add-AppxPackage -RegisterByFamilyName $Family -ErrorAction Stop'
    Assert-BEdit 'R6' 'Add-AppxPackage -RegisterByFamilyName -MainPackage $Family -ErrorAction Stop' 'Add-AppxPackage -RegisterByFamilyName -MainPackage -ErrorAction Stop'
    # positionals, splatting, valueless parameters
    Assert-BEdit 'R6' 'Set-Service -Name $Name' 'Set-Service $Name'
    Assert-BEdit 'R6' 'Get-AppxPackage -Name $Name' 'Get-AppxPackage $Name'
    Assert-BEdit 'R6' 'Get-Content -LiteralPath $Path -Raw -Encoding UTF8' 'Get-Content -LiteralPath $Path -Raw $true -Encoding UTF8'
    Assert-BEdit 'R6' 'Get-Content -LiteralPath $Path -Raw -Encoding UTF8' 'Get-Content -LiteralPath $Path -Raw -Encoding'
    Assert-BEdit 'R6' 'Get-Content -LiteralPath $Path -Raw -Encoding UTF8' 'Get-Content @args -LiteralPath $Path -Raw -Encoding UTF8'
    Assert-BInject 'R6' '$h = @{ Name = ''x'' }; $z = Join-Path @h'
    Assert-BInject 'R6' '$h = @{ Name = ''x'' }; Say @h'
    Assert-BInject 'R6' '$z = Join-Path $Probe ''x'''
    Assert-BInject 'R6' '$z = Join-Path -Path $Probe -ChildPath ''x'' -Resolve'
    # pipelines, Out-Null, value pins
    Assert-BEdit 'R6' 'return Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop' 'return $TaskPath | Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop'
    Assert-BEdit 'R6' 'Remove-AppxPackage -Package $Package -ErrorAction Stop' '$Package | Remove-AppxPackage -Package $Package -ErrorAction Stop'
    Assert-BInject 'R6' '@(1) | Out-Null'
    Assert-BInject 'R6' '$z = @(1) | Out-Null'
    Assert-BInject 'R6' '@(1) | ForEach-Object DeleteValue ''x'''
    Assert-BInject 'R6' '@(1) | ForEach-Object -MemberName SetValue'
    Assert-BInject 'R6' '@(1) | ForEach-Object -Process $Probe'
    Assert-BInject 'R6' '@(1) | ForEach-Object { $_ }'
    Assert-BInject 'R6' '@(1) | ForEach-Object -Begin { } -Process { $_ }'
    Assert-BInject 'R6' '@(1) | Where-Object -Property x'
    Assert-BInject 'R6' '@(1) | Where-Object -FilterScript $Probe'
    Assert-BInject 'R6' '@(1) | Where-Object { $_ }'
    Assert-BInject 'R6' '@(1) | Select-Object -Property x'
    Assert-BInject 'R6' '@(1) | Select-Object -ExpandProperty ''InvokeProvider'''
    Assert-BInject 'R6' '@(1) | Select-Object -ExpandProperty $Probe'
    Assert-BInject 'R6' '@(1) | Select-Object -ExpandProperty ''GetRuntimeMethods'''
    Assert-BInject 'R6' '@(1) | Select-Object -Last 1'
    Assert-BEdit 'R6' 'Get-CimInstance -ClassName Win32_Service -Filter' 'Get-CimInstance -Filter'
    Assert-BEdit 'R6' 'Get-CimInstance -ClassName Win32_ComputerSystem -Property' 'Get-CimInstance -Property'
    Assert-BEdit 'R6' 'Get-CimInstance -ClassName Win32_UserAccount -Filter' 'Get-CimInstance -Filter'
    # maximum lists: a fixture map that widens a list is reported by the meta-test
    foreach ($mx in @(
            @('Get-AppxPackage', 'Get-UserAppxPackage', @('Name', 'AllUsers', 'ErrorAction')),
            @('Remove-AppxPackage', 'Remove-UserAppxPackage', @('Package', 'AllUsers', 'ErrorAction')),
            @('Remove-AppxPackage', 'Remove-UserAppxPackage', @('Package', 'User', 'ErrorAction')),
            @('Add-AppxPackage', 'Register-UserAppxPackage', @('RegisterByFamilyName', 'MainPackage', 'Path', 'ErrorAction')),
            @('Add-AppxPackage', 'Register-UserAppxPackage', @('RegisterByFamilyName', 'MainPackage', 'ForceApplicationShutdown', 'ErrorAction')),
            @('Set-Service', 'Set-ServiceStart', @('Name', 'StartupType', 'ErrorAction', 'Force')),
            @('Get-CimInstance', 'Get-ServiceStart', @('ClassName=Win32_Service', 'Filter', 'Property', 'ErrorAction', 'ComputerName')),
            @('Get-ScheduledTask', 'Get-TaskState', @('TaskPath', 'TaskName', 'ErrorAction', 'CimSession')))) {
        $mm = New-BFixtureMaps
        $mm.Owners[$mx[0]][$mx[1]] = $mx[2]
        $mp = @(Get-BMapProblemsFor $mm $BoundaryFixture | Where-Object -FilterScript { $_ -like 'R6*exceeds the maximum*' })
        Assert-True ($mp.Count -ge 1) "the maximum-list meta-test catches $($mx[0]) with $($mx[2] -join ',')"
        Add-BSeedCount 'R6' $false
    }
    # negative seed: the clean maps stay within the maximum lists
    Assert-Eq (@(Get-BMapProblemsFor (New-BFixtureMaps) $BoundaryFixture | Where-Object -FilterScript { $_ -like 'R6*' })).Count 0 'clean maps are within the maximum lists'
    Add-BSeedCount 'R6' $true
    # pinned Invoke-Native and Resolve-Program
    $gitCall = '-ExePath (Resolve-Program -Name ''git.exe'') -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)'
    Assert-BEdit 'R6' '-ExePath (Resolve-Program -Name ''git.exe'') -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)' '-ExePath ''git.exe'' -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)'
    Assert-BEdit 'R6' ('$tracked = Invoke-Native ' + $gitCall) ('$git = ''git.exe''' + "`n" + '    $tracked = Invoke-Native -ExePath $git -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)')
    Assert-BEdit 'R6' ('$tracked = Invoke-Native ' + $gitCall) ('if ($Path) { $git = ''git.exe'' }' + "`n" + '    $tracked = Invoke-Native -ExePath $git -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)')
    Assert-BEdit 'R6' ('$tracked = Invoke-Native ' + $gitCall) ('$tracked = Invoke-Native -ExePath $git -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)')
    Assert-BEdit 'R6' ('$tracked = Invoke-Native ' + $gitCall) ('$git, $other = ''git.exe'', ''x''' + "`n" + '    $tracked = Invoke-Native -ExePath $git -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)')
    Assert-BEdit 'R6' ('$tracked = Invoke-Native ' + $gitCall) ('foreach ($git in @(''git.exe'')) { $null = $git }' + "`n" + '    $tracked = Invoke-Native -ExePath $git -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)')
    Assert-BEdit 'R6' ('$tracked = Invoke-Native ' + $gitCall) ('$git = data { ''git.exe'' }' + "`n" + '    $tracked = Invoke-Native -ExePath $git -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)')
    $withDefault = [regex]::Replace($BoundaryFixture, '(function Test-WindowsSettingsCommitted \{\s*param\(\[string\]\$Path)\)', '$1, [string]$git = ''git.exe'')')
    Assert-True ($withDefault -ne $BoundaryFixture) 'param default seed applied'
    Assert-BCaught 'R6' (Edit-BFirst $withDefault '$tracked = Invoke-Native -ExePath (Resolve-Program -Name ''git.exe'')' '$tracked = Invoke-Native -ExePath $git') 'param default'
    Assert-BEdit 'R6' '$tracked = Invoke-Native -ExePath (Resolve-Program -Name ''git.exe'') -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)' '$tracked = Invoke-Native -ExePath $Path -WorkingDirectory $script:RepoRoot -Arguments @(''ls-files'', ''--error-unmatch'', ''--'', $Path)'
    Assert-BEdit 'R6' '''ls-files'', ''--error-unmatch'', ''--'', $Path' '''-c'', ''alias.x=!sh'', ''ls-files'', ''--error-unmatch'', ''--'', $Path'
    Assert-BEdit 'R6' '''ls-files'', ''--error-unmatch'', ''--'', $Path' '''--config-env=a=B'', ''ls-files'', ''--error-unmatch'', ''--'', $Path'
    Assert-BEdit 'R6' '''ls-files'', ''--error-unmatch'', ''--'', $Path' '''ls-files'', ''--error-unmatch'', ''--'', $Path, ''extra'''
    Assert-BEdit 'R6' '''ls-files'', ''--error-unmatch'', ''--'', $Path' '''ls-files'', ''--error-unmatch'', ''--'''
    Assert-BEdit 'R6' '''ls-files'', ''--error-unmatch'', ''--'', $Path' '''ls-files'', $Path, ''--'', $Path'
    Assert-BEdit 'R6' '''diff'', ''--quiet'', ''--no-ext-diff'', ''--no-textconv'', ''HEAD'', ''--'', $Path' '''diff'', ''--quiet'', ''--no-ext-diff'', ''HEAD'', ''--'', $Path'
    Assert-BEdit 'R6' '''diff'', ''--quiet'', ''--no-ext-diff'', ''--no-textconv'', ''HEAD'', ''--'', $Path' '''diff'', ''--quiet'', ''--ext-diff'', ''--no-textconv'', ''HEAD'', ''--'', $Path'
    Assert-BEdit 'R6' '''diff'', ''--quiet'', ''--no-ext-diff'', ''--no-textconv'', ''HEAD'', ''--'', $Path' '$Path'
    Assert-BEdit 'R6' '-WorkingDirectory $script:RepoRoot -Arguments @(''ls-files''' '-WorkingDirectory $RepoRoot -Arguments @(''ls-files'''
    Assert-BEdit 'R6' '-WorkingDirectory $script:RepoRoot -Arguments @(''ls-files''' '-WorkingDirectory $Path -Arguments @(''ls-files'''
    Assert-BEdit 'R6' '-WorkingDirectory $script:RepoRoot -Arguments @(''ls-files''' '-Arguments @(''ls-files'''
    Assert-BEdit 'R6' '-TimeoutSeconds 60' '-TimeoutSeconds $Path'
    Assert-BEdit 'R6' '-TimeoutSeconds 60' '-TimeoutSeconds ''60'''
    Assert-BEdit 'R6' '-TimeoutSeconds 60' '-TimeoutSeconds 60 -Passthrough'
    Assert-BEdit 'R6' 'Resolve-Program -Name ''git.exe''' 'Resolve-Program -Name ''git'''
    Assert-BEdit 'R6' 'Resolve-Program -Name ''git.exe''' 'Resolve-Program -Name $Path'
    Assert-BEdit 'R6' 'Resolve-Program -Name ''git.exe''' 'Resolve-Program ''git.exe'''
    Assert-BEdit 'R6' 'Resolve-Program -Name ''git.exe''' 'Resolve-Program -Name ''git.exe'' -Extra 1'
    Assert-BInject 'R6' '$z = Resolve-Program -Name ''git.exe'''
    Assert-BInject 'R6' '$z = Invoke-Native -ExePath ''x'''
    Assert-BEdit 'R6' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')' '-ExePath ''dsregcmd.exe'' -Arguments @(''/status'')'
    Assert-BEdit 'R6' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'', ''/debug'')'
    Assert-BEdit 'R6' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\cmdkey.exe'') -Arguments @(''/status'')'
    Assert-BEdit 'R6' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')' '-ExePath (Join-Path -Path $env:windir -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')'
    Assert-BEdit 'R6' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'') -WorkingDirectory $script:RepoRoot'
    Assert-BEdit 'R6' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'')' '-ExePath (Join-Path -Path $env:SystemRoot -ChildPath ''System32\dsregcmd.exe'') -Arguments @(''/status'') -TimeoutSeconds ''x'''
    # negative seeds
    Assert-BClean 'R6' '$z = Join-Path -Path $Probe -ChildPath ''x'''
    Assert-BClean 'R6' '$z = @(1) | ForEach-Object -Process { $_ }'
    Assert-BClean 'R6' '$z = @(1) | Where-Object -FilterScript { $_ }'
    Assert-BClean 'R6' '$z = @(1) | Select-Object -First 1'
    Assert-BClean 'R6' '$z = @(@{ a = 1 }) | Select-Object -ExpandProperty ''a'''
    Assert-BClean 'R6' '[void]$Probe'
    Assert-BClean 'R6' '$null = $Probe'
    Assert-BClean 'R6' 'Say "x $Probe"'
    Assert-BClean 'R6' '$z = Get-ProbeLocal $Probe'
    Assert-BClean 'R6' '$z = Get-ProbeLocal -Probe $Probe'
}

Test-Case 'BR7 New-Object only with a named -TypeName (R4) and an optional -ArgumentList, no positionals, no COM (seeded)' {
    Assert-BInject 'R7' '$z = New-Object System.Text.StringBuilder'
    Assert-BInject 'R7' '$z = New-Object ''System.Collections.Generic.List[string]'' @()'
    Assert-BInject 'R7' '$z = New-Object -ComObject WScript.Shell'
    Assert-BInject 'R7' '$z = New-Object -ComObject Shell.Application -Strict'
    Assert-BInject 'R7' '$z = New-Object -TypeName ''System.Collections.Generic.List[string]'' -Property @{ Capacity = 1 }'
    Assert-BInject 'R7' '$z = New-Object -TypeName ''System.Collections.Generic.List[string]'' -Strict'
    Assert-BInject 'R7' '$z = New-Object -TypeName ''System.Collections.Generic.List[string]'' a b c'
    Assert-BInject 'R7' '$h = @{ TypeName = ''x'' }; $z = New-Object @h'
    Assert-BInject 'R7' '$z = New-Object -ArgumentList 1'
    Assert-BInject 'R7' '$z = New-Object -Type ''System.Collections.Generic.List[string]'''
    Assert-BClean 'R7' '$z = New-Object -TypeName ''System.Collections.Generic.List[string]'''
    Assert-BClean 'R7' '$z = New-Object -TypeName ''System.Collections.Generic.List[string]'' -ArgumentList 4'
    Assert-BClean 'R7' '$z = New-Object -ArgumentList 4 -TypeName ''System.Collections.Generic.List[string]'''
}

Test-Case 'BR8 tripwire: no executable-name strings in scope; programs only through the pinned forms (seeded)' {
    Assert-BInject 'R8' '$z = @("C:\Program Files\x\reg.exe", ''add'')'
    Assert-BInject 'R8' '$z = ''C:\Program Files\PowerShell\7\pwsh.exe'''
    Assert-BInject 'R8' '$z = ''%SystemRoot%\System32\reg.exe'''
    Assert-BInject 'R8' '$z = ''reg.com'''
    Assert-BInject 'R8' '$z = ''sc'''
    Assert-BInject 'R8' '$z = ''powershell.exe'''
    Assert-BInject 'R8' '$z = ''cmd.exe /c schtasks'''
    Assert-BInject 'R8' '$z = ''reg'''
    Assert-BInject 'R8' '$z = '' schtasks '''
    Assert-BInject 'R8' '$z = ''regedit.exe'''
    Assert-BInject 'R8' '$z = ''wsl.exe'''
    Assert-BInject 'R8' '$z = ''C:\Windows\System32\wsl.exe'''
    Assert-BInject 'R8' '$z = ''/usr/bin/pwsh.exe'''
    Assert-BInject 'R8' '$z = "run=reg.exe add"'
    Assert-BInject 'R8' '$z = "x $Probe schtasks.exe;"'
    Assert-BInject 'R8' '$z = ''SC.EXE'''
    Assert-BInject 'R8' '$z = ''pwsh'''
    Assert-BInject 'R8' '$z = ''cmd'''
    Assert-BInject 'R8' 'reg.exe add x'
    # negative seeds
    Assert-BClean 'R8' '$z = ''PowerShell 5.1 is required'''
    Assert-BClean 'R8' '$z = ''Reg value missing'''
    Assert-BClean 'R8' '$z = ''the sc word in a sentence'''
    Assert-BClean 'R8' '$z = ''dsregcmd.exe'''
    Assert-BClean 'R8' '$z = ''System32\dsregcmd.exe'''
    Assert-BClean 'R8' '$z = ''git.exe'''
    Assert-BClean 'R8' '$z = ''registry.exe.txt'''
    Assert-BClean 'R8' '$z = ''myreg.exe'''
    Assert-BClean 'R8' 'Say "step W: run elevated: .\ops\windows\bootstrap.ps1 -WindowsSettings x -SetupProfile personal -MachineWide"'
    Assert-BClean 'R8' 'Say "step W: run elevated: Disable-ScheduledTask -TaskPath ''\x\'' -TaskName ''y''"'
    Assert-BClean 'R8' 'Say ''step W: run elevated: .\ops\windows\bootstrap.ps1 -WindowsRollback x -MachineWide'''
}

Test-Case 'BR9 -LiteralPath from metadata: map cmdlets that have it take -LiteralPath and never -Path; New-Item and Join-Path are exempt (seeded)' {
    Assert-BEdit 'R9' 'Get-Content -LiteralPath $Path -Raw' 'Get-Content -Path $Path -Raw'
    Assert-BEdit 'R9' 'Import-PowerShellDataFile -LiteralPath $Path' 'Import-PowerShellDataFile -Path $Path'
    Assert-BEdit 'R9' 'Get-Item -LiteralPath (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -ErrorAction Stop' 'Get-Item -Path (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -ErrorAction Stop'
    Assert-BEdit 'R9' 'Remove-Item -LiteralPath (Join-Path -Path ''HKLM:\'' -ChildPath $Key)' 'Remove-Item -Path (Join-Path -Path ''HKLM:\'' -ChildPath $Key)'
    Assert-BEdit 'R9' 'Get-ChildItem -LiteralPath (Join-Path' 'Get-ChildItem -Path (Join-Path'
    Assert-BEdit 'R9' 'Set-ItemProperty -LiteralPath (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -Name' 'Set-ItemProperty -Path (Join-Path -Path ''HKCU:\'' -ChildPath $Key) -Name'
    Assert-BEdit 'R9' 'Remove-ItemProperty -LiteralPath (Join-Path -Path ''HKCU:\'' -ChildPath $Key)' 'Remove-ItemProperty -Name $Name -Path (Join-Path -Path ''HKCU:\'' -ChildPath $Key)'
    Assert-BEdit 'R9' 'Get-Content -LiteralPath $Path -Raw' 'Get-Content -LiteralPath $Path -Path $Path -Raw'
    Assert-BEdit 'R9' 'Get-Content -LiteralPath $Path -Raw' 'Get-Content -Raw'
    # negative seeds: New-Item (no -LiteralPath in 5.1, N1) and Join-Path keep -Path
    $r = Get-BText $BoundaryFixture
    Assert-Eq (@($r.V | Where-Object -FilterScript { $_ -like 'R9 *' })).Count 0 'the clean fixture has no R9 violation although New-Item and Join-Path take -Path'
    Add-BSeedCount 'R9' $true
    Assert-True ($BoundaryFixture.Contains('New-Item -Path $Path -ItemType Directory')) 'New-Item -Path is in the fixture'
    Assert-True ($BoundaryFixture.Contains('Join-Path -Path')) 'Join-Path -Path is in the fixture'
    Add-BSeedCount 'R9' $true
}

Test-Case 'BR10 nested scriptblocks count as their function; no nested function definitions; SetEnvironmentVariable is banned (seeded)' {
    # a defect inside a nested scriptblock of an in-scope function is attributed to that function
    Assert-BInject 'R3' '$z = @(1) | ForEach-Object -Process { & $Probe }'
    Assert-BInject 'R5' '$z = @(1) | ForEach-Object -Process { $Unknown }'
    Assert-BInject 'R1' '$z = @(1) | Where-Object -FilterScript { Get-Item -LiteralPath $_ }'
    Assert-BInject 'R3' '$z = { & $Probe }'
    Assert-BInject 'R10' 'function Inner { }'
    Assert-BInject 'R10' 'function Inner { function Deeper { } }'
    Assert-BInject 'R10' '[Environment]::SetEnvironmentVariable(''A'', ''B'', ''User'')'
    Assert-BInject 'R10' '[System.Environment]::SetEnvironmentVariable(''A'', $null, ''Machine'')'
    Assert-BInject 'R10' '$z = @(1) | ForEach-Object -Process { [Environment]::SetEnvironmentVariable(''A'', ''B'') }'
    Assert-BInject 'R10' ('$o = $Probe' + "`n" + '$o.SetEnvironmentVariable(''A'', ''B'')')
    Assert-BInject 'R10' ('$o = $Probe' + "`n" + '$o.setenvironmentvariable(''A'', ''B'')')
    # the same defect outside the scope is not attributed to any scope function
    $t =$BoundaryFixture + "`nfunction Out-Of-Scope { `$z = @(1) | ForEach-Object -Process { & `$Probe }; [Environment]::SetEnvironmentVariable('A', 'B') }`n"
    Assert-Eq (@((Get-BText $t).V | Where-Object -FilterScript { $_ -like 'R3 *' -or $_ -like 'R10 *' })).Count 0 'a defect in a function that is not in scope is not reported'
    Add-BSeedCount 'R10' $true
    Assert-BClean 'R10' '$z = @(1) | ForEach-Object -Process { $_ }'
    Assert-BClean 'R10' '$z = { param($x1) $x1 }'
}

Test-Case 'BR-real the real script: dispatcher anchored, switches have branches, the reachable set is $BoundaryScope, every rule holds (seeded on copies)' {
    $text = [IO.File]::ReadAllText($ScriptPath)
    $tokens = $null; $errs = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errs)
    Assert-Eq $errs.Count 0 'parse errors'
    $maps = @{ Scope = $BoundaryScope; Owners = $CommandOwners; Common = $BoundaryCommon; TypeAllow = $BoundaryTypeAllow; Switches = $BoundarySwitches }
    $d = Get-BDispatcherInfo $ast
    Assert-True $d.Found "the dispatcher $BoundaryDispatcher is found"
    Assert-Eq $d.Declared.Count 0 "no W switch is declared yet: $($d.Declared -join ',')"
    Assert-Eq $d.Problems.Count 0 "dispatcher problems: $($d.Problems -join ' | ')"
    $reach = @(Get-BReachable $ast $BoundaryEntries)
    Assert-Eq $reach.Count 0 "no entry point exists yet, so the reachable set is empty: $($reach -join ',')"
    Assert-Eq (@(Get-BoundaryScopeProblems $ast $maps)).Count 0 "scope problems: $(@(Get-BoundaryScopeProblems $ast $maps) -join ' | ')"
    $v = @(Get-BoundaryViolations $ast $maps)
    Assert-Eq $v.Count 0 "boundary violations: $($v -join ' | ')"
    $mp = @(Get-BoundaryMapProblems $ast $maps $SeamNames $S1Safe)
    Assert-Eq $mp.Count 0 "map problems: $($mp -join ' | ')"
    Assert-Eq $CommandOwners.Count 0 'the real owner map stays empty until its seam lands'
    Assert-Eq $BoundaryCommon.Count 0 'the real common map stays empty until its key is used'
    # trusted and pinned helpers exist exactly once in the real script
    foreach ($h in $BoundaryTrusted) { Assert-Eq (@($ast.FindAll({ param($n) $n -is $BtFn -and $n.Name -ceq $h }, $true))).Count 1 "trusted helper $h is defined once" }
    # no real script function carries an entry-point or W seam name yet, and none is named like an R3 command
    foreach ($e in $BoundaryEntries) { Assert-True (-not (@($ast.FindAll({ param($n) $n -is $BtFn -and $n.Name -ieq $e }, $true)).Count)) "$e does not exist yet" }
    # seeded copies of the real script
    $a2 = [Management.Automation.Language.Parser]::ParseInput($text.Replace('function Invoke-BootstrapRun', 'function Invoke-BootstrapRunX'), [ref]$tokens, [ref]$errs)
    Assert-True (@(Get-BoundaryViolations $a2 $maps | Where-Object -FilterScript { $_ -like 'R1 *dispatcher*' }).Count -ge 1) 'a missing dispatcher fails closed'
    Add-BSeedCount 'R1' $false
    foreach ($sw in @('WindowsSnapshot', 'WindowsSettings', 'WindowsRollback', 'MachineWide', 'RemoveApps', 'DisableTeamsStartup')) {
        $a3 = [Management.Automation.Language.Parser]::ParseInput($text.Replace('[switch]$ClaudeStatusLine,', "[switch]`$ClaudeStatusLine, [switch]`$$sw,"), [ref]$tokens, [ref]$errs)
        Assert-True (@(Get-BoundaryViolations $a3 $maps | Where-Object -FilterScript { $_ -like 'R1 *declared but has no branch*' }).Count -ge 1) "a declared -$sw without a branch fails"
        Add-BSeedCount 'R1' $false
    }
    # a branch must hold only entry-point calls, Say and return; each variant is injected right after the real anchor
    Assert-True ($text.Contains('    # arguments')) 'the anchor "    # arguments" exists in Invoke-BootstrapRun'
    foreach ($bv in @(
            @('Get-Date; return 0', 'calls ''Get-Date'''),
            @('$q = 1; return 0', 'has a statement other than'),
            @('[IO.File]::Delete(''x''); return 0', 'has a statement other than'),
            @('return [IO.File]::Delete(''x'')', 'has a statement other than'),
            @('Say ([IO.File]::Exists(''x'')); return 0', 'contains a member access'))) {
        $inj = $text.Replace('[switch]$ClaudeStatusLine,', '[switch]$ClaudeStatusLine, [switch]$WindowsSnapshot,').Replace('    # arguments', ('    if ($WindowsSnapshot) { ' + $bv[0] + ' }' + "`n" + '    # arguments'))
        Assert-True ($inj.Contains('if ($WindowsSnapshot) {')) 'the branch was injected'
        $a4 = [Management.Automation.Language.Parser]::ParseInput($inj, [ref]$tokens, [ref]$errs)
        Assert-Eq $errs.Count 0 "the seeded real-script copy parses: $($bv[0])"
        Assert-True (@(Get-BoundaryViolations $a4 $maps | Where-Object -FilterScript { $_ -like 'R1 *' -and $_ -like "*$($bv[1])*" }).Count -ge 1) "a bad branch fails: $($bv[0])"
        Add-BSeedCount 'R1' $false
    }
    # negative: a branch with only Say and return is accepted
    $okb = $text.Replace('[switch]$ClaudeStatusLine,', '[switch]$ClaudeStatusLine, [switch]$WindowsSnapshot,').Replace('    # arguments', '    if ($WindowsSnapshot) { Say ''x''; return 2 }' + "`n" + '    # arguments')
    $a7 = [Management.Automation.Language.Parser]::ParseInput($okb, [ref]$tokens, [ref]$errs)
    Assert-Eq (@(Get-BDispatcherInfo $a7).Problems).Count 0 'a Say-and-return branch is accepted'
    Add-BSeedCount 'R1' $true
    # an entry point that exists but is not in the scope list
    $a5 = [Management.Automation.Language.Parser]::ParseInput($text + "`nfunction Invoke-WindowsSnapshot { param([string]`$Label) return 0 }`n", [ref]$tokens, [ref]$errs)
    Assert-True (@(Get-BoundaryScopeProblems $a5 $maps).Count -ge 1) 'an entry point missing from $BoundaryScope is reported'
    Add-BSeedCount 'R1' $false
    # a using statement anywhere in the script
    $a6 = [Management.Automation.Language.Parser]::ParseInput('using namespace System' + "`n" + $text, [ref]$tokens, [ref]$errs)
    Assert-True (@(Get-BoundaryViolations $a6 $maps | Where-Object -FilterScript { $_ -like 'R4 *using*' }).Count -ge 1) 'a using statement fails'
    Add-BSeedCount 'R4' $false
}

function Test-BScriptReadOperand {
    # a path operand: $PSScriptRoot, a single-quoted literal, or a nested allowed Split-Path/Join-Path in parentheses
    param($Op)
    if ($Op -is $BtVar) { return ($Op.VariablePath.UserPath -ieq 'PSScriptRoot') }
    if ($Op -is $BtStr) { return ($Op.StringConstantType.ToString() -ceq 'SingleQuoted') }
    if ($Op -is $BtParen) { return (Test-BScriptReadValue $Op.Pipeline -CommandOnly) }
    return $false
}

function Test-BScriptReadValue {
    # a string or number literal, or Split-Path/Join-Path with no array or comma argument and no -Resolve (only -Parent -Leaf -Path -ChildPath),
    # every path operand being $PSScriptRoot, a single-quoted literal or a nested allowed form (the existing RepoRoot pattern)
    param($Right, [switch]$CommandOnly)
    $pe = $Right
    if ($Right -is $BtPipe) {
        if ($Right.PipelineElements.Count -ne 1) { return $false }
        $pe = $Right.PipelineElements[0]
    }
    if ($pe -is [Management.Automation.Language.CommandExpressionAst]) {
        if ($CommandOnly) { return $false }
        $x = $pe.Expression
        if ($x -is $BtStr) { return ($x.StringConstantType.ToString() -ne 'BareWord') }
        return ($x -is $BtConst -and $x.Value -is [ValueType])
    }
    if ($pe -is $BtCmd) {
        $cn = $pe.GetCommandName()
        if (-not ($cn -ceq 'Split-Path' -or $cn -ceq 'Join-Path')) { return $false }
        if (@($pe.Redirections).Count -ne 0) { return $false }
        $els = @($pe.CommandElements)
        $nOps = 0
        for ($i = 1; $i -lt $els.Count; $i++) {
            $el = $els[$i]
            if ($el -is $BtParam) {
                if (@('Parent', 'Leaf', 'Path', 'ChildPath') -cnotcontains $el.ParameterName) { return $false }
                if ($el.Argument) {
                    if (-not (Test-BScriptReadOperand $el.Argument)) { return $false }
                    $nOps++
                }
            } else {
                if (-not (Test-BScriptReadOperand $el)) { return $false }
                $nOps++
            }
        }
        return ($nOps -ge 1)
    }
    return $false
}

function Get-BLeftNames {
    # every variable name on an assignment left side: plain, cast or inside a comma list
    param($Left)
    if ($Left -is $BtVar) { return @($Left.VariablePath.UserPath -replace '^(?i)script:', '') }
    if ($Left -is [Management.Automation.Language.ConvertExpressionAst]) { return @(Get-BLeftNames $Left.Child) }
    if ($Left -is $BtArrLit) { return @($Left.Elements | ForEach-Object -Process { Get-BLeftNames $_ }) }
    return @()
}

function Get-BScriptReadAssigns {
    param($Ast, [string]$Name)
    return @($Ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and (@(Get-BLeftNames $n.Left) -ccontains $Name) }, $true))
}

function Test-BScriptReadAssign {
    # plain `$Name = <string or number value>` at script level; any cast, comma list or compound operator fails
    param($Asg)
    return ($null -eq (Get-BNearestFn $Asg) -and $Asg.Left -is $BtVar -and $Asg.Operator.ToString() -ceq 'Equals' -and (Test-BScriptReadValue $Asg.Right))
}

Test-Case 'BR5 invariant: every $BoundaryScriptReads name is assigned only a string or number value at script level in the real script' {
    $tk = $null; $er = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tk, [ref]$er)
    Assert-Eq $er.Count 0 'parse errors'
    foreach ($name in $BoundaryScriptReads) {
        $asg = Get-BScriptReadAssigns $ast $name
        Assert-True ($asg.Count -ge 1) "$name is assigned in the real script"
        foreach ($a in $asg) {
            Assert-True (Test-BScriptReadAssign $a) "$name is assigned only a plain string or number value at script level (line $($a.Extent.StartLineNumber)): $($a.Extent.Text)"
        }
    }
    # seeds: the value test rejects mutable, computed or array values and accepts the legal forms
    $badVals = @('$x = @{}', '$x = @(1, 2)', '$x = New-Object System.Collections.ArrayList', '$x = Get-Date', '$x = [System.Collections.ArrayList]::new()', '$x = "a $y"', '$x = $y',
        '$x = Join-Path -Path ''a'',''b'' -ChildPath ''c''', '$x = Split-Path -Path ''a\b'',''c\d'' -Parent', '$x = Split-Path -Parent $PSScriptRoot -Resolve',
        '$x = Split-Path -Parent (Get-Date)', '$x = Split-Path -Parent $y', '$x = Split-Path -Parent "$PSScriptRoot"', '$x = Split-Path -Parent ''a'', ''b''',
        '$x = Join-Path (Split-Path -Parent $PSScriptRoot) (Get-Date)', '$x = Split-Path -Parent -LiteralPath ''a''', '$x = Split-Path -Parent $PSScriptRoot | Out-String')
    foreach ($bad in $badVals) {
        $a2 = [Management.Automation.Language.Parser]::ParseInput($bad, [ref]$tk, [ref]$er)
        $as2 = @($a2.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] }, $true))[0]
        Assert-True (-not (Test-BScriptReadValue $as2.Right)) "the value test rejects: $bad"
    }
    $goodVals = @('$x = ''a''', '$x = 5', '$x = Split-Path -Parent $PSScriptRoot', '$x = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)',
        '$x = Join-Path $PSScriptRoot ''sub''', '$x = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath ''sub''')
    foreach ($good in $goodVals) {
        $a2 = [Management.Automation.Language.Parser]::ParseInput($good, [ref]$tk, [ref]$er)
        $as2 = @($a2.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] }, $true))[0]
        Assert-True (Test-BScriptReadValue $as2.Right) "the value test accepts: $good"
    }
    # seeds: the assignment finder sees cast and comma-list left sides, and the assignment test fails them
    foreach ($bad in @('$a, $RepoRoot = 1, @{}', '[string[]]$RepoRoot = ''a''', '[object]$RepoRoot = @{}', '$RepoRoot += ''a''', 'function f { $RepoRoot = ''a'' }', '$script:RepoRoot = Get-Date')) {
        $a3 = [Management.Automation.Language.Parser]::ParseInput($bad, [ref]$tk, [ref]$er)
        $found = @(Get-BScriptReadAssigns $a3 'RepoRoot')
        Assert-True ($found.Count -ge 1) "the finder sees: $bad"
        Assert-True (@($found | Where-Object -FilterScript { -not (Test-BScriptReadAssign $_) }).Count -ge 1) "the assignment test rejects: $bad"
    }
    $a3 = [Management.Automation.Language.Parser]::ParseInput('$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)', [ref]$tk, [ref]$er)
    Assert-True (Test-BScriptReadAssign @(Get-BScriptReadAssigns $a3 'RepoRoot')[0]) 'the assignment test accepts the RepoRoot pattern'
}

[Console]::WriteLine('BR seeds (rule: seeded / negative): ' + (($script:BSeeds.Keys | Sort-Object | ForEach-Object -Process { "$_ $($script:BSeeds[$_][0])/$($script:BSeeds[$_][1])" }) -join ', '))

# ---------------------------------------------------------------- ADR-0020 catalogue W1, W1g, V1, V2 (T-0055 T3)
# W1 checks ops\windows\windows-settings.psd1 and the two pure functions in bootstrap.ps1 against the ADR-0020
# "Catalogue contract" and ADR-0035 "Key expansion". The oracle constants below are copied from those ADR tables.
# Paths come from $OrigRepoRoot because Test-Case repoints $script:RepoRoot to a temp directory.
# T3 loads the catalogue with Import-PowerShellDataFile; T4 switches this to Read-WindowsSettingsCatalogue.
# Problem strings are "<code>: <Id or '-'>: <message>". Every seed works on a copy and must produce exactly its code.
$WCatPath = Join-Path $OrigRepoRoot 'ops\windows\windows-settings.psd1'
$WYamlPath = Join-Path $OrigRepoRoot 'docs\platforms\windows\visual-effects.yaml'

# Oracle constants, copied mechanically from ADR-0020 ("Entries", "N12 allowlist", (b), (d), (e), "Notices") and ADR-0035 "Key expansion".
# When an ADR table changes, change these in the same commit; W1 pins the catalogue and the two bootstrap.ps1 functions to them.
$W1Ids = @(
    'startup-edge', 'startup-onedrive', 'startup-teams', 'appx-microsoft-bingnews',
    'appx-microsoft-bingweather', 'appx-microsoft-bingsearch', 'appx-microsoft-microsoftsolitairecollection', 'appx-clipchamp-clipchamp',
    'appx-microsoft-powerautomatedesktop', 'appx-microsoft-windowsfeedbackhub', 'appx-microsoft-windows-devhome', 'appx-microsoft-todos',
    'appx-microsoft-yourphone', 'appx-microsoftwindows-crossdevice', 'appx-microsoftcorporationii-microsoftfamily', 'appx-microsoft-gamingapp',
    'appx-microsoft-xboxgamingoverlay', 'appx-microsoft-xboxspeechtotextoverlay', 'appx-microsoft-xbox-tcui', 'appx-microsoft-xboxidentityprovider',
    'appx-microsoft-gethelp', 'appx-microsoftcorporationii-quickassist', 'appx-msteams', 'appx-microsoft-outlookforwindows',
    'appx-microsoft-microsoftofficehub', 'notice-work-folders', 'notice-onedrive-task', 'preset',
    'animate-windows', 'taskbar-animations', 'fade-slide-menus', 'combo-slide',
    'fade-slide-tooltips', 'fade-menu-items', 'animate-controls', 'tel-advertising-id',
    'tel-tailored-experiences', 'tel-feedback-frequency', 'tel-implicit-ink', 'tel-implicit-text',
    'tel-harvest-contacts', 'tel-personalization-policy', 'tel-online-speech', 'tel-tips-338389',
    'tel-system-pane-suggestions', 'tel-soft-landing', 'tel-suggested-338393', 'tel-suggested-353694',
    'tel-suggested-353696', 'tel-suggested-310093', 'tel-scoobe', 'tel-track-progs',
    'tel-iris-recommendations', 'tel-accept-language-optout', 'tel-m-feedback-notifications', 'tel-m-publish-activities',
    'tel-m-upload-activities', 'tel-m-ceip', 'tel-m-diagtrack', 'tel-m-task-consolidator',
    'tel-m-task-usbceip', 'tel-m-task-diskdiag', 'tel-m-task-dmclient', 'tel-m-task-dmclient-download',
    'tel-m-task-autochk-proxy', 'rec-allowtelemetry-policy', 'rec-allowtelemetry-current', 'rec-maxtelemetry-current',
    'rec-limit-diaglog', 'rec-limit-dump', 'rec-dmwappush', 'rec-location'
)
$W1TagKeys = @{
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
$W1Protected = @{ Names = @('Microsoft.ZuneMusic', 'Microsoft.DesktopAppInstaller', 'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.SecHealthUI', 'Microsoft.WindowsTerminal', 'MicrosoftCorporationII.WindowsSubsystemForLinux'); Prefixes = @('Microsoft.VCLibs.', 'Microsoft.UI.Xaml.', 'Microsoft.NET.Native.', 'Microsoft.WindowsAppRuntime.') }
$W1Consumer = @('Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.MicrosoftSolitaireCollection', 'Clipchamp.Clipchamp', 'Microsoft.PowerAutomateDesktop', 'Microsoft.WindowsFeedbackHub', 'Microsoft.Windows.DevHome', 'Microsoft.Todos', 'Microsoft.YourPhone', 'MicrosoftWindows.CrossDevice', 'MicrosoftCorporationII.MicrosoftFamily', 'Microsoft.GamingApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxIdentityProvider')
$W1Support = @('Microsoft.GetHelp', 'MicrosoftCorporationII.QuickAssist')
$W1WorkApps = @('MSTeams', 'Microsoft.OutlookForWindows', 'Microsoft.MicrosoftOfficeHub')
$W1Telemetry = @(
    @{ Ref = 'U1'; Id = 'tel-advertising-id'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; ValueName = 'Enabled'; Target = 0; Source = 'chosen'; Host = 'HC'; Exec = $false }
    @{ Ref = 'U2'; Id = 'tel-tailored-experiences'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\Privacy'; ValueName = 'TailoredExperiencesWithDiagnosticDataEnabled'; Target = 0; Source = 'chosen'; Host = 'HC'; Exec = $false }
    @{ Ref = 'U3'; Id = 'tel-feedback-frequency'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Siuf\Rules'; ValueName = 'NumberOfSIUFInPeriod'; Target = 0; Source = 'public'; Host = 'UC'; Exec = $false }
    @{ Ref = 'U4'; Id = 'tel-implicit-ink'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\InputPersonalization'; ValueName = 'RestrictImplicitInkCollection'; Target = 1; Source = 'public'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U4'; Id = 'tel-implicit-text'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\InputPersonalization'; ValueName = 'RestrictImplicitTextCollection'; Target = 1; Source = 'public'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U4'; Id = 'tel-harvest-contacts'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\InputPersonalization\TrainedDataStore'; ValueName = 'HarvestContacts'; Target = 0; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U4'; Id = 'tel-personalization-policy'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Personalization\Settings'; ValueName = 'AcceptedPrivacyPolicy'; Target = 0; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U5'; Id = 'tel-online-speech'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; ValueName = 'HasAccepted'; Target = 0; Source = 'public'; Host = 'UC'; Exec = $false }
    @{ Ref = 'U6'; Id = 'tel-tips-338389'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SubscribedContent-338389Enabled'; Target = 0; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U6'; Id = 'tel-system-pane-suggestions'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SystemPaneSuggestionsEnabled'; Target = 0; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U6'; Id = 'tel-soft-landing'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SoftLandingEnabled'; Target = 0; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'U7'; Id = 'tel-suggested-338393'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SubscribedContent-338393Enabled'; Target = 0; Source = 'none'; Host = 'HK'; Exec = $false }
    @{ Ref = 'U7'; Id = 'tel-suggested-353694'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SubscribedContent-353694Enabled'; Target = 0; Source = 'none'; Host = 'HK'; Exec = $false }
    @{ Ref = 'U7'; Id = 'tel-suggested-353696'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SubscribedContent-353696Enabled'; Target = 0; Source = 'none'; Host = 'HK'; Exec = $false }
    @{ Ref = 'U7'; Id = 'tel-suggested-310093'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; ValueName = 'SubscribedContent-310093Enabled'; Target = 0; Source = 'none'; Host = 'HK'; Exec = $false }
    @{ Ref = 'U8'; Id = 'tel-scoobe'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; ValueName = 'ScoobeSystemSettingEnabled'; Target = 0; Source = 'adr'; Host = 'UC'; Exec = $false }
    @{ Ref = 'U9'; Id = 'tel-track-progs'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; ValueName = 'Start_TrackProgs'; Target = 0; Source = 'public'; Host = 'HK'; Exec = $false }
    @{ Ref = 'U9'; Id = 'tel-iris-recommendations'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; ValueName = 'Start_IrisRecommendations'; Target = 0; Source = 'adr'; Host = 'HK'; Exec = $false }
    @{ Ref = 'U10'; Id = 'tel-accept-language-optout'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Control Panel\International\User Profile'; ValueName = 'HttpAcceptLanguageOptOut'; Target = 1; Source = 'public'; Host = 'HK'; Exec = $false }
    @{ Ref = 'E2'; Id = 'tel-m-feedback-notifications'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; ValueName = 'DoNotShowFeedbackNotifications'; Target = 1; Source = 'public'; Host = 'HK'; Exec = $false }
    @{ Ref = 'E3'; Id = 'tel-m-publish-activities'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'PublishUserActivities'; Target = 0; Source = 'public'; Host = 'HK'; Exec = $false }
    @{ Ref = 'E3'; Id = 'tel-m-upload-activities'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'UploadUserActivities'; Target = 0; Source = 'public'; Host = 'HK'; Exec = $false }
    @{ Ref = 'E4'; Id = 'tel-m-ceip'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\SQMClient\Windows'; ValueName = 'CEIPEnable'; Target = 0; Source = 'adr'; Host = 'UC'; Exec = $false }
    @{ Ref = 'S1'; Id = 'tel-m-diagtrack'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Service'; Name = 'DiagTrack'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'T1'; Id = 'tel-m-task-consolidator'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Task'; TaskPath = '\Microsoft\Windows\Customer Experience Improvement Program\'; TaskName = 'Consolidator'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'T1'; Id = 'tel-m-task-usbceip'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Task'; TaskPath = '\Microsoft\Windows\Customer Experience Improvement Program\'; TaskName = 'UsbCeip'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'T2'; Id = 'tel-m-task-diskdiag'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Task'; TaskPath = '\Microsoft\Windows\DiskDiagnostic\'; TaskName = 'Microsoft-Windows-DiskDiagnosticDataCollector'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'T3'; Id = 'tel-m-task-dmclient'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Task'; TaskPath = '\Microsoft\Windows\Feedback\Siuf\'; TaskName = 'DmClient'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'T3'; Id = 'tel-m-task-dmclient-download'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Task'; TaskPath = '\Microsoft\Windows\Feedback\Siuf\'; TaskName = 'DmClientOnScenarioDownload'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'T4'; Id = 'tel-m-task-autochk-proxy'; Tag = 'telemetry-machine'; Scope = 'machine'; Kind = 'Task'; TaskPath = '\Microsoft\Windows\Autochk\'; TaskName = 'Proxy'; Target = 'Disabled'; Source = 'adr'; Host = 'HC'; Exec = $true }
    @{ Ref = 'E1'; Id = 'rec-allowtelemetry-policy'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; ValueName = 'AllowTelemetry'; Source = 'chosen'; Host = 'HK'; Exec = $null }
    @{ Ref = 'E1'; Id = 'rec-allowtelemetry-current'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'DWord'; Key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; ValueName = 'AllowTelemetry'; Source = 'chosen'; Host = 'HC'; Exec = $null }
    @{ Ref = 'E1'; Id = 'rec-maxtelemetry-current'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'DWord'; Key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; ValueName = 'MaxTelemetryAllowed'; Source = 'adr'; Host = 'HC'; Exec = $null }
    @{ Ref = 'REC'; Id = 'rec-limit-diaglog'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; ValueName = 'LimitDiagnosticLogCollection'; Source = 'chosen'; Host = 'HK'; Exec = $null }
    @{ Ref = 'REC'; Id = 'rec-limit-dump'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; ValueName = 'LimitDumpCollection'; Source = 'chosen'; Host = 'HK'; Exec = $null }
    @{ Ref = 'REC'; Id = 'rec-dmwappush'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'Service'; Name = 'dmwappushservice'; Source = 'adr'; Host = 'HC'; Exec = $null }
    @{ Ref = 'REC'; Id = 'rec-location'; Tag = 'telemetry-record'; Scope = 'machine'; Kind = 'Record'; RecordOf = 'String'; Key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; ValueName = 'Value'; Source = 'adr'; Host = 'HC'; Exec = $null }
)
$W1Labels = @{
    'startup-edge' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'startup-onedrive' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'startup-teams' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-bingnews' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-bingweather' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-bingsearch' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-microsoftsolitairecollection' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-clipchamp-clipchamp' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-powerautomatedesktop' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-windowsfeedbackhub' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-windows-devhome' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-todos' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-yourphone' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoftwindows-crossdevice' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoftcorporationii-microsoftfamily' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-gamingapp' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-xboxgamingoverlay' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-xboxspeechtotextoverlay' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-xbox-tcui' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-xboxidentityprovider' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-gethelp' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoftcorporationii-quickassist' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-msteams' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-outlookforwindows' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'appx-microsoft-microsoftofficehub' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'preset' = @{ Source = 'adr'; Host = 'HK'; Exec = $false }
    'animate-windows' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'taskbar-animations' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'fade-slide-menus' = @{ Source = 'adr'; Host = 'HP'; Exec = $false }
    'combo-slide' = @{ Source = 'adr'; Host = 'HP'; Exec = $false }
    'fade-slide-tooltips' = @{ Source = 'adr'; Host = 'HP'; Exec = $false }
    'fade-menu-items' = @{ Source = 'adr'; Host = 'HP'; Exec = $false }
    'animate-controls' = @{ Source = 'adr'; Host = 'HP'; Exec = $false }
    'tel-advertising-id' = @{ Source = 'chosen'; Host = 'HC'; Exec = $false }
    'tel-tailored-experiences' = @{ Source = 'chosen'; Host = 'HC'; Exec = $false }
    'tel-feedback-frequency' = @{ Source = 'public'; Host = 'UC'; Exec = $false }
    'tel-implicit-ink' = @{ Source = 'public'; Host = 'HC'; Exec = $true }
    'tel-implicit-text' = @{ Source = 'public'; Host = 'HC'; Exec = $true }
    'tel-harvest-contacts' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-personalization-policy' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-online-speech' = @{ Source = 'public'; Host = 'UC'; Exec = $false }
    'tel-tips-338389' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-system-pane-suggestions' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-soft-landing' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-suggested-338393' = @{ Source = 'none'; Host = 'HK'; Exec = $false }
    'tel-suggested-353694' = @{ Source = 'none'; Host = 'HK'; Exec = $false }
    'tel-suggested-353696' = @{ Source = 'none'; Host = 'HK'; Exec = $false }
    'tel-suggested-310093' = @{ Source = 'none'; Host = 'HK'; Exec = $false }
    'tel-scoobe' = @{ Source = 'adr'; Host = 'UC'; Exec = $false }
    'tel-track-progs' = @{ Source = 'public'; Host = 'HK'; Exec = $false }
    'tel-iris-recommendations' = @{ Source = 'adr'; Host = 'HK'; Exec = $false }
    'tel-accept-language-optout' = @{ Source = 'public'; Host = 'HK'; Exec = $false }
    'tel-m-feedback-notifications' = @{ Source = 'public'; Host = 'HK'; Exec = $false }
    'tel-m-publish-activities' = @{ Source = 'public'; Host = 'HK'; Exec = $false }
    'tel-m-upload-activities' = @{ Source = 'public'; Host = 'HK'; Exec = $false }
    'tel-m-ceip' = @{ Source = 'adr'; Host = 'UC'; Exec = $false }
    'tel-m-diagtrack' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-m-task-consolidator' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-m-task-usbceip' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-m-task-diskdiag' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-m-task-dmclient' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-m-task-dmclient-download' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'tel-m-task-autochk-proxy' = @{ Source = 'adr'; Host = 'HC'; Exec = $true }
    'rec-allowtelemetry-policy' = @{ Source = 'chosen'; Host = 'HK'; Exec = $null }
    'rec-allowtelemetry-current' = @{ Source = 'chosen'; Host = 'HC'; Exec = $null }
    'rec-maxtelemetry-current' = @{ Source = 'adr'; Host = 'HC'; Exec = $null }
    'rec-limit-diaglog' = @{ Source = 'chosen'; Host = 'HK'; Exec = $null }
    'rec-limit-dump' = @{ Source = 'chosen'; Host = 'HK'; Exec = $null }
    'rec-dmwappush' = @{ Source = 'adr'; Host = 'HC'; Exec = $null }
    'rec-location' = @{ Source = 'adr'; Host = 'HC'; Exec = $null }
}
$W1NoticeText = @{
    'notice-work-folders' = @{ personal = 'NOTICE step W: Work Folders sync tasks are not changed by step W; they need elevation. Change them by hand only if you do not use Work Folders.'; work = 'NOTICE step W: Work Folders sync tasks are not changed in the work profile; they stay as configured.' }
    'notice-onedrive-task' = @{ personal = 'NOTICE step W: the OneDrive scheduled startup task is not changed by step W; the OneDrive sign-in entry is handled by the startup entries.'; work = 'NOTICE step W: OneDrive startup is not changed in the work profile.' }
}
$W1Matrix = @{
    'startup' = @{ Kinds = @('StartupApproved', 'DWord'); Scope = 'user'; Profiles = $null }
    'consumer' = @{ Kinds = @('AppxRemove'); Scope = 'user'; Profiles = @('personal', 'work') }
    'support' = @{ Kinds = @('AppxRemove'); Scope = 'user'; Profiles = @('personal') }
    'work-app' = @{ Kinds = @('AppxRemove'); Scope = 'user'; Profiles = @('personal') }
    'report-only' = @{ Kinds = @('Notice'); Scope = 'user'; Profiles = @('personal', 'work') }
    'visual' = @{ Kinds = @('DWord', 'String', 'BinaryBit'); Scope = 'user'; Profiles = @('personal', 'work') }
    'telemetry-user' = @{ Kinds = @('DWord'); Scope = 'user'; Profiles = @('personal') }
    'telemetry-machine' = @{ Kinds = @('DWord', 'Service', 'Task'); Scope = 'machine'; Profiles = @('personal') }
    'telemetry-record' = @{ Kinds = @('Record'); Scope = 'machine'; Profiles = @('personal') }
}
$W1UpmFrom = @(0x9E, 0x1E, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00)
$W1UpmTo = @(0x98, 0x12, 0x07, 0x80, 0x10, 0x00, 0x00, 0x00)

# Fixed in code (not oracle data): the closed sets of ADR-0020 "Catalogue contract".
$W1Tags = @('startup', 'consumer', 'support', 'work-app', 'report-only', 'visual', 'telemetry-user', 'telemetry-machine', 'telemetry-record')
$W1Kinds = @('DWord', 'String', 'BinaryBit', 'StartupApproved', 'AppxRemove', 'Notice', 'Service', 'Task', 'Record')
$W1Sources = @('public', 'adr', 'chosen', 'none')
$W1Hosts = @('HC', 'HK', 'UC', 'HP')
$W1OptIns = @('RemoveApps', 'DisableTeamsStartup')
$W1GpuRegex = '(?i)(^|[^a-z0-9])(nvidia|nvcpl|radeon|amd|gpu|drs)([^a-z0-9]|$)|\.nip$'
$W1RunKey = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$W1SysAppRegex = '^Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\CurrentVersion\\AppModel\\SystemAppData\\([A-Za-z0-9.]+)_([a-z0-9]{13})\\[A-Za-z0-9]+$'
$W1CommonFields = @('Id', 'Tag', 'Kind', 'Scope', 'Profiles')
$W1WriterReq = @('WindowsDefaultState', 'Verified', 'Effect', 'Source', 'Host', 'Executable')
$W1KindFields = @{
    'DWord'           = @{ Req = @('Key', 'ValueName', 'Target') + $W1WriterReq; Opt = @('WindowsDefault', 'Ref', 'NoOpValues', 'OptIn', 'PolicyValues', 'RequiresUnmanaged') }
    'String'          = @{ Req = @('Key', 'ValueName', 'Target') + $W1WriterReq; Opt = @('WindowsDefault', 'Ref') }
    'BinaryBit'       = @{ Req = @('Key', 'ValueName', 'Byte', 'Mask', 'Target') + $W1WriterReq; Opt = @('WindowsDefault', 'Ref') }
    'StartupApproved' = @{ Req = @('Key', 'Target') + $W1WriterReq; Opt = @('ValueName', 'Pattern', 'WindowsDefault', 'Ref') }
    'AppxRemove'      = @{ Req = @('Name', 'Target', 'OptIn', 'Source', 'Host', 'Executable'); Opt = @('Ref') }
    'Notice'          = @{ Req = @('Notice'); Opt = @('Ref') }
    'Service'         = @{ Req = @('Name', 'Target') + $W1WriterReq; Opt = @('WindowsDefault', 'Ref') }
    'Task'            = @{ Req = @('TaskPath', 'TaskName', 'Target') + $W1WriterReq; Opt = @('WindowsDefault', 'Ref') }
    'Record'          = @{ Req = @('RecordOf', 'Source', 'Host'); Opt = @('Ref', 'Key', 'ValueName', 'Name') }
}

$script:WSeeds = @{}
$script:WFailures = New-Object 'System.Collections.Generic.List[string]'

function Add-WSeedCount {
    param([string]$Code, [bool]$Neg)
    if (-not $script:WSeeds.ContainsKey($Code)) { $script:WSeeds[$Code] = @(0, 0) }
    $i = 0
    if ($Neg) { $i = 1 }
    $script:WSeeds[$Code][$i]++
}

function Add-WFailure {
    param([string]$Msg)
    [void]$script:WFailures.Add($Msg)
}

function Assert-WNoFailures {
    $f = @($script:WFailures)
    $script:WFailures.Clear()
    Assert-True ($f.Count -eq 0) ("$($f.Count) W check(s) failed:`n  " + ($f -join "`n  "))
}

function Assert-WOnly {
    param($Problems, [string]$Code, [string]$Label)
    $pp = @($Problems)
    if ($pp.Count -lt 1) { Add-WFailure "$Code seed '$Label' was not caught"; return }
    foreach ($x in $pp) {
        if (-not $x.StartsWith("${Code}:")) { Add-WFailure "$Code seed '$Label' yields other codes: $($pp -join ' | ')"; return }
    }
    Add-WSeedCount $Code $false
}

function Assert-WAbsent {
    param($Problems, [string]$Code, [string]$Label)
    $pp = @($Problems)
    foreach ($x in $pp) {
        if ($x.StartsWith("${Code}:")) { Add-WFailure "$Code negative '$Label' was flagged: $x"; return }
    }
    Add-WSeedCount $Code $true
}

function Add-WProblem {
    param($List, [string]$Code, [string]$Id, [string]$Msg)
    [void]$List.Add("${Code}: ${Id}: $Msg")
}

function Copy-WData {
    param($X)
    if ($X -is [hashtable]) {
        $h = @{}
        foreach ($k in $X.Keys) { $h[$k] = Copy-WData $X[$k] }
        return $h
    }
    if ($X -is [System.Collections.IEnumerable] -and $X -isnot [string]) {
        $l = New-Object 'System.Collections.Generic.List[object]'
        foreach ($i in $X) { $l.Add((Copy-WData $i)) }
        return , ($l.ToArray())
    }
    return $X
}

function Get-WReal {
    if ($null -eq $script:WRealData) { $script:WRealData = Import-PowerShellDataFile -LiteralPath $WCatPath -ErrorAction Stop }
    return (Copy-WData $script:WRealData)
}

function Get-WEntry {
    param($Data, [string]$Id)
    foreach ($x in $Data.Entries) { if ($x.Id -ceq $Id) { return $x } }
    throw "Get-WEntry: no entry $Id"
}

function Edit-WEntry {
    param($Data, [string]$Id, [hashtable]$Set = @{}, [string[]]$Remove = @())
    $e = Get-WEntry $Data $Id
    foreach ($k in $Set.Keys) { $e[$k] = $Set[$k] }
    foreach ($k in $Remove) { $e.Remove($k) }
}

function Add-WEntry {
    param($Data, $Entry)
    $Data.Entries = [object[]](@($Data.Entries) + @(, $Entry))
}

function Copy-WEntryAs {
    param($Data, [string]$Id, [string]$NewId, [hashtable]$Set = @{})
    $c = Copy-WData (Get-WEntry $Data $Id)
    $c['Id'] = $NewId
    foreach ($k in $Set.Keys) { $c[$k] = $Set[$k] }
    Add-WEntry $Data $c
}

function Remove-WEntry {
    param($Data, [string]$Id)
    $Data.Entries = [object[]]@($Data.Entries | Where-Object -FilterScript { $_.Id -cne $Id })
}

function Swap-WEntries {
    param($Data, [string]$A, [string]$B)
    $l = @($Data.Entries)
    $i = -1; $j = -1
    for ($n = 0; $n -lt $l.Count; $n++) {
        if ($l[$n].Id -ceq $A) { $i = $n }
        if ($l[$n].Id -ceq $B) { $j = $n }
    }
    if ($i -lt 0 -or $j -lt 0) { throw "Swap-WEntries: missing $A or $B" }
    $t = $l[$i]; $l[$i] = $l[$j]; $l[$j] = $t
    $Data.Entries = [object[]]$l
}

function Test-WSameSet {
    param($A, $B, [bool]$IgnoreCase = $false)
    $cmp = [StringComparer]::Ordinal
    if ($IgnoreCase) { $cmp = [StringComparer]::OrdinalIgnoreCase }
    $x = New-Object 'System.Collections.Generic.List[string]'
    $y = New-Object 'System.Collections.Generic.List[string]'
    foreach ($i in @($A)) { $x.Add([string]$i) }
    foreach ($i in @($B)) { $y.Add([string]$i) }
    $x.Sort($cmp); $y.Sort($cmp)
    if ($x.Count -ne $y.Count) { return $false }
    for ($i = 0; $i -lt $x.Count; $i++) { if (-not $cmp.Equals($x[$i], $y[$i])) { return $false } }
    return $true
}

function Test-WDeepEqual {
    param($A, $B)
    if ($A -is [hashtable] -or $B -is [hashtable]) {
        if ($A -isnot [hashtable] -or $B -isnot [hashtable]) { return $false }
        if ($A.Count -ne $B.Count) { return $false }
        foreach ($k in $A.Keys) {
            if (-not (@($B.Keys) -ccontains $k)) { return $false }
            if (-not (Test-WDeepEqual $A[$k] $B[$k])) { return $false }
        }
        return $true
    }
    if ($A -is [Array] -or $B -is [Array]) {
        if ($A -isnot [Array] -or $B -isnot [Array]) { return $false }
        if ($A.Count -ne $B.Count) { return $false }
        for ($i = 0; $i -lt $A.Count; $i++) { if (-not (Test-WDeepEqual $A[$i] $B[$i])) { return $false } }
        return $true
    }
    if ($null -eq $A -or $null -eq $B) { return ($null -eq $A -and $null -eq $B) }
    if ($A.GetType() -ne $B.GetType()) { return $false }
    return ($A -ceq $B)
}

function Test-WConstantAst {
    # the descendant nodes (and the node itself) that are not allowed in a data-only literal
    param($Node)
    $ns = 'Management.Automation.Language'
    $bad = New-Object 'System.Collections.Generic.List[object]'
    foreach ($n in @($Node.FindAll({ param($x) $true }, $true))) {
        $ok = $false
        if ($n -is [Management.Automation.Language.ScriptBlockAst]) {
            $ok = ($null -eq $n.Parent)
        } elseif ($n -is [Management.Automation.Language.NamedBlockAst]) {
            $ok = ($n.Parent -is [Management.Automation.Language.ScriptBlockAst] -and $null -eq $n.Parent.Parent)
        } elseif ($n -is [Management.Automation.Language.StringConstantExpressionAst]) {
            $t = $n.StringConstantType.ToString()
            if ($t -ceq 'SingleQuoted') { $ok = $true }
            elseif ($t -ceq 'BareWord' -and $n.Parent -is [Management.Automation.Language.HashtableAst]) {
                foreach ($kv in $n.Parent.KeyValuePairs) { if ([object]::ReferenceEquals($kv.Item1, $n)) { $ok = $true } }
            }
        } elseif ($n -is [Management.Automation.Language.VariableExpressionAst]) {
            $vn = $n.VariablePath.UserPath
            $ok = ($vn -ceq 'true' -or $vn -ceq 'false')
        } elseif ($n -is [Management.Automation.Language.ConstantExpressionAst]) {
            $ok = $true
        } elseif ($n -is [Management.Automation.Language.StatementBlockAst] -or $n -is [Management.Automation.Language.PipelineAst] -or
            $n -is [Management.Automation.Language.CommandExpressionAst] -or $n -is [Management.Automation.Language.HashtableAst] -or
            $n -is [Management.Automation.Language.ArrayExpressionAst] -or $n -is [Management.Automation.Language.ArrayLiteralAst]) {
            $ok = $true
        }
        if (-not $ok) { [void]$bad.Add($n) }
    }
    return $bad
}

function Get-WAstProblems {
    param([string]$Path)
    $p = New-Object 'System.Collections.Generic.List[string]'
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { Add-WProblem $p 'W1-ast' '-' 'the file has a byte order mark' }
    foreach ($b in $bytes) { if ($b -gt 0x7F) { Add-WProblem $p 'W1-ast' '-' 'the file has a byte above 0x7F'; break } }
    $tk = $null; $er = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tk, [ref]$er)
    if ($er.Count -gt 0) { Add-WProblem $p 'W1-ast' '-' "parse error: $($er[0].Message)"; return $p }
    if ($ast.ParamBlock) { Add-WProblem $p 'W1-ast' '-' 'the root has a param block' }
    $st = @()
    if ($ast.EndBlock) { $st = @($ast.EndBlock.Statements) }
    if ($st.Count -ne 1) { Add-WProblem $p 'W1-ast' '-' "the root holds $($st.Count) statements, expected 1"; return $p }
    $s0 = $st[0]
    if ($s0 -isnot [Management.Automation.Language.PipelineAst] -or $s0.PipelineElements.Count -ne 1 -or
        $s0.PipelineElements[0] -isnot [Management.Automation.Language.CommandExpressionAst] -or
        $s0.PipelineElements[0].Expression -isnot [Management.Automation.Language.HashtableAst]) {
        Add-WProblem $p 'W1-ast' '-' 'the root statement is not a single hashtable literal'
        return $p
    }
    foreach ($n in @(Test-WConstantAst $ast)) {
        Add-WProblem $p 'W1-ast' '-' "line $($n.Extent.StartLineNumber): not allowed in a data file: $($n.GetType().Name) $($n.Extent.Text)"
    }
    return $p
}

function Get-WFnBodyProblems {
    param($Ast)
    $p = New-Object 'System.Collections.Generic.List[string]'
    foreach ($fnName in @('Get-WindowsSettingsTagKeys', 'Get-WindowsSettingsProtectedAppx')) {
        $defs = @($Ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $fnName }, $true))
        if ($defs.Count -ne 1) { Add-WProblem $p 'W1-fn-body' $fnName "defined $($defs.Count) times, expected 1"; continue }
        $f = $defs[0]
        if (-not ($f.Parent -is [Management.Automation.Language.NamedBlockAst] -and $f.Parent.Parent -eq $Ast)) { Add-WProblem $p 'W1-fn-body' $fnName 'not defined at top level'; continue }
        $b = $f.Body
        if ($b.ParamBlock -or $b.DynamicParamBlock -or $b.BeginBlock -or $b.ProcessBlock) { Add-WProblem $p 'W1-fn-body' $fnName 'has a param, dynamicparam, begin or process block'; continue }
        $st = @()
        if ($b.EndBlock) { $st = @($b.EndBlock.Statements) }
        if ($st.Count -ne 1 -or $st[0] -isnot [Management.Automation.Language.ReturnStatementAst]) { Add-WProblem $p 'W1-fn-body' $fnName 'the body is not exactly one return statement'; continue }
        $pl = $st[0].Pipeline
        if ($pl -isnot [Management.Automation.Language.PipelineAst] -or $pl.PipelineElements.Count -ne 1 -or $pl.PipelineElements[0] -isnot [Management.Automation.Language.CommandExpressionAst]) { Add-WProblem $p 'W1-fn-body' $fnName 'the return is not a single expression'; continue }
        $lit = $pl.PipelineElements[0].Expression
        if ($lit -isnot [Management.Automation.Language.HashtableAst] -and $lit -isnot [Management.Automation.Language.ArrayExpressionAst]) { Add-WProblem $p 'W1-fn-body' $fnName 'the return is not a hashtable or array literal'; continue }
        foreach ($n in @(Test-WConstantAst $lit)) { Add-WProblem $p 'W1-fn-body' $fnName "line $($n.Extent.StartLineNumber): not a constant: $($n.GetType().Name) $($n.Extent.Text)" }
    }
    return $p
}

function Get-WOracleProblems {
    param($TagKeys, $Protected, $OracleTagKeys = $W1TagKeys, $OracleTelemetry = $W1Telemetry)
    $p = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-WDeepEqual $TagKeys $W1TagKeys)) { Add-WProblem $p 'W1-oracle-allow' '-' 'Get-WindowsSettingsTagKeys differs from the ADR-0020 N12 table' }
    if (-not (Test-WDeepEqual $Protected $W1Protected)) { Add-WProblem $p 'W1-oracle-protected' '-' 'Get-WindowsSettingsProtectedAppx differs from the ADR-0020 (d) protected set' }
    foreach ($tag in @('telemetry-user', 'telemetry-machine', 'telemetry-record')) {
        $rows = New-Object 'System.Collections.Generic.List[object]'
        $svc = New-Object 'System.Collections.Generic.List[object]'
        $tsk = New-Object 'System.Collections.Generic.List[object]'
        foreach ($r in $OracleTelemetry) {
            if ($r.Tag -cne $tag) { continue }
            if ($r.ContainsKey('Key')) {
                $row = $null
                foreach ($x in $rows) { if ($x.Key -ieq $r.Key) { $row = $x } }
                if ($null -eq $row) { $row = @{ Key = $r.Key; Names = (New-Object 'System.Collections.Generic.List[object]') }; $rows.Add($row) }
                $dup = $false
                foreach ($nm in $row.Names) { if ($nm -ieq $r.ValueName) { $dup = $true } }
                if (-not $dup) { $row.Names.Add($r.ValueName) }
            } elseif ($r.Kind -ceq 'Task') {
                $tsk.Add($r.TaskPath + $r.TaskName)
            } elseif ($r.ContainsKey('Name')) {
                $svc.Add($r.Name)
            }
        }
        $want = @()
        foreach ($x in $rows) { $want += , @{ Key = $x.Key; Names = [object[]]$x.Names.ToArray() } }
        $have = $OracleTagKeys[$tag]
        if (-not (Test-WDeepEqual ([object[]]$want) $have.Registry) -or -not (Test-WDeepEqual ([object[]]$svc.ToArray()) $have.Services) -or -not (Test-WDeepEqual ([object[]]$tsk.ToArray()) $have.Tasks)) {
            Add-WProblem $p 'W1-oracle-sync' $tag 'the ADR-0035 Key expansion rows and the ADR-0020 N12 table disagree'
        }
    }
    return $p
}

function Get-WBitProblem {
    param($E)
    if ($E['Byte'] -lt 0 -or $E['Byte'] -gt 7) { return 'Byte must be 0 to 7' }
    if (@(1, 2, 4, 8, 16, 32, 64, 128) -notcontains $E['Mask']) { return 'Mask must be a single bit' }
    if ($E['Byte'] -eq 3 -and $E['Mask'] -eq 0x80) { return 'byte 3 with mask 0x80 is forbidden' }
    if ($E['Target'] -ne 0 -and $E['Target'] -ne 1) { return 'Target must be 0 or 1' }
    if ($E['Key'] -ine 'Control Panel\Desktop' -or $E['ValueName'] -ine 'UserPreferencesMask') { return 'BinaryBit applies to UserPreferencesMask only' }
    return $null
}

function Test-WEntryTier1 {
    param($E, $Seen, $P)
    $id = '-'
    if ($E['Id'] -is [string]) { $id = $E['Id'] }
    foreach ($f in @('Id', 'Key', 'Name', 'ValueName', 'TaskName')) {
        if ($E.ContainsKey($f) -and $E[$f] -is [string] -and $E[$f] -match $W1GpuRegex) { Add-WProblem $P 'W1-gpu' $id "$f names a GPU or driver-profile target"; return }
    }
    if ($E['Id'] -isnot [string] -or $E['Id'] -cnotmatch '^[a-z0-9][a-z0-9-]{0,47}$') { Add-WProblem $P 'W1-id' $id 'Id does not match ^[a-z0-9][a-z0-9-]{0,47}$'; return }
    if (-not $Seen.Add($E['Id'])) { Add-WProblem $P 'W1-id' $id 'duplicate Id'; return }
    $tag = $E['Tag']
    if ($tag -isnot [string] -or $W1Tags -cnotcontains $tag) { Add-WProblem $P 'W1-tag' $id 'Tag is not in the closed set'; return }
    $kind = $E['Kind']
    if ($kind -isnot [string] -or $W1Kinds -cnotcontains $kind -or $W1Matrix[$tag].Kinds -cnotcontains $kind) { Add-WProblem $P 'W1-kind' $id "Kind is not allowed for Tag $tag"; return }
    if ($E['Scope'] -isnot [string] -or $E['Scope'] -cne $W1Matrix[$tag].Scope) { Add-WProblem $P 'W1-scope' $id "Scope must be $($W1Matrix[$tag].Scope) for Tag $tag"; return }
    if ($kind -ceq 'Record') {
        $ro = $E['RecordOf']
        $hasKey = $E.ContainsKey('Key'); $hasVn = $E.ContainsKey('ValueName'); $hasName = $E.ContainsKey('Name')
        $shapeOk = $false
        if ($ro -is [string]) {
            if ($ro -ceq 'DWord' -or $ro -ceq 'String') { $shapeOk = ($hasKey -and $hasVn -and -not $hasName) }
            elseif ($ro -ceq 'Service') { $shapeOk = ($hasName -and -not $hasKey -and -not $hasVn) }
        }
        if (-not $shapeOk) { Add-WProblem $P 'W1-record-of' $id 'RecordOf must be DWord or String (Key and ValueName, no Name) or Service (Name, no Key or ValueName)'; return }
        foreach ($f in @('Target', 'WindowsDefaultState', 'WindowsDefault', 'Verified', 'Effect', 'Executable')) {
            if ($E.ContainsKey($f)) { Add-WProblem $P 'W1-record-field' $id "a Record must not carry $f"; return }
        }
    }
    # W1-field
    $kf = $W1KindFields[$kind]
    $req = @($W1CommonFields) + @($kf.Req)
    $allowed = $req + @($kf.Opt)
    foreach ($k in @($E.Keys)) { if ($allowed -cnotcontains $k) { Add-WProblem $P 'W1-field' $id "unknown field $k"; return } }
    foreach ($k in $req) { if (-not $E.ContainsKey($k)) { Add-WProblem $P 'W1-field' $id "missing field $k"; return } }
    $isTel = $tag -like 'telemetry-*'
    if ($E.ContainsKey('Ref') -and -not $isTel) { Add-WProblem $P 'W1-field' $id 'Ref is only for telemetry Tags'; return }
    if ($isTel -and -not $E.ContainsKey('Ref')) { Add-WProblem $P 'W1-field' $id 'a telemetry Tag needs Ref'; return }
    if ($kind -ceq 'StartupApproved' -and ($E.ContainsKey('ValueName') -eq $E.ContainsKey('Pattern'))) { Add-WProblem $P 'W1-field' $id 'StartupApproved needs exactly one of ValueName and Pattern'; return }
    # W1-type
    foreach ($f in @('Id', 'Tag', 'Kind', 'Scope', 'Key', 'ValueName', 'Pattern', 'Name', 'TaskPath', 'TaskName', 'Source', 'Host', 'OptIn', 'RecordOf', 'Ref', 'Effect', 'WindowsDefaultState')) {
        if ($E.ContainsKey($f) -and $E[$f] -isnot [string]) { Add-WProblem $P 'W1-type' $id "$f must be a string"; return }
    }
    if ($E.ContainsKey('Source') -and $W1Sources -cnotcontains $E['Source']) { Add-WProblem $P 'W1-type' $id 'Source is not in the closed set'; return }
    if ($E.ContainsKey('Host') -and $W1Hosts -cnotcontains $E['Host']) { Add-WProblem $P 'W1-type' $id 'Host is not in the closed set'; return }
    foreach ($f in @('Profiles', 'NoOpValues', 'PolicyValues')) {
        if ($E.ContainsKey($f) -and $E[$f] -isnot [object[]]) { Add-WProblem $P 'W1-type' $id "$f must be an array"; return }
    }
    foreach ($f in @('Verified', 'Executable', 'RequiresUnmanaged')) {
        if ($E.ContainsKey($f) -and $E[$f] -isnot [bool]) { Add-WProblem $P 'W1-type' $id "$f must be a bool"; return }
    }
    foreach ($f in @('Byte', 'Mask')) {
        if ($E.ContainsKey($f) -and $E[$f] -isnot [int]) { Add-WProblem $P 'W1-type' $id "$f must be an int"; return }
    }
    if ($E.ContainsKey('Notice') -and $E['Notice'] -isnot [hashtable]) { Add-WProblem $P 'W1-type' $id 'Notice must be a hashtable'; return }
    if ($E.ContainsKey('Target')) {
        $t = $E['Target']
        $tok = $true
        if ($kind -ceq 'DWord' -or $kind -ceq 'BinaryBit') { $tok = ($t -is [int] -or $t -is [long]) }
        elseif ($kind -ceq 'String') { $tok = ($t -is [string]) }
        elseif ($kind -ceq 'StartupApproved') { $tok = ($t -is [string] -and $t -ceq 'disabled') }
        elseif ($kind -ceq 'AppxRemove') { $tok = ($t -is [string] -and $t -ceq 'absent') }
        elseif ($kind -ceq 'Service' -or $kind -ceq 'Task') { $tok = ($t -is [string] -and $t -ceq 'Disabled') }
        if (-not $tok) { Add-WProblem $P 'W1-type' $id "Target has the wrong type or value for Kind $kind"; return }
    }
    # W1-range
    if ($kind -ceq 'DWord') {
        foreach ($f in @('Target', 'WindowsDefault')) {
            if ($E.ContainsKey($f)) {
                $v = $E[$f]
                if ($v -is [long] -or ($v -is [int] -and $v -lt 0)) { Add-WProblem $P 'W1-range' $id "$f is outside 0 to 0x7FFFFFFF"; return }
            }
        }
    }
}

function Test-WEntryTier2 {
    param($E, $TagKeys, $Protected, $P)
    $id = $E['Id']; $tag = $E['Tag']; $kind = $E['Kind']; $scope = $E['Scope']
    # W1-profile
    $pr = @($E['Profiles'])
    $profOk = ($pr.Count -ge 1)
    foreach ($x in $pr) { if ($x -isnot [string] -or ($x -cne 'personal' -and $x -cne 'work')) { $profOk = $false } }
    if ($profOk -and -not (Test-WSameSet $pr (@($pr | Select-Object -Unique)))) { $profOk = $false }
    $mp = $W1Matrix[$tag].Profiles
    if ($profOk -and $null -ne $mp -and -not (Test-WSameSet $pr $mp)) { $profOk = $false }
    if (-not $profOk) { Add-WProblem $P 'W1-profile' $id 'Profiles must be a distinct subset of personal and work that matches the Tag' }
    # key group
    if ($E.ContainsKey('Key')) {
        $key = $E['Key']
        $keyBad = $false
        if ($key -match '(?i)^HK|HKEY_|Registry::' -or $key.Contains('*') -or $key.Contains('?') -or $key.Contains('/')) { $keyBad = $true }
        foreach ($seg in ($key -split '\\')) { if ($seg -ceq '.' -or $seg -ceq '..') { $keyBad = $true } }
        if ($E.ContainsKey('Pattern') -and $E['Pattern'] -cnotmatch '^[A-Za-z0-9]+_\*$') { $keyBad = $true }
        if ($keyBad) {
            Add-WProblem $P 'W1-key' $id 'Key or Pattern has a hive form, a wildcard, a slash or a dot segment'
        } else {
            $canonBad = ($key.StartsWith('\') -or $key.EndsWith('\') -or $key.Contains('\\'))
            foreach ($seg in ($key -split '\\')) { if ($seg.StartsWith(' ') -or $seg.EndsWith(' ')) { $canonBad = $true } }
            if ($canonBad) {
                Add-WProblem $P 'W1-key-canon' $id 'Key is not in canonical form'
            } elseif ($scope -ceq 'user' -and $key -match '(?i)(^|\\)Policies(\\|$)') {
                Add-WProblem $P 'W1-policies' $id 'a user-scope key must not be under Policies'
            } elseif ($tag -ceq 'startup' -and $key -ine $W1RunKey -and $key -notmatch $W1SysAppRegex) {
                Add-WProblem $P 'W1-startup-shape' $id 'a startup key must be the Run key or a SystemAppData task key'
            } else {
                $row = $null
                $tkRow = $TagKeys[$tag]
                if ($null -ne $tkRow) { foreach ($r in @($tkRow.Registry)) { if ($null -eq $row -and $r.Key -ieq $key) { $row = $r } } }
                if ($null -eq $row) {
                    Add-WProblem $P 'W1-allow' $id 'Key is not on the allowlist of its Tag'
                } else {
                    $names = @($row.Names)
                    $tripleOk = $true
                    if ($E.ContainsKey('Pattern')) {
                        $tripleOk = $false
                        foreach ($nm in $names) { if ($nm -ieq $E['Pattern']) { $tripleOk = $true } }
                    } elseif ($E.ContainsKey('ValueName')) {
                        $tripleOk = $false
                        foreach ($nm in $names) { if ($E['ValueName'] -like $nm) { $tripleOk = $true } }
                    }
                    if (-not $tripleOk) { Add-WProblem $P 'W1-triple' $id 'ValueName or Pattern is not allowed under this key for this Tag' }
                }
            }
        }
    }
    if ($kind -ceq 'Service' -or ($kind -ceq 'Record' -and $E['RecordOf'] -ceq 'Service')) {
        $on = $false
        if ($null -ne $TagKeys[$tag]) { foreach ($s in @($TagKeys[$tag].Services)) { if ($s -ieq $E['Name']) { $on = $true } } }
        if (-not $on) { Add-WProblem $P 'W1-allow' $id 'service is not on the allowlist of its Tag' }
    }
    if ($kind -ceq 'Task') {
        $on = $false
        if ($null -ne $TagKeys[$tag]) { foreach ($s in @($TagKeys[$tag].Tasks)) { if ($s -ieq ($E['TaskPath'] + $E['TaskName'])) { $on = $true } } }
        if (-not $on) { Add-WProblem $P 'W1-allow' $id 'task is not on the allowlist of its Tag' }
    }
    if ($kind -ceq 'BinaryBit') {
        $bp = Get-WBitProblem $E
        if ($bp) { Add-WProblem $P 'W1-bit' $id $bp }
    }
    if ($kind -ceq 'AppxRemove') {
        $nm = $E['Name']
        $prot = $false
        foreach ($x in @($Protected.Names)) { if ($nm -ieq $x) { $prot = $true } }
        foreach ($x in @($Protected.Prefixes)) { if ($nm.StartsWith($x, [StringComparison]::OrdinalIgnoreCase)) { $prot = $true } }
        if ($prot) { Add-WProblem $P 'W1-protected' $id 'a protected package must never be removed' }
        $wantAppxId = 'appx-' + $nm.ToLowerInvariant().Replace('.', '-')
        if ($E['Id'] -cne $wantAppxId) { Add-WProblem $P 'W1-appx-id' $id "an AppxRemove Id must be $wantAppxId" }
    }
    if ($E.ContainsKey('NoOpValues')) {
        $nv = @($E['NoOpValues'])
        $nopOk = ($tag -ceq 'startup' -and $kind -ceq 'DWord')
        foreach ($x in $nv) { if ($x -isnot [int] -or $x -lt 0 -or $x -eq $E['Target']) { $nopOk = $false } }
        if (@($nv | Select-Object -Unique).Count -ne $nv.Count) { $nopOk = $false }
        if ($tag -ceq 'startup' -and $kind -ceq 'DWord' -and ($nv.Count -ne 1 -or $nv[0] -ne 0)) { $nopOk = $false }
        if (-not $nopOk) { Add-WProblem $P 'W1-noop' $id 'NoOpValues is only for startup DWord entries: distinct ints >= 0 that exclude the Target' }
    }
    if ($E.ContainsKey('Effect')) {
        $ef = $E['Effect']
        $efOk = ($ef -ceq 'none' -or $ef -ceq 'sign-out')
        if ($tag -ceq 'visual' -and $ef -cne 'sign-out') { $efOk = $false }
        if ($tag -cne 'visual' -and $ef -cne 'none') { $efOk = $false }
        if (-not $efOk) { Add-WProblem $P 'W1-effect' $id 'Effect must be sign-out for visual and none for every other Tag' }
    }
    if ($E.ContainsKey('WindowsDefaultState')) {
        $ws = $E['WindowsDefaultState']
        $dOk = ($ws -ceq 'value' -or $ws -ceq 'absent' -or $ws -ceq 'unknown')
        if ($dOk) {
            if (($ws -ceq 'value') -ne $E.ContainsKey('WindowsDefault')) { $dOk = $false }
            elseif ($ws -ceq 'value') {
                $wd = $E['WindowsDefault']
                if ($kind -ceq 'DWord') { if ($wd -isnot [int] -or $wd -lt 0) { $dOk = $false } }
                elseif ($kind -ceq 'BinaryBit') { if ($wd -isnot [int] -or ($wd -ne 0 -and $wd -ne 1)) { $dOk = $false } }
                elseif ($kind -ceq 'StartupApproved') { $dOk = $false }
                else { if ($wd -isnot [string]) { $dOk = $false } }
            }
        }
        if (-not $dOk) { Add-WProblem $P 'W1-default' $id 'WindowsDefaultState or WindowsDefault is invalid' }
    }
    if ($E.ContainsKey('Verified') -and $E['Verified'] -ne $false) { Add-WProblem $P 'W1-verified' $id 'Verified must be $false until its human check' }
    if ($kind -ceq 'Notice') {
        $nt = $E['Notice']
        foreach ($k in @($nt.Keys)) {
            $tx = $nt[$k]
            $why = $null
            if ($tx -isnot [string]) { $why = 'the text is not a string' }
            elseif (-not $tx.StartsWith('NOTICE step W: ', [StringComparison]::Ordinal)) { $why = 'the text does not start with NOTICE step W: ' }
            elseif ($tx -cmatch '[^\x00-\x7F]') { $why = 'the text is not ASCII' }
            elseif ($tx -match $BoundaryR8Regex1 -or $tx -match $BoundaryR8Regex2) { $why = 'the text names an executable' }
            else {
                foreach ($bad in @('S-1-5-', '\', 'OneDrive Startup Task', 'OneDrive Reporting Task', 'OneDrive Standalone Update Task', 'Work Folders Logon Synchronization', 'Work Folders Maintenance Work')) {
                    if ($tx.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { $why = "the text contains '$bad'" }
                }
            }
            if ($why) { Add-WProblem $P 'W1-notice' $id "profile ${k}: $why" }
        }
        if (-not (Test-WSameSet @($nt.Keys) $pr)) { Add-WProblem $P 'W1-notice-profiles' $id 'the Notice keys must equal Profiles' }
    }
    # W1-optin
    if ($kind -ceq 'AppxRemove') {
        if ($E['OptIn'] -cne 'RemoveApps') { Add-WProblem $P 'W1-optin' $id 'an AppxRemove entry needs OptIn RemoveApps' }
    } elseif ($E.ContainsKey('OptIn') -and $E['OptIn'] -cne 'DisableTeamsStartup') {
        Add-WProblem $P 'W1-optin' $id 'only OptIn DisableTeamsStartup is allowed on a non-Appx entry'
    }
    # W1-gate
    if ($kind -cne 'AppxRemove' -and $kind -cne 'Notice' -and $kind -cne 'Record') {
        $isTeams = ($tag -ceq 'startup' -and $kind -ceq 'DWord')
        $gateOk = $true
        if ($isTeams) {
            # the Teams SystemAppData startup entry carries the full gate; OptIn's value is checked by W1-optin, NoOpValues' value by W1-noop
            foreach ($gf in @('NoOpValues', 'OptIn', 'PolicyValues', 'RequiresUnmanaged')) { if (-not $E.ContainsKey($gf)) { $gateOk = $false } }
            if ($E['Target'] -isnot [int] -or $E['Target'] -ne 1) { $gateOk = $false }
        } else {
            foreach ($gf in @('OptIn', 'PolicyValues', 'RequiresUnmanaged')) { if ($E.ContainsKey($gf)) { $gateOk = $false } }
        }
        if ($E.ContainsKey('PolicyValues')) {
            $pv = @($E['PolicyValues'])
            if ($pv.Count -ne 2 -or $pv[0] -isnot [int] -or $pv[1] -isnot [int] -or $pv[0] -ne 3 -or $pv[1] -ne 4) { $gateOk = $false }
        }
        if ($E.ContainsKey('RequiresUnmanaged') -and $E['RequiresUnmanaged'] -ne $true) { $gateOk = $false }
        if (-not $gateOk) { Add-WProblem $P 'W1-gate' $id 'only the Teams SystemAppData startup entry carries the gate: Target 1, NoOpValues, OptIn, PolicyValues @(3,4), RequiresUnmanaged $true' }
    }
    if ($E.ContainsKey('Executable')) {
        $want = (($E['Source'] -ceq 'public' -or $E['Source'] -ceq 'adr') -and $E['Host'] -ceq 'HC')
        if ($E['Executable'] -ne $want) { Add-WProblem $P 'W1-exec' $id "Executable must be $want for Source $($E['Source']) and Host $($E['Host'])" }
    }
    if ($W1Labels.ContainsKey($id) -and $E.ContainsKey('Source') -and $E.ContainsKey('Host')) {
        if ($E['Source'] -cne $W1Labels[$id].Source -or $E['Host'] -cne $W1Labels[$id].Host) { Add-WProblem $P 'W1-oracle-label' $id 'Source or Host differs from the ADR label' }
    }
}

function Get-WTargetKey {
    param($E)
    return (($E['Scope'] + '|' + $E['Key'] + '|' + $E['ValueName'])).ToLowerInvariant()
}

function Test-WCatalogueGlobal {
    param($Entries, $TagKeys, $P)
    $appx = @($Entries | Where-Object -FilterScript { $_['Kind'] -ceq 'AppxRemove' })
    # W1-list
    $listBad = $false
    foreach ($prof in @('personal', 'work')) {
        $have = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($a in $appx) { if (@($a['Profiles']) -ccontains $prof) { [void]$have.Add($a['Name']) } }
        $want = @($W1Consumer)
        if ($prof -ceq 'personal') { $want = @($W1Consumer) + @($W1Support) + @($W1WorkApps) }
        if (-not (Test-WSameSet @($have) $want $true)) { $listBad = $true; Add-WProblem $P 'W1-list' '-' "the AppxRemove names for profile $prof differ from the ADR-0020 (b) lists" }
    }
    # W1-order
    if (-not $listBad) {
        $order = New-Object 'System.Collections.Generic.List[string]'
        foreach ($a in $appx) { if ($a['Tag'] -ceq 'consumer' -and @($order | Where-Object -FilterScript { $_ -ieq $a['Name'] }).Count -eq 0) { $order.Add($a['Name']) } }
        if (-not (Test-WDeepEqual ([object[]]$order.ToArray()) ([object[]]@($W1Consumer)))) { Add-WProblem $P 'W1-order' '-' 'the consumer names are not in ADR-0020 (b) order' }
    }
    # W1-n8 and W1-work-startup
    foreach ($e in $Entries) {
        if ($e['Tag'] -ceq 'startup' -and $e.ContainsKey('Key')) {
            $m = [regex]::Match($e['Key'], $W1SysAppRegex)
            if ($m.Success) {
                $pkg = $m.Groups[1].Value
                foreach ($prof in @($e['Profiles'])) {
                    foreach ($a in $appx) {
                        if ($a['Name'] -ieq $pkg -and @($a['Profiles']) -ccontains $prof) { Add-WProblem $P 'W1-n8' $e['Id'] "package $pkg is removed in profile $prof by $($a['Id'])" }
                    }
                }
            }
        }
    }
    $ws = @($Entries | Where-Object -FilterScript { $_['Tag'] -ceq 'startup' -and @($_['Profiles']) -ccontains 'work' } | ForEach-Object -Process { $_['Id'] })
    if (-not (Test-WDeepEqual ([object[]]$ws) ([object[]]@('startup-teams')))) { Add-WProblem $P 'W1-work-startup' '-' 'the work startup set must be exactly startup-teams' }
    # W1-dup-target
    $whole = New-Object 'System.Collections.Generic.List[object]'
    $wholeKeys = @{}
    $bitKeys = @{}
    $bitValues = @{}
    $patterns = New-Object 'System.Collections.Generic.List[object]'
    foreach ($e in $Entries) {
        $k = $e['Kind']
        if ($k -ceq 'DWord' -or $k -ceq 'String' -or ($k -ceq 'StartupApproved' -and $e.ContainsKey('ValueName'))) {
            $tk = Get-WTargetKey $e
            if ($wholeKeys.ContainsKey($tk)) { Add-WProblem $P 'W1-dup-target' $e['Id'] "same target as $($wholeKeys[$tk])" } else { $wholeKeys[$tk] = $e['Id']; [void]$whole.Add($e) }
        } elseif ($k -ceq 'StartupApproved') {
            [void]$patterns.Add($e)
        } elseif ($k -ceq 'BinaryBit') {
            $tk = (Get-WTargetKey $e) + '|' + $e['Byte'] + '|' + $e['Mask']
            if ($bitKeys.ContainsKey($tk)) { Add-WProblem $P 'W1-dup-target' $e['Id'] "same bit as $($bitKeys[$tk])" } else { $bitKeys[$tk] = $e['Id'] }
            $bitValues[(Get-WTargetKey $e)] = $e['Id']
        }
    }
    foreach ($tk in @($wholeKeys.Keys)) {
        if ($bitValues.ContainsKey($tk)) { Add-WProblem $P 'W1-dup-target' $wholeKeys[$tk] "whole-value target shares its value with the BinaryBit entry $($bitValues[$tk])" }
    }
    foreach ($pe in $patterns) {
        foreach ($we in $whole) {
            if ($we['Scope'] -ceq $pe['Scope'] -and $we['Key'] -ieq $pe['Key'] -and $we['ValueName'] -like $pe['Pattern']) {
                Add-WProblem $P 'W1-dup-target' $pe['Id'] "Pattern matches the value name of $($we['Id'])"
            }
        }
    }
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $Entries) {
        $ident = $null
        if ($e['Kind'] -ceq 'AppxRemove') { $ident = 'appx|' + $e['Name'] }
        elseif ($e['Kind'] -ceq 'Service') { $ident = 'svc|' + $e['Name'] }
        elseif ($e['Kind'] -ceq 'Task') { $ident = 'task|' + $e['TaskPath'] + $e['TaskName'] }
        if ($null -ne $ident -and -not $names.Add($ident)) { Add-WProblem $P 'W1-dup-target' $e['Id'] "duplicate $ident" }
    }
    # W1-record-overlap
    foreach ($e in $Entries) {
        if ($e['Kind'] -cne 'Record') { continue }
        if ($e['RecordOf'] -ceq 'Service') {
            foreach ($w in $Entries) { if ($w['Kind'] -ceq 'Service' -and $w['Name'] -ieq $e['Name']) { Add-WProblem $P 'W1-record-overlap' $e['Id'] "same service as writer $($w['Id'])" } }
        } else {
            $tk = Get-WTargetKey $e
            if ($wholeKeys.ContainsKey($tk)) { Add-WProblem $P 'W1-record-overlap' $e['Id'] "same value as writer $($wholeKeys[$tk])" }
            if ($bitValues.ContainsKey($tk)) { Add-WProblem $P 'W1-record-overlap' $e['Id'] "same value as writer $($bitValues[$tk])" }
        }
    }
    # W1-dead-allow
    foreach ($tag in @($TagKeys.Keys)) {
        $mine = @($Entries | Where-Object -FilterScript { $_['Tag'] -ceq $tag })
        foreach ($row in @($TagKeys[$tag].Registry)) {
            foreach ($nm in @($row.Names)) {
                $used = $false
                foreach ($e in $mine) {
                    if ($e.ContainsKey('Key') -and $e['Key'] -ieq $row.Key) {
                        if (($e.ContainsKey('ValueName') -and $e['ValueName'] -ieq $nm) -or ($e.ContainsKey('Pattern') -and $e['Pattern'] -ieq $nm)) { $used = $true }
                    }
                }
                if (-not $used) { Add-WProblem $P 'W1-dead-allow' '-' "$tag $($row.Key) $nm is used by no entry" }
            }
        }
        foreach ($s in @($TagKeys[$tag].Services)) {
            $used = $false
            foreach ($e in $mine) { if ($e.ContainsKey('Name') -and ($e['Kind'] -ceq 'Service' -or $e['Kind'] -ceq 'Record') -and $e['Name'] -ieq $s) { $used = $true } }
            if (-not $used) { Add-WProblem $P 'W1-dead-allow' '-' "$tag service $s is used by no entry" }
        }
        foreach ($s in @($TagKeys[$tag].Tasks)) {
            $used = $false
            foreach ($e in $mine) { if ($e['Kind'] -ceq 'Task' -and ($e['TaskPath'] + $e['TaskName']) -ieq $s) { $used = $true } }
            if (-not $used) { Add-WProblem $P 'W1-dead-allow' '-' "$tag task $s is used by no entry" }
        }
    }
    # W1-oracle-telemetry
    foreach ($e in $Entries) {
        if (-not ($e['Tag'] -like 'telemetry-*')) { continue }
        $o = $null
        foreach ($r in $W1Telemetry) { if ($r.Id -ceq $e['Id']) { $o = $r } }
        if ($null -eq $o) { continue }
        $bad = ($e['Ref'] -cne $o.Ref -or $e['Scope'] -cne $o.Scope -or $e['Kind'] -cne $o.Kind)
        foreach ($f in @('Key', 'ValueName', 'Name', 'TaskPath', 'TaskName')) {
            if ($o.ContainsKey($f)) { if (-not $e.ContainsKey($f) -or $e[$f] -ine $o[$f]) { $bad = $true } }
            elseif ($e.ContainsKey($f)) { $bad = $true }
        }
        if ($o.ContainsKey('RecordOf') -and $e['RecordOf'] -cne $o.RecordOf) { $bad = $true }
        if ($o.ContainsKey('Target')) {
            if (-not $e.ContainsKey('Target') -or $e['Target'].GetType() -ne $o.Target.GetType() -or $e['Target'] -cne $o.Target) { $bad = $true }
        } elseif ($e.ContainsKey('Target')) { $bad = $true }
        if ($bad) { Add-WProblem $P 'W1-oracle-telemetry' $e['Id'] 'differs from the ADR-0035 Key expansion row' }
    }
    # W1-oracle-notice
    foreach ($e in $Entries) {
        if ($e['Kind'] -cne 'Notice' -or -not $W1NoticeText.ContainsKey($e['Id'])) { continue }
        foreach ($prof in @($e['Profiles'])) {
            if ($e['Notice'][$prof] -cne $W1NoticeText[$e['Id']][$prof]) { Add-WProblem $P 'W1-oracle-notice' $e['Id'] "the $prof text differs from ADR-0020 Notices" }
        }
    }
}

function Get-WCatalogueProblems {
    param($Data, $TagKeys = (Get-WindowsSettingsTagKeys), $Protected = (Get-WindowsSettingsProtectedAppx))
    $p = New-Object 'System.Collections.Generic.List[string]'
    # tier 0
    if ($Data -isnot [hashtable] -or @($Data.Keys).Count -ne 1 -or @($Data.Keys) -cnotcontains 'Entries') { Add-WProblem $p 'W1-top' '-' 'the top level must be a hashtable whose only key is Entries'; return $p }
    if ($Data['Entries'] -isnot [object[]]) { Add-WProblem $p 'W1-top' '-' 'Entries must be an array'; return $p }
    foreach ($x in $Data['Entries']) { if ($x -isnot [hashtable]) { Add-WProblem $p 'W1-top' '-' 'every entry must be a hashtable'; return $p } }
    $entries = @($Data['Entries'])
    # tier 1
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($e in $entries) { Test-WEntryTier1 $e $seen $p }
    if ($p.Count -gt 0) { return $p }
    # tier 2
    foreach ($e in $entries) { Test-WEntryTier2 $e $TagKeys $Protected $p }
    if ($p.Count -gt 0) { return $p }
    # tier 3
    Test-WCatalogueGlobal $entries $TagKeys $p
    if ($p.Count -gt 0) { return $p }
    # tier 4
    $ids = @($entries | ForEach-Object -Process { $_['Id'] })
    if (-not (Test-WDeepEqual ([object[]]$ids) ([object[]]@($W1Ids)))) { Add-WProblem $p 'W1-oracle-ids' '-' 'the entry Ids differ from the 72 Ids of ADR-0020 and ADR-0035, or are in another order' }
    return $p
}

function Get-WVisualProblems {
    param($Data, [string[]]$YamlLines)
    $p = New-Object 'System.Collections.Generic.List[string]'
    $blocks = [ordered]@{}
    $cur = $null
    foreach ($ln in $YamlLines) {
        if ($ln -match '^- id: (\S+)\s*$') { $cur = $Matches[1]; $blocks[$cur] = @{ managed = $null; recommended = $null; registry = $null }; continue }
        if ($null -ne $cur -and $ln -match '^  (managed|recommended|registry): (.*)$') { $blocks[$cur][$Matches[1]] = $Matches[2].Trim() }
    }
    $visual = @($Data.Entries | Where-Object -FilterScript { $_['Tag'] -ceq 'visual' })
    foreach ($id in $blocks.Keys) {
        $b = $blocks[$id]
        $e = $null
        foreach ($x in $Data.Entries) { if ($x['Id'] -ceq $id) { $e = $x } }
        if ($b.managed -ceq 'true') {
            if ($null -eq $e -or $e['Tag'] -cne 'visual') { Add-WProblem $p 'V1' $id 'a managed: true block has no visual entry'; continue }
            $rec = $b.recommended
            $kind = $e['Kind']
            if ($rec -ceq '3') {
                if ($kind -cne 'DWord' -or $e['Target'] -ne 3) { Add-WProblem $p 'V1' $id 'recommended 3 needs a DWord entry with Target 3' }
            } elseif ($rec -ceq 'off') {
                $tOk = ($kind -ceq 'DWord' -and $e['Target'] -is [int] -and $e['Target'] -eq 0) -or ($kind -ceq 'String' -and $e['Target'] -ceq '0') -or ($kind -ceq 'BinaryBit' -and $e['Target'] -is [int] -and $e['Target'] -eq 0)
                if (-not $tOk) { Add-WProblem $p 'V1' $id 'recommended off needs Target 0 (DWord), ''0'' (String) or 0 (BinaryBit)' }
            } else {
                Add-WProblem $p 'V1' $id "unexpected recommended value $rec"
            }
            if ($kind -ceq 'BinaryBit') {
                $m = [regex]::Match([string]$b.registry, 'UPM byte (\d), mask 0x([0-9A-Fa-f]{2})')
                if (-not $m.Success) { Add-WProblem $p 'V1' $id 'registry line has no UPM byte and mask' }
                elseif ($e['Byte'] -ne [int]$m.Groups[1].Value -or $e['Mask'] -ne [Convert]::ToInt32($m.Groups[2].Value, 16)) { Add-WProblem $p 'V1' $id 'Byte or Mask differs from the yaml registry line' }
            }
        } elseif ($null -ne $e) {
            Add-WProblem $p 'V1' $id 'a managed: false block has a catalogue entry'
        }
    }
    foreach ($e in $visual) {
        if (-not $blocks.Contains($e['Id']) -or $blocks[$e['Id']].managed -cne 'true') { Add-WProblem $p 'V1' $e['Id'] 'a visual entry has no managed: true block' }
    }
    return $p
}

function Get-WUpmProblems {
    param($Data)
    $p = New-Object 'System.Collections.Generic.List[string]'
    $b = [int[]]@($W1UpmFrom)
    foreach ($e in $Data.Entries) {
        if ($e['Kind'] -cne 'BinaryBit') { continue }
        if ($e['Target'] -eq 0) { $b[$e['Byte']] = $b[$e['Byte']] -band (0xFF -bxor $e['Mask']) }
        else { $b[$e['Byte']] = $b[$e['Byte']] -bor $e['Mask'] }
    }
    $got = ($b | ForEach-Object -Process { '{0:X2}' -f $_ }) -join ' '
    $want = (@($W1UpmTo) | ForEach-Object -Process { '{0:X2}' -f $_ }) -join ' '
    if ($got -cne $want) { Add-WProblem $p 'V2' '-' "UserPreferencesMask would become $got, expected $want" }
    return $p
}

function Edit-WLine {
    # replace the first Find inside the catalogue line of one entry
    param([string]$Text, [string]$Id, [string]$Find, [string]$Rep)
    $lines = $Text -split "`n"
    $hit = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Contains("Id = '$Id';")) { $hit = $i } }
    Assert-True ($hit -ge 0) "catalogue line of $Id exists"
    $ix = $lines[$hit].IndexOf($Find)
    Assert-True ($ix -ge 0) "anchor '$Find' exists in the line of $Id"
    $lines[$hit] = $lines[$hit].Substring(0, $ix) + $Rep + $lines[$hit].Substring($ix + $Find.Length)
    return ($lines -join "`n")
}

function Invoke-WSeed {
    param([string]$Code, [string]$Label, [scriptblock]$Mutate)
    $d = Get-WReal
    $null = & $Mutate $d
    Assert-WOnly @(Get-WCatalogueProblems -Data $d) $Code $Label
}

function Invoke-WNegative {
    param([string]$Code, [string]$Label, [scriptblock]$Mutate)
    $d = Get-WReal
    $null = & $Mutate $d
    Assert-WAbsent @(Get-WCatalogueProblems -Data $d) $Code $Label
}

function Invoke-WAstSeed {
    param([string]$Label, [string]$Text)
    $f = Join-Path $script:T 'w1.psd1'
    [IO.File]::WriteAllText($f, $Text)
    Assert-WOnly @(Get-WAstProblems -Path $f) 'W1-ast' $Label
}

Test-Case 'W1a the real catalogue, the real functions and the oracles are clean; counts and the default personal run set' {
    $real = Get-WReal
    Assert-Eq (@(Get-WAstProblems -Path $WCatPath)).Count 0 "W1-ast on the real file: $(@(Get-WAstProblems -Path $WCatPath) -join ' | ')"
    $cp = @(Get-WCatalogueProblems -Data $real)
    Assert-Eq $cp.Count 0 "catalogue problems: $($cp -join ' | ')"
    $op = @(Get-WOracleProblems -TagKeys (Get-WindowsSettingsTagKeys) -Protected (Get-WindowsSettingsProtectedAppx))
    Assert-Eq $op.Count 0 "oracle problems: $($op -join ' | ')"
    $tk = $null; $er = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tk, [ref]$er)
    $fp = @(Get-WFnBodyProblems -Ast $ast)
    Assert-Eq $fp.Count 0 "function body problems: $($fp -join ' | ')"
    foreach ($n in @('Get-WindowsSettingsTagKeys', 'Get-WindowsSettingsProtectedAppx')) { Assert-True ($SeamNames -cnotcontains $n) "$n is not a seam" }
    # oracle meta-checks
    Assert-Eq $W1Ids.Count 72 'the oracle has 72 Ids'
    Assert-Eq @($W1Ids | Select-Object -Unique).Count 72 'the oracle Ids are unique'
    $telIds = @($W1Telemetry | ForEach-Object -Process { $_.Id })
    Assert-Eq $telIds.Count 37 'the ADR-0035 table has 37 rows'
    $tail = @($W1Ids | Select-Object -Last 37)
    Assert-True (Test-WDeepEqual ([object[]]$tail) ([object[]]$telIds)) 'the ADR-0035 Ids are the last 37 oracle Ids, in order'
    foreach ($k in $W1Labels.Keys) {
        $l = $W1Labels[$k]
        if ($null -ne $l.Exec) {
            $want = (($l.Source -ceq 'public' -or $l.Source -ceq 'adr') -and $l.Host -ceq 'HC')
            Assert-True ($l.Exec -eq $want) "oracle label of $k is consistent: Exec $($l.Exec), Source $($l.Source), Host $($l.Host)"
        }
    }
    # counts
    $ex = @($real.Entries | Where-Object -FilterScript { $_['Executable'] -eq $true })
    $nx = @($real.Entries | Where-Object -FilterScript { $_.ContainsKey('Executable') -and $_['Executable'] -eq $false })
    Assert-Eq $ex.Count 41 'executable entries'
    Assert-Eq $nx.Count 22 'report-only writer entries'
    $run = @($real.Entries | Where-Object -FilterScript { $_['Executable'] -eq $true -and @($_['Profiles']) -ccontains 'personal' -and $_['Scope'] -ceq 'user' -and -not $_.ContainsKey('OptIn') -and $_['Tag'] -cne 'telemetry-user' } | ForEach-Object -Process { $_['Id'] })
    Assert-True (Test-WDeepEqual ([object[]]$run) ([object[]]@('startup-edge', 'startup-onedrive', 'animate-windows', 'taskbar-animations'))) "the default personal run set: $($run -join ',')"
    # negatives that need nothing but the clean real data
    foreach ($c in @('W1-top', 'W1-tag', 'W1-kind', 'W1-scope', 'W1-record-of', 'W1-record-field', 'W1-field', 'W1-type', 'W1-gpu', 'W1-profile', 'W1-key', 'W1-key-canon', 'W1-policies', 'W1-startup-shape', 'W1-allow', 'W1-triple', 'W1-bit', 'W1-protected', 'W1-noop', 'W1-effect', 'W1-default', 'W1-verified', 'W1-notice', 'W1-notice-profiles', 'W1-optin', 'W1-gate', 'W1-exec', 'W1-oracle-label', 'W1-list', 'W1-order', 'W1-n8', 'W1-work-startup', 'W1-dup-target', 'W1-record-overlap', 'W1-dead-allow', 'W1-oracle-telemetry', 'W1-oracle-notice', 'W1-oracle-ids', 'W1-appx-id')) {
        Assert-WAbsent $cp $c 'real catalogue'
    }
    Assert-WAbsent @(Get-WAstProblems -Path $WCatPath) 'W1-ast' 'real file'
    $f2 = Join-Path $script:T 'w1-comment.psd1'
    [IO.File]::WriteAllText($f2, ([IO.File]::ReadAllText($WCatPath) + "`n# comment`n"))
    Assert-WAbsent @(Get-WAstProblems -Path $f2) 'W1-ast' 'real file plus a comment line'
    Assert-WAbsent $op 'W1-oracle-allow' 'real output'
    Assert-WAbsent $op 'W1-oracle-protected' 'real output'
    Assert-WAbsent $op 'W1-oracle-sync' 'real oracles'
    Assert-WAbsent $fp 'W1-fn-body' 'real script'
    Assert-WNoFailures
}

Test-Case 'W1b catalogue tiers 0 and 1 (seeded)' {
    $wt = [IO.File]::ReadAllText($WCatPath)
    Invoke-WAstSeed 'preset Target = [int]''3''' (Edit-WLine $wt 'preset' 'Target = 3;' 'Target = [int]''3'';')
    Invoke-WAstSeed 'double-quoted notice with a variable' ($wt.Replace('work = ''NOTICE step W: OneDrive startup is not changed in the work profile.''', 'work = "NOTICE step W: OneDrive startup is not changed in the work profile. $true"'))
    $i = $wt.IndexOf('Source = ''adr''')
    Invoke-WAstSeed 'first Source double-quoted' ($wt.Substring(0, $i) + 'Source = "adr"' + $wt.Substring($i + 'Source = ''adr'''.Length))
    Invoke-WAstSeed 'Executable = $null' (Edit-WLine $wt 'taskbar-animations' 'Executable = $true' 'Executable = $null')
    Invoke-WAstSeed 'Target = (0)' (Edit-WLine $wt 'taskbar-animations' 'Target = 0;' 'Target = (0);')
    Invoke-WAstSeed 'non-ASCII comment' ($wt + "`n# x" + [char]0xE9 + "`n")
    Invoke-WAstSeed 'Key = $env:X' (Edit-WLine $wt 'animate-windows' 'Key = ''Control Panel\Desktop\WindowMetrics''' 'Key = $env:X')

    Invoke-WSeed 'W1-top' 'extra top-level key' { param($d) $d['Protected'] = @() }
    Invoke-WSeed 'W1-top' 'Entries is a hashtable' { param($d) $d['Entries'] = @{ Id = 'preset' } }

    Invoke-WSeed 'W1-id' 'uppercase Id' { param($d) Edit-WEntry $d 'preset' -Set @{ Id = 'Preset' } }
    Invoke-WSeed 'W1-id' 'duplicate Id' { param($d) Edit-WEntry $d 'combo-slide' -Set @{ Id = 'fade-slide-menus' } }
    $d = Get-WReal
    $longId = 'appx-microsoftcorporationii-microsoftfamily'
    Assert-Eq $longId.Length 43 'the long Id has 43 characters'
    Assert-WAbsent @(Get-WCatalogueProblems -Data $d) 'W1-id' 'the real 43-character Id'

    Invoke-WSeed 'W1-tag' 'Visual' { param($d) Edit-WEntry $d 'preset' -Set @{ Tag = 'Visual' } }
    Invoke-WSeed 'W1-tag' 'gpu' { param($d) Edit-WEntry $d 'preset' -Set @{ Tag = 'gpu' } }
    Invoke-WSeed 'W1-kind' 'dword' { param($d) Edit-WEntry $d 'preset' -Set @{ Kind = 'dword' } }
    Invoke-WSeed 'W1-kind' 'AppxRemove on a visual Tag' { param($d) Edit-WEntry $d 'preset' -Set @{ Kind = 'AppxRemove' } }
    Invoke-WSeed 'W1-scope' 'User' { param($d) Edit-WEntry $d 'preset' -Set @{ Scope = 'User' } }
    Invoke-WSeed 'W1-scope' 'machine' { param($d) Edit-WEntry $d 'preset' -Set @{ Scope = 'machine' } }

    Invoke-WSeed 'W1-record-of' 'RecordOf Task' { param($d) Edit-WEntry $d 'rec-dmwappush' -Set @{ RecordOf = 'Task' } }
    Invoke-WSeed 'W1-record-of' 'service record with a Key' { param($d) Edit-WEntry $d 'rec-dmwappush' -Set @{ Key = 'SOFTWARE\X' } }
    Invoke-WSeed 'W1-record-of' 'DWord record without ValueName' { param($d) Edit-WEntry $d 'rec-limit-dump' -Remove @('ValueName') }
    Invoke-WSeed 'W1-record-field' 'Record with Target' { param($d) Edit-WEntry $d 'rec-limit-dump' -Set @{ Target = 1 } }
    Invoke-WSeed 'W1-record-field' 'Record with Verified' { param($d) Edit-WEntry $d 'rec-limit-dump' -Set @{ Verified = $false } }
    Invoke-WSeed 'W1-record-field' 'Record with Executable' { param($d) Edit-WEntry $d 'rec-limit-dump' -Set @{ Executable = $false } }

    Invoke-WSeed 'W1-field' 'unknown field' { param($d) Edit-WEntry $d 'preset' -Set @{ Force = $true } }
    Invoke-WSeed 'W1-field' 'missing Profiles' { param($d) Edit-WEntry $d 'preset' -Remove @('Profiles') }
    Invoke-WSeed 'W1-field' 'Ref on a visual entry' { param($d) Edit-WEntry $d 'preset' -Set @{ Ref = 'U1' } }
    Invoke-WSeed 'W1-field' 'telemetry entry without Ref' { param($d) Edit-WEntry $d 'tel-implicit-ink' -Remove @('Ref') }
    Invoke-WSeed 'W1-field' 'ValueName and Pattern together' { param($d) Edit-WEntry $d 'startup-edge' -Set @{ ValueName = 'X' } }
    Invoke-WSeed 'W1-field' 'Executable on a Notice' { param($d) Edit-WEntry $d 'notice-work-folders' -Set @{ Executable = $false } }
    Invoke-WSeed 'W1-field' 'AppxRemove without OptIn' { param($d) Edit-WEntry $d 'appx-microsoft-todos' -Remove @('OptIn') }

    Invoke-WSeed 'W1-type' 'DWord Target as a string' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ Target = '0' } }
    Invoke-WSeed 'W1-type' 'String Target as an int' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Target = 0 } }
    Invoke-WSeed 'W1-type' 'Profiles as a string' { param($d) Edit-WEntry $d 'preset' -Set @{ Profiles = 'personal' } }
    Invoke-WSeed 'W1-type' 'Verified as a string' { param($d) Edit-WEntry $d 'preset' -Set @{ Verified = 'false' } }
    Invoke-WSeed 'W1-type' 'StartupApproved Target enabled' { param($d) Edit-WEntry $d 'startup-edge' -Set @{ Target = 'enabled' } }
    Invoke-WSeed 'W1-type' 'Source outside the closed set' { param($d) Edit-WEntry $d 'preset' -Set @{ Source = 'x' } }

    Invoke-WSeed 'W1-range' 'Int32 minimum' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ Target = [int]-2147483648 } }
    Invoke-WSeed 'W1-range' 'Int64 value' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ Target = [long]2147483648 } }
    Invoke-WNegative 'W1-range' 'Target 0x7FFFFFFF' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ Target = 0x7FFFFFFF } }

    Invoke-WSeed 'W1-gpu' 'nvidia in an Id' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ Id = 'nvidia-taskbar' } }
    Assert-WNoFailures
}

Test-Case 'W1c catalogue tier 2 (seeded)' {
    Invoke-WSeed 'W1-profile' 'telemetry entry in both profiles' { param($d) Edit-WEntry $d 'tel-implicit-ink' -Set @{ Profiles = @('personal', 'work') } }
    Invoke-WSeed 'W1-profile' 'empty' { param($d) Edit-WEntry $d 'preset' -Set @{ Profiles = @() } }
    Invoke-WSeed 'W1-profile' 'home' { param($d) Edit-WEntry $d 'preset' -Set @{ Profiles = @('home') } }
    Invoke-WSeed 'W1-profile' 'Personal' { param($d) Edit-WEntry $d 'preset' -Set @{ Profiles = @('Personal') } }
    Invoke-WSeed 'W1-profile' 'work, work' { param($d) Edit-WEntry $d 'preset' -Set @{ Profiles = @('work', 'work') } }
    Invoke-WSeed 'W1-profile' 'consumer entry in personal only' { param($d) Edit-WEntry $d 'appx-microsoft-todos' -Set @{ Profiles = @('personal') } }
    Invoke-WNegative 'W1-profile' 'work, personal order' { param($d) Edit-WEntry $d 'appx-microsoft-todos' -Set @{ Profiles = @('work', 'personal') } }

    $wk = 'Control Panel\Desktop\WindowMetrics'
    Invoke-WSeed 'W1-key' 'HKCU: prefix' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'HKCU:\Control Panel\Desktop\WindowMetrics' } }
    Invoke-WSeed 'W1-key' 'HKEY_CURRENT_USER' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics' } }
    Invoke-WSeed 'W1-key' 'dot-dot segment' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'Control Panel\..\Desktop\WindowMetrics' } }
    Invoke-WSeed 'W1-key' 'forward slashes' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'Control Panel/Desktop/WindowMetrics' } }
    Invoke-WSeed 'W1-key' 'wildcard' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'Control Panel\Desktop\*' } }
    Invoke-WSeed 'W1-key' 'bare * Pattern' { param($d) Edit-WEntry $d 'startup-edge' -Set @{ Pattern = '*' } }

    Invoke-WSeed 'W1-key-canon' 'doubled backslash' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'Control Panel\\Desktop\WindowMetrics' } }
    Invoke-WSeed 'W1-key-canon' 'trailing backslash' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'Control Panel\Desktop\WindowMetrics\' } }
    Invoke-WSeed 'W1-key-canon' 'leading backslash' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = '\Control Panel\Desktop\WindowMetrics' } }
    Invoke-WSeed 'W1-key-canon' 'space at a segment edge' { param($d) Edit-WEntry $d 'animate-windows' -Set @{ Key = 'Control Panel\ Desktop\WindowMetrics' } }

    Invoke-WSeed 'W1-policies' 'user key under Policies' { param($d) Edit-WEntry $d 'tel-tips-338389' -Set @{ Key = 'Software\Policies\Microsoft\Windows\CloudContent' } }

    Invoke-WSeed 'W1-startup-shape' 'a plain Run key' { param($d) Edit-WEntry $d 'startup-onedrive' -Set @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Run' } }
    Invoke-WSeed 'W1-startup-shape' 'package without a publisher id' {
        param($d)
        $t = Get-WEntry $d 'startup-teams'
        Edit-WEntry $d 'startup-teams' -Set @{ Key = $t['Key'].Replace('MSTeams_8wekyb3d8bbwe', 'MSTeams') }
    }

    Invoke-WSeed 'W1-allow' 'key not on the list' { param($d) Edit-WEntry $d 'tel-tips-338389' -Set @{ Key = 'Software\Microsoft\Windows\CurrentVersion\Run' } }
    Invoke-WSeed 'W1-allow' 'service not on the list' { param($d) Edit-WEntry $d 'tel-m-diagtrack' -Set @{ Name = 'WerSvc' } }
    Invoke-WSeed 'W1-allow' 'task not on the list' { param($d) Edit-WEntry $d 'tel-m-task-autochk-proxy' -Set @{ TaskName = 'Other' } }
    Invoke-WSeed 'W1-triple' 'value name of another key' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ ValueName = 'Start_TrackProgs' } }

    Invoke-WSeed 'W1-bit' 'Byte 8' { param($d) Edit-WEntry $d 'fade-slide-menus' -Set @{ Byte = 8 } }
    Invoke-WSeed 'W1-bit' 'Mask 0x03' { param($d) Edit-WEntry $d 'fade-slide-menus' -Set @{ Mask = 0x03 } }
    Invoke-WSeed 'W1-bit' 'byte 3 with mask 0x80' { param($d) Edit-WEntry $d 'fade-slide-menus' -Set @{ Byte = 3; Mask = 0x80 } }
    Invoke-WSeed 'W1-bit' 'Target 2' { param($d) Edit-WEntry $d 'fade-slide-menus' -Set @{ Target = 2 } }
    Invoke-WSeed 'W1-bit' 'BinaryBit on another value' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ Kind = 'BinaryBit'; Byte = 0; Mask = 0x01 } }
    Invoke-WNegative 'W1-bit' 'byte 7 with mask 0x80' { param($d) Edit-WEntry $d 'animate-controls' -Set @{ Byte = 7; Mask = 0x80 } }

    foreach ($pn in @('Microsoft.ZuneMusic', 'Microsoft.VCLibs.140.00.UWPDesktop', 'Microsoft.UI.Xaml.2.8', 'Microsoft.UI.Xaml.CBS', 'Microsoft.NET.Native.Framework.2.2', 'Microsoft.WindowsAppRuntime.1.8', 'Microsoft.WindowsAppRuntime.CBS.2', 'microsoft.zunemusic', 'microsoft.vclibs.140.00', 'MICROSOFT.WINDOWSSTORE', 'microsoft.ui.xaml.2.8')) {
        $name = $pn
        $newId = 'appx-' + $pn.ToLowerInvariant().Replace('.', '-')
        Invoke-WSeed 'W1-protected' $name { param($d) Edit-WEntry $d 'appx-microsoft-bingnews' -Set @{ Name = $name; Id = $newId } }
    }
    Invoke-WNegative 'W1-protected' 'Microsoft.UIX' { param($d) Edit-WEntry $d 'appx-microsoft-bingnews' -Set @{ Name = 'Microsoft.UIX'; Id = 'appx-microsoft-uix' } }
    Invoke-WSeed 'W1-appx-id' 'two Names swapped' {
        param($d)
        $a = Get-WEntry $d 'appx-microsoft-bingnews'; $b = Get-WEntry $d 'appx-microsoft-bingweather'
        $t = $a['Name']; $a['Name'] = $b['Name']; $b['Name'] = $t
    }
    Invoke-WSeed 'W1-appx-id' 'an Id that is not derived from the Name' { param($d) Edit-WEntry $d 'appx-microsoft-todos' -Set @{ Id = 'appx-todos' } }

    Invoke-WSeed 'W1-noop' 'the Target in NoOpValues' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ NoOpValues = @(1) } }
    Invoke-WSeed 'W1-noop' 'a negative value' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ NoOpValues = @(-1) } }
    Invoke-WSeed 'W1-noop' 'NoOpValues on a visual entry' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ NoOpValues = @(0) } }
    Invoke-WSeed 'W1-noop' 'startup-teams NoOpValues other than the pinned @(0)' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ NoOpValues = @(2) } }

    Invoke-WSeed 'W1-effect' 'sign-out on telemetry' { param($d) Edit-WEntry $d 'tel-implicit-ink' -Set @{ Effect = 'sign-out' } }
    Invoke-WSeed 'W1-effect' 'none on visual' { param($d) Edit-WEntry $d 'preset' -Set @{ Effect = 'none' } }
    Invoke-WSeed 'W1-effect' 'reboot' { param($d) Edit-WEntry $d 'preset' -Set @{ Effect = 'reboot' } }

    Invoke-WSeed 'W1-default' 'WindowsDefault with state absent' { param($d) Edit-WEntry $d 'preset' -Set @{ WindowsDefault = 3 } }
    Invoke-WSeed 'W1-default' 'state value without WindowsDefault' { param($d) Edit-WEntry $d 'animate-windows' -Remove @('WindowsDefault') }
    Invoke-WSeed 'W1-default' 'state maybe' { param($d) Edit-WEntry $d 'preset' -Set @{ WindowsDefaultState = 'maybe' } }
    Invoke-WSeed 'W1-verified' 'BinaryBit Verified true' { param($d) Edit-WEntry $d 'fade-slide-menus' -Set @{ Verified = $true } }
    Invoke-WSeed 'W1-verified' 'startup Verified true' { param($d) Edit-WEntry $d 'startup-edge' -Set @{ Verified = $true } }

    Invoke-WSeed 'W1-notice' 'names schtasks.exe' { param($d) $e = Get-WEntry $d 'notice-work-folders'; $e['Notice']['personal'] = $e['Notice']['personal'] + ' schtasks.exe' }
    Invoke-WSeed 'W1-notice' 'carries a SID' { param($d) $e = Get-WEntry $d 'notice-work-folders'; $e['Notice']['personal'] = $e['Notice']['personal'] + ' S-1-5-21-1' }
    Invoke-WSeed 'W1-notice' 'names a task' { param($d) $e = Get-WEntry $d 'notice-work-folders'; $e['Notice']['personal'] = $e['Notice']['personal'] + ' OneDrive Startup Task' }
    Invoke-WSeed 'W1-notice' 'is not ASCII' { param($d) $e = Get-WEntry $d 'notice-work-folders'; $e['Notice']['personal'] = $e['Notice']['personal'] + [string][char]0xE9 }
    Invoke-WSeed 'W1-notice-profiles' 'without work' { param($d) $e = Get-WEntry $d 'notice-work-folders'; $e['Notice'].Remove('work') }
    Invoke-WSeed 'W1-notice-profiles' 'extra home key' { param($d) $e = Get-WEntry $d 'notice-work-folders'; $e['Notice']['home'] = 'NOTICE step W: x' }

    Invoke-WSeed 'W1-optin' 'RemoveApps entry opts into Teams' { param($d) Edit-WEntry $d 'appx-microsoft-todos' -Set @{ OptIn = 'DisableTeamsStartup' } }
    Invoke-WSeed 'W1-gate' 'the whole Teams gate removed' { param($d) Edit-WEntry $d 'startup-teams' -Remove @('OptIn', 'PolicyValues', 'RequiresUnmanaged') }
    Invoke-WSeed 'W1-gate' 'the whole Teams gate and NoOpValues removed' { param($d) Edit-WEntry $d 'startup-teams' -Remove @('NoOpValues', 'OptIn', 'PolicyValues', 'RequiresUnmanaged') }
    Invoke-WSeed 'W1-gate' 'Teams Target 2' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ Target = 2 } }
    Invoke-WSeed 'W1-gate' 'the full gate on taskbar-animations' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ OptIn = 'DisableTeamsStartup'; PolicyValues = @(3, 4); RequiresUnmanaged = $true } }
    Invoke-WSeed 'W1-optin' 'Teams entry opts into RemoveApps' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ OptIn = 'RemoveApps' } }
    Invoke-WSeed 'W1-optin' 'unknown OptIn' { param($d) Edit-WEntry $d 'appx-microsoft-todos' -Set @{ OptIn = 'Other' } }

    Invoke-WSeed 'W1-gate' 'PolicyValues without OptIn' { param($d) Edit-WEntry $d 'taskbar-animations' -Set @{ PolicyValues = @(3, 4) } }
    Invoke-WSeed 'W1-gate' 'RequiresUnmanaged false' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ RequiresUnmanaged = $false } }
    Invoke-WSeed 'W1-gate' 'PolicyValues @(3)' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ PolicyValues = @(3) } }
    Invoke-WSeed 'W1-gate' 'OptIn removed' { param($d) Edit-WEntry $d 'startup-teams' -Remove @('OptIn') }

    Invoke-WSeed 'W1-exec' 'chosen and HC marked executable' { param($d) Edit-WEntry $d 'tel-advertising-id' -Set @{ Executable = $true } }
    Invoke-WSeed 'W1-exec' 'public and HK marked executable' { param($d) Edit-WEntry $d 'tel-accept-language-optout' -Set @{ Executable = $true } }
    Invoke-WSeed 'W1-exec' 'machine HK marked executable' { param($d) Edit-WEntry $d 'tel-m-feedback-notifications' -Set @{ Executable = $true } }
    Invoke-WSeed 'W1-oracle-label' 'Host promoted without the ADR' { param($d) Edit-WEntry $d 'tel-accept-language-optout' -Set @{ Host = 'HC'; Executable = $true } }
    Assert-WNoFailures
}

Test-Case 'W1d catalogue tiers 3 and 4 (seeded)' {
    Invoke-WSeed 'W1-list' 'a consumer app is missing' { param($d) Remove-WEntry $d 'appx-microsoft-bingnews' }
    Invoke-WSeed 'W1-list' 'an extra app' { param($d) Copy-WEntryAs $d 'appx-microsoft-todos' 'appx-microsoft-extra' @{ Name = 'Microsoft.Extra' } }
    Invoke-WSeed 'W1-order' 'two consumer entries swapped' { param($d) Swap-WEntries $d 'appx-microsoft-gamingapp' 'appx-microsoft-xbox-tcui' }
    Invoke-WSeed 'W1-n8' 'Teams startup in the personal profile' { param($d) Edit-WEntry $d 'startup-teams' -Set @{ Profiles = @('personal', 'work') } }
    Invoke-WSeed 'W1-work-startup' 'Edge startup in the work profile' { param($d) Edit-WEntry $d 'startup-edge' -Set @{ Profiles = @('personal', 'work') } }

    Invoke-WSeed 'W1-dup-target' 'whole-value target in another case' { param($d) Copy-WEntryAs $d 'taskbar-animations' 'taskbar-animations-2' @{ Key = 'software\microsoft\windows\currentversion\explorer\advanced' } }
    Invoke-WSeed 'W1-dup-target' 'the same bit twice' { param($d) Copy-WEntryAs $d 'fade-slide-menus' 'fade-slide-menus-2' }
    Invoke-WSeed 'W1-dup-target' 'a whole-value entry on UserPreferencesMask' {
        param($d)
        Add-WEntry $d @{ Id = 'upm-whole'; Tag = 'visual'; Kind = 'DWord'; Scope = 'user'; Profiles = @('personal', 'work'); Key = 'Control Panel\Desktop'; ValueName = 'UserPreferencesMask'; Target = 0; WindowsDefaultState = 'unknown'; Verified = $false; Effect = 'sign-out'; Source = 'adr'; Host = 'HC'; Executable = $true }
    }
    Invoke-WSeed 'W1-dup-target' 'a name the Pattern matches' { param($d) Copy-WEntryAs $d 'startup-onedrive' 'startup-edge-x' @{ ValueName = 'MicrosoftEdgeAutoLaunch_0123' } }
    Invoke-WSeed 'W1-dup-target' 'a service twice' { param($d) Copy-WEntryAs $d 'tel-m-diagtrack' 'tel-m-diagtrack-2' }

    # W1-record-overlap, second seed of the spec: a Service record that shares the DiagTrack writer's name
    $d = Get-WReal
    $tkc = Copy-WData (Get-WindowsSettingsTagKeys)
    $tkc['telemetry-record'].Services = [object[]]@('dmwappushservice', 'DiagTrack')
    Add-WEntry $d @{ Id = 'rec-x'; Tag = 'telemetry-record'; Kind = 'Record'; Scope = 'machine'; Profiles = @('personal'); Ref = 'REC'; RecordOf = 'Service'; Name = 'DiagTrack'; Source = 'adr'; Host = 'HC' }
    Assert-WOnly @(Get-WCatalogueProblems -Data $d -TagKeys $tkc) 'W1-record-overlap' 'a Service record named DiagTrack'
    # W1-record-overlap, registry form: a Record on a writer's key and value name
    $d = Get-WReal
    $tkc = Copy-WData (Get-WindowsSettingsTagKeys)
    $row = @($tkc['telemetry-record'].Registry | Where-Object -FilterScript { $_.Key -ceq 'SOFTWARE\Policies\Microsoft\Windows\DataCollection' })[0]
    $row.Names = [object[]](@($row.Names) + 'DoNotShowFeedbackNotifications')
    Add-WEntry $d @{ Id = 'rec-y'; Tag = 'telemetry-record'; Kind = 'Record'; Scope = 'machine'; Profiles = @('personal'); Ref = 'REC'; RecordOf = 'DWord'; Key = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; ValueName = 'DoNotShowFeedbackNotifications'; Source = 'chosen'; Host = 'HK' }
    Assert-WOnly @(Get-WCatalogueProblems -Data $d -TagKeys $tkc) 'W1-record-overlap' 'a DWord record on the feedback-notifications value'

    $d = Get-WReal
    $tkc = Copy-WData (Get-WindowsSettingsTagKeys)
    $tkc['visual'].Registry = [object[]](@($tkc['visual'].Registry) + @(, @{ Key = 'Control Panel\Mouse'; Names = [object[]]@('MouseSpeed') }))
    Assert-WOnly @(Get-WCatalogueProblems -Data $d -TagKeys $tkc) 'W1-dead-allow' 'an allowlist row no entry uses'

    Invoke-WSeed 'W1-oracle-telemetry' 'tel-tips-338389 Target 1' { param($d) Edit-WEntry $d 'tel-tips-338389' -Set @{ Target = 1 } }
    Invoke-WSeed 'W1-oracle-notice' 'a changed word' {
        param($d)
        $e = Get-WEntry $d 'notice-onedrive-task'
        $e['Notice']['work'] = $e['Notice']['work'].Replace('changed', 'altered')
    }
    Invoke-WSeed 'W1-oracle-ids' 'two visual entries swapped' { param($d) Swap-WEntries $d 'animate-windows' 'taskbar-animations' }
    Assert-WNoFailures
}

Test-Case 'W1e oracle and function-body checks (seeded)' {
    $tk = Get-WindowsSettingsTagKeys
    $pr = Get-WindowsSettingsProtectedAppx
    $c1 = Copy-WData $tk
    $adv = @($c1['telemetry-user'].Registry | Where-Object -FilterScript { $_.Key -ceq 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' })[0]
    $adv.Names = [object[]]@($adv.Names | Where-Object -FilterScript { $_ -cne 'Start_IrisRecommendations' })
    Assert-WOnly @(Get-WOracleProblems -TagKeys $c1 -Protected $pr) 'W1-oracle-allow' 'the function output lacks Start_IrisRecommendations'
    $p1 = Copy-WData $pr
    $p1.Names = [object[]]@($p1.Names | Where-Object -FilterScript { $_ -cne 'Microsoft.WindowsStore' })
    Assert-WOnly @(Get-WOracleProblems -TagKeys $tk -Protected $p1) 'W1-oracle-protected' 'the protected set lacks Microsoft.WindowsStore'
    $t1 = Copy-WData $W1Telemetry
    $t1 = [object[]](@($t1) + @(, @{ Ref = 'U99'; Id = 'tel-x'; Tag = 'telemetry-user'; Scope = 'user'; Kind = 'DWord'; Key = 'Software\X'; ValueName = 'Y'; Target = 0 }))
    Assert-WOnly @(Get-WOracleProblems -TagKeys $tk -Protected $pr -OracleTelemetry $t1) 'W1-oracle-sync' 'an extra ADR-0035 row'
    $o1 = Copy-WData $W1TagKeys
    $adv2 = @($o1['telemetry-user'].Registry | Where-Object -FilterScript { $_.Key -ceq 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' })[0]
    $adv2.Names = [object[]]@($adv2.Names | Where-Object -FilterScript { $_ -cne 'Start_IrisRecommendations' })
    Assert-WOnly @(Get-WOracleProblems -TagKeys $tk -Protected $pr -OracleTagKeys $o1) 'W1-oracle-sync' 'the N12 oracle lacks Start_IrisRecommendations'

    $text = [IO.File]::ReadAllText($ScriptPath)
    $hdr = 'function Get-WindowsSettingsTagKeys {'
    $variants = @(
        @('a script variable in a protected name', $text.Replace('''Microsoft.ZuneMusic''', '$script:Extra')),
        @('a method call in a protected name', $text.Replace('''Microsoft.WindowsStore''', '[string]::Concat(''Microsoft.'', ''WindowsStore'')')),
        @('a second statement in the body', $text.Replace($hdr, $hdr + "`n    `$q = 1"))
    )
    foreach ($v in $variants) {
        $t = $null; $er = $null
        $a = [Management.Automation.Language.Parser]::ParseInput($v[1], [ref]$t, [ref]$er)
        Assert-Eq $er.Count 0 "the seed '$($v[0])' parses"
        Assert-WOnly @(Get-WFnBodyProblems -Ast $a) 'W1-fn-body' $v[0]
    }
    Assert-WNoFailures
}

Test-Case 'W1f every W1 code has a seed and a negative' {
    $codes = @('W1-ast', 'W1-top', 'W1-id', 'W1-tag', 'W1-kind', 'W1-scope', 'W1-record-of', 'W1-record-field', 'W1-field', 'W1-type', 'W1-range', 'W1-gpu',
        'W1-profile', 'W1-key', 'W1-key-canon', 'W1-policies', 'W1-startup-shape', 'W1-allow', 'W1-triple', 'W1-bit', 'W1-protected', 'W1-noop', 'W1-effect',
        'W1-default', 'W1-verified', 'W1-notice', 'W1-notice-profiles', 'W1-optin', 'W1-gate', 'W1-exec', 'W1-oracle-label', 'W1-appx-id',
        'W1-list', 'W1-order', 'W1-n8', 'W1-work-startup', 'W1-dup-target', 'W1-record-overlap', 'W1-dead-allow', 'W1-oracle-telemetry', 'W1-oracle-notice', 'W1-oracle-ids',
        'W1-oracle-allow', 'W1-oracle-protected', 'W1-oracle-sync', 'W1-fn-body')
    foreach ($c in $codes) {
        Assert-True ($script:WSeeds.ContainsKey($c)) "$c has seed counts"
        Assert-True ($script:WSeeds[$c][0] -ge 1) "$c has at least one seed"
        Assert-True ($script:WSeeds[$c][1] -ge 1) "$c has at least one negative"
    }
}

Test-Case 'W1g the boundary dialect holds for the two pure functions (seeded)' {
    $m = @{ Scope = @('Get-WindowsSettingsTagKeys', 'Get-WindowsSettingsProtectedAppx'); Owners = @{}; Common = @{}; TypeAllow = $BoundaryTypeAllow; Switches = $BoundarySwitches }
    $tk = $null; $er = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tk, [ref]$er)
    Assert-Eq $er.Count 0 'parse errors'
    $v = @(Get-BoundaryViolations $ast $m)
    Assert-Eq $v.Count 0 "boundary violations on the real script: $($v -join ' | ')"
    $text = [IO.File]::ReadAllText($ScriptPath)
    $hdr = 'function Get-WindowsSettingsTagKeys {'
    Assert-True ($text.IndexOf($hdr) -ge 0) 'the function header exists'
    foreach ($seed in @(@('R5', '$script:Cache = 1'), @('R4', '$null = [regex]''x'''), @('R1', '$null = Get-Date'))) {
        $t2 = $text.Replace($hdr, $hdr + "`n    " + $seed[1])
        $t = $null; $er2 = $null
        $a2 = [Management.Automation.Language.Parser]::ParseInput($t2, [ref]$t, [ref]$er2)
        Assert-Eq $er2.Count 0 "the seed '$($seed[1])' parses"
        $m2 = @{ Scope = @('Get-WindowsSettingsTagKeys', 'Get-WindowsSettingsProtectedAppx'); Owners = @{}; Common = @{}; TypeAllow = $BoundaryTypeAllow; Switches = $BoundarySwitches }
        $v2 = @(Get-BoundaryViolations $a2 $m2 | Where-Object -FilterScript { $_ -like "$($seed[0]) *" })
        Assert-True ($v2.Count -ge 1) "$($seed[0]) catches '$($seed[1])' in the pure function"
    }
}

Test-Case 'V1 the catalogue matches visual-effects.yaml (seeded)' {
    $lines = [IO.File]::ReadAllLines($WYamlPath)
    $real = Get-WReal
    $p = @(Get-WVisualProblems -Data $real -YamlLines $lines)
    Assert-Eq $p.Count 0 "V1 problems: $($p -join ' | ')"
    $d = Get-WReal
    Edit-WEntry $d 'animate-controls' -Set @{ Mask = 0x04 }
    Assert-True (@(Get-WVisualProblems -Data $d -YamlLines $lines).Count -ge 1) 'V1 catches animate-controls Mask 0x04'
    $d = Get-WReal
    Edit-WEntry $d 'preset' -Set @{ Target = 0 }
    Assert-True (@(Get-WVisualProblems -Data $d -YamlLines $lines).Count -ge 1) 'V1 catches preset Target 0'
    $d = Get-WReal
    Remove-WEntry $d 'combo-slide'
    Assert-True (@(Get-WVisualProblems -Data $d -YamlLines $lines).Count -ge 1) 'V1 catches a missing managed entry'
}

Test-Case 'V2 applying every BinaryBit target to the recorded mask gives the ADR result (seeded)' {
    $real = Get-WReal
    $p = @(Get-WUpmProblems -Data $real)
    Assert-Eq $p.Count 0 "V2 problems: $($p -join ' | ')"
    $d = Get-WReal
    Edit-WEntry $d 'combo-slide' -Set @{ Byte = 1 }
    Assert-True (@(Get-WUpmProblems -Data $d).Count -ge 1) 'V2 catches combo-slide Byte 1'
}

[Console]::WriteLine('W seeds (code: seeded / negative): ' + (($script:WSeeds.Keys | Sort-Object | ForEach-Object -Process { "$_ $($script:WSeeds[$_][0])/$($script:WSeeds[$_][1])" }) -join ', '))


Test-Case 'Z2 suite guard: the real profile settings.json, statusline.sh and backup root are untouched' {
    Assert-Eq $env:USERPROFILE $RealUserProfile 'USERPROFILE restored'
    $after = @((Get-FileState (Join-Path $RealUserProfile '.claude\settings.json')), (Get-FileState (Join-Path $RealUserProfile '.claude\statusline.sh')))
    Assert-Eq ($after -join "`n") ($SlGuardBefore -join "`n") 'real .claude files'
    Assert-Eq (Test-Path -LiteralPath (Join-Path $OrigLocalAppData 'app-configs\claude')) $SlGuardStateBefore 'real backup root'
}

$env:LOCALAPPDATA = $OrigLocalAppData
$script:RepoRoot = $OrigRepoRoot
Remove-Item -LiteralPath $TestTmp -Recurse -Force -ErrorAction SilentlyContinue
if ($script:Skip -gt 0) {
    [Console]::WriteLine("Skipped (not run, not counted as passed):")
    foreach ($s in $script:SkipList) { [Console]::WriteLine("  $s") }
}
[Console]::WriteLine("$script:Pass passed, $script:Skip skipped, $script:Fail failed")
if ($script:Fail -gt 0) { exit 1 }
exit 0
