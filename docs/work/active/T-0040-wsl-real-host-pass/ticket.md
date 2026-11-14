Source: local

# T-0040: Real WSL2 host acceptance pass (human verification)

Status: open (needs a person on a Windows 11 machine)
Wave: 4
Depends on: T-0034, T-0035, T-0036, T-0037, T-0038, T-0039

## Summary
First real activation of the `wsl` profile, bracketed by a backup and
before/after snapshots, with every result recorded. Failures become new tickets;
they are not fixed here.

## Owned files (write boundary)
- docs/platforms/wsl/test-pass.md (adds the "Acceptance checklist" section)
- docs/work/active/T-0040-wsl-real-host-pass/evidence/** (sanitised outputs)
- docs/plans/migration/followups.md ("WSL validation" row only, after the pass;
  tracked file, the user approves the edit)

## Checklist (mark only what ran; attach evidence)
- [ ] Backup: `wsl --export` tar created and its size noted (the tar stays out of the repo)
- [ ] Windows before: `wsl --version`, `wsl --list --verbose`, `winget list`
- [ ] WSL before: `bash ops/host-snapshot.sh --label before`
- [ ] Install per docs/platforms/wsl/setup.md (wsl.conf, `wsl --shutdown`, `bash ops/install.sh`)
- [ ] WSL after and Windows after snapshots; `diff -ru` and `Compare-Object`; record unexpected changes
- [ ] `sys-readiness` prints ALL SET with exit 0; every WSL2 line is OK
- [ ] `systemctl --user list-timers` shows the Home Manager timers
- [ ] tmux copy of non-ASCII text (`café — Привет`) pastes correctly into Notepad
- [ ] `open https://example.com` and `open .` work in fish and zsh; `gh auth login` opens the Windows browser
- [ ] `docker compose version`; `docker info` with the chosen engine
- [ ] `git commit` (no `-m`) opens VS Code and waits
- [ ] First `nvim` launch clones plugins over SSH
- [ ] `chezmoi diff` is empty; `bash ops/update-all.sh` (report mode) is clean
- [ ] Observation only: `code --list-extensions` from WSL; record which side it lists
- [ ] Optional: the AI login-expiry toast appears

## Acceptance criteria
- AC1: every checklist line is marked ran/passed, ran/failed or not run, with
  evidence for each line that ran.
- AC2: each failure gets its own new ticket; none are fixed here.
- AC3: the followups.md "WSL validation" row states what was verified and when.
- AC4: the evidence holds no tokens, `op` output, `~/.ssh` content, the backup tar
  or personal.yaml; a person reviews it before it is saved.

## Verification
- Human handoff; reproducible steps in docs/platforms/wsl/test-pass.md.

## Out of scope / notes
- Windows app installs (T-0041).
- Never `wsl --unregister` as part of this pass.
