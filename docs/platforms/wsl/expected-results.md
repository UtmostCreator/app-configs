# WSL2 bootstrap: what success looks like

Each run prints lines starting with "[bootstrap] step ...". Rows marked
VERIFIED were observed on a real PC; rows marked EXPECTED were not yet observed.

| Run | Where | You should see | Exit / next |
|---|---|---|---|
| 1 (VERIFIED 2026-11-15) | Elevated: Win+X, Terminal (Admin) | In order: "step C: skipped (elevated run)"; "step 0: Windows report (before): <path>"; "step 1: restore point created"; then Windows' own output "Windows Subsystem for Linux <version> has been installed", "Installing Windows optional component: VirtualMachinePlatform", "The operation completed successfully"; last line "step 1: WSL installed; reboot, then re-run in a normal PowerShell". Up to about 3 minutes of silence before the step 0 line is a known defect (T-0050), not a hang. | Exit 3 (reboot needed). Restart; use Settings > Windows Update > Restart now if offered. |
| 2 (VERIFIED 2026-11-15) | Normal PowerShell, after the restart | In order: "step C: chezmoi absent / gitleaks absent / lefthook absent"; "step C: installing twpayne.chezmoi", "installing Gitleaks.Gitleaks", "installing evilmartians.lefthook"; "step C: lefthook hooks installed"; "step 2: WSL 3.0.5.0 is new enough"; "step 3: downloading <pinned NixOS-WSL nixos.wsl URL>"; "The operation completed successfully."; "step 3: imported NixOS"; "step 4: nixpkgs channel present"; "step 5: systemd is PID 1 and WSLInterop exists"; "step 6: next: land the desktop-first commits (D0) ... then re-run". | Exit 3 at step 6: expected until D0 is pushed. |
| 3 (EXPECTED) | Normal PowerShell, after D0 is on this PC | Step 6 clone; 7a and 7b before-setup report and export; step 9 system setup, user switch and WSL restart; step 11 checks; step 12 install; 12b after reports; then the line "auto setup finished ..." points to `docs\platforms\windows\setup.md`, section "Manual steps after auto setup". | Exit 0. Then do the [manual steps](../windows/setup.md#manual-steps-after-auto-setup). |

Run 2 notes: steps 0 and 1 print nothing when there is nothing to do, so the
output seems to start at step C or 2 (known defect, T-0050: skipped steps will
print a line). The download is about 550 MB and shows no progress yet (T-0050).
Already-present tools print "present" instead of "absent" and "installing".

## Not success

- "step 0: reboot pending": restart from Settings > Windows Update > Restart now (a plain restart can leave the marker set).
- "run elevated": use an admin terminal for run 1 only.
- "re-run non-elevated": runs 2 and 3 must not be elevated.
- Exit 1: read the last line, fix the cause, re-run. Finished steps are skipped.
