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
$RealTestLefthookHooks = ${function:Test-LefthookHooks}
$RealInvokeWinget = ${function:Invoke-Winget}
$RealInvokeLefthook = ${function:Invoke-Lefthook}
$RealUpdateSessionPath = ${function:Update-SessionPath}
$RealResolveProgram = ${function:Resolve-Program}
$RealInvokeWslRaw = ${function:Invoke-WslRaw}
$RealGetWingetList = ${function:Get-WingetList}
$RealGetForeignHooks = ${function:Get-ForeignHooks}
$RealInvokeDownload = ${function:Invoke-Download}
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
    'Invoke-Native'        = '[string]$ExePath, [string[]]$Arguments, [switch]$Passthrough, [int]$TimeoutSeconds, [string]$WorkingDirectory, [int]$HeartbeatSeconds'
    'Get-ToolVersion'      = '[string]$Name, [string[]]$VersionArgs'
    'Resolve-Program'      = '[string]$Name'
    'Invoke-Winget'        = '[string]$Id'
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

Test-Case 'S1 allowlist: every other command sits inside a seam function' {
    $tokens = $null; $errs = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errs)
    Assert-Eq $errs.Count 0 'parse errors'
    $defined = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name })
    # Built-ins that only touch the local file system or the console, anywhere.
    $safe = @('ForEach-Object', 'Where-Object', 'Select-Object', 'Sort-Object', 'Join-Path', 'Split-Path',
        'Test-Path', 'Get-ChildItem', 'Get-Item', 'New-Item', 'Move-Item', 'Remove-Item', 'New-Object', 'Write-Host')
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
        foreach ($m in [regex]::Matches($l, '\bwsl\b[^\r\n]*?\s-u root -- (\S+)')) {
            $advice++
            Assert-True (@('sh', 'bash') -contains $m.Groups[1].Value) "advised program after -- must be sh or bash (proven to resolve): $($m.Value)"
        }
    }
    Assert-True ($advice -ge 3) "the suite produced $advice advised wsl commands with a program (mv recovery, rollback)"
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
