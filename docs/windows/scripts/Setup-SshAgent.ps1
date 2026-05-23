<#
.SYNOPSIS
    Start Git's bundled ssh-agent for the current PowerShell session and load
    a key with an 8-hour TTL.

.DESCRIPTION
    Mirrors the .bashrc setup at
    C:\Users\<user>\Documents\___sync\syncthing\users\.bashrc
    for PowerShell sessions on Windows.

    - Reuses an existing live agent recorded in $HOME\.ssh\agent.env if any.
    - Otherwise starts a fresh agent from Git's bundled ssh-agent.exe.
    - Loads the configured private key with `ssh-add -t 28800` (8 hours).
    - Sets SSH_AUTH_SOCK and SSH_AGENT_PID in the current process so child
      processes (like git.exe) can find the agent.

    Does NOT modify system services, the registry, or any persistent state
    other than $HOME\.ssh\agent.env. Close the PowerShell session and the
    agent dies.

.PARAMETER KeyPath
    Path to the private key to load. Default: $HOME\.ssh\github.uc.ll5

.PARAMETER TtlSeconds
    ssh-add lifetime in seconds. Default: 28800 (8 hours).

.PARAMETER Force
    Always start a new agent and re-add the key, even if one is already
    running with the key loaded.

.PARAMETER GitRoot
    Override the Git for Windows install root. Default: probe known paths.

.EXAMPLE
    pwsh -NoProfile -File docs\windows\scripts\Setup-SshAgent.ps1

.EXAMPLE
    .\Setup-SshAgent.ps1 -KeyPath "$HOME\.ssh\gitlab.uc.ll5"

.NOTES
    Approval boundaries: this script touches your private key (`ssh-add`)
    and writes $HOME\.ssh\agent.env. No system or admin changes.
#>

[CmdletBinding()]
param(
    [string]$KeyPath = (Join-Path $HOME '.ssh\github.uc.ll5'),
    [int]$TtlSeconds = 28800,
    [switch]$Force,
    [string]$GitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-GitToolsRoot {
    param([string]$Override)
    if ($Override) {
        if (-not (Test-Path $Override)) {
            throw "Provided GitRoot does not exist: $Override"
        }
        return $Override
    }
    $candidates = @(
        "$env:ProgramFiles\Git",
        "$env:ProgramFiles(x86)\Git",
        "$env:LOCALAPPDATA\Programs\Git"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'usr\bin\ssh-agent.exe'))) {
            return $candidate
        }
    }
    throw 'Could not find Git for Windows. Install it from https://git-scm.com/download/win or pass -GitRoot explicitly.'
}

function Test-AgentAlive {
    param([int]$ProcessId)
    if (-not $ProcessId) { return $false }
    try {
        Get-Process -Id $ProcessId -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-KeyLoaded {
    param(
        [string]$SshAddExe,
        [string]$PrivateKeyPath
    )
    $fingerprint = & "$SshAddExe" -l 2>$null
    if (-not $fingerprint) { return $false }
    $keyName = Split-Path -Leaf $PrivateKeyPath
    return ($fingerprint -match [regex]::Escape($keyName))
}

try {
    if (-not (Test-Path $KeyPath)) {
        throw "Private key not found: $KeyPath. Either pass -KeyPath or generate one with ssh-keygen."
    }

    $gitRoot = Resolve-GitToolsRoot -Override $GitRoot
    $sshAgentExe = Join-Path $gitRoot 'usr\bin\ssh-agent.exe'
    $sshAddExe   = Join-Path $gitRoot 'usr\bin\ssh-add.exe'
    foreach ($exe in @($sshAgentExe, $sshAddExe)) {
        if (-not (Test-Path $exe)) {
            throw "Required binary not found: $exe"
        }
    }

    $agentEnvFile = Join-Path $HOME '.ssh\agent.env'
    $sshDir       = Join-Path $HOME '.ssh'
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    $reuseExisting = $false
    if ((-not $Force) -and (Test-Path $agentEnvFile)) {
        $envText  = Get-Content $agentEnvFile -Raw
        $sock     = ''
        $agentPid = 0
        if ($envText -match 'SSH_AUTH_SOCK=([^;]+);') { $sock = $Matches[1] }
        if ($envText -match 'SSH_AGENT_PID=([^;]+);') { $agentPid = [int]$Matches[1] }
        if ($sock -and $agentPid -and (Test-AgentAlive -ProcessId $agentPid)) {
            $env:SSH_AUTH_SOCK = $sock
            $env:SSH_AGENT_PID = "$agentPid"
            $null = & "$sshAddExe" -l 2>$null
            $lastExit = $LASTEXITCODE
            if ($lastExit -ne 2) {
                $reuseExisting = $true
                Write-Host "Reusing existing agent PID $agentPid (sock $sock)"
            } else {
                Write-Host "Existing agent.env points to an unreachable agent; starting a new one."
            }
        }
    }

    if (-not $reuseExisting) {
        Write-Host "Starting new ssh-agent from $sshAgentExe"
        $agentLines = & "$sshAgentExe" -s
        if (-not $agentLines) {
            throw 'ssh-agent.exe -s produced no output.'
        }
        $joined = ($agentLines -join "`n")
        Set-Content -Path $agentEnvFile -Value $joined -Encoding ASCII -NoNewline
        if ($joined -match 'SSH_AUTH_SOCK=([^;]+);') { $env:SSH_AUTH_SOCK = $Matches[1] }
        if ($joined -match 'SSH_AGENT_PID=([^;]+);') { $env:SSH_AGENT_PID = $Matches[1] }
        if (-not $env:SSH_AUTH_SOCK -or -not $env:SSH_AGENT_PID) {
            throw "Could not parse SSH_AUTH_SOCK/SSH_AGENT_PID from ssh-agent output:`n$joined"
        }
        Write-Host "Agent started: PID $env:SSH_AGENT_PID sock $env:SSH_AUTH_SOCK"
    }

    if (-not (Test-KeyLoaded -SshAddExe $sshAddExe -PrivateKeyPath $KeyPath) -or $Force) {
        Write-Host "Loading key $KeyPath with TTL $TtlSeconds seconds"
        & "$sshAddExe" -t $TtlSeconds $KeyPath
        if ($LASTEXITCODE -ne 0) {
            throw "ssh-add failed with exit $LASTEXITCODE for key $KeyPath."
        }
    } else {
        Write-Host "Key already loaded; skipping ssh-add (use -Force to override)."
    }

    Write-Host ''
    Write-Host 'Loaded identities:'
    & "$sshAddExe" -l
    Write-Host ''
    Write-Host 'Next step: verify GitHub auth with'
    Write-Host '    ssh -T git@github.com'
}
catch {
    Write-Error $_
    exit 1
}
