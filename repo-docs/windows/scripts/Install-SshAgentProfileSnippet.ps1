<#
.SYNOPSIS
    Install (or remove) an 8-hour ssh-agent re-prompt snippet in the current
    user's PowerShell profile, plus optionally GIT_SSH scoping.

.DESCRIPTION
    Mimics the .bashrc 8h TTL behavior for PowerShell sessions on Windows.
    Idempotent: re-running with no flags refreshes the snippet in place; the
    delimited block is rewritten and nothing outside the block is touched.

    The snippet itself, when loaded by each new PowerShell session:
      1. Skips if the Windows ssh-agent service is not Running.
      2. Skips if the configured key file does not exist.
      3. If $HOME\.ssh\state\pwsh-last-add.txt is younger than 8 hours,
         does nothing else.
      4. Otherwise, checks whether the key is already loaded; if not, runs
         `ssh-add` (which prompts for the passphrase if needed).
      5. Touches the marker file so the next 8h window starts.
      6. (Optional) Sets $env:GIT_SSH to Windows OpenSSH so git.exe in
         PowerShell uses the same agent.

.PARAMETER KeyPath
    Path to the private key the snippet will manage. Default:
    $HOME\.ssh\github.uc.ll5

.PARAMETER ProfilePath
    Profile file to edit. Default: $PROFILE (current host's user profile).

.PARAMETER IncludeGitSshOverride
    Add `$env:GIT_SSH = "C:\WINDOWS\System32\OpenSSH\ssh.exe"` to the
    snippet so git.exe in PowerShell uses Windows OpenSSH regardless of
    `core.sshCommand`. Git Bash is unaffected.

.PARAMETER Remove
    Remove the snippet block from the profile. Other content is preserved.

.EXAMPLE
    pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1

.EXAMPLE
    pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1 -IncludeGitSshOverride

.EXAMPLE
    pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1 -Remove

.NOTES
    Approval boundaries: this script edits your PowerShell user profile.
    It does not touch system services, gitconfig, or your private key.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$KeyPath = (Join-Path $HOME '.ssh\github.uc.ll5'),
    [string]$ProfilePath = $PROFILE,
    [switch]$IncludeGitSshOverride,
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$beginMarker = '# --- ssh-agent 8h prompt (managed by repo-docs/windows/scripts/Install-SshAgentProfileSnippet.ps1) ---'
$endMarker   = '# --- end ssh-agent 8h prompt ---'

function New-SnippetBody {
    param(
        [string]$Key,
        [bool]$WithGitSsh
    )

    $gitSshLine = if ($WithGitSsh) {
        '$env:GIT_SSH = "C:\WINDOWS\System32\OpenSSH\ssh.exe"'
    } else {
        '# GIT_SSH override not installed; pass -IncludeGitSshOverride to enable.'
    }

    $keyLiteral = $Key.Replace("'", "''")

    return @"
$beginMarker
# Re-prompts for the SSH passphrase at most once per 8 hours, mirroring the
# Git Bash SSH_ADD_TTL=28800 setup. Safe to keep when offline: skips silently
# if the Windows ssh-agent service or the key file are unavailable.
$gitSshLine
`$keyPath   = '$keyLiteral'
`$stateDir  = Join-Path `$HOME '.ssh\state'
`$marker    = Join-Path `$stateDir 'pwsh-last-add.txt'
`$svc       = Get-Service ssh-agent -ErrorAction SilentlyContinue
`$ssh_add   = 'C:\WINDOWS\System32\OpenSSH\ssh-add.exe'
if (`$svc -and `$svc.Status -eq 'Running' -and (Test-Path `$keyPath) -and (Test-Path `$ssh_add)) {
    if (-not (Test-Path `$stateDir)) {
        New-Item -ItemType Directory -Path `$stateDir -Force | Out-Null
    }
    `$needsAdd = `$true
    if (Test-Path `$marker) {
        `$lastWrite = (Get-Item `$marker -ErrorAction SilentlyContinue).LastWriteTime
        if (`$lastWrite -and ((Get-Date) - `$lastWrite).TotalHours -lt 8) {
            `$needsAdd = `$false
        }
    }
    if (`$needsAdd) {
        `$listed = & `$ssh_add -l 2>&1
        `$keyName = Split-Path -Leaf `$keyPath
        if (`$LASTEXITCODE -ne 0 -or `$listed -notmatch [regex]::Escape(`$keyName)) {
            & `$ssh_add `$keyPath
        }
        New-Item -ItemType File -Path `$marker -Force | Out-Null
    }
}
$endMarker
"@
}

function Read-ProfileText {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '' }
    return (Get-Content $Path -Raw)
}

function Remove-Snippet {
    param([string]$Text)
    if (-not $Text) { return '' }
    # Match the FIRST $beginMarker, then EVERYTHING through $endMarker (greedy
    # is fine because the markers are unique strings).
    $pattern = "(?s)" + [regex]::Escape($beginMarker) + ".*?" + [regex]::Escape($endMarker) + "\r?\n?"
    return [regex]::Replace($Text, $pattern, '')
}

try {
    if (-not $ProfilePath) {
        throw 'No profile path. Pass -ProfilePath explicitly.'
    }

    $profileDir = Split-Path -Parent $ProfilePath
    if ($profileDir -and -not (Test-Path $profileDir)) {
        if ($PSCmdlet.ShouldProcess($profileDir, 'New-Item -ItemType Directory')) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
    }

    $existing = Read-ProfileText -Path $ProfilePath
    $without  = Remove-Snippet -Text $existing

    if ($Remove) {
        if ($without -eq $existing) {
            Write-Host "No ssh-agent snippet found in $ProfilePath; nothing to remove."
            return
        }
        if ($PSCmdlet.ShouldProcess($ProfilePath, 'Remove ssh-agent snippet')) {
            Set-Content -Path $ProfilePath -Value $without.TrimEnd() -Encoding UTF8
            Write-Host "Removed ssh-agent snippet from $ProfilePath."
        }
        return
    }

    if (-not (Test-Path $KeyPath)) {
        Write-Warning "Key not found at $KeyPath. Snippet will be installed anyway; it skips at runtime when the key is absent."
    }

    $snippet = New-SnippetBody -Key $KeyPath -WithGitSsh:$IncludeGitSshOverride.IsPresent
    $newBody = if ($without) { ($without.TrimEnd() + "`r`n`r`n" + $snippet) } else { $snippet }

    if ($PSCmdlet.ShouldProcess($ProfilePath, 'Install ssh-agent snippet')) {
        Set-Content -Path $ProfilePath -Value $newBody -Encoding UTF8
        Write-Host "Installed ssh-agent snippet in $ProfilePath."
        if ($IncludeGitSshOverride) {
            Write-Host '  Includes: $env:GIT_SSH override to Windows OpenSSH.'
        } else {
            Write-Host '  Without GIT_SSH override (pass -IncludeGitSshOverride to add it).'
        }
        Write-Host ''
        Write-Host 'Open a NEW PowerShell window to activate. The snippet will:'
        Write-Host '  - run ssh-add at most once per 8 hours'
        Write-Host '  - silently no-op when the service or key are unavailable'
    }
}
catch {
    Write-Error $_
    exit 1
}
