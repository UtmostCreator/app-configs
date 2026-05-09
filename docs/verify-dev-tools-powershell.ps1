<#
.SYNOPSIS
  Verifies Windows developer CLI tools from PowerShell.

.DESCRIPTION
  Non-mutating verifier. It checks whether each tool is callable from a clean
  PowerShell process, captures version output, and writes JSON + Markdown reports.

.OUTPUT
  %USERPROFILE%\.dev-cli-tools\verify-powershell-report.json
  %USERPROFILE%\.dev-cli-tools\verify-powershell-report.md
#>

[CmdletBinding()]
param(
    [switch]$TreatOptionalAsFailure,
    [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [Console]::OutputEncoding

    if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSStyle) {
        $PSStyle.OutputRendering = 'PlainText'
    }
} catch { }

$ReportDir = Join-Path $env:USERPROFILE '.dev-cli-tools'
$JsonReport = Join-Path $ReportDir 'verify-powershell-report.json'
$MdReport = Join-Path $ReportDir 'verify-powershell-report.md'

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

function Add-ProcessPath {
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path).Trim().TrimEnd('\')

    if (-not (Test-Path -LiteralPath $expanded)) {
        return
    }

    $parts = @($env:Path -split ';' | Where-Object { $_ })

    foreach ($part in $parts) {
        if ($part.TrimEnd('\').Equals($expanded, [StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }

    $env:Path = "$expanded;$env:Path"
}

function Add-DirectoryOfCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($cmd) {
        $source = $null

        if ($cmd.Source) {
            $source = $cmd.Source
        } elseif ($cmd.Path) {
            $source = $cmd.Path
        }

        if ($source -and (Test-Path -LiteralPath $source)) {
            Add-ProcessPath (Split-Path -Parent $source)
        }
    }
}

function Initialize-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    foreach ($p in @($machinePath -split ';') + @($userPath -split ';')) {
        Add-ProcessPath $p
    }

    $knownPaths = @(
        "$HOME\bin",
        "$HOME\scoop\shims",
        "$HOME\scoop\apps\starship\current",
        "$HOME\.cargo\bin",
        "$HOME\.local\bin",
        "$env:APPDATA\npm",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin",
        "$env:ProgramFiles\nodejs",
        "$env:ProgramFiles\PowerShell\7",
        "$env:ProgramFiles\Docker\Docker\resources\bin",
        "$env:ProgramFiles\Git\cmd",
        "$env:ProgramFiles\Git\bin",
        "$env:ProgramFiles\Git\usr\bin",
        "$env:ProgramFiles\Neovim\bin",
        'C:\msys64\usr\bin',
        'C:\msys64\mingw64\bin'
    )

    foreach ($p in $knownPaths) {
        Add-ProcessPath $p
    }

    $wingetRoots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages')
    )

    foreach ($root in $wingetRoots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Add-ProcessPath $_.FullName
                    Add-ProcessPath (Join-Path $_.FullName 'bin')
                }
        }
    }

    $mysqlRoot = Join-Path $env:ProgramFiles 'MySQL'
    if (Test-Path -LiteralPath $mysqlRoot) {
        Get-ChildItem -LiteralPath $mysqlRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Add-ProcessPath (Join-Path $_.FullName 'bin')
            }
    }

    foreach ($root in @($env:APPDATA, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        $pythonRoot = Join-Path $root 'Python'

        if (Test-Path -LiteralPath $pythonRoot) {
            Get-ChildItem -LiteralPath $pythonRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Add-ProcessPath (Join-Path $_.FullName 'Scripts')
                }
        }
    }
}

function New-Candidate {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [string[]]$Args = @()
    )

    [pscustomobject]@{
        Command = $Command
        Args = [string[]]$Args
    }
}

function ConvertTo-CommandLineArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $escaped = $Argument -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Resolve-ExecutablePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    if (Test-Path -LiteralPath $Command) {
        return (Resolve-Path -LiteralPath $Command).Path
    }

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($cmd) {
        if ($cmd.Source) {
            return $cmd.Source
        }

        if ($cmd.Path) {
            return $cmd.Path
        }
    }

    return $null
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [int]$Timeout = 25
    )

    $actualFile = $FilePath
    $actualArgs = (($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')

    if ($FilePath -match '\.(cmd|bat)$') {
        $actualFile = $env:ComSpec
        $actualArgs = '/d /c ' + (ConvertTo-CommandLineArgument $FilePath)

        if ($Arguments.Count -gt 0) {
            $actualArgs += ' ' + (($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
        }
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $actualFile
    $psi.Arguments = $actualArgs
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    try {
        $process = [System.Diagnostics.Process]::Start($psi)
    } catch {
        return [pscustomobject]@{
            ExitCode = $null
            Stdout = ''
            Stderr = $_.Exception.Message
            TimedOut = $false
        }
    }

    if (-not $process.WaitForExit($Timeout * 1000)) {
        try {
            $process.Kill($true)
        } catch { }

        return [pscustomobject]@{
            ExitCode = 124
            Stdout = ''
            Stderr = "Timed out after $Timeout seconds"
            TimedOut = $true
        }
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
        TimedOut = $false
    }
}

function Get-FirstLine {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $line = (
        $Text -split "`r?`n" |
            Where-Object { $_.Trim() } |
            Select-Object -First 1
    )

    if ($line) {
        return $line.Trim()
    }

    return ''
}

function Test-Candidate {
    param(
        [Parameter(Mandatory = $true)]
        $Candidate
    )

    if (-not $Candidate -or -not $Candidate.Command) {
        return [pscustomobject]@{
            Ok = $false
            Used = ''
            Version = ''
            ErrorText = 'Invalid candidate.'
        }
    }

    Add-DirectoryOfCommand $Candidate.Command

    $resolved = Resolve-ExecutablePath -Command $Candidate.Command
    $used = "$($Candidate.Command) $($Candidate.Args -join ' ')".Trim()

    if (-not $resolved) {
        return [pscustomobject]@{
            Ok = $false
            Used = $used
            Version = ''
            ErrorText = "Command not found: $($Candidate.Command)"
        }
    }

    $result = Invoke-ExternalCommand -FilePath $resolved -Arguments $Candidate.Args -Timeout $TimeoutSeconds
    $combined = ($result.Stdout + $result.Stderr)

    if ($result.ExitCode -eq 0) {
        return [pscustomobject]@{
            Ok = $true
            Used = $used
            Version = (Get-FirstLine $combined)
            ErrorText = ''
        }
    }

    return [pscustomobject]@{
        Ok = $false
        Used = $used
        Version = ''
        ErrorText = "$(Get-FirstLine $combined) [exit=$($result.ExitCode)]"
    }
}

function Test-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [object[]]$Candidates = @(),

        [switch]$Optional,

        [scriptblock]$FileCheck
    )

    if ($FileCheck) {
        $ok = & $FileCheck

        return [pscustomobject]@{
            Name = $Name
            Status = if ($ok) { 'ok' } elseif ($Optional -and -not $TreatOptionalAsFailure) { 'optional-missing' } else { 'fail' }
            Used = 'file-check'
            Version = if ($ok) { 'present' } else { '' }
            ErrorText = if ($ok) { '' } else { 'Expected file/component was not found.' }
            Optional = [bool]$Optional
        }
    }

    $candidateList = @($Candidates | Where-Object { $_ })

    if ($candidateList.Count -eq 0) {
        return [pscustomobject]@{
            Name = $Name
            Status = if ($Optional -and -not $TreatOptionalAsFailure) { 'optional-missing' } else { 'fail' }
            Used = ''
            Version = ''
            ErrorText = 'No candidates were provided.'
            Optional = [bool]$Optional
        }
    }

    $attemptErrors = [System.Collections.Generic.List[string]]::new()
    $lastUsed = ''

    foreach ($candidate in $candidateList) {
        $result = Test-Candidate -Candidate $candidate
        $lastUsed = $result.Used

        if ($result.Ok) {
            return [pscustomobject]@{
                Name = $Name
                Status = 'ok'
                Used = $result.Used
                Version = $result.Version
                ErrorText = ''
                Optional = [bool]$Optional
            }
        }

        if ($result.ErrorText) {
            $attemptErrors.Add($result.ErrorText) | Out-Null
        }
    }

    return [pscustomobject]@{
        Name = $Name
        Status = if ($Optional -and -not $TreatOptionalAsFailure) { 'optional-missing' } else { 'fail' }
        Used = $lastUsed
        Version = ''
        ErrorText = ($attemptErrors -join ' | ')
        Optional = [bool]$Optional
    }
}

Initialize-ProcessPath

$NodeExe = Join-Path $env:ProgramFiles 'nodejs\node.exe'
$NpmCli = Join-Path $env:ProgramFiles 'nodejs\node_modules\npm\bin\npm-cli.js'
$NpmRoot = Join-Path $env:APPDATA 'npm\node_modules'

$OpenCodeJs = Join-Path $NpmRoot 'opencode-ai\bin\opencode'
$AstGrepCmd = Join-Path $env:APPDATA 'npm\ast-grep.cmd'
$SgCmd = Join-Path $env:APPDATA 'npm\sg.cmd'

$ScoopShims = Join-Path $HOME 'scoop\shims'
$CargoBin = Join-Path $HOME '.cargo\bin'
$WinGetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'

$tools = @(
    @{ Name = 'WinGet'; Candidates = @((New-Candidate 'winget' @('--version'))) },
    @{ Name = 'Git'; Candidates = @((New-Candidate 'git' @('--version'))) },
    @{ Name = 'Git Bash'; Candidates = @((New-Candidate 'bash' @('--version'))) },
    @{ Name = 'PowerShell 7'; Candidates = @((New-Candidate 'pwsh' @('--version'))) },

    @{
        Name = 'Python'
        Candidates = @(
            (New-Candidate 'python' @('--version')),
            (New-Candidate 'py' @('-3.12', '--version')),
            (New-Candidate 'py' @('--version'))
        )
    },
    @{ Name = 'Python launcher'; Optional = $true; Candidates = @((New-Candidate 'py' @('--version'))) },

    @{
        Name = 'Node.js'
        Candidates = @(
            (New-Candidate 'node' @('--version')),
            (New-Candidate $NodeExe @('--version'))
        )
    },
    @{
        Name = 'npm'
        Candidates = @(
            (New-Candidate 'npm' @('--version')),
            (New-Candidate 'npm.cmd' @('--version')),
            (New-Candidate $NodeExe @($NpmCli, '--version'))
        )
    },

    @{ Name = 'Rust cargo'; Candidates = @((New-Candidate 'cargo' @('--version'))) },
    @{ Name = 'Rustup'; Candidates = @((New-Candidate 'rustup' @('--version'))) },

    @{ Name = 'Atuin'; Candidates = @((New-Candidate 'atuin' @('--version'))) },
    @{ Name = 'bat'; Candidates = @((New-Candidate 'bat' @('--version'))) },
    @{ Name = 'btop'; Candidates = @((New-Candidate 'btop' @('--version')), (New-Candidate 'btop4win' @('--version'))) },
    @{ Name = 'Docker CLI'; Candidates = @((New-Candidate 'docker' @('--version')), (New-Candidate "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe" @('--version'))) },
    @{ Name = 'eza'; Candidates = @((New-Candidate 'eza' @('--version'))) },
    @{ Name = 'fd'; Candidates = @((New-Candidate 'fd' @('--version'))) },
    @{ Name = 'fzf'; Candidates = @((New-Candidate 'fzf' @('--version'))) },
    @{ Name = 'git-delta'; Candidates = @((New-Candidate 'delta' @('--version'))) },
    @{ Name = 'Difftastic'; Candidates = @((New-Candidate 'difft' @('--version'))) },
    @{ Name = 'direnv'; Candidates = @((New-Candidate 'direnv' @('version'))) },
    @{ Name = 'GitHub Copilot CLI'; Candidates = @((New-Candidate 'copilot' @('--version')), (New-Candidate 'gh' @('copilot', '--version'))) },

    @{
        Name = 'just'
        Candidates = @(
            (New-Candidate 'just' @('--version')),
            (New-Candidate (Join-Path $ScoopShims 'just.exe') @('--version')),
            (New-Candidate (Join-Path $WinGetLinks 'just.exe') @('--version'))
        )
    },

    @{ Name = 'lazygit'; Candidates = @((New-Candidate 'lazygit' @('--version'))) },
    @{ Name = 'lnav'; Candidates = @((New-Candidate 'lnav' @('-V'))) },
    @{ Name = 'lychee'; Candidates = @((New-Candidate 'lychee' @('--version'))) },
    @{ Name = 'mise'; Candidates = @((New-Candidate 'mise' @('--version'))) },
    @{ Name = 'MySQL Shell'; Candidates = @((New-Candidate 'mysqlsh' @('--version'))) },
    @{ Name = 'mysql.exe classic client'; Optional = $true; Candidates = @((New-Candidate 'mysql' @('--version'))) },
    @{ Name = 'Neovim'; Candidates = @((New-Candidate 'nvim' @('--version'))) },
    @{ Name = 'pnpm'; Candidates = @((New-Candidate 'pnpm' @('--version')), (New-Candidate 'pnpm.cmd' @('--version'))) },
    @{ Name = 'ripgrep'; Candidates = @((New-Candidate 'rg' @('--version'))) },

    @{
        Name = 'ripgrep-all'
        Candidates = @(
            (New-Candidate 'rga' @('--version')),
            (New-Candidate (Join-Path $CargoBin 'rga.exe') @('--version')),
            (New-Candidate (Join-Path $ScoopShims 'rga.exe') @('--version')),
            (New-Candidate (Join-Path $WinGetLinks 'rga.exe') @('--version'))
        )
    },

    @{ Name = 'Semgrep'; Candidates = @((New-Candidate 'semgrep' @('--version'))) },
    @{ Name = 'ShellCheck'; Candidates = @((New-Candidate 'shellcheck' @('--version'))) },
    @{ Name = 'shfmt'; Candidates = @((New-Candidate 'shfmt' @('--version'))) },
    @{ Name = 'Starship'; Candidates = @((New-Candidate 'starship' @('--version'))) },

    @{
        Name = 'tlrc'
        Candidates = @(
            (New-Candidate 'tlrc' @('--version')),
            (New-Candidate (Join-Path $ScoopShims 'tlrc.exe') @('--version')),
            (New-Candidate (Join-Path $WinGetLinks 'tlrc.exe') @('--version'))
        )
    },

    @{ Name = 'tldr wrapper'; Optional = $true; Candidates = @((New-Candidate 'tldr' @('--version'))) },
    @{ Name = 'tmux'; Candidates = @((New-Candidate 'tmux' @('-V'))) },

    @{
        Name = 'watchexec'
        Candidates = @(
            (New-Candidate 'watchexec' @('--version')),
            (New-Candidate (Join-Path $CargoBin 'watchexec.exe') @('--version')),
            (New-Candidate (Join-Path $ScoopShims 'watchexec.exe') @('--version')),
            (New-Candidate (Join-Path $WinGetLinks 'watchexec.exe') @('--version'))
        )
    },

    @{ Name = 'Yazi'; Candidates = @((New-Candidate 'yazi' @('--version'))) },
    @{ Name = 'yq'; Candidates = @((New-Candidate 'yq' @('--version'))) },
    @{ Name = 'zoxide'; Candidates = @((New-Candidate 'zoxide' @('--version'))) },
    @{ Name = 'actionlint'; Candidates = @((New-Candidate 'actionlint' @('--version'))) },
    @{ Name = 'bats-core'; Candidates = @((New-Candidate 'bats' @('--version'))) },
    @{ Name = 'zsh'; Optional = $true; Candidates = @((New-Candidate 'zsh' @('--version'))) },

    @{
        Name = 'OpenCode'
        Candidates = @(
            (New-Candidate $NodeExe @($OpenCodeJs, '--version')),
            (New-Candidate 'opencode.cmd' @('--version')),
            (New-Candidate 'opencode' @('--version'))
        )
    },

    @{
        Name = 'ast-grep'
        Candidates = @(
            (New-Candidate 'ast-grep.cmd' @('--version')),
            (New-Candidate 'ast-grep' @('--version')),
            (New-Candidate $AstGrepCmd @('--version'))
        )
    },

    @{
        Name = 'sg'
        Candidates = @(
            (New-Candidate 'sg.cmd' @('--version')),
            (New-Candidate 'sg' @('--version')),
            (New-Candidate $SgCmd @('--version'))
        )
    },

    @{ Name = 'VS Code CLI'; Optional = $true; Candidates = @((New-Candidate 'code' @('--version'))) },
    @{ Name = 'Stripe CLI'; Optional = $true; Candidates = @((New-Candidate 'stripe' @('--version'))) },

    @{
        Name = 'zsh-autosuggestions plugin'
        Optional = $true
        FileCheck = { Test-Path 'C:\msys64\usr\share\zsh\plugins\zsh-autosuggestions\zsh-autosuggestions.zsh' }
    },

    @{
        Name = 'zsh-syntax-highlighting plugin'
        Optional = $true
        FileCheck = { Test-Path 'C:\msys64\usr\share\zsh\plugins\zsh-syntax-highlighting\zsh-syntax-highlighting.zsh' }
    }
)

$results = foreach ($tool in $tools) {
    $toolCandidates = @()

    if ($tool.ContainsKey('Candidates') -and $null -ne $tool.Candidates) {
        $toolCandidates = @($tool.Candidates)
    }

    $toolFileCheck = $null

    if ($tool.ContainsKey('FileCheck')) {
        $toolFileCheck = $tool.FileCheck
    }

    Test-Tool `
        -Name $tool.Name `
        -Candidates $toolCandidates `
        -Optional:([bool]$tool.Optional) `
        -FileCheck $toolFileCheck
}

$results = @($results) + [pscustomobject]@{
    Name = 'colima'
    Status = 'unsupported'
    Used = 'native Windows'
    Version = ''
    ErrorText = 'Colima is not a native Windows container runtime. Use Docker Desktop on Windows or Colima inside WSL2.'
    Optional = $true
}

$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    shell = 'PowerShell'
    powershellVersion = $PSVersionTable.PSVersion.ToString()
    ok = @($results | Where-Object { $_.Status -eq 'ok' }).Count
    failed = @($results | Where-Object { $_.Status -eq 'fail' }).Count
    optionalMissing = @($results | Where-Object { $_.Status -eq 'optional-missing' }).Count
    unsupported = @($results | Where-Object { $_.Status -eq 'unsupported' }).Count
    results = $results
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonReport -Encoding UTF8

$md = [System.Collections.Generic.List[string]]::new()
$md.Add('# PowerShell CLI Verification Report') | Out-Null
$md.Add('') | Out-Null
$md.Add("- Generated: $($summary.generatedAt)") | Out-Null
$md.Add("- OK: $($summary.ok)") | Out-Null
$md.Add("- Failed: $($summary.failed)") | Out-Null
$md.Add("- Optional missing: $($summary.optionalMissing)") | Out-Null
$md.Add("- Unsupported: $($summary.unsupported)") | Out-Null
$md.Add('') | Out-Null
$md.Add('| Status | Tool | Used | Version / First output | Error |') | Out-Null
$md.Add('|---|---|---|---|---|') | Out-Null

foreach ($r in $results) {
    $versionText = (($r.Version | Out-String).Trim() -replace '\|', '\|')
    $errorText = (($r.ErrorText | Out-String).Trim() -replace '\|', '\|')
    $usedText = (($r.Used | Out-String).Trim() -replace '\|', '\|')

    $md.Add("| $($r.Status) | $($r.Name) | ``$usedText`` | $versionText | $errorText |") | Out-Null
}

$md -join "`r`n" | Set-Content -LiteralPath $MdReport -Encoding UTF8

$results |
    Sort-Object Status, Name |
    Format-Table Status, Name, Used, Version -AutoSize

Write-Host ''
Write-Host "JSON report: $JsonReport"
Write-Host "Markdown report: $MdReport"

if (@($results | Where-Object { $_.Status -eq 'fail' }).Count -gt 0) {
    exit 1
}

exit 0