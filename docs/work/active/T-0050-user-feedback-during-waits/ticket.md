Source: local

# T-0050: Always show user feedback during waits (bug + rule)

Status: open
Depends on: none
Relates to: T-0047 (Windows bootstrap)

Found 2026-11-15 in the first real elevated run of the Windows bootstrap.

## Summary
Any operation that makes the user wait must say what it is doing before it waits. After "step C: skipped", nothing was printed for about 3 minutes (09:49 to 09:52) while the script probed wsl.exe and created a restore point. The user thought it had hung.

## Rule (the acceptance target)
- Before any step that can take more than ~2 seconds, print one line saying what is starting and roughly how long it can take.
- For waits over ~30 seconds, print progress or a heartbeat at least every 30 seconds.
- Never capture the output of a tool that may prompt interactively without first telling the user.
- End each step with a result line.
- Applies to every script in ops/ (PowerShell and bash) and to agent-driven runs: an agent tells the user before starting a long wait.

## Known cases to fix first (Windows bootstrap, not yet committed)
- The wsl.exe --version and --status probes when WSL is absent: each took about a minute, silent. Suspected cause: the inbox wsl.exe shows a hidden "press any key to install" prompt that times out (unverified). Fix: when the WSL Appx package is absent, skip the wsl.exe probes entirely.
- Restore point creation: tens of seconds, silent.
- The NixOS-WSL download (large file), wsl --import, wsl --export, winget installs and the report capture: each needs a "starting..." line and, where long, a heartbeat.
- Skipped steps print nothing: run 2 appeared to "start from step 2".
- The roughly 550 MB download prints no progress.
- The step-6 message still mentions git bundle.

## Audit task
List every wait in ops/install.sh, ops/update-all.sh, ops/system-setup.sh, ops/bootstrap.sh and the Windows bootstrap. Mark each as has-feedback or silent. Fix the silent ones.

## Acceptance criteria
- [ ] AC-1: no silent wait over 2 s in the Windows bootstrap (tests assert a log line precedes each seam call that can block).
- [ ] AC-2: no wsl.exe call when the Appx package is absent.
- [ ] AC-3: heartbeat for download, import, export and winget.
- [ ] AC-4: the audit table for the bash scripts exists and silent waits are fixed or listed as follow-ups.
- [ ] AC-5: the rule is in docs/index.md.

## Owned files (write boundary)
- The Windows bootstrap script and its tests (Windows session).
- ops/*.sh audits (the NixOS session, per the T-0047 coordination split).
