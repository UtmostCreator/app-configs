Source: local

# T-0040: Real WSL2 host acceptance pass (human verification)

Status: open (needs a person on a Windows 11 machine)
Wave: 4
Depends on: T-0034, T-0035, T-0036, T-0037, T-0038, T-0039, T-0045
Order: last. Recommended implementation order for the WSL2 work: T-0035, T-0038, T-0037, T-0036, T-0034, T-0045 (Wave 2), T-0039 (its wsl.conf fix may land first), T-0040 last. Full test order and fix-before gates: T-0040.

Re-verified 2026-11-15 against main ed39171: none of the WSL2 tickets has been executed and every bug described is still present. User decisions unchanged: Wave 1 = T-0034..T-0038; Windows-side provisioning stays manual; T-0041 is docs-only.

## Summary
First real activation of the `wsl` profile, bracketed by a backup and
before/after snapshots, with every result recorded. Failures become new tickets;
they are not fixed here.

## Owned files (write boundary)
- docs/platforms/wsl/test-pass.md (adds the "Acceptance checklist" section)
- docs/work/active/T-0040-wsl-real-host-pass/evidence/** (sanitised outputs)
- docs/plans/migration/followups.md ("WSL validation" row only, around line 18, after the pass;
  tracked file, the user approves the edit)

## Ordered checklist (mark only what ran; attach evidence)
[C] = verifiable from a Linux host or CI; [W] = needs a real Windows 11 + WSL2 machine.

- [ ] 1. [W, manual] PowerShell: `wsl --install -d Ubuntu`, `wsl --update`; `wsl --list --verbose` shows VERSION 2. Create the user named in `nix/vars/default.nix`.
- [ ] 2. [W, manual] Back up: `wsl --shutdown`, then `wsl --export` (the tar stays out of the repo; note its size). Take the Windows "before" snapshots (`wsl --version`, `wsl --list --verbose`, `winget list`). Install the Windows prerequisites (VS Code, Windows Terminal, a Nerd Font) per T-0041's docs.
- [ ] 3. [W] Write /etc/wsl.conf (`[boot] systemd=true`, `[user] default=`, `[interop] enabled=true`, `appendWindowsPath=true`), each comment on its own line. Run `wsl --shutdown` and reopen. Confirm `cat /proc/1/comm` prints `systemd` and `systemctl is-system-running` is not `offline`; no failed user units (`systemctl --user list-units --failed`).
- [ ] 4. [W] `sudo apt update && sudo apt install -y git curl ca-certificates`. Clone into the Linux filesystem (under ~), never /mnt/c.
- [ ] 5. [C+W] `bash ops/detect-host.sh` prints `wsl`; `--wsl-version` prints 2. Covered in CI by `tests/bash/detect-host.bats`.
- [ ] 6. [W] WSL "before" snapshot: `bash ops/host-snapshot.sh --label before` (needs T-0034).
- [ ] 7. [C+W] `bash ops/install.sh --dry-run </dev/null`. With no selection file and no TTY it prints the "no local selection ... nothing written" line and no macInput row; on a TTY it prompts. `--profile work` prints "would write .../selection.toml". With XDG_CONFIG_HOME under /mnt/c the ignore note prints once and the Linux path is used. Covered in CI by the AC15 tests in `tests/bash/selection.bats`.
- [ ] 8. [W] Real `bash ops/install.sh`. systemd must be on (the Determinate Nix installer on Linux likely needs it: unverified). It seeds the chezmoi data with hostProfile wsl and gui false.
- [ ] 9. [W] T-0042 human check 4 (see `docs/work/active/T-0042-install-selection/evidence/t6-t8-results.md`), plus `mise run sync:dry-run` with no prompt.
- [ ] 10. [W] Post-install: `sys-doctor`/doctor, `bash ops/wsl-check.sh`, `sys-readiness` (exit 0, or exit 3 only with explained TODOs, unless T-0035, T-0037 and T-0038 are done); `systemctl --user list-timers` (codebase-memory-mcp, audit, ai-cli-updates); `systemctl --user status codebase-memory-mcp-ui`; `curl 127.0.0.1:9749`.
- [ ] 11. [W] Behaviour checks: tmux copy of non-ASCII text (`café — Привет`) pastes into Notepad; `open https://example.com` and `open .` in fish and zsh; `gh auth login` opens the Windows browser; `git commit` without `-m` opens VS Code and waits; `docker compose version` (and `docker info` with the chosen engine); first `nvim` launch clones plugins over SSH. Observation only: `code --list-extensions` from WSL, recording which side it lists. Optional: the AI login-expiry toast.
- [ ] 12. [W] `chezmoi diff` is empty; `bash ops/update-all.sh` in report mode is clean; WSL "after" and Windows "after" snapshots; `diff -ru` and `Compare-Object`; record unexpected changes.
- [ ] 13. [W] Only then `sys-update --apply` (clean worktree, a GitHub SSH key, no concurrent codebase-memory-mcp updater run).

### Fix-before gates
- T-0039's wsl.conf fix before step 3.
- T-0035 before step 10.
- T-0038 before the first activation (step 8).
- T-0037 before steps 8 and 13.
- T-0036 before step 11.
- T-0034 before steps 6 and 12.
- T-0045 before step 10.

### Implementation order
T-0035, T-0038, T-0037, T-0036, T-0034, T-0045 (Wave 2, not Wave 1), T-0039 (its wsl.conf fix may land first), T-0040 last.

## Acceptance criteria
- AC1: every checklist step is marked ran/passed, ran/failed or not run, with
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
