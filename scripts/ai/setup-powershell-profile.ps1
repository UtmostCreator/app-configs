$ErrorActionPreference = 'Stop'

param(
    [switch]$DryRun,
    [switch]$NoProfileUpdate
)

function Add-PathIfMissing {
    param(
        [string]$PathValue,
        [System.Collections.Generic.List[string]]$Current,
        [System.Collections.Generic.List[string]]$Added
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return }
    if (-not (Test-Path $PathValue)) { return }

    foreach ($existing in $Current) {
        if ([string]::Equals($existing.Trim(), $PathValue.Trim(), [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }

    $Current.Add($PathValue)
    $Added.Add($PathValue)
}

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

$repoRoot = Resolve-RepoRoot
$userPathRaw = [Environment]::GetEnvironmentVariable('Path', 'User')
$currentPath = New-Object 'System.Collections.Generic.List[string]'
$added = New-Object 'System.Collections.Generic.List[string]'

if (-not [string]::IsNullOrWhiteSpace($userPathRaw)) {
    foreach ($part in ($userPathRaw -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($part)) {
            $currentPath.Add($part)
        }
    }
}

$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
$npmBin = Join-Path $env:APPDATA 'npm'
$gitCmd = 'C:\Program Files\Git\cmd'
$xamppPhp = 'C:\xampp\php'

Add-PathIfMissing -PathValue $wingetLinks -Current $currentPath -Added $added
Add-PathIfMissing -PathValue $npmBin -Current $currentPath -Added $added
Add-PathIfMissing -PathValue $gitCmd -Current $currentPath -Added $added
Add-PathIfMissing -PathValue $xamppPhp -Current $currentPath -Added $added

$newUserPath = ($currentPath -join ';')

if ($DryRun) {
    Write-Host '[dry-run] would ensure user PATH contains:'
    foreach ($item in $added) { Write-Host " - $item" }
} else {
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    $env:Path = $newUserPath + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
}

if (-not $NoProfileUpdate) {
    $profilePath = $PROFILE.CurrentUserCurrentHost
    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path $profileDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    }

    $markerStart = '# >>> app-configs tool bootstrap >>>'
    $markerEnd = '# <<< app-configs tool bootstrap <<<'
    $profileBlock = @"
$markerStart

$repoRootVar = '$repoRoot'
if (Test-Path "$repoRootVar\scripts\ai\setup-powershell-profile.ps1") {
    # Keep aliases stable for tools with alternate executable names.
    if (Get-Command sg -ErrorAction SilentlyContinue) {
        Set-Alias -Name ast-grep -Value sg -Scope Global -Force
    }
}

$markerEnd
"@

    if ($DryRun) {
        Write-Host '[dry-run] would ensure PowerShell profile bootstrap block exists:'
        Write-Host " - $profilePath"
    } else {
        $existing = if (Test-Path $profilePath) { Get-Content -Raw -Path $profilePath } else { '' }
        if ($existing -notmatch [Regex]::Escape($markerStart)) {
            Add-Content -Path $profilePath -Value "`r`n$profileBlock`r`n"
        }
    }
}

function Check-Tool {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $true }
    return $false
}

if (-not $DryRun) {
    if ((-not (Check-Tool 'ast-grep')) -and (Check-Tool 'sg')) {
        Set-Alias -Name ast-grep -Value sg -Scope Global -Force
    }
}

$required = @('php', 'bash', 'git', 'jq', 'rg', 'fd', 'repomix')
$status = @{}
foreach ($tool in $required) {
    $status[$tool] = Check-Tool $tool
}
$status['ast-grep'] = (Check-Tool 'ast-grep') -or (Check-Tool 'sg')

Write-Host 'PowerShell tool bootstrap summary:'
Write-Host " - Repo root: $repoRoot"
if ($added.Count -gt 0) {
    Write-Host ' - Added PATH entries:'
    foreach ($item in $added) { Write-Host "   * $item" }
} else {
    Write-Host ' - PATH already contained required bootstrap locations.'
}

Write-Host ' - Tool availability:'
foreach ($key in $status.Keys | Sort-Object) {
    $value = if ($status[$key]) { 'ok' } else { 'missing' }
    Write-Host "   * $key: $value"
}

Write-Host ''
Write-Host 'Open a new PowerShell session to apply user PATH changes globally.'
