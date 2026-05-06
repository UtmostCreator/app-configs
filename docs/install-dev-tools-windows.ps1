<#
.SYNOPSIS
  Windows 11+ developer CLI tool installer and verifier.

.DESCRIPTION
  Installs the Windows equivalents of a macOS Homebrew CLI stack, normalizes user PATH,
  configures PowerShell/Git Bash/Zsh startup files, creates command wrappers where needed,
  and verifies that tools are callable from a fresh CLI process.

.USAGE
  powershell -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1
  powershell -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -VerifyOnly
  powershell -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -InstallOnly
  powershell -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -SkipMsys2ZshPlugins
  powershell -ExecutionPolicy Bypass -File .\install-dev-tools-windows.ps1 -StartDockerDesktop

.NOTES
  - Designed for Windows 11 or later.
  - Uses WinGet where a reliable Windows package exists.
  - Uses cargo/pip/source install for tools not consistently available through WinGet.
  - colima is not installed because it is not a native Windows tool.
#>

[CmdletBinding()]
param(
    [switch]$VerifyOnly,
    [switch]$InstallOnly,
    [switch]$SkipProfiles,
    [switch]$SkipMsys2ZshPlugins,
    [switch]$StartDockerDesktop,
    [switch]$FailOnUnsupported
)

$ErrorActionPreference = 'Stop'

$Script:InstallRoot = Join-Path $env:USERPROFILE '.dev-cli-tools'
$Script:UserBin = Join-Path $env:USERPROFILE 'bin'
$Script:LogPath = Join-Path $Script:InstallRoot 'install.log'
$Script:ReportPath = Join-Path $Script:InstallRoot 'install-report.json'
$Script:Failures = New-Object System.Collections.Generic.List[object]
$Script:Warnings = New-Object System.Collections.Generic.List[object]
$Script:Verified = New-Object System.Collections.Generic.List[object]

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
    try { Add-Content -LiteralPath $Script:LogPath -Value "$(Get-Date -Format o) $line" -Encoding UTF8 } catch { }
}

function Add-WarningRecord {
    param([string]$Name, [string]$Message)
    $Script:Warnings.Add([ordered]@{ name = $Name; message = $Message }) | Out-Null
    Write-Step "${Name}: $Message" 'Warn'
}

function Add-FailureRecord {
    param([string]$Name, [string]$Message)
    $Script:Failures.Add([ordered]@{ name = $Name; message = $Message }) | Out-Null
    Write-Step "${Name}: $Message" 'Error'
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
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Normalize-PathList {
    param([string[]]$Items)
    $seen = @{}
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Items) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        $expanded = [Environment]::ExpandEnvironmentVariables($item.Trim().TrimEnd('\'))
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

function Add-UserPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path).Trim().TrimEnd('\')
    if (-not (Test-Path -LiteralPath $expanded)) { return }

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $items = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) { $items = $current -split ';' }
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

    $env:Path = ((Normalize-PathList (($env:Path -split ';') + @($expanded))) -join ';')
}

function Initialize-KnownPaths {
    Ensure-Directory $Script:InstallRoot
    Ensure-Directory $Script:UserBin

    $known = @(
        $Script:UserBin,
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages'),
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:USERPROFILE '.cargo\bin'),
        (Join-Path $env:USERPROFILE '.local\bin'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'),
        (Join-Path $env:ProgramFiles 'Git\cmd'),
        (Join-Path $env:ProgramFiles 'Git\bin'),
        (Join-Path $env:ProgramFiles 'Git\usr\bin'),
        'C:\msys64\usr\bin',
        'C:\msys64\mingw64\bin'
    )

    foreach ($path in $known) { Add-UserPath $path }
    Add-PythonUserScriptsPaths
}

function Add-PythonUserScriptsPaths {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($root in @($env:APPDATA, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        $pythonRoot = Join-Path $root 'Python'
        if (Test-Path -LiteralPath $pythonRoot) {
            Get-ChildItem -LiteralPath $pythonRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { $candidates.Add((Join-Path $_.FullName 'Scripts')) | Out-Null }
        }
    }
    foreach ($path in $candidates) { Add-UserPath $path }
}

function Add-DirectoryForCommandIfFound {
    param([Parameter(Mandatory = $true)][string]$Command)

    $found = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found -and $found.Source) {
        $dir = Split-Path -Parent $found.Source
        Add-UserPath $dir
        return $dir
    }

    $names = @("$Command.exe", "$Command.cmd", "$Command.bat", $Command)
    $roots = @(
        $Script:UserBin,
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages'),
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:USERPROFILE '.cargo\bin'),
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

function Test-WinGetAvailable {
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw 'WinGet was not found. Install or repair Microsoft App Installer first, then rerun this script.'
    }
    Write-Step "WinGet found: $($cmd.Source)" 'OK'
    & winget source update | Out-Host
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name
    )

    Write-Step "Installing/updating $Name [$Id] via WinGet"
    $baseArgs = @(
        'install', '--exact', '--id', $Id, '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements'
    )

    & winget @baseArgs --silent
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        Write-Step "$Name silent install did not complete cleanly; retrying without --silent" 'Warn'
        & winget @baseArgs
        $exit = $LASTEXITCODE
    }

    if ($exit -ne 0) {
        Add-FailureRecord $Name "WinGet install failed with exit code $exit."
    } else {
        Write-Step "$Name install command completed" 'OK'
    }
}

function Install-WingetPackages {
    $packages = @(
        @{ Name = 'Visual C++ Redistributable x64'; Id = 'Microsoft.VCRedist.2015+.x64' },
        @{ Name = 'Git for Windows'; Id = 'Git.Git' },
        @{ Name = 'PowerShell 7'; Id = 'Microsoft.PowerShell' },
        @{ Name = 'Python 3.12'; Id = 'Python.Python.3.12' },
        @{ Name = 'Node.js LTS'; Id = 'OpenJS.NodeJS.LTS' },
        @{ Name = 'Rustup'; Id = 'Rustlang.Rustup' },
        @{ Name = 'Atuin'; Id = 'Atuinsh.Atuin' },
        @{ Name = 'bat'; Id = 'sharkdp.bat' },
        @{ Name = 'btop4win'; Id = 'aristocratos.btop4win' },
        @{ Name = 'Docker Desktop'; Id = 'Docker.DockerDesktop' },
        @{ Name = 'eza'; Id = 'eza-community.eza' },
        @{ Name = 'fd'; Id = 'sharkdp.fd' },
        @{ Name = 'fzf'; Id = 'junegunn.fzf' },
        @{ Name = 'delta'; Id = 'dandavison.delta' },
        @{ Name = 'Difftastic'; Id = 'Wilfred.difftastic' },
        @{ Name = 'direnv'; Id = 'direnv.direnv' },
        @{ Name = 'GitHub Copilot CLI'; Id = 'GitHub.Copilot' },
        @{ Name = 'just'; Id = 'Casey.Just' },
        @{ Name = 'lazygit'; Id = 'JesseDuffield.lazygit' },
        @{ Name = 'lnav'; Id = 'tstack.lnav' },
        @{ Name = 'lychee'; Id = 'lycheeverse.lychee' },
        @{ Name = 'mise'; Id = 'jdx.mise' },
        @{ Name = 'MySQL Shell'; Id = 'Oracle.MySQLShell' },
        @{ Name = 'Neovim'; Id = 'Neovim.Neovim' },
        @{ Name = 'pnpm'; Id = 'pnpm.pnpm' },
        @{ Name = 'ripgrep'; Id = 'BurntSushi.ripgrep.MSVC' },
        @{ Name = 'ShellCheck'; Id = 'koalaman.shellcheck' },
        @{ Name = 'shfmt'; Id = 'mvdan.shfmt' },
        @{ Name = 'Starship'; Id = 'Starship.Starship' },
        @{ Name = 'tldr official Rust client'; Id = 'tldr-pages.tlrc' },
        @{ Name = 'tmux-windows'; Id = 'arndawg.tmux-windows' },
        @{ Name = 'Yazi'; Id = 'sxyazi.yazi' },
        @{ Name = 'yq'; Id = 'MikeFarah.yq' },
        @{ Name = 'zoxide'; Id = 'ajeetdsouza.zoxide' },
        @{ Name = 'actionlint'; Id = 'rhysd.actionlint' }
    )

    if (-not $SkipMsys2ZshPlugins) {
        $packages += @{ Name = 'MSYS2'; Id = 'MSYS2.MSYS2' }
    }

    foreach ($pkg in $packages) {
        try { Install-WingetPackage -Id $pkg.Id -Name $pkg.Name }
        catch { Add-FailureRecord $pkg.Name $_.Exception.Message }
        Refresh-ProcessPathFromRegistry
        Initialize-KnownPaths
    }
}

function ConvertTo-CommandLineArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Argument)
    if ($Argument -notmatch '[\s"]') { return $Argument }
    $escaped = $Argument -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Invoke-Cli {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $PWD.Path
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = (($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [ordered]@{ exitCode = $process.ExitCode; stdout = $stdout; stderr = $stderr }
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

    $python = Get-Command py -ErrorAction SilentlyContinue
    if ($python) {
        Write-Step "Installing $Package with py -3.12 -m pip --user"
        & py -3.12 -m pip install --upgrade pip
        & py -3.12 -m pip install --user --upgrade $Package
    } else {
        $pythonExe = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonExe) { throw "Python not found; cannot install $Package." }
        Write-Step "Installing $Package with python -m pip --user"
        & python -m pip install --upgrade pip
        & python -m pip install --user --upgrade $Package
    }

    Add-PythonUserScriptsPaths
    Add-DirectoryForCommandIfFound $CommandName | Out-Null
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

    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
    if (-not $cargo) { throw "cargo not found; cannot install $Crate." }

    Write-Step "Installing $Crate with cargo"
    $args = @('install')
    if (-not $NoLocked) { $args += '--locked' }
    $args += $Crate
    & cargo @args
    if ($LASTEXITCODE -ne 0) { throw "cargo install $Crate failed with exit code $LASTEXITCODE." }
    Add-UserPath (Join-Path $env:USERPROFILE '.cargo\bin')
    Add-DirectoryForCommandIfFound $CommandName | Out-Null
}

function Install-BatsCore {
    if (Get-Command bats -ErrorAction SilentlyContinue) {
        Write-Step 'bats already callable' 'OK'
        return
    }

    $bash = Get-Command bash -ErrorAction SilentlyContinue
    $git = Get-Command git -ErrorAction SilentlyContinue
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
    Set-Content -LiteralPath $tmp -Value $bashScript -Encoding UTF8
    & $bash.Source -lc "bash '$($tmp -replace '\\','/')'"
    if ($LASTEXITCODE -ne 0) { throw "bats-core install failed with exit code $LASTEXITCODE." }

    $batsScript = Join-Path $env:USERPROFILE 'bin\bats'
    $wrapper = Join-Path $Script:UserBin 'bats.cmd'
    $bashExe = $bash.Source
    $wrapperContent = @"
@echo off
"$bashExe" "%USERPROFILE%\bin\bats" %*
"@
    Set-Content -LiteralPath $wrapper -Value $wrapperContent -Encoding ASCII
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
        Add-WarningRecord 'MSYS2' 'MSYS2 bash was not found after installation; zsh plugins were not installed.'
        return
    }

    Add-UserPath 'C:\msys64\usr\bin'
    Write-Step 'Installing zsh, zsh-autosuggestions, and zsh-syntax-highlighting via MSYS2 pacman'
    & $bashPath -lc 'pacman --noconfirm -S --needed zsh zsh-autosuggestions zsh-syntax-highlighting'
    if ($LASTEXITCODE -ne 0) {
        Add-WarningRecord 'MSYS2 zsh plugins' "pacman returned exit code $LASTEXITCODE. You may need to open MSYS2 once and rerun this script."
    } else {
        Write-Step 'MSYS2 zsh packages installed' 'OK'
    }
}

function New-CmdWrapper {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$TargetCommand
    )

    $wrapper = Join-Path $Script:UserBin "$Name.cmd"
    $content = @"
@echo off
$TargetCommand %*
"@
    Set-Content -LiteralPath $wrapper -Value $content -Encoding ASCII
    Add-UserPath $Script:UserBin
    Write-Step "Created wrapper: $Name -> $TargetCommand" 'OK'
}

function Ensure-WrappersAndAliases {
    if (Get-Command tlrc -ErrorAction SilentlyContinue) {
        New-CmdWrapper -Name 'tldr' -TargetCommand 'tlrc'
    }

    # If a classic mysql.exe exists, add its directory. If not, keep mysqlsh as the installed Windows client.
    $mysqlDir = Add-DirectoryForCommandIfFound 'mysql'
    if (-not $mysqlDir) {
        Add-WarningRecord 'mysql-client' 'Standalone mysql.exe is not provided by a clean WinGet client-only package. Installed and verified mysqlsh instead. If you later install MySQL Server/Client, this script will add mysql.exe to PATH on rerun.'
    }
}

function Set-ManagedBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$StartMarker,
        [Parameter(Mandatory = $true)][string]$EndMarker,
        [Parameter(Mandatory = $true)][string]$Block
    )

    $dir = Split-Path -Parent $Path
    if ($dir) { Ensure-Directory $dir }

    $existing = ''
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
        $backup = "$Path.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $Path -Destination $backup -Force
    }

    $pattern = [regex]::Escape($StartMarker) + '[\s\S]*?' + [regex]::Escape($EndMarker)
    $managed = "$StartMarker`r`n$Block`r`n$EndMarker"
    if ($existing -match $pattern) {
        $newContent = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $managed })
    } else {
        $newContent = ($existing.TrimEnd() + "`r`n`r`n" + $managed + "`r`n").TrimStart()
    }

    Set-Content -LiteralPath $Path -Value $newContent -Encoding UTF8
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
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
  "$env:APPDATA\npm",
  "$HOME\.cargo\bin",
  "$HOME\.local\bin",
  "$env:ProgramFiles\Docker\Docker\resources\bin",
  "$env:ProgramFiles\Git\cmd",
  "$env:ProgramFiles\Git\bin",
  "$env:ProgramFiles\Git\usr\bin",
  "C:\msys64\usr\bin",
  "C:\msys64\mingw64\bin"
) | Where-Object { $_ -and (Test-Path $_) }
foreach ($__p in $__devCliPaths) {
  if (($env:Path -split ';') -notcontains $__p) { $env:Path = "$env:Path;$__p" }
}
Remove-Variable __devCliPaths, __p -ErrorAction SilentlyContinue

if (Get-Command starship -ErrorAction SilentlyContinue) { Invoke-Expression (&starship init powershell) }
if (Get-Command zoxide -ErrorAction SilentlyContinue) { Invoke-Expression (&zoxide init powershell) }
if (Get-Command atuin -ErrorAction SilentlyContinue) { atuin init powershell | Out-String | Invoke-Expression }
if (Get-Command direnv -ErrorAction SilentlyContinue) { direnv hook pwsh | Out-String | Invoke-Expression }
if (Get-Command mise -ErrorAction SilentlyContinue) { mise activate pwsh | Out-String | Invoke-Expression }
'@

    $profileTargets = New-Object System.Collections.Generic.List[string]
    try { $profileTargets.Add($PROFILE.CurrentUserAllHosts) | Out-Null } catch { }
    try { $profileTargets.Add($PROFILE.CurrentUserCurrentHost) | Out-Null } catch { }
    $profileTargets = $profileTargets | Where-Object { $_ } | Select-Object -Unique
    foreach ($path in $profileTargets) {
        Set-ManagedBlock -Path $path -StartMarker $start -EndMarker $end -Block $powershellBlock
    }

    $bashBlock = @'
# Common CLI install locations.
for p in "$HOME/bin" "$APPDATA/npm" "$HOME/.cargo/bin" "$HOME/.local/bin" "/c/Program Files/Docker/Docker/resources/bin" "/c/Program Files/Git/cmd" "/c/Program Files/Git/bin" "/c/Program Files/Git/usr/bin" "/c/msys64/usr/bin" "/c/msys64/mingw64/bin"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$PATH:$p" ;; esac
done
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
'@

    $zshBlock = @'
# Common CLI install locations.
for p in "$HOME/bin" "$APPDATA/npm" "$HOME/.cargo/bin" "$HOME/.local/bin" "/c/Program Files/Docker/Docker/resources/bin" "/c/Program Files/Git/cmd" "/c/Program Files/Git/bin" "/c/Program Files/Git/usr/bin" "/c/msys64/usr/bin" "/c/msys64/mingw64/bin"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$PATH:$p" ;; esac
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
        Set-Content -LiteralPath $bashProfile -Value 'test -f ~/.bashrc && . ~/.bashrc' -Encoding UTF8
        Write-Step "Created profile: $bashProfile" 'OK'
    }
}

function Start-DockerIfRequested {
    if (-not $StartDockerDesktop) { return }
    $dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (Test-Path -LiteralPath $dockerDesktop) {
        Write-Step 'Starting Docker Desktop'
        Start-Process -FilePath $dockerDesktop | Out-Null
    } else {
        Add-WarningRecord 'Docker Desktop' 'Docker Desktop executable was not found; cannot start it.'
    }
}

function Test-CommandFromFreshCmd {
    param([Parameter(Mandatory = $true)][string]$Command)
    $result = Invoke-Cli -FilePath $env:ComSpec -Arguments @('/d','/c',"where $Command")
    return $result.exitCode -eq 0
}

function Verify-Tool {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Args = @('--version'),
        [switch]$Optional,
        [scriptblock]$FileCheck
    )

    if ($FileCheck) {
        $ok = & $FileCheck
        if ($ok) {
            $Script:Verified.Add([ordered]@{ name = $Name; command = $Command; status = 'ok'; mode = 'file-check' }) | Out-Null
            Write-Step "$Name verified" 'OK'
        } else {
            $msg = 'Expected file/component was not found.'
            if ($Optional) { Add-WarningRecord $Name $msg } else { Add-FailureRecord $Name $msg }
        }
        return
    }

    Add-DirectoryForCommandIfFound $Command | Out-Null
    Refresh-ProcessPathFromRegistry
    Initialize-KnownPaths

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) {
        $freshWhere = Test-CommandFromFreshCmd $Command
        if (-not $freshWhere) {
            $msg = "Command '$Command' was not found in PATH."
            if ($Optional) { Add-WarningRecord $Name $msg } else { Add-FailureRecord $Name $msg }
            return
        }
    }

    try {
        $execPath = $Command
        if ($cmd -and $cmd.Source) { $execPath = $cmd.Source }
        $result = Invoke-Cli -FilePath $execPath -Arguments $Args
        if ($result.exitCode -eq 0) {
            $versionLine = (($result.stdout + $result.stderr) -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
            $Script:Verified.Add([ordered]@{ name = $Name; command = $Command; status = 'ok'; version = $versionLine }) | Out-Null
            Write-Step "$Name verified: $Command $($Args -join ' ')" 'OK'
        } else {
            $msg = "'$Command $($Args -join ' ')' exited with code $($result.exitCode). $($result.stderr.Trim())"
            if ($Optional) { Add-WarningRecord $Name $msg } else { Add-FailureRecord $Name $msg }
        }
    } catch {
        $msg = $_.Exception.Message
        if ($Optional) { Add-WarningRecord $Name $msg } else { Add-FailureRecord $Name $msg }
    }
}

function Verify-AllTools {
    Write-Step 'Verifying commands from current and fresh CLI PATH'

    $checks = @(
        @{ Name = 'WinGet'; Command = 'winget'; Args = @('--version') },
        @{ Name = 'Git'; Command = 'git'; Args = @('--version') },
        @{ Name = 'Git Bash'; Command = 'bash'; Args = @('--version') },
        @{ Name = 'PowerShell'; Command = 'pwsh'; Args = @('--version'); Optional = $true },
        @{ Name = 'Python'; Command = 'python'; Args = @('--version') },
        @{ Name = 'Python launcher'; Command = 'py'; Args = @('--version'); Optional = $true },
        @{ Name = 'Node.js'; Command = 'node'; Args = @('--version') },
        @{ Name = 'npm'; Command = 'npm'; Args = @('--version') },
        @{ Name = 'Rust cargo'; Command = 'cargo'; Args = @('--version') },
        @{ Name = 'Atuin'; Command = 'atuin'; Args = @('--version') },
        @{ Name = 'bat'; Command = 'bat'; Args = @('--version') },
        @{ Name = 'btop'; Command = 'btop'; Args = @('--version') },
        @{ Name = 'Docker CLI'; Command = 'docker'; Args = @('--version') },
        @{ Name = 'eza'; Command = 'eza'; Args = @('--version') },
        @{ Name = 'fd'; Command = 'fd'; Args = @('--version') },
        @{ Name = 'fzf'; Command = 'fzf'; Args = @('--version') },
        @{ Name = 'git-delta'; Command = 'delta'; Args = @('--version') },
        @{ Name = 'Difftastic'; Command = 'difft'; Args = @('--version') },
        @{ Name = 'direnv'; Command = 'direnv'; Args = @('version') },
        @{ Name = 'GitHub Copilot CLI'; Command = 'copilot'; Args = @('--version') },
        @{ Name = 'just'; Command = 'just'; Args = @('--version') },
        @{ Name = 'lazygit'; Command = 'lazygit'; Args = @('--version') },
        @{ Name = 'lnav'; Command = 'lnav'; Args = @('-V') },
        @{ Name = 'lychee'; Command = 'lychee'; Args = @('--version') },
        @{ Name = 'mise'; Command = 'mise'; Args = @('--version') },
        @{ Name = 'MySQL Shell'; Command = 'mysqlsh'; Args = @('--version') },
        @{ Name = 'mysql.exe classic client'; Command = 'mysql'; Args = @('--version'); Optional = $true },
        @{ Name = 'Neovim'; Command = 'nvim'; Args = @('--version') },
        @{ Name = 'pnpm'; Command = 'pnpm'; Args = @('--version') },
        @{ Name = 'ripgrep'; Command = 'rg'; Args = @('--version') },
        @{ Name = 'ripgrep-all'; Command = 'rga'; Args = @('--version') },
        @{ Name = 'Semgrep'; Command = 'semgrep'; Args = @('--version') },
        @{ Name = 'ShellCheck'; Command = 'shellcheck'; Args = @('--version') },
        @{ Name = 'shfmt'; Command = 'shfmt'; Args = @('--version') },
        @{ Name = 'Starship'; Command = 'starship'; Args = @('--version') },
        @{ Name = 'tldr client'; Command = 'tlrc'; Args = @('--version') },
        @{ Name = 'tldr wrapper'; Command = 'tldr'; Args = @('--version') },
        @{ Name = 'tmux'; Command = 'tmux'; Args = @('-V') },
        @{ Name = 'watchexec'; Command = 'watchexec'; Args = @('--version') },
        @{ Name = 'Yazi'; Command = 'yazi'; Args = @('--version') },
        @{ Name = 'yq'; Command = 'yq'; Args = @('--version') },
        @{ Name = 'zoxide'; Command = 'zoxide'; Args = @('--version') },
        @{ Name = 'actionlint'; Command = 'actionlint'; Args = @('--version') },
        @{ Name = 'bats-core'; Command = 'bats'; Args = @('--version') },
        @{ Name = 'zsh'; Command = 'zsh'; Args = @('--version'); Optional = $SkipMsys2ZshPlugins.IsPresent }
    )

    foreach ($check in $checks) {
        $optional = $false
        if ($check.ContainsKey('Optional')) { $optional = [bool]$check.Optional }
        Verify-Tool -Name $check.Name -Command $check.Command -Args $check.Args -Optional:$optional
    }

    if (-not $SkipMsys2ZshPlugins) {
        Verify-Tool -Name 'zsh-autosuggestions plugin' -Command 'zsh-autosuggestions' -FileCheck {
            Test-Path 'C:\msys64\usr\share\zsh\plugins\zsh-autosuggestions\zsh-autosuggestions.zsh'
        }
        Verify-Tool -Name 'zsh-syntax-highlighting plugin' -Command 'zsh-syntax-highlighting' -FileCheck {
            Test-Path 'C:\msys64\usr\share\zsh\plugins\zsh-syntax-highlighting\zsh-syntax-highlighting.zsh'
        }
    }

    Add-WarningRecord 'colima' 'Not installed: Colima is not a native Windows container runtime. Use Docker Desktop on Windows, or install Colima inside WSL2 manually if you specifically want the colima command.'
    if ($FailOnUnsupported) {
        Add-FailureRecord 'colima' 'Unsupported native Windows tool requested and -FailOnUnsupported was set.'
    }
}

function Write-Report {
    $report = [ordered]@{
        generatedAt = (Get-Date).ToString('o')
        installRoot = $Script:InstallRoot
        reportPath = $Script:ReportPath
        logPath = $Script:LogPath
        verified = $Script:Verified
        warnings = $Script:Warnings
        failures = $Script:Failures
    }
    $json = $report | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $Script:ReportPath -Value $json -Encoding UTF8
    Write-Step "Report written: $Script:ReportPath" 'OK'
}

function Main {
    Ensure-Directory $Script:InstallRoot
    Ensure-Directory $Script:UserBin
    Set-Content -LiteralPath $Script:LogPath -Value "install-dev-tools-windows started $(Get-Date -Format o)" -Encoding UTF8

    Test-IsWindows11OrLater
    if (-not (Test-IsAdministrator)) {
        Add-WarningRecord 'elevation' 'Not running as Administrator. Most user-scope CLI packages should install, but Docker Desktop or some machine-scope installers may request elevation or fail.'
    }

    Test-WinGetAvailable
    Refresh-ProcessPathFromRegistry
    Initialize-KnownPaths

    if (-not $VerifyOnly) {
        Install-WingetPackages
        Refresh-ProcessPathFromRegistry
        Initialize-KnownPaths

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
        Verify-AllTools
    }

    Write-Report

    if ($Script:Failures.Count -gt 0) {
        Write-Step "Completed with $($Script:Failures.Count) failure(s). See $Script:ReportPath" 'Error'
        exit 1
    }

    Write-Step "Completed successfully with $($Script:Warnings.Count) warning(s). See $Script:ReportPath" 'OK'
}

Main
