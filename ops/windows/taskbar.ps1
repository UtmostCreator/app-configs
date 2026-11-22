# Taskbar pins for the Windows host (ADR-0044). Run by hand in a normal Windows PowerShell 5.1;
# no other repo script, WSL or CI runs it.
#
#   powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Manifest home          # report only, changes nothing
#   powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Unpin                 # unpin Edge, Copilot, Outlook now
#   powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Manifest home -Pin     # elevated: pin layout at next sign-in
#   powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Undo                  # elevated: remove the pin policy
#
# Data: docs\platforms\windows\taskbar-pins.yaml (pins, order, unpin list) and
# ops\windows\winget\<profile>.json (which apps the profile installs).
# -Pin writes a LayoutModification XML (PinListPlacement=Replace, PinGeneration=1) under
# %LOCALAPPDATA%\app-configs\taskbar and points the per-user Start layout policy at it
# (HKCU\Software\Policies\Microsoft\Windows\Explorer: StartLayoutFile, LockedStartLayout).
# Exit codes: 0 done, 1 failed, 2 usage error.
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet('home', 'work')][string]$Manifest,
    [switch]$Pin,
    [switch]$Unpin,
    [switch]$Undo
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$PinsYaml = Join-Path $RepoRoot 'docs\platforms\windows\taskbar-pins.yaml'
$ManifestDir = Join-Path $RepoRoot 'ops\windows\winget'
$PolicyKey = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
$LayoutDir = Join-Path $env:LOCALAPPDATA 'app-configs\taskbar'
$LayoutFile = Join-Path $LayoutDir 'LayoutModification.xml'

function Say { param([string]$Message) Write-Host "taskbar: $Message" }

# Reads the narrow YAML subset taskbar-pins.yaml uses: a `pins:` list of single-line
# `key: value` maps and plain `- item` lists (`not_pinned:`, `unpin:`).
function Read-PinsYaml {
    param([string]$Path)
    $pins = New-Object 'System.Collections.Generic.List[hashtable]'
    $unpin = New-Object 'System.Collections.Generic.List[string]'
    $section = ''
    $row = $null
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([a-z_]+):\s*$') { $section = $Matches[1]; $row = $null; continue }
        if ($section -eq 'pins') {
            if ($line -match '^  - ([a-z_]+):\s*(.*)$') {
                $row = @{}
                $pins.Add($row)
                $row[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2]
            } elseif ($line -match '^    ([a-z_]+):\s*(.*)$' -and $null -ne $row) {
                $row[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2]
            } else {
                throw "unsupported line in ${Path}: $line"
            }
        } elseif ($section -eq 'unpin') {
            if ($line -match '^  - (.+)$') { $unpin.Add((ConvertFrom-YamlScalar $Matches[1])) }
            else { throw "unsupported line in ${Path}: $line" }
        }
    }
    return @{ Pins = $pins.ToArray(); Unpin = $unpin.ToArray() }
}

function ConvertFrom-YamlScalar {
    param([string]$Value)
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and $v[0] -eq "'" -and $v[-1] -eq "'") { return $v.Substring(1, $v.Length - 2).Replace("''", "'") }
    if ($v.Length -ge 2 -and $v[0] -eq '"' -and $v[-1] -eq '"') { return $v.Substring(1, $v.Length - 2) }
    return $v
}

function Get-ManifestIds {
    param([string]$Path)
    $json = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
    return @($json.Sources | ForEach-Object { $_.Packages } | ForEach-Object { [string]$_.PackageIdentifier })
}

# Rows the profile pins, in position order: `chosen` rows whose winget id is in the
# profile's manifest, and `system` rows with an aumid.
function Select-ProfilePins {
    param([hashtable[]]$Pins, [string[]]$ManifestIds)
    $selected = foreach ($p in $Pins) {
        if ($p.status -eq 'system' -and $p.aumid) { $p }
        elseif ($p.status -eq 'chosen' -and $p.winget -and ($ManifestIds -contains $p.winget)) { $p }
    }
    return @($selected | Sort-Object { [int]$_.position })
}

# Seam: the installed Start menu apps (Name, AppID).
function Get-InstalledStartApps { return @(Get-StartApps | ForEach-Object { [pscustomobject]@{ Name = $_.Name; AppID = $_.AppID } }) }

# Matches each row to an installed app: by AppID when the row has one (environment
# variables expanded), else by exact Start menu name. Unmatched rows go to Missing.
function Resolve-PinTargets {
    param([hashtable[]]$Rows, [object[]]$StartApps)
    $found = New-Object 'System.Collections.Generic.List[object]'
    $missing = New-Object 'System.Collections.Generic.List[string]'
    foreach ($r in $Rows) {
        $hit = $null
        if ($r.aumid) {
            $want = [Environment]::ExpandEnvironmentVariables([string]$r.aumid)
            $hit = $StartApps | Where-Object { $_.AppID -eq $want } | Select-Object -First 1
        } else {
            $hit = $StartApps | Where-Object { $_.Name -eq $r.app } | Select-Object -First 1
        }
        if ($hit) { $found.Add([pscustomobject]@{ App = [string]$r.app; AppID = [string]$hit.AppID }) }
        else { $missing.Add([string]$r.app) }
    }
    return @{ Found = $found.ToArray(); Missing = $missing.ToArray() }
}

# A packaged app's AppID has "!" (PackageFamilyName!AppId); anything else is a desktop app.
function New-TaskbarLayoutXml {
    param([object[]]$Targets)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('<?xml version="1.0" encoding="utf-8"?>')
    $lines.Add('<!-- Generated by ops/windows/taskbar.ps1 from docs/platforms/windows/taskbar-pins.yaml (ADR-0044). -->')
    $lines.Add('<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">')
    $lines.Add('  <CustomTaskbarLayoutCollection PinListPlacement="Replace">')
    $lines.Add('    <defaultlayout:TaskbarLayout>')
    $lines.Add('      <taskbar:TaskbarPinList>')
    foreach ($t in $Targets) {
        $id = [Security.SecurityElement]::Escape([string]$t.AppID)
        if ($t.AppID -like '*!*') { $lines.Add("        <taskbar:UWA AppUserModelID=`"$id`" PinGeneration=`"1`" />") }
        else { $lines.Add("        <taskbar:DesktopApp DesktopApplicationID=`"$id`" PinGeneration=`"1`" />") }
    }
    $lines.Add('      </taskbar:TaskbarPinList>')
    $lines.Add('    </defaultlayout:TaskbarLayout>')
    $lines.Add('  </CustomTaskbarLayoutCollection>')
    $lines.Add('</LayoutModificationTemplate>')
    return ($lines -join "`r`n") + "`r`n"
}

# Seam: shell:AppsFolder items; Path is the AppID, Verbs() the context-menu verbs.
function Get-AppsFolderItems {
    $folder = (New-Object -ComObject Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}')
    return @($folder.Items())
}

# The "Unpin from taskbar" verb of an item, or $null when the app is not pinned. The verb
# name is localised; only English Windows is matched.
function Get-UnpinVerb {
    param($Item)
    foreach ($v in @($Item.Verbs())) {
        if (($v.Name -replace '&', '') -eq 'Unpin from taskbar') { return $v }
    }
    return $null
}

function Invoke-Unpin {
    param([object[]]$Items, [string[]]$Prefixes, [switch]$ReportOnly)
    $count = 0
    foreach ($item in $Items) {
        $path = [string]$item.Path
        $match = $Prefixes | Where-Object { $path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if (-not $match) { continue }
        $verb = Get-UnpinVerb $item
        if (-not $verb) { continue }
        $count++
        if ($ReportOnly) { Say "would unpin $($item.Name) ($path)"; continue }
        $verb.DoIt()
        Say "unpinned $($item.Name) ($path)"
    }
    if ($count -eq 0) { Say 'unpin: nothing from the unpin list is pinned (on non-English Windows the verb is not found; unpin by hand)' }
    return $count
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Seam: the current StartLayoutFile policy value, or $null.
function Get-LayoutPolicy {
    $p = Get-ItemProperty -LiteralPath $PolicyKey -ErrorAction SilentlyContinue
    if ($p -and $p.PSObject.Properties['StartLayoutFile']) { return [string]$p.StartLayoutFile }
    return $null
}

function Set-LayoutPolicy {
    param([string]$Xml)
    $current = Get-LayoutPolicy
    if ($current -and $current -ne $LayoutFile) {
        throw "StartLayoutFile already points to '$current' (set by IT or another tool); not changing it"
    }
    [void](New-Item -ItemType Directory -Force -Path $LayoutDir)
    [IO.File]::WriteAllText($LayoutFile, $Xml, (New-Object Text.UTF8Encoding($false)))
    if (-not (Test-Path -LiteralPath $PolicyKey)) { [void](New-Item -Path $PolicyKey -Force) }
    New-ItemProperty -LiteralPath $PolicyKey -Name StartLayoutFile -PropertyType ExpandString -Value $LayoutFile -Force | Out-Null
    New-ItemProperty -LiteralPath $PolicyKey -Name LockedStartLayout -PropertyType DWord -Value 1 -Force | Out-Null
}

function Remove-LayoutPolicy {
    $current = Get-LayoutPolicy
    if (-not $current) { Say 'undo: no StartLayoutFile policy is set; nothing to remove'; return }
    if ($current -ne $LayoutFile) { throw "StartLayoutFile points to '$current', not this script's file; not removing it" }
    Remove-ItemProperty -LiteralPath $PolicyKey -Name StartLayoutFile, LockedStartLayout -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $LayoutFile) { Remove-Item -LiteralPath $LayoutFile -Force }
    Say 'undo: policy removed. Pins already on the taskbar stay; unpin by hand if you want them gone'
}

function Invoke-Taskbar {
    param([string]$Manifest, [switch]$Pin, [switch]$Unpin, [switch]$Undo)
    if ($Undo -and ($Pin -or $Unpin)) { Say 'usage: -Undo cannot be combined with -Pin or -Unpin'; return 2 }
    if ($Pin -and -not $Manifest) { Say 'usage: -Pin needs -Manifest home|work'; return 2 }
    if (-not ($Pin -or $Unpin -or $Undo) -and -not $Manifest) { Say 'usage: give -Manifest home|work for a report, or -Pin, -Unpin, -Undo'; return 2 }
    if (($Pin -or $Undo) -and -not (Test-IsAdmin)) {
        Say 'the Start layout policy key is admin-only: run this from an elevated PowerShell on the same account'
        return 1
    }
    $data = Read-PinsYaml $PinsYaml
    if ($Undo) { Remove-LayoutPolicy; return 0 }

    $reportOnly = -not ($Pin -or $Unpin)
    if ($Manifest) {
        $ids = Get-ManifestIds (Join-Path $ManifestDir "$Manifest.json")
        $rows = Select-ProfilePins $data.Pins $ids
        $res = Resolve-PinTargets $rows (Get-InstalledStartApps)
        foreach ($t in $res.Found) { Say "pin: $($t.App) [$($t.AppID)]" }
        foreach ($m in $res.Missing) { Say "skip: $m is not installed or not found in Start; install it, then run again" }
        if ($Pin) {
            if ($res.Found.Count -eq 0) { Say 'nothing to pin; policy not changed'; return 1 }
            Set-LayoutPolicy (New-TaskbarLayoutXml $res.Found)
            Say "wrote $LayoutFile and set the Start layout policy. Sign out and back in to apply."
            Say 'Default pins (Edge, Store, Copilot, Outlook) are replaced. You can unpin any of these later; they stay unpinned.'
        }
    }
    if ($Unpin -or $reportOnly) { [void](Invoke-Unpin (Get-AppsFolderItems) $data.Unpin -ReportOnly:$reportOnly) }
    if ($reportOnly) { Say 'report only: nothing changed. Add -Unpin and/or -Pin to apply.' }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    try { exit (Invoke-Taskbar @PSBoundParameters) }
    catch { Say "failed: $($_.Exception.Message)"; exit 1 }
}
