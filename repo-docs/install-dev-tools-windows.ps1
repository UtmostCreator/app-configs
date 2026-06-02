<#
.SYNOPSIS
  Windows 11+ developer CLI tool installer, repairer, profile configurator, and verifier.

.DESCRIPTION
  Installs and verifies a Windows equivalent of a macOS Homebrew CLI stack.
  Repairs PATH visibility, configures PowerShell/Git Bash/Zsh startup files,
  creates stable wrappers where WinGet/Scoop/npm expose inconsistent command names,
  and uses the Rust GNU toolchain for cargo-installed tools to avoid wrong link.exe issues.

.USAGE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -VerifyOnly
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -InstallOnly
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -SkipProfiles
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -SkipMsys2ZshPlugins
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -StartDockerDesktop
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -FailOnUnsupported

.NOTES
  - Designed for Windows 11 or later.
  - Uses WinGet where reliable native Windows packages exist.
  - Uses pip/npm/cargo/source installs where needed.
  - Uses Rust GNU toolchain for cargo tools to avoid MSVC link.exe conflicts.
  - Colima is not installed because it is not a native Windows container runtime.
#>

[CmdletBinding()]
param(
    [switch]$VerifyOnly,
    [switch]$InstallOnly,
    [switch]$SkipProfiles,
    [switch]$SkipMsys2ZshPlugins,
    [switch]$StartDockerDesktop,
    [switch]$FailOnUnsupported,
    [int]$VerifyTimeoutSeconds = 25
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$Script:InstallRoot = Join-Path $env:USERPROFILE '.dev-cli-tools'
$Script:UserBin = Join-Path $env:USERPROFILE 'bin'
$Script:LogPath = Join-Path $Script:InstallRoot 'install.log'
$Script:ReportPath = Join-Path $Script:InstallRoot 'install-report.json'
$Script:MarkdownReportPath = Join-Path $Script:InstallRoot 'install-report.md'

$Script:Failures = [System.Collections.Generic.List[object]]::new()
$Script:Warnings = [System.Collections.Generic.List[object]]::new()
$Script:Verified = [System.Collections.Generic.List[object]]::new()
$Script:IsAdmin = $false
$Script:WingetExe = $null

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [Console]::OutputEncoding
    if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSStyle) {
        $PSStyle.OutputRendering = 'PlainText'
    }
} catch { }

function Write-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('Info','OK','Warn','Error')][string]$Level = 'Info'
    )

    $prefix = switch ($Level) {
        'OK'    { '[OK] ' }
        'Warn'  { '[WARN] ' }
        'Error' { '[ERROR] ' }
        default { '[INFO] ' }
    }

    $color = switch ($Level) {
        'OK'    { 'Green' }
        'Warn'  { 'Yellow' }
        'Error' { 'Red' }
        default { 'Cyan' }
    }

    $line = "$prefix$Message"
    Write-Host $line -ForegroundColor $color

    try {
        Add-Content -LiteralPath $Script:LogPath -Value "$(Get-Date -Format o) $line" -Encoding UTF8
    } catch { }
}

function Add-WarningRecord {
    param([string]$Name, [string]$Message)

    $Script:Warnings.Add([ordered]@{
        name = $Name
        message = $Message
    }) | Out-Null

    Write-Step "${Name}: $Message" 'Warn'
}

function Add-FailureRecord {
    param([string]$Name, [string]$Message)

    $Script:Failures.Add([ordered]@{
        name = $Name
        message = $Message
    }) | Out-Null

    Write-Step "${Name}: $Message" 'Error'
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-TextFileUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        Ensure-Directory $dir
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Normalize-PathList {
    param([string[]]$Items)

    $seen = @{}
    $result = [System.Collections.Generic.List[string]]::new()

    foreach ($item in $Items) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $expanded = [Environment]::ExpandEnvironmentVariables($item.Trim().TrimEnd('\'))

        if ([string]::IsNullOrWhiteSpace($expanded)) {
            continue
        }

        $key = $expanded.ToLowerInvariant()

        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $result.Add($expanded) | Out-Null
        }
    }

    return $result.ToArray()
}

function Refresh-ProcessPathFromRegistry {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    $env:Path = ((Normalize-PathList (($machinePath -split ';') + ($userPath -split ';'))) -join ';')
}

function Add-ProcessPath {
    param([AllowNull()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path).Trim().TrimEnd('\')

    if (-not (Test-Path -LiteralPath $expanded)) {
        return
    }

    $env:Path = ((Normalize-PathList (@($expanded) + ($env:Path -split ';'))) -join ';')
}

function Add-UserPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path).Trim().TrimEnd('\')

    if (-not (Test-Path -LiteralPath $expanded)) {
        return
    }

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $items = @()

    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $items = $current -split ';'
    }

    $normalized = Normalize-PathList $items
    $exists = $false

    foreach ($item in $normalized) {
        if ($item.Equals($expanded, [StringComparison]::OrdinalIgnoreCase)) {
            $exists = $true
            break
        }
    }

    if (-not $exists) {
        $newPath = ((Normalize-PathList ($normalized + @($expanded))) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Step "Added to user PATH: $expanded" 'OK'
    }

    Add-ProcessPath $expanded
}

function Add-PythonUserScriptsPaths {
    foreach ($root in @($env:APPDATA, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        $pythonRoot = Join-Path $root 'Python'

        if (Test-Path -LiteralPath $pythonRoot) {
            Get-ChildItem -LiteralPath $pythonRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Add-UserPath (Join-Path $_.FullName 'Scripts')
                }
        }
    }
}

function Initialize-KnownPaths {
    Ensure-Directory $Script:InstallRoot
    Ensure-Directory $Script:UserBin

    $known = @(
        $Script:UserBin,
        (Join-Path $env:USERPROFILE 'scoop\shims'),
        (Join-Path $env:USERPROFILE 'scoop\apps\starship\current'),
        (Join-Path $env:USERPROFILE '.cargo\bin'),
        (Join-Path $env:USERPROFILE '.local\bin'),
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin'),
        (Join-Path $env:ProgramFiles 'nodejs'),
        (Join-Path $env:ProgramFiles 'PowerShell\7'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'),
        (Join-Path $env:ProgramFiles 'Git\cmd'),
        (Join-Path $env:ProgramFiles 'Git\bin'),
        (Join-Path $env:ProgramFiles 'Git\usr\bin'),
        (Join-Path $env:ProgramFiles 'Neovim\bin'),
        'C:\msys64\usr\bin',
        'C:\msys64\mingw64\bin'
    )

    foreach ($path in $known) {
        Add-UserPath $path
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

    Add-PythonUserScriptsPaths
}

function Test-IsWindows11OrLater {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $build = [int]$os.BuildNumber

    if ($build -lt 22000) {
        throw "This script is designed for Windows 11 or later. Detected build: $build."
    }

    Write-Step "Detected $($os.Caption), build $build" 'OK'
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $null
    }

    if (Test-Path -LiteralPath $Command) {
        return (Resolve-Path -LiteralPath $Command).Path
    }

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($cmd) {
        if ($cmd.Source) { return $cmd.Source }
        if ($cmd.Path) { return $cmd.Path }
    }

    return $null
}

function Add-DirectoryForCommandIfFound {
    param([Parameter(Mandatory = $true)][string]$Command)

    $resolved = Resolve-CommandPath $Command

    if ($resolved -and (Test-Path -LiteralPath $resolved)) {
        $dir = Split-Path -Parent $resolved
        Add-UserPath $dir
        return $dir
    }

    $names = @("$Command.exe", "$Command.cmd", "$Command.bat", $Command)
    $roots = @(
        $Script:UserBin,
        (Join-Path $env:USERPROFILE 'scoop\shims'),
        (Join-Path $env:USERPROFILE '.cargo\bin'),
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'),
        (Join-Path $env:ProgramFiles 'Git'),
        (Join-Path $env:ProgramFiles 'MySQL'),
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        'C:\msys64\usr\bin',
        'C:\msys64\mingw64\bin'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($root in $roots) {
        foreach ($name in $names) {
            $match = Get-ChildItem -LiteralPath $root -Filter $name -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($match) {
                Add-UserPath $match.DirectoryName
                return $match.DirectoryName
            }
        }
    }

    return $null
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

function Invoke-Cli {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $PWD.Path,
        [int]$TimeoutSeconds = 120
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
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    try {
        $process = [System.Diagnostics.Process]::Start($psi)
    } catch {
        return [ordered]@{
            exitCode = $null
            stdout = ''
            stderr = $_.Exception.Message
            timedOut = $false
        }
    }

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill($true) } catch { }

        return [ordered]@{
            exitCode = 124
            stdout = ''
            stderr = "Timed out after $TimeoutSeconds seconds"
            timedOut = $true
        }
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    return [ordered]@{
        exitCode = $process.ExitCode
        stdout = $stdout
        stderr = $stderr
        timedOut = $false
    }
}

function Get-FirstOutputLine {
    param([AllowNull()][string]$Text)

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

function Resolve-WinGet {
    Initialize-KnownPaths

    $cmd = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($cmd -and $cmd.Source) {
        $Script:WingetExe = $cmd.Source
        return $Script:WingetExe
    }

    $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'

    if (Test-Path -LiteralPath $candidate) {
        $Script:WingetExe = $candidate
        Add-UserPath (Split-Path -Parent $candidate)
        return $Script:WingetExe
    }

    return $null
}

function Test-WinGetAvailable {
    $winget = Resolve-WinGet

    if (-not $winget) {
        throw 'WinGet was not found. Install or repair Microsoft App Installer, enable App execution aliases for Windows Package Manager, then rerun this script.'
    }

    Write-Step "WinGet found: $winget" 'OK'
    & $winget source update | Out-Host
}

function Test-WinGetNoApplicableUpdateExit {
    param([int]$ExitCode)

    return ($ExitCode -eq -1978335189)
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$CommandName,
        [switch]$RequiresAdmin,
        [switch]$Optional
    )

    $winget = Resolve-WinGet

    if (-not $winget) {
        if ($Optional) {
            Add-WarningRecord $Name 'WinGet was not found; optional package skipped.'
            return
        }

        throw 'WinGet was not found.'
    }

    Write-Step "Installing/updating $Name [$Id] via WinGet"

    $baseArgs = @(
        'install',
        '--exact',
        '--id', $Id,
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )

    & $winget @baseArgs --silent
    $exit = $LASTEXITCODE

    if (Test-WinGetNoApplicableUpdateExit $exit) {
        Write-Step "$Name is already installed and no upgrade is available" 'OK'
        return
    }

    if ($exit -ne 0) {
        Write-Step "$Name silent install did not complete cleanly; retrying without --silent" 'Warn'
        & $winget @baseArgs
        $exit = $LASTEXITCODE
    }

    if (Test-WinGetNoApplicableUpdateExit $exit) {
        Write-Step "$Name is already installed and no upgrade is available" 'OK'
        return
    }

    if ($exit -ne 0) {
        if ($Optional) {
            Add-WarningRecord $Name "Optional WinGet package failed with exit code $exit."
            return
        }

        if ($RequiresAdmin -and -not $Script:IsAdmin) {
            Add-WarningRecord $Name "WinGet install failed with exit code $exit. This package commonly requires elevation; rerun PowerShell as Administrator if needed."
            return
        }

        if (-not [string]::IsNullOrWhiteSpace($CommandName)) {
            Add-DirectoryForCommandIfFound $CommandName | Out-Null

            if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
                Add-WarningRecord $Name "WinGet returned exit code $exit, but '$CommandName' is already callable; treating as installed."
                return
            }
        }

        Add-FailureRecord $Name "WinGet install failed with exit code $exit."
    } else {
        Write-Step "$Name install command completed" 'OK'
    }
}

function Install-WingetPackages {
    $packages = @(
        @{ Name = 'Visual C++ Redistributable x64'; Id = 'Microsoft.VCRedist.2015+.x64'; RequiresAdmin = $true; Command = '' },
        @{ Name = 'Git for Windows'; Id = 'Git.Git'; Command = 'git'; RequiresAdmin = $true },
        @{ Name = 'PowerShell 7'; Id = 'Microsoft.PowerShell'; Command = 'pwsh' },
        @{ Name = 'Python 3.12'; Id = 'Python.Python.3.12'; Command = 'py' },
        @{ Name = 'Node.js LTS'; Id = 'OpenJS.NodeJS.LTS'; Command = 'node' },
        @{ Name = 'Rustup'; Id = 'Rustlang.Rustup'; Command = 'rustup' },
        @{ Name = 'Atuin'; Id = 'Atuinsh.Atuin'; Command = 'atuin' },
        @{ Name = 'bat'; Id = 'sharkdp.bat'; Command = 'bat' },
        @{ Name = 'btop4win'; Id = 'aristocratos.btop4win'; Command = 'btop' },
        @{ Name = 'Docker Desktop'; Id = 'Docker.DockerDesktop'; Command = 'docker'; RequiresAdmin = $true },
        @{ Name = 'eza'; Id = 'eza-community.eza'; Command = 'eza' },
        @{ Name = 'fd'; Id = 'sharkdp.fd'; Command = 'fd' },
        @{ Name = 'fzf'; Id = 'junegunn.fzf'; Command = 'fzf' },
        @{ Name = 'delta'; Id = 'dandavison.delta'; Command = 'delta' },
        @{ Name = 'Difftastic'; Id = 'Wilfred.difftastic'; Command = 'difft' },
        @{ Name = 'direnv'; Id = 'direnv.direnv'; Command = 'direnv' },
        @{ Name = 'GitHub Copilot CLI'; Id = 'GitHub.Copilot'; Command = 'copilot'; Optional = $true },
        @{ Name = 'just'; Id = 'Casey.Just'; Command = 'just' },
        @{ Name = 'lazygit'; Id = 'JesseDuffield.lazygit'; Command = 'lazygit' },
        @{ Name = 'lnav'; Id = 'tstack.lnav'; Command = 'lnav' },
        @{ Name = 'lychee'; Id = 'lycheeverse.lychee'; Command = 'lychee' },
        @{ Name = 'mise'; Id = 'jdx.mise'; Command = 'mise' },
        @{ Name = 'MySQL Shell'; Id = 'Oracle.MySQLShell'; Command = 'mysqlsh' },
        @{ Name = 'Neovim'; Id = 'Neovim.Neovim'; Command = 'nvim' },
        @{ Name = 'pnpm'; Id = 'pnpm.pnpm'; Command = 'pnpm' },
        @{ Name = 'ripgrep'; Id = 'BurntSushi.ripgrep.MSVC'; Command = 'rg' },
        @{ Name = 'ShellCheck'; Id = 'koalaman.shellcheck'; Command = 'shellcheck' },
        @{ Name = 'shfmt'; Id = 'mvdan.shfmt'; Command = 'shfmt' },
        @{ Name = 'Starship'; Id = 'Starship.Starship'; Command = 'starship' },
        @{ Name = 'tldr official Rust client'; Id = 'tldr-pages.tlrc'; Command = 'tlrc'; Optional = $true },
        @{ Name = 'tmux-windows'; Id = 'arndawg.tmux-windows'; Command = 'tmux' },
        @{ Name = 'Yazi'; Id = 'sxyazi.yazi'; Command = 'yazi' },
        @{ Name = 'yq'; Id = 'MikeFarah.yq'; Command = 'yq' },
        @{ Name = 'zoxide'; Id = 'ajeetdsouza.zoxide'; Command = 'zoxide' },
        @{ Name = 'actionlint'; Id = 'rhysd.actionlint'; Command = 'actionlint' },
        @{ Name = 'Stripe CLI'; Id = 'Stripe.StripeCLI'; Command = 'stripe'; Optional = $true },
        @{ Name = 'MSYS2'; Id = 'MSYS2.MSYS2'; Command = 'bash' }
    )

    foreach ($pkg in $packages) {
        $commandName = if ($pkg.ContainsKey('Command')) { [string]$pkg.Command } else { '' }
        $requiresAdmin = ($pkg.ContainsKey('RequiresAdmin') -and [bool]$pkg.RequiresAdmin)
        $optional = ($pkg.ContainsKey('Optional') -and [bool]$pkg.Optional)

        try {
            Install-WingetPackage `
                -Id $pkg.Id `
                -Name $pkg.Name `
                -CommandName $commandName `
                -RequiresAdmin:$requiresAdmin `
                -Optional:$optional
        } catch {
            if ($optional) {
                Add-WarningRecord $pkg.Name $_.Exception.Message
            } else {
                Add-FailureRecord $pkg.Name $_.Exception.Message
            }
        }

        Refresh-ProcessPathFromRegistry
        Initialize-KnownPaths
    }
}

function Configure-NpmPrefix {
    $npmRoot = Join-Path $env:APPDATA 'npm'
    Ensure-Directory $npmRoot
    Add-UserPath $npmRoot

    $npm = Resolve-CommandPath 'npm.cmd'
    if (-not $npm) {
        $npm = Resolve-CommandPath 'npm'
    }

    if (-not $npm) {
        Add-WarningRecord 'npm' 'npm was not found; npm global tools were skipped.'
        return
    }

    Write-Step "Setting npm global prefix to $npmRoot"
    & $npm config set prefix $npmRoot
}

function Install-NpmTool {
    param(
        [Parameter(Mandatory = $true)][string]$Package,
        [Parameter(Mandatory = $true)][string]$CommandName,
        [switch]$Optional
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Step "$Package already callable as $CommandName" 'OK'
        return
    }

    $npm = Resolve-CommandPath 'npm.cmd'
    if (-not $npm) {
        $npm = Resolve-CommandPath 'npm'
    }

    if (-not $npm) {
        if ($Optional) {
            Add-WarningRecord $Package 'npm was not found; optional npm tool skipped.'
            return
        }

        throw "npm not found; cannot install $Package."
    }

    Write-Step "Installing/updating $Package with npm -g"
    & $npm install -g "$Package@latest"

    if ($LASTEXITCODE -ne 0) {
        if ($Optional) {
            Add-WarningRecord $Package "npm install failed with exit code $LASTEXITCODE."
            return
        }

        throw "npm install $Package failed with exit code $LASTEXITCODE."
    }

    Add-UserPath (Join-Path $env:APPDATA 'npm')
    Add-DirectoryForCommandIfFound $CommandName | Out-Null
}

function Install-PipTool {
    param(
        [Parameter(Mandatory = $true)][string]$Package,
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Step "$Package already callable as $CommandName" 'OK'
        return
    }

    $py = Resolve-CommandPath 'py'
    $python = Resolve-CommandPath 'python'

    if ($py) {
        Write-Step "Installing/updating $Package with py -3.12 -m pip --user"
        & $py -3.12 -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed with exit code $LASTEXITCODE." }

        & $py -3.12 -m pip install --user --upgrade $Package
        if ($LASTEXITCODE -ne 0) { throw "pip install $Package failed with exit code $LASTEXITCODE." }
    } elseif ($python) {
        Write-Step "Installing/updating $Package with python -m pip --user"
        & $python -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed with exit code $LASTEXITCODE." }

        & $python -m pip install --user --upgrade $Package
        if ($LASTEXITCODE -ne 0) { throw "pip install $Package failed with exit code $LASTEXITCODE." }
    } else {
        throw "Python not found; cannot install $Package."
    }

    Add-PythonUserScriptsPaths
    Add-DirectoryForCommandIfFound $CommandName | Out-Null
}

function Ensure-RustGnuToolchain {
    $rustup = Resolve-CommandPath 'rustup'
    if (-not $rustup) {
        throw 'rustup not found; cannot prepare GNU Rust toolchain.'
    }

    $bashPath = 'C:\msys64\usr\bin\bash.exe'

    if (-not (Test-Path -LiteralPath $bashPath)) {
        $winget = Resolve-WinGet
        if ($winget) {
            Write-Step 'MSYS2 not found. Installing MSYS2 via WinGet.'
            & $winget install --id MSYS2.MSYS2 -e --accept-package-agreements --accept-source-agreements
        }
    }

    if (Test-Path -LiteralPath $bashPath) {
        Add-UserPath 'C:\msys64\usr\bin'
        Add-UserPath 'C:\msys64\mingw64\bin'

        Write-Step 'Installing MinGW GNU linker dependencies for cargo tools via MSYS2 pacman'
        & $bashPath -lc 'pacman --noconfirm -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-pkgconf make'

        if ($LASTEXITCODE -ne 0) {
            throw "MSYS2 pacman failed to install GNU linker dependencies with exit code $LASTEXITCODE."
        }
    }

    Add-UserPath 'C:\msys64\mingw64\bin'

    $gcc = Resolve-CommandPath 'gcc'
    if (-not $gcc) {
        throw 'gcc was not found for the GNU Rust toolchain. Install MSYS2 and mingw-w64-x86_64-gcc, then rerun this script.'
    }

    Write-Step 'Ensuring Rust stable-x86_64-pc-windows-gnu toolchain'
    & $rustup toolchain install stable-x86_64-pc-windows-gnu

    if ($LASTEXITCODE -ne 0) {
        throw "rustup toolchain install stable-x86_64-pc-windows-gnu failed with exit code $LASTEXITCODE."
    }
}

function Install-CargoTool {
    param(
        [Parameter(Mandatory = $true)][string]$Crate,
        [Parameter(Mandatory = $true)][string]$CommandName,
        [switch]$NoLocked
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Step "$Crate already callable as $CommandName" 'OK'
        return
    }

    $cargo = Resolve-CommandPath 'cargo'
    if (-not $cargo) {
        throw "cargo not found; cannot install $Crate."
    }

    Ensure-RustGnuToolchain

    $args = @('install')
    if (-not $NoLocked) {
        $args += '--locked'
    }
    $args += $Crate

    Write-Step "Installing $Crate with cargo +stable-x86_64-pc-windows-gnu"

    $oldPath = $env:Path
    $oldLinker = $env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER
    $oldCc = $env:CC_x86_64_pc_windows_gnu

    try {
        $env:Path = ((Normalize-PathList (@('C:\msys64\mingw64\bin', (Join-Path $env:USERPROFILE '.cargo\bin')) + ($env:Path -split ';'))) -join ';')
        $env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = 'gcc'
        $env:CC_x86_64_pc_windows_gnu = 'gcc'

        & $cargo '+stable-x86_64-pc-windows-gnu' @args
    } finally {
        $env:Path = $oldPath
        $env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = $oldLinker
        $env:CC_x86_64_pc_windows_gnu = $oldCc
    }

    if ($LASTEXITCODE -ne 0) {
        throw "cargo install $Crate failed with exit code $LASTEXITCODE."
    }

    Add-UserPath (Join-Path $env:USERPROFILE '.cargo\bin')
    Add-DirectoryForCommandIfFound $CommandName | Out-Null
}

function Install-BatsCore {
    if (Get-Command bats -ErrorAction SilentlyContinue) {
        Write-Step 'bats already callable' 'OK'
        return
    }

    $bash = Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1
    $git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $bash -or -not $git) {
        throw 'Git Bash and git are required to install bats-core on Windows.'
    }

    Write-Step 'Installing bats-core from source via Git Bash'

    $bashScript = @"
set -euo pipefail
rm -rf "`$HOME/bats-core-install"
git clone --depth 1 https://github.com/bats-core/bats-core.git "`$HOME/bats-core-install"
cd "`$HOME/bats-core-install"
./install.sh "`$HOME"
"@

    $tmp = Join-Path $env:TEMP 'install-bats-core.sh'
    Set-TextFileUtf8NoBom -Path $tmp -Content $bashScript

    & $bash.Source -lc "bash '$($tmp -replace '\\','/')'"

    if ($LASTEXITCODE -ne 0) {
        throw "bats-core install failed with exit code $LASTEXITCODE."
    }

    $batsScript = Join-Path $env:USERPROFILE 'bin\bats'
    $wrapper = Join-Path $Script:UserBin 'bats.cmd'
    $bashExe = $bash.Source

    $wrapperContent = @"
@echo off
"$bashExe" "$batsScript" %*
"@

    Set-TextFileUtf8NoBom -Path $wrapper -Content $wrapperContent
    Add-UserPath $Script:UserBin

    Write-Step "Created bats wrapper: $wrapper" 'OK'
}

function Install-Msys2ZshPlugins {
    if ($SkipMsys2ZshPlugins) {
        Add-WarningRecord 'zsh plugins' 'Skipped by -SkipMsys2ZshPlugins.'
        return
    }

    $bashPath = 'C:\msys64\usr\bin\bash.exe'

    if (-not (Test-Path -LiteralPath $bashPath)) {
        Add-WarningRecord 'MSYS2' 'MSYS2 bash was not found; zsh plugins were not installed.'
        return
    }

    Add-UserPath 'C:\msys64\usr\bin'

    Write-Step 'Installing zsh, zsh-autosuggestions, and zsh-syntax-highlighting via MSYS2 pacman'
    & $bashPath -lc 'pacman --noconfirm -S --needed zsh zsh-autosuggestions zsh-syntax-highlighting'

    if ($LASTEXITCODE -ne 0) {
        Add-WarningRecord 'MSYS2 zsh plugins' "pacman returned exit code $LASTEXITCODE."
    } else {
        Write-Step 'MSYS2 zsh packages installed' 'OK'
    }
}

function New-CmdWrapper {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$TargetCommand
    )

    Ensure-Directory $Script:UserBin

    $wrapper = Join-Path $Script:UserBin "$Name.cmd"

    $content = @"
@echo off
"$TargetCommand" %*
"@

    Set-TextFileUtf8NoBom -Path $wrapper -Content $content
    Add-UserPath $Script:UserBin

    Write-Step "Created wrapper: $Name -> $TargetCommand" 'OK'
}

function Find-ToolExecutable {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
            return $cmd.Source
        }
    }

    $roots = @(
        $Script:UserBin,
        (Join-Path $env:USERPROFILE 'scoop\shims'),
        (Join-Path $env:USERPROFILE '.cargo\bin'),
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($root in $roots) {
        foreach ($name in $Names) {
            $candidates = @(
                $name,
                "$name.exe",
                "$name.cmd",
                "$name.bat"
            ) | Select-Object -Unique

            foreach ($candidate in $candidates) {
                $match = Get-ChildItem -LiteralPath $root -Filter $candidate -File -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if ($match) {
                    return $match.FullName
                }
            }
        }
    }

    return $null
}

function Ensure-TldrWrappers {
    Ensure-Directory $Script:UserBin
    Add-UserPath $Script:UserBin

    Remove-Item (Join-Path $Script:UserBin 'tlrc.cmd') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $Script:UserBin 'tldr.cmd') -Force -ErrorAction SilentlyContinue

    Add-DirectoryForCommandIfFound 'tlrc' | Out-Null
    Add-DirectoryForCommandIfFound 'tldr' | Out-Null

    $realExe = Find-ToolExecutable -Names @('tlrc', 'tldr')

    if (-not $realExe) {
        Add-WarningRecord 'tlrc' 'Neither tlrc nor tldr executable was found under PATH, WinGet, Scoop, npm, or Cargo locations.'
        return
    }

    $tlrcWrapper = Join-Path $Script:UserBin 'tlrc.cmd'
    $tldrWrapper = Join-Path $Script:UserBin 'tldr.cmd'

    $content = @"
@echo off
"$realExe" %*
"@

    Set-TextFileUtf8NoBom -Path $tlrcWrapper -Content $content
    Set-TextFileUtf8NoBom -Path $tldrWrapper -Content $content

    Write-Step "Created wrappers: tlrc/tldr -> $realExe" 'OK'
}

function Ensure-WrappersAndAliases {
    Ensure-TldrWrappers

    Add-DirectoryForCommandIfFound 'mysql' | Out-Null
    if (-not (Get-Command mysql -ErrorAction SilentlyContinue)) {
        Add-WarningRecord 'mysql-client' 'Standalone mysql.exe is optional and was not found. mysqlsh is the installed Windows MySQL client.'
    }

    Add-DirectoryForCommandIfFound 'code' | Out-Null
    Add-DirectoryForCommandIfFound 'opencode' | Out-Null
    Add-DirectoryForCommandIfFound 'ast-grep' | Out-Null
    Add-DirectoryForCommandIfFound 'sg' | Out-Null
}

function Set-ManagedBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$StartMarker,
        [Parameter(Mandatory = $true)][string]$EndMarker,
        [Parameter(Mandatory = $true)][string]$Block
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        Ensure-Directory $dir
    }

    $existing = ''

    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
        $backup = "$Path.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $Path -Destination $backup -Force
    }

    $pattern = [regex]::Escape($StartMarker) + '[\s\S]*?' + [regex]::Escape($EndMarker)
    $managed = "$StartMarker`r`n$Block`r`n$EndMarker"

    if ($existing -match $pattern) {
        $newContent = [regex]::Replace(
            $existing,
            $pattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $managed }
        )
    } else {
        $newContent = ($existing.TrimEnd() + "`r`n`r`n" + $managed + "`r`n").TrimStart()
    }

    Set-TextFileUtf8NoBom -Path $Path -Content $newContent
    Write-Step "Updated profile: $Path" 'OK'
}

function Configure-ShellProfiles {
    if ($SkipProfiles) {
        Add-WarningRecord 'shell profiles' 'Skipped by -SkipProfiles.'
        return
    }

    $start = '# >>> dev-cli-tools-windows managed block >>>'
    $end = '# <<< dev-cli-tools-windows managed block <<<'

    $powershellBlock = @'
# Keep common CLI install locations available in fresh PowerShell sessions.
$__devCliPaths = @(
  "$HOME\bin",
  "$HOME\scoop\shims",
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
  "C:\msys64\usr\bin",
  "C:\msys64\mingw64\bin"
) | Where-Object { $_ -and (Test-Path $_) }

foreach ($__p in $__devCliPaths) {
  if (($env:Path -split ';') -notcontains $__p) {
    $env:Path = "$__p;$env:Path"
  }
}

Remove-Variable __devCliPaths, __p -ErrorAction SilentlyContinue

if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (& starship init powershell | Out-String)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& zoxide init powershell | Out-String)
}

if (Get-Command atuin -ErrorAction SilentlyContinue) {
  Invoke-Expression (& atuin init powershell | Out-String)
}

if (($PSVersionTable.PSVersion -ge [Version]'7.2') -and (Get-Command direnv -ErrorAction SilentlyContinue)) {
  Invoke-Expression (& direnv hook pwsh | Out-String)
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
  Invoke-Expression (& mise activate pwsh | Out-String)
}
'@

    $profileTargets = [System.Collections.Generic.List[string]]::new()

    try { $profileTargets.Add($PROFILE.CurrentUserAllHosts) | Out-Null } catch { }
    try { $profileTargets.Add($PROFILE.CurrentUserCurrentHost) | Out-Null } catch { }

    $profileTargets = $profileTargets | Where-Object { $_ } | Select-Object -Unique

    foreach ($path in $profileTargets) {
        Set-ManagedBlock -Path $path -StartMarker $start -EndMarker $end -Block $powershellBlock
    }

    $bashBlock = @'
# Core Git Bash paths.
for p in "/usr/bin" "/bin" "/mingw64/bin" "/mingw64/libexec/git-core" "/cmd"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
done

# Common CLI install locations.
for p in "$HOME/bin" "$HOME/scoop/shims" "$HOME/.cargo/bin" "$HOME/.local/bin" "/c/Program Files/nodejs" "/c/Program Files/Docker/Docker/resources/bin" "/c/Program Files/Git/cmd" "/c/Program Files/Git/bin" "/c/Program Files/Git/usr/bin" "/c/msys64/usr/bin" "/c/msys64/mingw64/bin"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
done

# npm global tools.
if command -v cygpath >/dev/null 2>&1 && [ -n "${APPDATA:-}" ]; then
  npm_bin="$(cygpath -u "$APPDATA")/npm"
  [ -d "$npm_bin" ] && case ":$PATH:" in *":$npm_bin:"*) ;; *) export PATH="$npm_bin:$PATH" ;; esac
  unset npm_bin
else
  [ -d "$HOME/AppData/Roaming/npm" ] && export PATH="$HOME/AppData/Roaming/npm:$PATH"
fi

# Robust launchers for npm tools affected by Git Bash shim conversion.
if [ -f "/c/Program Files/nodejs/node.exe" ] && [ -f "$HOME/AppData/Roaming/npm/node_modules/opencode-ai/bin/opencode" ]; then
  opencode() {
    "/c/Program Files/nodejs/node.exe" "$HOME/AppData/Roaming/npm/node_modules/opencode-ai/bin/opencode" "$@"
  }
fi

if [ -x "$HOME/AppData/Roaming/npm/node_modules/@ast-grep/cli/ast-grep" ]; then
  ast-grep() {
    "$HOME/AppData/Roaming/npm/node_modules/@ast-grep/cli/ast-grep" "$@"
  }
fi

if [ -x "$HOME/AppData/Roaming/npm/node_modules/@ast-grep/cli/sg" ]; then
  sg() {
    "$HOME/AppData/Roaming/npm/node_modules/@ast-grep/cli/sg" "$@"
  }
fi

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
'@

    $zshBlock = @'
# Common CLI install locations.
for p in "$HOME/bin" "$HOME/scoop/shims" "$HOME/.cargo/bin" "$HOME/.local/bin" "/c/Program Files/nodejs" "/c/Program Files/Docker/Docker/resources/bin" "/c/Program Files/Git/cmd" "/c/Program Files/Git/bin" "/c/Program Files/Git/usr/bin" "/c/msys64/usr/bin" "/c/msys64/mingw64/bin"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
done

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
'@

    $bashrc = Join-Path $env:USERPROFILE '.bashrc'
    $bashProfile = Join-Path $env:USERPROFILE '.bash_profile'
    $zshrc = Join-Path $env:USERPROFILE '.zshrc'

    Set-ManagedBlock -Path $bashrc -StartMarker $start -EndMarker $end -Block $bashBlock
    Set-ManagedBlock -Path $zshrc -StartMarker $start -EndMarker $end -Block $zshBlock

    if (-not (Test-Path -LiteralPath $bashProfile)) {
        Set-TextFileUtf8NoBom -Path $bashProfile -Content 'test -f ~/.bashrc && . ~/.bashrc'
        Write-Step "Created profile: $bashProfile" 'OK'
    }
}

function Start-DockerIfRequested {
    if (-not $StartDockerDesktop) {
        return
    }

    $dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'

    if (Test-Path -LiteralPath $dockerDesktop) {
        Write-Step 'Starting Docker Desktop'
        Start-Process -FilePath $dockerDesktop | Out-Null
    } else {
        Add-WarningRecord 'Docker Desktop' 'Docker Desktop executable was not found; cannot start it.'
    }
}

function New-Candidate {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Command,
        [Parameter(Position = 1)][string[]]$Args = @()
    )

    [pscustomobject]@{
        Command = $Command
        Args = [string[]]$Args
    }
}

function Test-Candidate {
    param([Parameter(Mandatory = $true)]$Candidate)

    if (-not $Candidate -or -not $Candidate.Command) {
        return [pscustomobject]@{
            ok = $false
            used = ''
            version = ''
            error = 'Invalid candidate.'
        }
    }

    $resolved = Resolve-CommandPath $Candidate.Command
    $used = "$($Candidate.Command) $($Candidate.Args -join ' ')".Trim()

    if (-not $resolved) {
        return [pscustomobject]@{
            ok = $false
            used = $used
            version = ''
            error = "Command not found: $($Candidate.Command)"
        }
    }

    $result = Invoke-Cli -FilePath $resolved -Arguments $Candidate.Args -TimeoutSeconds $VerifyTimeoutSeconds
    $combined = ($result.stdout + $result.stderr)

    if ($result.exitCode -eq 0) {
        return [pscustomobject]@{
            ok = $true
            used = $used
            version = (Get-FirstOutputLine $combined)
            error = ''
        }
    }

    return [pscustomobject]@{
        ok = $false
        used = $used
        version = ''
        error = "$(Get-FirstOutputLine $combined) [exit=$($result.exitCode)]"
    }
}

function Verify-ToolCandidates {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [object[]]$Candidates = @(),
        [switch]$Optional,
        [scriptblock]$FileCheck
    )

    if ($FileCheck) {
        $ok = & $FileCheck

        if ($ok) {
            $Script:Verified.Add([ordered]@{
                name = $Name
                command = 'file-check'
                status = 'ok'
                version = 'present'
            }) | Out-Null

            Write-Step "$Name verified" 'OK'
        } else {
            $msg = 'Expected file/component was not found.'
            if ($Optional) {
                Add-WarningRecord $Name $msg
            } else {
                Add-FailureRecord $Name $msg
            }
        }

        return
    }

    $candidateList = @($Candidates | Where-Object { $_ })

    if ($candidateList.Count -eq 0) {
        $msg = 'No candidates were provided.'
        if ($Optional) {
            Add-WarningRecord $Name $msg
        } else {
            Add-FailureRecord $Name $msg
        }
        return
    }

    $errors = [System.Collections.Generic.List[string]]::new()

    foreach ($candidate in $candidateList) {
        $result = Test-Candidate -Candidate $candidate

        if ($result.ok) {
            $Script:Verified.Add([ordered]@{
                name = $Name
                command = $result.used
                status = 'ok'
                version = $result.version
            }) | Out-Null

            Write-Step "$Name verified: $($result.used)" 'OK'
            return
        }

        if ($result.error) {
            $errors.Add($result.error) | Out-Null
        }
    }

    $message = ($errors -join ' | ')

    if ($Optional) {
        Add-WarningRecord $Name $message
    } else {
        Add-FailureRecord $Name $message
    }
}

function Get-TlrcDiscoveredPath {
    return Find-ToolExecutable -Names @('tlrc', 'tldr')
}

function Verify-AllTools {
    Write-Step 'Verifying commands from current and repaired PATH'

    Refresh-ProcessPathFromRegistry
    Initialize-KnownPaths

    $nodeExe = Join-Path $env:ProgramFiles 'nodejs\node.exe'
    $npmCli = Join-Path $env:ProgramFiles 'nodejs\node_modules\npm\bin\npm-cli.js'
    $npmRoot = Join-Path $env:APPDATA 'npm\node_modules'
    $openCodeJs = Join-Path $npmRoot 'opencode-ai\bin\opencode'
    $astGrepCmd = Join-Path $env:APPDATA 'npm\ast-grep.cmd'
    $sgCmd = Join-Path $env:APPDATA 'npm\sg.cmd'
    $scoopShims = Join-Path $env:USERPROFILE 'scoop\shims'
    $cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
    $wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    $tlrcDiscovered = Get-TlrcDiscoveredPath

    $checks = @(
        @{ Name = 'WinGet'; Candidates = @((New-Candidate 'winget' @('--version')), (New-Candidate (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe') @('--version'))) },
        @{ Name = 'Git'; Candidates = @((New-Candidate 'git' @('--version'))) },
        @{ Name = 'Git Bash'; Candidates = @((New-Candidate 'bash' @('--version'))) },
        @{ Name = 'PowerShell 7'; Candidates = @((New-Candidate 'pwsh' @('--version'))) },
        @{ Name = 'Python'; Candidates = @((New-Candidate 'python' @('--version')), (New-Candidate 'py' @('-3.12', '--version')), (New-Candidate 'py' @('--version'))) },
        @{ Name = 'Python launcher'; Optional = $true; Candidates = @((New-Candidate 'py' @('--version'))) },
        @{ Name = 'Node.js'; Candidates = @((New-Candidate 'node' @('--version')), (New-Candidate $nodeExe @('--version'))) },
        @{ Name = 'npm'; Candidates = @((New-Candidate 'npm.cmd' @('--version')), (New-Candidate 'npm' @('--version')), (New-Candidate $nodeExe @($npmCli, '--version'))) },
        @{ Name = 'Rust cargo'; Candidates = @((New-Candidate 'cargo' @('--version')), (New-Candidate (Join-Path $cargoBin 'cargo.exe') @('--version'))) },
        @{ Name = 'Rustup'; Candidates = @((New-Candidate 'rustup' @('--version')), (New-Candidate (Join-Path $cargoBin 'rustup.exe') @('--version'))) },
        @{ Name = 'Atuin'; Candidates = @((New-Candidate 'atuin' @('--version'))) },
        @{ Name = 'bat'; Candidates = @((New-Candidate 'bat' @('--version'))) },
        @{ Name = 'btop'; Candidates = @((New-Candidate 'btop' @('--version')), (New-Candidate 'btop4win' @('--version'))) },
        @{ Name = 'Docker CLI'; Candidates = @((New-Candidate 'docker' @('--version')), (New-Candidate "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe" @('--version'))); Optional = (-not $Script:IsAdmin) },
        @{ Name = 'eza'; Candidates = @((New-Candidate 'eza' @('--version'))) },
        @{ Name = 'fd'; Candidates = @((New-Candidate 'fd' @('--version'))) },
        @{ Name = 'fzf'; Candidates = @((New-Candidate 'fzf' @('--version'))) },
        @{ Name = 'git-delta'; Candidates = @((New-Candidate 'delta' @('--version'))) },
        @{ Name = 'Difftastic'; Candidates = @((New-Candidate 'difft' @('--version'))) },
        @{ Name = 'direnv'; Candidates = @((New-Candidate 'direnv' @('version'))) },
        @{ Name = 'GitHub Copilot CLI'; Optional = $true; Candidates = @((New-Candidate 'copilot' @('--version')), (New-Candidate "$env:APPDATA\npm\copilot.cmd" @('--version'))) },
        @{ Name = 'just'; Candidates = @((New-Candidate 'just' @('--version')), (New-Candidate (Join-Path $scoopShims 'just.exe') @('--version')), (New-Candidate (Join-Path $wingetLinks 'just.exe') @('--version'))) },
        @{ Name = 'lazygit'; Candidates = @((New-Candidate 'lazygit' @('--version'))) },
        @{ Name = 'lnav'; Candidates = @((New-Candidate 'lnav' @('-V'))) },
        @{ Name = 'lychee'; Candidates = @((New-Candidate 'lychee' @('--version'))) },
        @{ Name = 'mise'; Candidates = @((New-Candidate 'mise' @('--version'))) },
        @{ Name = 'MySQL Shell'; Candidates = @((New-Candidate 'mysqlsh' @('--version'))) },
        @{ Name = 'mysql.exe classic client'; Optional = $true; Candidates = @((New-Candidate 'mysql' @('--version'))) },
        @{ Name = 'Neovim'; Candidates = @((New-Candidate 'nvim' @('--version'))) },
        @{ Name = 'pnpm'; Candidates = @((New-Candidate 'pnpm' @('--version')), (New-Candidate 'pnpm.cmd' @('--version'))) },
        @{ Name = 'ripgrep'; Candidates = @((New-Candidate 'rg' @('--version'))) },
        @{ Name = 'ripgrep-all'; Candidates = @((New-Candidate 'rga' @('--version')), (New-Candidate (Join-Path $cargoBin 'rga.exe') @('--version')), (New-Candidate (Join-Path $scoopShims 'rga.exe') @('--version')), (New-Candidate (Join-Path $wingetLinks 'rga.exe') @('--version'))) },
        @{ Name = 'Semgrep'; Candidates = @((New-Candidate 'semgrep' @('--version'))) },
        @{ Name = 'ShellCheck'; Candidates = @((New-Candidate 'shellcheck' @('--version'))) },
        @{ Name = 'shfmt'; Candidates = @((New-Candidate 'shfmt' @('--version'))) },
        @{ Name = 'Starship'; Candidates = @((New-Candidate 'starship' @('--version'))) },
        @{ Name = 'tlrc'; Candidates = @((New-Candidate 'tlrc' @('--version')), (New-Candidate 'tldr' @('--version')), (New-Candidate (Join-Path $Script:UserBin 'tlrc.cmd') @('--version')), (New-Candidate (Join-Path $Script:UserBin 'tldr.cmd') @('--version')), (New-Candidate (Join-Path $wingetLinks 'tlrc.exe') @('--version')), (New-Candidate (Join-Path $wingetLinks 'tldr.exe') @('--version')), (New-Candidate "$tlrcDiscovered" @('--version'))) },
        @{ Name = 'tldr wrapper'; Optional = $true; Candidates = @((New-Candidate 'tldr' @('--version')), (New-Candidate 'tlrc' @('--version')), (New-Candidate (Join-Path $Script:UserBin 'tldr.cmd') @('--version')), (New-Candidate (Join-Path $Script:UserBin 'tlrc.cmd') @('--version')), (New-Candidate "$tlrcDiscovered" @('--version'))) },
        @{ Name = 'tmux'; Candidates = @((New-Candidate 'tmux' @('-V'))) },
        @{ Name = 'watchexec'; Candidates = @((New-Candidate 'watchexec' @('--version')), (New-Candidate (Join-Path $cargoBin 'watchexec.exe') @('--version')), (New-Candidate (Join-Path $scoopShims 'watchexec.exe') @('--version')), (New-Candidate (Join-Path $wingetLinks 'watchexec.exe') @('--version'))) },
        @{ Name = 'Yazi'; Candidates = @((New-Candidate 'yazi' @('--version'))) },
        @{ Name = 'yq'; Candidates = @((New-Candidate 'yq' @('--version'))) },
        @{ Name = 'zoxide'; Candidates = @((New-Candidate 'zoxide' @('--version'))) },
        @{ Name = 'actionlint'; Candidates = @((New-Candidate 'actionlint' @('--version'))) },
        @{ Name = 'bats-core'; Candidates = @((New-Candidate 'bats' @('--version')), (New-Candidate (Join-Path $Script:UserBin 'bats.cmd') @('--version'))) },
        @{ Name = 'zsh'; Optional = $SkipMsys2ZshPlugins.IsPresent; Candidates = @((New-Candidate 'zsh' @('--version')), (New-Candidate 'C:\msys64\usr\bin\zsh.exe' @('--version'))) },
        @{ Name = 'OpenCode'; Optional = $true; Candidates = @((New-Candidate $nodeExe @($openCodeJs, '--version')), (New-Candidate 'opencode.cmd' @('--version')), (New-Candidate 'opencode' @('--version'))) },
        @{ Name = 'ast-grep'; Optional = $true; Candidates = @((New-Candidate 'ast-grep.cmd' @('--version')), (New-Candidate 'ast-grep' @('--version')), (New-Candidate $astGrepCmd @('--version'))) },
        @{ Name = 'sg'; Optional = $true; Candidates = @((New-Candidate 'sg.cmd' @('--version')), (New-Candidate 'sg' @('--version')), (New-Candidate $sgCmd @('--version'))) },
        @{ Name = 'VS Code CLI'; Optional = $true; Candidates = @((New-Candidate 'code' @('--version'))) },
        @{ Name = 'Stripe CLI'; Optional = $true; Candidates = @((New-Candidate 'stripe' @('--version'))) },
        @{ Name = 'zsh-autosuggestions plugin'; Optional = $true; FileCheck = { Test-Path 'C:\msys64\usr\share\zsh\plugins\zsh-autosuggestions\zsh-autosuggestions.zsh' } },
        @{ Name = 'zsh-syntax-highlighting plugin'; Optional = $true; FileCheck = { Test-Path 'C:\msys64\usr\share\zsh\plugins\zsh-syntax-highlighting\zsh-syntax-highlighting.zsh' } }
    )

    foreach ($check in $checks) {
        $optional = $false
        if ($check.ContainsKey('Optional')) {
            $optional = [bool]$check.Optional
        }

        $fileCheck = $null
        if ($check.ContainsKey('FileCheck')) {
            $fileCheck = $check.FileCheck
        }

        $candidates = @()
        if ($check.ContainsKey('Candidates') -and $null -ne $check.Candidates) {
            $candidates = @($check.Candidates)
        }

        Verify-ToolCandidates `
            -Name $check.Name `
            -Candidates $candidates `
            -Optional:$optional `
            -FileCheck $fileCheck
    }

    Add-WarningRecord 'colima' 'Not installed: Colima is not a native Windows container runtime. Use Docker Desktop on Windows, or install Colima inside WSL2 manually if required.'

    if ($FailOnUnsupported) {
        Add-FailureRecord 'colima' 'Unsupported native Windows tool requested and -FailOnUnsupported was set.'
    }
}

function Write-Report {
    $report = [ordered]@{
        generatedAt = (Get-Date).ToString('o')
        installRoot = $Script:InstallRoot
        reportPath = $Script:ReportPath
        markdownReportPath = $Script:MarkdownReportPath
        logPath = $Script:LogPath
        verified = $Script:Verified
        warnings = $Script:Warnings
        failures = $Script:Failures
    }

    $json = $report | ConvertTo-Json -Depth 10
    Set-TextFileUtf8NoBom -Path $Script:ReportPath -Content $json

    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add('# Windows Dev CLI Install Report') | Out-Null
    $md.Add('') | Out-Null
    $md.Add("- Generated: $($report.generatedAt)") | Out-Null
    $md.Add("- Verified: $($Script:Verified.Count)") | Out-Null
    $md.Add("- Warnings: $($Script:Warnings.Count)") | Out-Null
    $md.Add("- Failures: $($Script:Failures.Count)") | Out-Null
    $md.Add('') | Out-Null

    $md.Add('## Verified') | Out-Null
    $md.Add('') | Out-Null
    $md.Add('| Tool | Command | Version / First output |') | Out-Null
    $md.Add('|---|---|---|') | Out-Null

    foreach ($item in $Script:Verified) {
        $name = (($item.name | Out-String).Trim() -replace '\|', '\|')
        $command = (($item.command | Out-String).Trim() -replace '\|', '\|')
        $version = (($item.version | Out-String).Trim() -replace '\|', '\|')
        $md.Add("| $name | ``$command`` | $version |") | Out-Null
    }

    $md.Add('') | Out-Null
    $md.Add('## Warnings') | Out-Null
    $md.Add('') | Out-Null

    if ($Script:Warnings.Count -eq 0) {
        $md.Add('None.') | Out-Null
    } else {
        foreach ($item in $Script:Warnings) {
            $md.Add("- **$($item.name)**: $($item.message)") | Out-Null
        }
    }

    $md.Add('') | Out-Null
    $md.Add('## Failures') | Out-Null
    $md.Add('') | Out-Null

    if ($Script:Failures.Count -eq 0) {
        $md.Add('None.') | Out-Null
    } else {
        foreach ($item in $Script:Failures) {
            $md.Add("- **$($item.name)**: $($item.message)") | Out-Null
        }
    }

    Set-TextFileUtf8NoBom -Path $Script:MarkdownReportPath -Content ($md -join "`r`n")

    Write-Step "JSON report written: $Script:ReportPath" 'OK'
    Write-Step "Markdown report written: $Script:MarkdownReportPath" 'OK'
}

function Main {
    Ensure-Directory $Script:InstallRoot
    Ensure-Directory $Script:UserBin

    Set-TextFileUtf8NoBom -Path $Script:LogPath -Content "install-dev-tools-windows started $(Get-Date -Format o)`r`n"

    Test-IsWindows11OrLater

    $Script:IsAdmin = Test-IsAdministrator

    if (-not $Script:IsAdmin) {
        Add-WarningRecord 'elevation' 'Not running as Administrator. Most user-scope CLI packages should install, but Docker Desktop or machine-scope packages may require elevation.'
    }

    Refresh-ProcessPathFromRegistry
    Initialize-KnownPaths
    Test-WinGetAvailable

    if (-not $VerifyOnly) {
        Install-WingetPackages

        Refresh-ProcessPathFromRegistry
        Initialize-KnownPaths

        Configure-NpmPrefix
        try { Install-NpmTool -Package 'opencode-ai' -CommandName 'opencode' -Optional } catch { Add-WarningRecord 'OpenCode' $_.Exception.Message }
        try { Install-NpmTool -Package '@ast-grep/cli' -CommandName 'ast-grep' -Optional } catch { Add-WarningRecord 'ast-grep' $_.Exception.Message }

        try { Install-PipTool -Package 'semgrep' -CommandName 'semgrep' } catch { Add-FailureRecord 'Semgrep' $_.Exception.Message }
        try { Install-CargoTool -Crate 'ripgrep_all' -CommandName 'rga' } catch { Add-FailureRecord 'ripgrep-all' $_.Exception.Message }
        try { Install-CargoTool -Crate 'watchexec-cli' -CommandName 'watchexec' } catch { Add-FailureRecord 'watchexec' $_.Exception.Message }
        try { Install-BatsCore } catch { Add-FailureRecord 'bats-core' $_.Exception.Message }
        try { Install-Msys2ZshPlugins } catch { Add-FailureRecord 'MSYS2 zsh plugins' $_.Exception.Message }

        Ensure-WrappersAndAliases
        Configure-ShellProfiles
        Start-DockerIfRequested
    }

    if (-not $InstallOnly) {
        Refresh-ProcessPathFromRegistry
        Initialize-KnownPaths
        Ensure-WrappersAndAliases
        Verify-AllTools
    }

    Write-Report

    if ($Script:Failures.Count -gt 0) {
        Write-Step "Completed with $($Script:Failures.Count) failure(s). See $Script:MarkdownReportPath" 'Error'
        exit 1
    }

    Write-Step "Completed successfully with $($Script:Warnings.Count) warning(s). See $Script:MarkdownReportPath" 'OK'
    exit 0
}

Main
