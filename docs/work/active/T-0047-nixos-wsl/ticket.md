Source: local

# T-0047: WSL2 on NixOS-WSL, desktop-first (feature)

Status: WSL2 setup complete; pending (b), then the open ACs (see "Final design and outcome")
Depends on: none to start. Slice 3 items: T-0038, T-0035, T-0045(a).
Blocks: T-0040 (acceptance = Slice 4 here)
Supersedes: T-0034 (reports live in bootstrap.ps1 -Report), T-0039 (folded in)
Coordinates with: T-0029
Plan: [plan.md](plan.md)

Written 2026-11-15 against main c644dd6.

## Summary
- Milestone 1: WSL2 reproducible at parity with the NixOS desktop.
- Path: the desktop path on NixOS-WSL. /etc/nixos + sys-setup + standalone HM via the shared install.sh.
- Plan and slices: plan.md.

## Decision (2026-11-15, user)
- Distro: NixOS-WSL, the desktop path.
- Reverses "Windows provisioning stays manual": one script, ops/windows/bootstrap.ps1 (planned), runs wsl.exe. winget stays manual.
- Transfer: push/pull (commit + push to origin authorised 2026-11-15; replaces the git bundle). Each session confirms its own push authorisation (AGENTS.md: authorisation does not carry over).
- Tailscale: Windows only.
- Docker: declarative via sys-setup. Never an automatic docker group on wsl.
- aiCli opt-out key: a deliberate exception.
- Git editor: per host. Answers T-0037's old rejection:
  - VS Code is not in Milestone 1.
  - A template value needs no wrapper.
  - GIT_EDITOR still overrides.
- Docs-only commits on Windows are allowed with validate-config + gitleaks run by hand (no hooks installed there); code commits only where the hooks run.
- T-0047 extends sys-setup (option 1, the user's decision 2026-11-15). T-0029 (proposed, unauthorised) would later replace it with nixosConfigurations; the NixOS-WSL host moves in that same milestone (option 2), a proposal to extend T-0029 to NixOS-WSL (T-0029 does not mention WSL). If T-0029 is authorised before D0 lands, re-plan D0 against it. D0 keeps its edits to system-setup.sh minimal and additive so T-0029 can absorb them.

## Owned files (write boundary)
- ops/windows/bootstrap.ps1
- tests/windows/bootstrap.tests.ps1
- nix/modules/nixos/wsl.nix (new)
- ops/system-setup.sh
- nix/hosts/wsl/home.nix
- ops/lib/preflight.sh
- ops/readiness.sh
- ops/validate-config.sh
- tests/bash/{system-setup,nix-identity,nixos-wsl-module,windows-bootstrap,doc-contracts}.bats
- tests/bash/readiness.bats (D0 adds a wsl case)
- docs/platforms/wsl/setup.md
- docs/platforms/wsl/windows-and-wsl.md
- plus each task's Files in plan.md

## Before anything: install/check list

Windows PC
- [ ] Pro upgrade reboot finished (CBS RebootPending cleared)
- [ ] System Protection on C: (or plan `-EnableSystemRestore`)
- [ ] Free space on C: >= the export size
- [ ] Git for Windows present
- [ ] chezmoi and gitleaks: `winget install -e --id twpayne.chezmoi` (verified 2026-11-15; winget installs the latest), `winget install -e --id Gitleaks.Gitleaks` (verified 2026-11-15); in a new Git Bash `command -v chezmoi gitleaks`

NixOS desktop
- [ ] Repo clone up to date (`git pull --ff-only`)
- [ ] nix, bats, lefthook, gitleaks available
- [ ] Clean worktree
- [ ] Known-good generation recorded: `nixos-rebuild list-generations`
- [ ] Backup: `sudo cp -a /etc/nixos /root/etc-nixos-backup-$(date -u +%Y%m%dT%H%M%SZ)` (outside /etc/nixos, unique name). Record the path.
- [ ] `command -v rsync` (else `nix shell nixpkgs#rsync -c rsync -a --delete <backup>/ /etc/nixos/`; fallback: cp + `diff -r`)
- [ ] Backup restorable, before any apply: `sudo diff -r /etc/nixos <backup>` shows no differences; `sudo ls -la <backup>` shows the files.
- [ ] Baseline recorded at the Transfer-0 commits, before any D0 edit: outputs of D1, D3, D4, D5

## NixOS desktop verification (D0), run before any WSL install

Order: baseline, tests (D2b, D8 bats), backup + restorability check, dry-activate preview, apply (D2), verify (D3-D6).

| ID | TODO | Expected | Pass/Fail evidence |
|----|------|----------|--------------------|
| D1 | `bash ops/system-setup.sh` (report), old commit vs new | Identical to the baseline (a configured desktop prints "already present ... Nothing to add"; when a snippet prints, it shows docker with `user = "<you>"`, tailscale, linger, no wsl import). | |
| D2b | Before D2: `bats tests/bash/system-setup.bats` after the pull (B2 failure-safety; bats only, NEVER on the real /etc/nixos) | Simulated dry-build failure restores every file byte-for-byte: content, mode, owner, symlink; absent files stay absent. With and without an existing docker copy. | |
| D8 | Before D2: full `bats tests/bash`; `nix flake check ./nix`; activation builds of linux-desktop, linux-cli, wsl | All pass. | |
| D2 | First `sudo nixos-rebuild dry-activate --flake /etc/nixos#nixos` if /etc/nixos/flake.nix exists, else plain `sudo nixos-rebuild dry-activate` (record which services would restart), then `sudo bash ops/system-setup.sh --apply` | Preview: none unexpected, e.g. no display-manager restart. It reflects the real apply only when D1 printed "Nothing to add"; otherwise it previews the current /etc/nixos. Apply: `nixos-rebuild dry-build`, then `switch` (not `boot`). app-configs-extra.nix as before. app-configs-docker.nix still present. NO app-configs-wsl.nix. `id` lists docker. `systemctl is-active docker tailscaled` = active active. `systemctl --failed` empty. | |
| D3 | `sys-readiness` | Same exit code as before (0, or 2 if a rebuild is pending). Tailscale line still printed. | |
| D4 | `bash ops/install.sh --dry-run </dev/null` | Same output as before. | |
| D5 | `nix eval --raw path:$PWD/nix#homeConfigurations.linux-desktop.activationPackage.drvPath`, before and after | Unchanged (only wsl drops genericLinux). | |
| D6 | `grep -rn 'app-configs\|nix-ld' /etc/nixos`; `ls -l /lib64/ld-linux-x86-64.so.2`; `echo $NIX_LD`; `command -v claude codex` | Records: does the desktop import repo modules by absolute path (blocks deleting nix/modules/nixos/default.nix)? How does Claude run there (decides nix-ld in the shared snippet vs wsl.nix only)? | |
| D7 | Later, after each Slice 3 item (T-0038, T-0035, T-0045(a), editor, ai-cli-install, ~/Projects): `sys-update` report, then `--apply`, then `sys-readiness` | T-0038 changes the linux-desktop drvPath (colima removed). Readiness may move 0 to 3 if TODOs exist. `git config core.editor` stays `code --wait`. ai-cli-install does nothing when claude/codex exist. CBM units stay active. | |

## Recovery

| Situation | Recovery |
|-----------|----------|
| Failure before any config write | Nothing to restore. |
| /etc/nixos files changed, no generation activated | Restore the backup: `sudo rsync -a --delete <backup>/ /etc/nixos/` (needs rsync: `command -v rsync`, else `nix shell nixpkgs#rsync -c rsync ...`; fallback: `cp -a`, then remove the files `sudo diff -r` lists as only in /etc/nixos) |
| A generation activated or partly switched | Restore the files AND `sudo nixos-rebuild switch --rollback` (or boot the previous generation). |
| NixOS-WSL | Also `wsl --import` from the before-setup export. |

- The WSL username migration uses `nixos-rebuild boot` + a WSL restart, not switch (NixOS-WSL docs).

## Final design and outcome (2026-11-16)

(b) is the last user action for the WSL2 setup: the user fills the Git name and email in personal.yaml and runs `chezmoi --source="$HOME/app-configs" apply`. The unticked ACs below stay open as follow-ups; T-0047 closes only when they are met or explicitly deferred. (a) commit test, (c), (d), (e) are follow-ups.

Final design = [ADR-0015](../../../architecture/decisions/0015-wsl-distro-selection-nixos-or-ubuntu.md), which supersedes the first D0 design where they differ:
- One host profile `wsl` for both distros. NixOS-WSL is the default path (personal PC); Ubuntu is supported by short manual steps (setup.md, "Alternative: Ubuntu") and is untested on a real distro.
- One extra Home Manager output, `wsl-nixos` (the wsl home with `targets.genericLinux` forced off). `ops/detect-host.sh --hm-attr` is the only place that chooses it. On the verified host: detect-host prints `wsl`, `--hm-attr` prints `wsl-nixos`.
- `genericLinux` is NOT dropped from the wsl home, and preflight does NOT refuse a non-NixOS wsl host (the two D0 points ADR-0015 supersedes).
- The Windows bootstrap targets only the distro named NixOS and never touches another distro. No `-Distro` switch yet (deferred, trigger in the ADR).

Real commits (`git log --oneline 4568249..8316e94`, 20 commits, fast-forwarded to origin/main 2026-11-16). Those in the fix stack (subject-matched, not individually proven to serve T-0047):

| SHA | Subject |
|-----|---------|
| 9a4c97d | fix(nixos-wsl): give the WSL mount-guard unit a NixOS path and keep activated configs on unit failures |
| 7df0c1f | fix(setup): treat activate-script failures as activated and spell out the rollback restore |
| 445a854 | test(setup): pin the host-dependent user and PATH checks so CI matches |
| 3ef84a6 | fix(install): stop installing home-manager into the profile it will collide with |
| 6862dfc | feat(install): announce long waits and keep a heartbeat going (T-0050) |
| 8beb383 | feat(hooks): route every hook install through ops/install-git-hooks.sh |
| f7619da | feat(hooks): refuse partially staged commits before lefthook can stash |
| 493b69f | docs(hooks): document partial commits and the hook installer |
| e8f7bcc | fix(update): do not suggest git stash in the dirty-tree hint |

The other 11 commits of the range are not T-0047 work (they rode along in the same fast-forward): 8316e94 fix(fish) Ctrl+C, 9e2809e, 07aac2a, e888a5d, 8d64414, 51a11c6 (git aliases), 00ea4a5, 3380589, 0e93bb7 (ssh), 6da3ab1 (git docs), da89418 (terminal scrollback). Run 5 failed at bootstrap step 12 (Home Manager collision); 3ef84a6 likely fixed it (inferred from its subject, not re-measured).

Earlier T-0047 commits (`git log --oneline --grep T-0047`; 4568249 is T-0052/ADR-0016 and is not listed here):

| SHA | Subject |
|-----|---------|
| 400a30b | feat(windows): add the NixOS-WSL bootstrap script and its tests |
| 28c588b | docs(wsl): plan T-0047 NixOS-WSL desktop-first |

Related commits that do not carry the id in the subject (found by subject, before 4568249): e71bdef (NixOS-WSL module and wsl-nixos home output), b07e102 (one fail-closed Home Manager output helper), cb69f7d (sys-setup wiring with dry-build and exact restore), b1391bf (system tools for install on NixOS-WSL), b7ff236 (ADR-0015, T-0051, T-0050 findings), 7731a31 and 9682803 (T-0051: personal-data guard script, installer in bootstrap step C).

Findings (issues met during the setup, with status and owner): [findings.md](findings.md). Evidence: [evidence/final-run-2026-11-16.md](evidence/final-run-2026-11-16.md) (includes the final health check), with the H1 files it builds on. Commit-message audit of the published commits: [evidence/commit-traceability-audit-2026-11-16.md](evidence/commit-traceability-audit-2026-11-16.md).

Open after the final run (details and owners: evidence file, same heading):

- (a) Windows hooks: `--check` fixed by 8f6b4eb (exit 0 on Windows and WSL, 2026-11-16). Remaining: a real commit from the Windows clone. Owner: the user / `all-reviewed-landing` (T-0051). Follow-up.
- (b) Git name and email in personal.yaml, then `chezmoi --source="$HOME/app-configs" apply`. Owner: the user. The last user action for the WSL2 setup; unticked ACs stay open until met or deferred.
- (c) codebase-memory-mcp-ui restart loop (missing ~/Projects, CBM_ALLOWED_ROOT). Worked around; healthy at the final check. Repo fix: d03a095 on origin/main (a clone needs the pull, then a Home Manager switch: on WSL `sys-install` / `bash ops/install.sh` or `ops/windows/bootstrap.ps1`; `sys-update --apply` and `ops/bootstrap.sh` now pass `--source` automatically since adedbb2, not re-run on WSL: unknown). Follow-up.
- (d) Keep or remove the SKIP_HOOKS=1 escape hatch in ops/hooks/pre-push.sh. Owner: the user (decision). Follow-up.
- (e) WSL git over SSH: WSL has no SSH key; the key is in the Windows ssh-agent. Working setup on this PC: `git -C ~/app-configs config --local core.sshCommand /mnt/c/Windows/System32/OpenSSH/ssh.exe`. Follow-up: make it permanent for fresh installs (chezmoi / Home Manager change). Owner: not assigned.
- The nix repo-audit and codebase-memory-mcp-update user units fail on WSL: they located the repo via `chezmoi source-path`, which points at a missing dir. Fixed in 501bb3f (on origin/main; not re-verified on WSL: unknown). Owner: all-reviewed-landing.
- The bats tests leak 1Password `op daemon` processes. 4127a6f (on origin/main) fixes the fish greeting test; other leaking tests: unknown. Owner: all-reviewed-landing.
- fish ssh-agent fix landed in cb81798 and 249b073 (origin/main 9e6cb03); confirm after pulling and running `chezmoi --source="$HOME/app-configs" apply`: `fish -ic true` prints no error.
- User steps for AC-WSL: install and log in to Claude Code and Codex in WSL; install and log in to Tailscale on Windows.
- CLAUDE.md: uncommitted edit adds a protected-action grant ("or if user says all permissions lifted"), unknown author; the user decides (findings #17).
- Other follow-ups (not done here):
  - Stale setup.md line references in the T-0037 ticket:34 and T-0038 ticket:26; followups.md:18 "WSL validation" is partly stale.
  - ADR status lines: ADR-0015 ("not yet implemented; Ubuntu path untested") and ADR-0001 ("not yet verified on a real WSL install") still carry their pre-run text, while their frontmatter and index rows say `decided-unverified`. Moving either to `decided` after the 2026-11-16 NixOS-WSL run is an ADR edit for the owner; not done here. The ADR-0001 consequence line may also be stale.
  - T-0051 should record the _lefthook.sh case (owner `all-reviewed-landing`).
  - T-0048 should capture the Windows time format (key missing in windows.yaml; see AC-TZ evidence).
  - sys-readiness `chezmoi verify` needs `--source=$HOME/app-configs` (false "pending" on WSL; `ops/readiness.sh:67`). Landed in ca3b67b and 70bb32b (on origin/main).
  - sys-update (`ops/update-all.sh` dotfile step and its status/diff/verify checks), `ops/audit.sh` and `ops/bootstrap.sh` called chezmoi without `--source` on WSL, so `sys-update --apply` could not apply dotfiles there. Fixed on origin/main: shared helper `ops/lib/chezmoi-source.sh` (5617787), applied by adedbb2 and 70bb32b; not re-run on WSL: unknown. Plain `chezmoi` commands still need `--source="$HOME/app-configs"` (for example `chezmoi --source="$HOME/app-configs" apply`).
  - Commit-message gate (proposal): [evidence/commit-traceability-audit-2026-11-16.md](evidence/commit-traceability-audit-2026-11-16.md).

## Acceptance criteria
- [x] AC-B1: `wsl.defaultUser = lib.mkForce "utmostcreator"` in a WSL-only module.
  - Code: met. nix/modules/nixos/wsl.nix:30 sets `wsl.defaultUser = lib.mkForce "utmostcreator"` (WSL-only module; comment at :10 notes the stock "nixos" value).
  - Build passes: met (the live system was built and switched with it).
  - WSL launches as utmostcreator: met (/etc/wsl.conf default=utmostcreator; `id utmostcreator` works; the final run ran as that user).
  - A test proves a stock "nixos" value loses: met. 2026-11-16 ~02:05 UTC, WSL non-elevated, clean clone at 8f6b4eb: `bats tests/bash/nixos-wsl-module.bats` 4/4 ok, exit 0 (B1 stock "nixos" loses to the module's mkForce; B1 control: without mkForce the same definitions conflict; 2 wsl module tests).
  - Measurements: final-run-2026-11-16.md, "Acceptance measurements".
- [ ] AC-B2: as D2b, plus /etc/nixos file state unchanged after a dry-build or validation failure. On a switch failure, print `nixos-rebuild switch --rollback`.
- [ ] AC-T1: bootstrap tests pass, ParseFile, ASCII. Evidence 2026-11-16 ~01:45 UTC: 176 passed, 0 skipped, 0 failed; ParseFile 0 errors; 0 non-ASCII bytes. Note: working tree incl. uncommitted T-0052 T2; HEAD ParseFile also clean. Real-host sub-items: not recorded (unit tests 1a, 1b, 4a, 8a, 8b, 8e only).
  - The real dry run stops at step 0 without writing only while RebootPending is set.
  - Re-runs do not reinstall or overwrite backups: exports and before reports are once per label; the download is reused when its hash matches.
- [ ] AC-D: D1-D6 and D8 pass on the real desktop, with evidence (D7 later, per Slice 3 task).
- [ ] AC-WSL (measured, Slice 4; partial: sys-readiness exit 0, sys-update selection-diff in sync, timezone, per final-run-2026-11-16.md; measured 2026-11-16 ~01:50 UTC, non-elevated; open items need the user):
  - sys-install, sys-update, nix flake check: report exit 0, flake check passed; sys-install not run
  - Docker (when enabled): not enabled (n/a)
  - Claude + Codex: OPEN (not installed; update timers skip via ConditionPathExists, ai-cli-updates.nix:41; findings #40)
  - statusline: entry present, not exercised
  - tailnet: OPEN (Tailscale not on Windows; findings #41)
  - restart keeps user/systemd/interop: yes
  - origin not /mnt; ~/Projects on ext4 (findmnt: ext4): yes
  - timezone; substituters: Europe/London; cache.nixos.org
  - Measurements: final-run-2026-11-16.md, "Acceptance measurements".
- [ ] AC-NEG: macOS, linux-desktop, linux-cli unchanged (full bats, flake check, builds). No force-push. No `wsl --unregister` scripted.
  - Partial evidence (2026-11-16 ~01:50 UTC): `nix flake check` passes on the WSL host; `nix build --dry-run` of homeConfigurations.linux-cli and linux-desktop activationPackage exit 0 (evaluation only, not built); macOS not checked (no darwin host).
  - Partial evidence (final-run health check): `--unregister` appears in ops/ only as user-facing text in ops/windows/bootstrap.ps1 (the two "never scripted" `Say` lines; 1100 and 1325 at 8f6b4eb); no scripted `wsl --unregister`.
  - Partial evidence (final-run B1, from the run agent's log, not re-run): full bats 1766/1766 and `nix flake check` on 8316e94. Per-host builds and the no-force-push condition are not recorded: unknown.
- [x] AC-TZ: decided: WSL keeps the sys-setup zone Europe/London and Windows is set to match ("GMT Standard Time", T-0048 windows.yaml). Evidence: evidence/final-run-2026-11-16.md (Europe/London, GMT inside WSL).
- [x] AC-DOCKER-MSG: `ws_ensure_docker` in ops/projects/workspace/config.sh no longer recommends Docker Desktop WSL integration (Slice 2b). Done: `fix(workspace): point the missing-Docker error at sys-setup, not Docker Desktop`.

## Transfer (push/pull)

Commit + push to origin authorised by the user 2026-11-15 (replaces the git bundle).

Transfer-0 (Windows): three commits, order A, B, C (path-contract). Each after `git pull --ff-only` and `bash ops/hooks/pre-commit.sh` (validate-config, gitleaks protect --staged, conflict markers, .env check, ops/doctor.sh); each pushed right after with `git push origin main`.

| Commit | Files | Subject |
|--------|-------|---------|
| A | docs/work/active/T-0048-cross-os-settings/ | `docs(settings): T-0048 Windows settings inventory` |
| B (planned 6 files; actual 28c588b: 9 files, adding docs/platforms/wsl/expected-results.md and the two h1 evidence files) | docs/work/active/T-0047-nixos-wsl/{ticket,plan}.md, docs/work/index.md, docs/platforms/wsl/setup.md, docs/platforms/wsl/windows-and-wsl.md, docs/platforms/windows/setup.md | `docs(wsl): plan T-0047 NixOS-WSL desktop-first` |
| C | docs/platforms/index.md, docs/platforms/base.md, README.md, docs/index.md | `docs(setup): add the setup index and base requirements` |

- The Windows clone has no hooks installed; run the hook script by hand after staging.
- Never bypass a failing hook. Never force-push, rebase or stash (shared stash, AGENTS.md).
- If a pull could collide with uncommitted work, save it first: `git diff --binary HEAD > <private>/windows-wip.patch`, plus a copy of untracked files.

Transfer-1..3 (NixOS desktop and Windows, later)
- Before work and before each commit: `git pull --ff-only`. Push right after the commit.
- Desktop: `git pull --ff-only`, then the baseline and D0.
- Windows: `git pull --ff-only` after the desktop session pushes its SHAs.

Validation split, recorded separately in the evidence
- Windows: the pre-commit.sh output on the staged docs. Record that the gitleaks scan actually ran (its output) and the validate-config result.
- NixOS desktop, after the pull/ff-merge (bats reads the working tree): `bats tests/bash/path-contract.bats tests/bash/doc-contracts.bats`.

## Coordination (two sessions)

| Session | Owns |
|---------|------|
| Windows (`___W11_WSL2_SETUP`) | ops/windows/**, tests/windows/**, docs/platforms/windows/**, docs/platforms/wsl/**, docs/platforms/index.md, docs/platforms/base.md, docs/work/active/T-0048-*/**, the T-0047 plan.md, Slice 2b |
| NixOS (`all-reviewed-landing`) | D0 files: nix/modules/nixos/wsl.nix, ops/system-setup.sh, nix/hosts/wsl/home.nix, ops/lib/preflight.sh, ops/readiness.sh, tests/bash/{system-setup,nix-identity,nixos-wsl-module,readiness}.bats; the later Slice 3 files; evidence/d0-*.md and evidence/s3-*.md; the D-table Pass/Fail cells |

- Shared, append-only: docs/work/index.md (own rows only).
- Shared: README.md. The Windows session added the setup link; the NixOS session edits it in S3-2. Pull before editing.
- Shared: this ticket. The NixOS session edits only the Pass/Fail cells and evidence links.
- Handoff: the NixOS session commits, pushes, and notifies the Windows session with SHAs and D1-D8 results.

## Reboot points
- R1: the edition upgrade or a pending update. The bootstrap refuses while pending.
- R2: after `wsl --install --no-distribution`.

## Open
- None blocking.
- Unknowns, verified in H1/H2:
  - NixOS-WSL tag and asset digest
  - whether the stock config enables flakes
  - wheelNeedsPassword
  - removal of the `nixos` user
- H1 is an intentionally incomplete install, not a success. After R2 a normal run checks the WSL version, imports NixOS, runs nix-channel and the systemd/interop check, then stops at the D0 gate (step 6, exit 3). The before-setup report and export run in H2. (WSL itself is installed by the elevated run before R2.)
- Follow-up proposal (separate change, not this work): ops/hooks/pre-commit.sh uses `gitleaks protect --staged`, deprecated since gitleaks v8.19.0 (still works). The maintained form is `gitleaks git --staged`.
- No passwd step in the script. Only if sudo asks, from Windows: `wsl -d NixOS -u root passwd utmostcreator`.
- The distro installs via `wsl --import NixOS` (not `--from-file`).
