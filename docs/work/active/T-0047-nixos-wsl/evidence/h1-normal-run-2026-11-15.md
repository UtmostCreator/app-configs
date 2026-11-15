# H1: first normal (non-elevated) run of the Windows bootstrap (2026-11-15)

Second run, in a normal PowerShell after the restart that followed the elevated run (see h1-elevated-run-2026-11-15.md).

## Output (verbatim)
```
[bootstrap] step C: chezmoi absent
[bootstrap] step C: gitleaks absent
[bootstrap] step C: lefthook absent
[bootstrap] step C: installing twpayne.chezmoi
[bootstrap] step C: installing Gitleaks.Gitleaks
[bootstrap] step C: installing evilmartians.lefthook
[bootstrap] step C: lefthook hooks installed
[bootstrap] step 2: WSL 3.0.5.0 is new enough
[bootstrap] step 3: downloading https://github.com/nix-community/NixOS-WSL/releases/download/2605.7.2/nixos.wsl
The operation completed successfully.
[bootstrap] step 3: imported NixOS
[bootstrap] step 4: nixpkgs channel present
[bootstrap] step 5: systemd is PID 1 and WSLInterop exists
[bootstrap] step 6: next: land the desktop-first commits (D0), fetch them into the Windows clone (git bundle), then re-run
```

## Facts checked on the PC afterwards
- `wsl --version`: WSL 3.0.5.0, kernel 6.18.58.1-1.
- `wsl --list --verbose`: NixOS, version 2.
- The downloaded nixos-wsl-2605.7.2.wsl is 577813513 bytes.
- The distro disk is under the app-configs state folder.
- .git\hooks\pre-commit exists (lefthook).

## Result
As designed (exit 3 at step 6 expected). H1 complete; waiting for D0.

## Unknowns resolved by this run
- winget runs from the script.
- Real wsl.exe output parses.
- `wsl --import` works.
- systemd is PID 1 on the stock NixOS-WSL image.
- WSLInterop is registered.
