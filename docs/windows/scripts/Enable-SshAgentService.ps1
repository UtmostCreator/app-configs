<#
.SYNOPSIS
    Enable and start the Windows OpenSSH ssh-agent service. Requires admin.

.DESCRIPTION
    Sets the Windows `ssh-agent` service to StartType = Automatic and starts
    it. This service hosts a persistent ssh-agent shared across all
    PowerShell sessions and any process that talks to
    `\\.\pipe\openssh-ssh-agent`.

    This script does NOT:
      - install or modify keys (use `ssh-add` separately).
      - change git's `core.sshCommand` (do that explicitly in a non-admin
        shell with `git config --global core.sshCommand ...`).
      - touch Git Bash's separate agent setup.

.PARAMETER WhatIf
    Built-in PowerShell switch. Prints the actions without applying them.

.EXAMPLE
    # Open Windows Terminal -> "PowerShell" tab as Administrator, then:
    pwsh -NoProfile -File docs\windows\scripts\Enable-SshAgentService.ps1

.EXAMPLE
    # Dry-run:
    pwsh -NoProfile -File docs\windows\scripts\Enable-SshAgentService.ps1 -WhatIf

.NOTES
    Approval boundaries: changing a Windows service startup type and starting
    it requires Administrator. The script refuses to run without elevation.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsElevated {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    if (-not (Test-IsElevated)) {
        throw 'This script must be run from an elevated PowerShell session (Run as Administrator).'
    }

    $service = Get-Service -Name 'ssh-agent' -ErrorAction Stop
    Write-Host ("Current state: Status={0}, StartType={1}" -f $service.Status, $service.StartType)

    if ($service.StartType -ne 'Automatic') {
        if ($PSCmdlet.ShouldProcess('ssh-agent', 'Set-Service -StartupType Automatic')) {
            Set-Service -Name 'ssh-agent' -StartupType Automatic
            Write-Host 'StartupType set to Automatic.'
        }
    } else {
        Write-Host 'StartupType already Automatic.'
    }

    if ($service.Status -ne 'Running') {
        if ($PSCmdlet.ShouldProcess('ssh-agent', 'Start-Service')) {
            Start-Service -Name 'ssh-agent'
            Write-Host 'Service started.'
        }
    } else {
        Write-Host 'Service already Running.'
    }

    $final = Get-Service -Name 'ssh-agent'
    Write-Host ("Final state:   Status={0}, StartType={1}" -f $final.Status, $final.StartType)
    if ($final.Status -ne 'Running' -or $final.StartType -ne 'Automatic') {
        throw 'Post-state did not reach Running + Automatic; check Event Viewer.'
    }

    Write-Host ''
    Write-Host 'Next steps (run in a NON-admin PowerShell):'
    Write-Host '  git config --global core.sshCommand "C:/WINDOWS/System32/OpenSSH/ssh.exe"'
    Write-Host '  ssh-add "$HOME\.ssh\github.uc.ll5"'
    Write-Host '  ssh -T git@github.com'
}
catch {
    Write-Error $_
    exit 1
}
