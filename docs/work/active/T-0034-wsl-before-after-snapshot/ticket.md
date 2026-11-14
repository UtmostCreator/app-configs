Source: local

# T-0034: WSL2 before/after state snapshot and backup runbook (feature)

Status: open
Wave: 1
Depends on: none
Blocks: T-0039, T-0040

## Summary
Before any real WSL2 test, record the state of the distro and Windows so an
"after" snapshot proves what the install changed and that every required tool
arrived. One small read-only script captures the WSL side; the Windows side and
the `wsl --export` backup are documented PowerShell steps the user runs by hand.
No repo script runs `wsl.exe`, `winget` or PowerShell.

## Owned files (write boundary)
- ops/host-snapshot.sh (new)
- tests/bash/host-snapshot.bats (new)
- docs/platforms/wsl/test-pass.md (new: backup, snapshot and compare sections)
- ops/lint-shell.sh (add the new script to the `curated` list only)

## Findings
- VERIFIED: nothing captures host state today. `ops/snapshot-home.sh` copies
  chezmoi-managed dotfiles (restore aid, not an inventory);
  `ops/update-version-report.sh` is a library sourced by `sys-update`.
- Reuse existing commands, no new collection logic: `home-manager generations`,
  `home-manager packages`, `nix --version`, `nix profile list`, `mise ls`,
  `dpkg-query -W`, `systemctl --user list-timers --all`,
  `bash ops/detect-host.sh` (+ `--wsl-version`), `bash ops/readiness.sh`
  (already includes `ops/wsl-check.sh` on the wsl profile).
- On a fresh distro (before install) nix, home-manager, mise and chezmoi are
  absent; the script must still succeed and record them as absent.

## Design
`bash ops/host-snapshot.sh [--label NAME] [-h|--help]`
- Writes to `${HOST_SNAPSHOT_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/app-configs/host-snapshots}/<UTC timestamp>-<label>/`;
  default label `snapshot`; label must match `^[a-z0-9][a-z0-9-]*$`. Never
  reuses an existing directory. Prints the directory as the last stdout line.
- Fixed file set, one source each. Missing command: `absent: <command> not
  found`. Failing command: its stdout plus `exit: <code>`. stderr is not captured.
  | File | Source |
  | --- | --- |
  | host.txt | UTC time, `detect-host.sh`, `detect-host.sh --wsl-version`, `uname -r`, `PRETTY_NAME` from /etc/os-release, `$WSL_DISTRO_NAME` |
  | wsl-conf.txt | copy of `/etc/wsl.conf` (test override `HOST_SNAPSHOT_WSL_CONF`) or `absent` |
  | apt-packages.txt | `dpkg-query -W -f '${Package}\t${Version}\n'`, sorted |
  | nix.txt | `nix --version`, `nix profile list` |
  | hm-generations.txt | `home-manager generations` |
  | hm-packages.txt | `home-manager packages`, sorted |
  | mise.txt | `mise ls` |
  | user-timers.txt | `systemctl --user list-timers --all --no-pager` |
  | readiness.txt | `bash ops/readiness.sh` stdout, then a final `exit: <code>` line |
- Never reads environment dumps, `~/.ssh`, `home/.chezmoidata/personal.yaml`,
  1Password or shell history.
- Exit codes: 0 directory written; 2 bad arguments (as in `ops/snapshot-home.sh`);
  1 directory cannot be created.
- Compare is documented as `diff -ru <before> <after>`; the script has no compare
  mode.

## docs/platforms/wsl/test-pass.md (sections this ticket writes)
1. Backup first (PowerShell on Windows, before modifying an existing distro):
   `wsl --shutdown`, then `wsl --export <Distro> <BackupDir>\<Distro>-before-<date>.tar`.
   Check free disk space first. The tar holds SSH keys and tokens: store it on a
   private disk, never in the repo or a synced folder. Restore under a new name:
   `wsl --import <Distro>-restore <Dir> <tar>`, then verify. `wsl --unregister`
   is never scripted or automatic; removing any distro is a manual decision.
2. Windows "before": `wsl --version`, `wsl --list --verbose`,
   `winget list --accept-source-agreements`, each redirected to
   `$HOME\wsl-test\before-*.txt`.
3. WSL "before" (after cloning the repo per setup.md):
   `bash ops/host-snapshot.sh --label before`.
4. "After": the same Windows commands into `after-*.txt`, then
   `bash ops/host-snapshot.sh --label after`.
5. Compare: `diff -ru <before> <after>` (WSL);
   `Compare-Object (Get-Content before-winget.txt) (Get-Content after-winget.txt)` (Windows).
6. Pass condition: `after/readiness.txt` shows `MISSING: 0` and `exit: 0`;
   `hm-packages.txt` is non-empty; `wsl-conf.txt` matches setup.md.

## Acceptance criteria
- AC1: With nix, home-manager, mise, dpkg-query and systemctl absent from PATH
  (fresh-distro simulation) the script exits 0, writes all 9 files and marks the
  missing sources `absent`.
- AC2: With recording stubs, each file contains its stub's output; readiness.txt
  ends with the stub's exit code.
- AC3: A planted env value (`SNAPSHOT_CANARY=canary-123`) and a planted
  `$HOME/.ssh/id_test` content never appear in any output file.
- AC4: An unknown argument or invalid label exits 2 and writes nothing; an
  existing target directory is never overwritten.
- AC5: `--help` exits 0 and writes nothing.
- AC6: Nothing is written outside the snapshot directory (compare a listing of
  the test `$HOME` before and after).
- AC7: test-pass.md contains the backup-first order, the export/import commands,
  the "never auto `--unregister`" rule, the tar secret warning, the Windows and
  WSL before/after steps and the compare commands.
- AC8: `bats tests/bash/host-snapshot.bats` and `bash ops/lint-shell.sh` pass.
- Independent review PASS; one conventional commit per logical change; no AI
  attribution trailers.

## Verification
- `bats tests/bash/host-snapshot.bats`; `bash ops/lint-shell.sh`
- Real host: run before and after on WSL2 (done in T-0040).

## Out of scope / notes
- Running anything on Windows; a compare mode; a mise task; uploading snapshots.
- readiness.txt records the raw exit code; T-0035 adds exit 3 ("READY with TODO").
- Only the files listed above. Unrelated findings are reported, not fixed.
