# Tests for ops\windows\taskbar.ps1. Plain PowerShell 5.1, no Pester.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\windows\taskbar.tests.ps1
# Every system seam (Start apps, shell items, the policy key, elevation) is stubbed, so
# nothing here changes the taskbar or the registry.
$ErrorActionPreference = 'Stop'

$TestsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = (Resolve-Path (Join-Path $TestsDir '..\..\ops\windows\taskbar.ps1')).Path
. $ScriptPath

$script:HostOut = New-Object 'System.Collections.Generic.List[string]'
function Write-Host { [void]$script:HostOut.Add(($args -join ' ')) }
function Get-InstalledStartApps { throw 'unstubbed seam: Get-InstalledStartApps' }
function Get-AppsFolderItems { throw 'unstubbed seam: Get-AppsFolderItems' }
function Get-LayoutPolicy { throw 'unstubbed seam: Get-LayoutPolicy' }
function Test-IsAdmin { throw 'unstubbed seam: Test-IsAdmin' }

$script:Pass = 0
$script:Fail = 0
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    $script:HostOut.Clear()
    try { & $Body; $script:Pass++; [Console]::WriteLine("PASS $Name") }
    catch { $script:Fail++; [Console]::WriteLine("FAIL $Name :: $($_.Exception.Message)") }
}
function Assert-True { param($Cond, [string]$Msg) if (-not $Cond) { throw $Msg } }
function Assert-Eq { param($Actual, $Expected, [string]$Msg) if ($Actual -ne $Expected) { throw "$Msg (expected '$Expected', got '$Actual')" } }

function New-FakeItem {
    param([string]$Name, [string]$Path, [string[]]$Verbs)
    $item = [pscustomobject]@{ Name = $Name; Path = $Path; VerbNames = $Verbs; Done = New-Object 'System.Collections.Generic.List[string]' }
    $item | Add-Member -MemberType ScriptMethod -Name Verbs -Value {
        $owner = $this
        foreach ($n in $owner.VerbNames) {
            $v = [pscustomobject]@{ Name = $n; Owner = $owner }
            $v | Add-Member -MemberType ScriptMethod -Name DoIt -Value { $this.Owner.Done.Add($this.Name) }
            $v
        }
    }
    return $item
}

$RealData = Read-PinsYaml $PinsYaml
$HomeIds = Get-ManifestIds (Join-Path $ManifestDir 'home.json')
$WorkIds = Get-ManifestIds (Join-Path $ManifestDir 'work.json')

Test-Case 'the real taskbar-pins.yaml parses: 28 pins in order and the unpin list' {
    Assert-Eq $RealData.Pins.Count 28 'pin rows'
    Assert-Eq $RealData.Pins[0].app 'Paint.NET' 'first row'
    Assert-Eq $RealData.Pins[2].aumid '{6D809377-6AF0-444B-8957-A3773F02200E}\Double Commander\doublecmd.exe' 'single-quoted scalar'
    Assert-True ($RealData.Unpin -contains 'MSEdge') 'Edge in unpin list'
    Assert-True ($RealData.Unpin -contains 'Microsoft.OutlookForWindows_') 'Outlook in unpin list'
    Assert-True ($RealData.Unpin -contains 'Microsoft.Copilot_') 'Copilot in unpin list'
}

Test-Case 'the YAML reader rejects lines outside its subset' {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('taskbar-tests-' + [guid]::NewGuid().ToString('N') + '.yaml')
    [IO.File]::WriteAllText($tmp, "pins:`n  - position: 1`n    app: [a, b]`n      nested: x`n")
    try {
        $threw = $false
        try { [void](Read-PinsYaml $tmp) } catch { $threw = $true }
        Assert-True $threw 'nested line accepted'
    } finally { Remove-Item -LiteralPath $tmp -Force }
}

Test-Case 'home pins: chosen apps in home.json plus system rows, in position order, no pending rows' {
    $apps = @(Select-ProfilePins $RealData.Pins $HomeIds | ForEach-Object { $_.app })
    Assert-Eq $apps[0] 'Paint.NET' 'first'
    Assert-Eq $apps[1] 'File Explorer' 'second'
    Assert-True ($apps -contains 'Telegram') 'Telegram on home'
    Assert-True ($apps -contains 'Notepad++') 'Notepad++ on home'
    Assert-True (-not ($apps -contains 'PDF reader')) 'Edge row (no aumid) not pinned'
    foreach ($p in 'Vesktop', 'PuTTY', 'Signal', 'ChatGPT', 'unknown', 'Git GUI') { Assert-True (-not ($apps -contains $p)) "$p pinned" }
}

Test-Case 'work pins drop personal apps and apps work.json does not install' {
    $apps = @(Select-ProfilePins $RealData.Pins $WorkIds | ForEach-Object { $_.app })
    foreach ($p in 'Paint.NET', 'Telegram', 'WizTree', 'KeePassXC') { Assert-True (-not ($apps -contains $p)) "$p pinned on work" }
    foreach ($p in 'File Explorer', 'Visual Studio Code', 'Notepad++', 'Bruno', 'Control Panel') { Assert-True ($apps -contains $p) "$p missing on work" }
}

Test-Case 'targets resolve by AppID (env vars expanded) or by Start name; the rest are reported missing' {
    $rows = @(
        @{ app = 'Terminal'; aumid = 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App' },
        @{ app = 'Telegram'; aumid = '%APPDATA%\Telegram Desktop\Telegram.exe' },
        @{ app = 'WinSCP'; aumid = '' },
        @{ app = 'HeidiSQL'; aumid = '' }
    )
    $start = @(
        [pscustomobject]@{ Name = 'Terminal'; AppID = 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App' },
        [pscustomobject]@{ Name = 'Telegram'; AppID = (Join-Path $env:APPDATA 'Telegram Desktop\Telegram.exe') },
        [pscustomobject]@{ Name = 'WinSCP'; AppID = '{6D809377-6AF0-444B-8957-A3773F02200E}\WinSCP\WinSCP.exe' }
    )
    $res = Resolve-PinTargets $rows $start
    Assert-Eq $res.Found.Count 3 'found'
    Assert-Eq $res.Found[2].AppID '{6D809377-6AF0-444B-8957-A3773F02200E}\WinSCP\WinSCP.exe' 'name lookup'
    Assert-Eq ($res.Missing -join ',') 'HeidiSQL' 'missing'
}

Test-Case 'layout XML: well formed, Replace, PinGeneration, UWA vs DesktopApp, escaped' {
    $xmlText = New-TaskbarLayoutXml @(
        [pscustomobject]@{ App = 'Explorer'; AppID = 'Microsoft.Windows.Explorer' },
        [pscustomobject]@{ App = 'Terminal'; AppID = 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App' },
        [pscustomobject]@{ App = 'Odd'; AppID = 'C:\A&B\x.exe' }
    )
    $doc = [xml]$xmlText
    $ns = New-Object Xml.XmlNamespaceManager($doc.NameTable)
    $ns.AddNamespace('d', 'http://schemas.microsoft.com/Start/2014/LayoutModification')
    $ns.AddNamespace('t', 'http://schemas.microsoft.com/Start/2014/TaskbarLayout')
    Assert-Eq $doc.SelectSingleNode('//d:CustomTaskbarLayoutCollection', $ns).PinListPlacement 'Replace' 'placement'
    $pins = $doc.SelectNodes('//t:TaskbarPinList/*', $ns)
    Assert-Eq $pins.Count 3 'pin count'
    Assert-Eq $pins[0].LocalName 'DesktopApp' 'explorer kind'
    Assert-Eq $pins[1].LocalName 'UWA' 'terminal kind'
    Assert-Eq $pins[1].AppUserModelID 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App' 'aumid'
    Assert-Eq $pins[2].DesktopApplicationID 'C:\A&B\x.exe' 'escaped round trip'
    foreach ($p in $pins) { Assert-Eq $p.PinGeneration '1' 'PinGeneration' }
}

Test-Case 'unpin: only pinned items whose AppID starts with a listed prefix; report mode does nothing' {
    $edge = New-FakeItem 'Microsoft Edge' 'MSEdge' @('Open', 'Unpin from tas&kbar')
    $outlook = New-FakeItem 'Outlook' 'Microsoft.OutlookForWindows_8wekyb3d8bbwe!Microsoft.OutlookforWindows' @('Open', 'Unpin from tas&kbar')
    $copilotUnpinned = New-FakeItem 'Copilot' 'Microsoft.Copilot_8wekyb3d8bbwe!App' @('Open')
    $terminal = New-FakeItem 'Terminal' 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App' @('Unpin from tas&kbar')
    $items = @($edge, $outlook, $copilotUnpinned, $terminal)
    $n = Invoke-Unpin $items $RealData.Unpin -ReportOnly
    Assert-Eq $n 2 'report count'
    Assert-Eq ($edge.Done.Count + $outlook.Done.Count) 0 'report mode acted'
    $n = Invoke-Unpin $items $RealData.Unpin
    Assert-Eq $n 2 'unpin count'
    Assert-Eq $edge.Done.Count 1 'edge unpinned'
    Assert-Eq $outlook.Done.Count 1 'outlook unpinned'
    Assert-Eq $terminal.Done.Count 0 'terminal untouched'
}

Test-Case 'pin policy is not overwritten when another layout file owns it' {
    function Get-LayoutPolicy { return 'C:\Corp\layout.xml' }
    $threw = $false
    try { Set-LayoutPolicy '<x/>' } catch { $threw = $_.Exception.Message -like '*not changing it*' }
    Assert-True $threw 'foreign policy overwritten'
    $threw = $false
    try { Remove-LayoutPolicy } catch { $threw = $_.Exception.Message -like '*not removing it*' }
    Assert-True $threw 'foreign policy removed'
}

Test-Case 'usage errors exit 2; -Pin and -Undo need elevation' {
    Assert-Eq (Invoke-Taskbar) 2 'no args'
    Assert-Eq (Invoke-Taskbar -Pin) 2 'pin without manifest'
    Assert-Eq (Invoke-Taskbar -Undo -Unpin) 2 'undo with unpin'
    function Test-IsAdmin { return $false }
    Assert-Eq (Invoke-Taskbar -Manifest home -Pin) 1 'pin unelevated'
    Assert-Eq (Invoke-Taskbar -Undo) 1 'undo unelevated'
}

Test-Case 'report mode changes nothing and lists pins, skips and unpins' {
    function Get-InstalledStartApps { return @([pscustomobject]@{ Name = 'File Explorer'; AppID = 'Microsoft.Windows.Explorer' }) }
    $edge = New-FakeItem 'Microsoft Edge' 'MSEdge' @('Unpin from tas&kbar')
    function Get-AppsFolderItems { return @($edge) }
    function Set-LayoutPolicy { throw 'report mode wrote the policy' }
    Assert-Eq (Invoke-Taskbar -Manifest work) 0 'exit'
    Assert-Eq $edge.Done.Count 0 'report unpinned'
    $out = $script:HostOut -join "`n"
    Assert-True ($out -like '*pin: File Explorer*') 'pin line'
    Assert-True ($out -like '*skip: Visual Studio Code*') 'skip line'
    Assert-True ($out -like '*would unpin Microsoft Edge*') 'unpin line'
}

[Console]::WriteLine("taskbar tests: $script:Pass passed, $script:Fail failed")
if ($script:Fail -gt 0) { exit 1 }
exit 0
