# H1: first elevated run of the Windows bootstrap (2026-11-15)

## How it was started
1. Win+X, then "Terminal (Admin)" / "Windows PowerShell (Admin)".
2. cd to the repo.
3. `powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1`

## Prerequisite learned
The pending-reboot marker cleared only after restarting from Settings > Windows Update > Restart now. A plain restart left it set.

## Output (verbatim)
```
[bootstrap] step C: skipped (elevated run); run non-elevated for the commit tooling
[bootstrap] step 0: Windows report (before): C:\Users\username\AppData\Local\app-configs\host-snapshots\20261115T174902Z-before\windows.txt
[bootstrap] step 1: restore point created
Downloading: Windows Subsystem for Linux 3.0.5
Installing: Windows Subsystem for Linux 3.0.5
Windows Subsystem for Linux 3.0.5 has been installed.
Installing Windows optional component: VirtualMachinePlatform
Deployment Image Servicing and Management tool
Version: 10.0.26100.9549
Image Version: 10.0.26300.9974
Enabling feature(s)
[==========================100.0%==========================]
The operation completed successfully.
The requested operation is successful. Changes will not be effective until the system is rebooted.
The requested operation is successful. Changes will not be effective until the system is rebooted.
[bootstrap] step 1: WSL installed; reboot, then re-run in a normal PowerShell
```

## Observations
- Result: as designed (exit 3 expected; the exit code was not captured).
- Windows 11 Home build 26300.
- WSL 3.0.5 was installed by `wsl --install --no-distribution`.
- About 3 minutes of silence before step 0's line (see T-0050).
- `wsl --install` itself reported the reboot requirement.

## Next
Reboot (R2), then run the same command in a normal PowerShell.
