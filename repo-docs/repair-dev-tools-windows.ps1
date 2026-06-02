[CmdletBinding()]
param(
    [switch]$InstallDocker,
    [switch]$InstallStripe,
    [switch]$InstallCopilot,
    [switch]$InstallZshStack
)

$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false

function Add-PathNow {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $expanded)) { return }

    if (($env:Path -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $expanded) {
        $env:Path = "$expanded;$env:Path"
    }
}

function Add-UserPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $expanded)) { return }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $items = @($userPath -split ';' | Where-Object { $_ })

    if (($items | ForEach-Object { $_.TrimEnd('\') }) -notcontains $expanded) {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$expanded", 'User')
    }

    Add-PathNow $expanded
}

function Run-Step {
    param(
        [string]$Name,
        [scriptblock]$Script
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan

    & $Script

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] $Name exited with code $LASTEXITCODE" -ForegroundColor Yellow
    }
}

# -------------------------------------------------------------------
# PATH bootstrap
# -------------------------------------------------------------------

$paths = @(
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
    "$env:ProgramFiles\Git\cmd",
    "$env:ProgramFiles\Git\bin",
    "$env:ProgramFiles\Git\usr\bin",
    "$env:ProgramFiles\Neovim\bin",
    'C:\msys64\usr\bin',
    'C:\msys64\mingw64\bin'
)

foreach ($p in $paths) {
    Add-UserPath $p
}

# -------------------------------------------------------------------
# Clean broken tlrc wrapper
# -------------------------------------------------------------------

Run-Step 'Remove broken tlrc wrapper if present' {
    Remove-Item "$HOME\bin\tlrc.cmd" -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------------
# Recreate tlrc wrapper safely
# -------------------------------------------------------------------

Run-Step 'Create tlrc wrapper from existing tldr/tlrc command' {
    New-Item -ItemType Directory -Force -Path "$HOME\bin" | Out-Null

    $tldrCmd = Get-Command tldr -ErrorAction SilentlyContinue | Select-Object -First 1
    $tlrcCmd = Get-Command tlrc -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($tlrcCmd) {
        Write-Host "tlrc already exists: $($tlrcCmd.Source)" -ForegroundColor Green
    } elseif ($tldrCmd -and $tldrCmd.Source) {
        $target = $tldrCmd.Source

@"
@echo off
"$target" %*
"@ | Set-Content "$HOME\bin\tlrc.cmd" -Encoding ASCII

        Add-UserPath "$HOME\bin"
        Write-Host "Created $HOME\bin\tlrc.cmd -> $target" -ForegroundColor Green
    } else {
        Write-Host "tldr/tlrc not found. Installing tlrc through WinGet..." -ForegroundColor Yellow
        winget install --id tldr-pages.tlrc -e --accept-package-agreements --accept-source-agreements
    }
}

# -------------------------------------------------------------------
# MSYS2 GCC for Rust GNU toolchain
# -------------------------------------------------------------------

Run-Step 'Install MSYS2 MinGW GCC dependencies' {
    if (Test-Path 'C:\msys64\usr\bin\bash.exe') {
        & 'C:\msys64\usr\bin\bash.exe' -lc 'pacman --noconfirm -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-pkgconf make'
    } else {
        Write-Host "MSYS2 not found. Installing MSYS2 via WinGet..." -ForegroundColor Yellow
        winget install --id MSYS2.MSYS2 -e --accept-package-agreements --accept-source-agreements
        Write-Host "After MSYS2 install finishes, rerun this script." -ForegroundColor Yellow
    }
}

Add-UserPath 'C:\msys64\mingw64\bin'

# -------------------------------------------------------------------
# Rust GNU toolchain
# -------------------------------------------------------------------

Run-Step 'Install Rust GNU toolchain' {
    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
    $rustup = Get-Command rustup -ErrorAction SilentlyContinue

    if (-not $rustup) {
        throw "rustup not found. Install Rustup first."
    }

    rustup toolchain install stable-x86_64-pc-windows-gnu
}

# -------------------------------------------------------------------
# Install cargo tools through GNU target
# -------------------------------------------------------------------

Run-Step 'Install ripgrep-all with GNU Rust toolchain' {
    $env:Path = "C:\msys64\mingw64\bin;$HOME\.cargo\bin;$env:Path"
    $env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = 'gcc'
    $env:CC_x86_64_pc_windows_gnu = 'gcc'

    & "$HOME\.cargo\bin\cargo.exe" '+stable-x86_64-pc-windows-gnu' install ripgrep_all --locked
}

Run-Step 'Install watchexec-cli with GNU Rust toolchain' {
    $env:Path = "C:\msys64\mingw64\bin;$HOME\.cargo\bin;$env:Path"
    $env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = 'gcc'
    $env:CC_x86_64_pc_windows_gnu = 'gcc'

    & "$HOME\.cargo\bin\cargo.exe" '+stable-x86_64-pc-windows-gnu' install watchexec-cli --locked
}

# -------------------------------------------------------------------
# Optional installs
# -------------------------------------------------------------------

if ($InstallDocker) {
    Run-Step 'Install Docker Desktop' {
        winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
    }
}

if ($InstallStripe) {
    Run-Step 'Install Stripe CLI' {
        winget install --id Stripe.StripeCli -e --accept-package-agreements --accept-source-agreements
    }
}

if ($InstallCopilot) {
    Run-Step 'Install GitHub Copilot CLI' {
        winget install --id GitHub.Copilot -e --accept-package-agreements --accept-source-agreements
    }
}

if ($InstallZshStack) {
    Run-Step 'Install zsh and plugins through MSYS2' {
        & 'C:\msys64\usr\bin\bash.exe' -lc 'pacman --noconfirm -S --needed zsh zsh-autosuggestions zsh-syntax-highlighting'
    }
}

# -------------------------------------------------------------------
# Verify repaired commands
# -------------------------------------------------------------------

Write-Host ""
Write-Host "==> Verification" -ForegroundColor Cyan

$env:Path = "$HOME\bin;$HOME\.cargo\bin;C:\msys64\mingw64\bin;$env:Path"

$checks = @(
    @('cargo', '--version'),
    @('gcc', '--version'),
    @('rga', '--version'),
    @('watchexec', '--version'),
    @('tlrc', '--version'),
    @('tldr', '--version')
)

foreach ($check in $checks) {
    $cmd = $check[0]
    $arg = $check[1]

    Write-Host ""
    Write-Host "> $cmd $arg" -ForegroundColor DarkCyan

    try {
        & $cmd $arg
    } catch {
        Write-Host "[FAIL] $cmd not available: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Repair script completed. Close and reopen Windows Terminal, then rerun verifier." -ForegroundColor Green