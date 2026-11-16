# WinUtil (optional reference, manual)

Owner request 2026-11-16: "add separate link for windows to allow tools selection and installation or reference his repo".

[WinUtil](https://github.com/ChrisTitusTech/winutil) (ChrisTitusTech/winutil) is a third-party PowerShell tool with a GUI for installing programs. It is not part of this repo, not run by any script here, and is use-at-your-own-risk. Windows installs stay manual (ADR-0011) or follow the tool-selection ADRs.

## Before running
- Create a restore point (ADR-0007) and take an ADR-0020 snapshot (`-WindowsSnapshot <label>`, once built).

## What to use
- Use the Install tab only.
- Do not run Tweaks, Updates or presets: they change the same settings as ADR-0020 and ADR-0035 and make a later `-WindowsSettings` apply refuse on drift.
- MicroWin is out of scope.

## Pinned run instead of `irm | iex`
Run in an elevated PowerShell. This downloads one release file, checks its digest, then runs it from disk:

```powershell
$tag = '26.11.13'; $sha = 'e9d05a59d564b4fbb61fcfa1a594504a0f81e8d27c787119e72a99b57ddbe66d'
$f = Join-Path $env:TEMP 'winutil.ps1'
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/ChrisTitusTech/winutil/releases/download/$tag/winutil.ps1" -OutFile $f
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash -ne $sha) { throw 'winutil.ps1 digest mismatch' }
powershell -NoProfile -ExecutionPolicy Bypass -File $f
```

- The digest proves the bytes match the pinned release; it does not prove the script is safe, and it does not cover what WinUtil downloads at run time.
- Read the script before running it.
- Refresh the pin: take the new tag and the SHA-256 `digest` of the `winutil.ps1` asset from the GitHub API (`https://api.github.com/repos/ChrisTitusTech/winutil/releases/latest`, field `assets[].digest`), then update `$tag` and `$sha` here.

## Upstream's command (what upstream suggests, not recommended here)
```powershell
irm "https://christitus.com/win" | iex
```
It runs whatever the server returns at that moment, with no pin and no check.
