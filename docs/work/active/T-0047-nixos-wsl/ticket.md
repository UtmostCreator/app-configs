Source: local

# T-0047: WSL2 on NixOS-WSL, desktop-first (feature)

Status: done, pending human (WSL verified at 531c4d8; owner: personal.yaml (b), Claude/Codex login, tailscale up, SKIP_HOOKS (d); (e) open). SHAs remapped to main after the 2026-11-18 rewrite; originals in backup-18-11-2026
Depends on: none to start. Slice 3 items: T-0038, T-0035, T-0045(a).
Blocks: T-0040 (acceptance = Slice 4 here)
Supersedes: T-0034 (reports live in bootstrap.ps1 -Report), T-0039 (folded in)
Coordinates with: T-0029
Plan: [plan.md](plan.md)

Written 2026-11-15 against main 0af3215.

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

Real commits (`git log --oneline 846f7dc..8f68d9b`, 20 commits, fast-forwarded to origin/main 2026-11-16). Those in the fix stack (subject-matched, not individually proven to serve T-0047):

| SHA | Subject |
|-----|---------|
| 9593781 | fix(nixos-wsl): give the WSL mount-guard unit a NixOS path and keep activated configs on unit failures |
| ef759a7 | fix(setup): treat activate-script failures as activated and spell out the rollback restore |
| 7bc78f3 | test(setup): pin the host-dependent user and PATH checks so CI matches |
| 0afd4ab | fix(install): stop installing home-manager into the profile it will collide with |
| 4a3dd20 | feat(install): announce long waits and keep a heartbeat going (T-0050) |
| 6041cf5 | feat(hooks): route every hook install through ops/install-git-hooks.sh |
| db6caaf | feat(hooks): refuse partially staged commits before lefthook can stash |
| 6224d4b | docs(hooks): document partial commits and the hook installer |
| 489a3d6 | fix(update): do not suggest git stash in the dirty-tree hint |

The other 11 commits of the range are not T-0047 work (they rode along in the same fast-forward): 8f68d9b fix(fish) Ctrl+C, 0b24c6c, d687428, 9159a5e, 71b173e, baae978 (git aliases), 9379257, cf541e6, 1294cbe (ssh), 0eb7d4d (git docs), 163439e (terminal scrollback). Run 5 failed at bootstrap step 12 (Home Manager collision); 0afd4ab likely fixed it (inferred from its subject, not re-measured).

Earlier T-0047 commits (`git log --oneline --grep T-0047`; 846f7dc is T-0052/ADR-0016 and is not listed here):

| SHA | Subject |
|-----|---------|
| 0654c1e | feat(windows): add the NixOS-WSL bootstrap script and its tests |
| 2b44a49 | docs(wsl): plan T-0047 NixOS-WSL desktop-first |

Related commits that do not carry the id in the subject (found by subject, before 846f7dc): f9de009 (NixOS-WSL module and wsl-nixos home output), 6ceea7b (one fail-closed Home Manager output helper), bfa3272 (sys-setup wiring with dry-build and exact restore), 571f1b6 (system tools for install on NixOS-WSL), c87ac4d (ADR-0015, T-0051, T-0050 findings), e9549bf and 2e5511c (T-0051: personal-data guard script, installer in bootstrap step C).

Findings (issues met during the setup, with status and owner): [findings.md](findings.md). Evidence: [evidence/final-run-2026-11-16.md](evidence/final-run-2026-11-16.md) (includes the final health check), with the H1 files it builds on. Commit-message audit of the published commits: [evidence/commit-traceability-audit-2026-11-16.md](evidence/commit-traceability-audit-2026-11-16.md).

Open after the final run (details and owners: evidence file, same heading):

- (a) Windows hooks: RESOLVED. `--check` fixed by dde8fd8 (exit 0 on Windows and WSL, 2026-11-16); 4 real commits from the Windows clone (ed9ba6f, 41207e5, 9b3a271, 531c4d8) passed the pre-commit hooks (no-personal-yaml; ops/hooks/pre-commit.sh: gitleaks, doctor.sh, validate-config.sh); the 4 commits, including the Windows code commit 531c4d8, landed before AC-T2 was fully met. Evidence: final-run-2026-11-16.md, "Post-landing verification".
- (b) Git name and email in personal.yaml, then `chezmoi --source="$HOME/app-configs" apply`. Owner: the user. The last user action for the WSL2 setup; unticked ACs stay open until met or deferred.
- (c) codebase-memory-mcp-ui restart loop (missing ~/Projects, CBM_ALLOWED_ROOT): RESOLVED. Repo fix ba7061b applied by `bash ops/update-all.sh --apply --yes` at 531c4d8 (exit 0; HM generation 2); unit healthy, NRestarts=0; the fresh-home path was not exercised on this PC (~/Projects already existed). A clone from before it needs the pull plus an apply.
- (d) Keep or remove the SKIP_HOOKS=1 escape hatch in ops/hooks/pre-push.sh. Owner: the user (decision). Follow-up.
- (e) WSL git over SSH: WSL has no SSH key; the key is in the Windows ssh-agent. Working setup on this PC: `git -C ~/app-configs config --local core.sshCommand /mnt/c/Windows/System32/OpenSSH/ssh.exe`. Follow-up: make it permanent for fresh installs (chezmoi / Home Manager change). Owner: not assigned.
- The nix repo-audit and codebase-memory-mcp-update user units fail on WSL: they located the repo via `chezmoi source-path`, which points at a missing dir. Fixed in 9878bd6 (on origin/main). Verified on WSL at 531c4d8 after the apply: repo-audit.service success (PASS 8 / WARN 0 / FAIL 0), `systemctl --user --failed` 0 units. (Before the apply the old unit was still installed and failed.)
- The bats tests leak 1Password `op daemon` processes. f8856b0 (on origin/main) fixes the fish greeting test; other leaking tests: unknown. Owner: all-reviewed-landing.
- fish ssh-agent fix landed in 211c639 and a161787 (on origin/main): verified after the apply at 531c4d8, `fish -ic true` exit 0 with no error (before it: "Unsupported use of '='" from ssh-agent.fish:83).
- User steps for AC-WSL: log in to Claude Code and Codex in WSL (the binaries are installed: Claude Code 2.1.325 at ~/.local/bin/claude, Codex 0.169.0 at ~/.local/bin/codex, installed 2026-11-16, versions checked during the final run and re-observed in ~/.local/bin on 531c4d8; the apply warned both are not signed in, ai-auth-status checks credentials only). The Codex installer appended a PATH line to ~/.profile (not chezmoi-managed); whether S3-5 (ai-cli-install, not built) should handle it is open; Tailscale is installed on Windows (1.104.7, service Running, StartType Automatic; read-only inventory 2026-11-16): log in (`tailscale up`).
- Owner decisions, open: the Co-Authored-By / Claude-Session trailers on the 4 landed commits, against repo convention (rewriting needs a force-push); SKIP_HOOKS=1 (d); U2 (whether the M365 Copilot (OfficeHub) startup entry stays enabled); T-0055 (planned as ADR-0020 under ADR-0019, not in 531c4d8).
- CLAUDE.md: the edit adds a protected-action grant ("or if user says all permissions lifted"), unknown author; the patch is saved at $HOME/claude-md.patch on Windows and was not reapplied; the user decides (findings #17).
- tests/bash/path-contract.bats needs python3, which is not on the plain WSL PATH: it passes 10/10 via `nix shell nixpkgs#python3 -c bats ...`. Upstream 7b246e9 (not in 531c4d8) skips path-contract without python3 (follow-up, owned by the NixOS session). Resolved in the repo (owner decision 2026-11-17): `nix/modules/home/dev.nix` now declares python3 (with lizard and pytest) for every host; it reaches WSL at the next `sys-update`. Live removal of the desktop `python312` profile element is pending. Owner live steps, in order: (1) after this lands, `nix profile list` (element `python312`); (2) `nix profile remove python312` (python3 is missing from PATH until step 3); (3) run `sys-update`, not `hms` or a bare `home-manager switch`; (4) check `type -a python3` shows only ~/.nix-profile/bin/python3 (python3-3.14.10-env), `python3 -c 'import lizard, pytest'` works, and `bats tests/bash` passes; (5) WSL: remove any python profile element the same way, then `sys-update`. Note: sys-update's package report skips `*-env` paths (update-facts.sh:73), so its first run lists lizard and pytest as removed and never shows python3 (follow-up, not changed here).
- Other follow-ups (not done here):
  - Stale setup.md line references in the T-0037 ticket:34 and T-0038 ticket:26; followups.md:18 "WSL validation" is partly stale.
  - ADR status lines: ADR-0015 ("not yet implemented; Ubuntu path untested") and ADR-0001 ("not yet verified on a real WSL install") still carry their pre-run text, while their frontmatter and index rows say `decided-unverified`. Moving either to `decided` after the 2026-11-16 NixOS-WSL run is an ADR edit for the owner; not done here. The ADR-0001 consequence line may also be stale.
  - T-0051 should record the _lefthook.sh case (owner `all-reviewed-landing`).
  - T-0048 should capture the Windows time format (key missing in windows.yaml; see AC-TZ evidence).
  - sys-readiness `chezmoi verify` needs `--source=$HOME/app-configs` (false "pending" on WSL; `ops/readiness.sh:73`). Landed in 0b08838 and 5c31d98 (on origin/main); verified on WSL at 531c4d8: readiness exit 0, ALL SET, 45 OK / 1 TODO (no Docker daemon), the chezmoi TODO is gone.
  - sys-update (`ops/update-all.sh` dotfile step and its status/diff/verify checks), `ops/audit.sh` and `ops/bootstrap.sh` called chezmoi without `--source` on WSL, so `sys-update --apply` could not apply dotfiles there. Fixed on origin/main: shared helper `ops/lib/chezmoi-source.sh` (3bd6166), applied by e45b995 and 5c31d98; verified on WSL at 531c4d8 for `update-all.sh` (report mode uses `--source=/home/utmostcreator/app-configs`; `--apply --yes` applied 9 files, exit 0); `ops/bootstrap.sh` not re-run: unknown. Plain `chezmoi` commands still need `--source="$HOME/app-configs"` (for example `chezmoi --source="$HOME/app-configs" apply`).
  - Commit-message gate (proposal): [evidence/commit-traceability-audit-2026-11-16.md](evidence/commit-traceability-audit-2026-11-16.md).

## Acceptance criteria
- [x] AC-B1: `wsl.defaultUser = lib.mkForce "utmostcreator"` in a WSL-only module.
  - Code: met. nix/modules/nixos/wsl.nix:30 sets `wsl.defaultUser = lib.mkForce "utmostcreator"` (WSL-only module; comment at :10 notes the stock "nixos" value).
  - Build passes: met (the live system was built and switched with it).
  - WSL launches as utmostcreator: met (/etc/wsl.conf default=utmostcreator; `id utmostcreator` works; the final run ran as that user).
  - A test proves a stock "nixos" value loses: met. 2026-11-16 ~02:05 UTC, WSL non-elevated, clean clone at dde8fd8: `bats tests/bash/nixos-wsl-module.bats` 4/4 ok, exit 0 (B1 stock "nixos" loses to the module's mkForce; B1 control: without mkForce the same definitions conflict; 2 wsl module tests).
  - Measurements: final-run-2026-11-16.md, "Acceptance measurements".
- [ ] AC-B2: as D2b, plus /etc/nixos file state unchanged after a dry-build or validation failure. On a switch failure, print `nixos-rebuild switch --rollback`.
- [ ] AC-T1: bootstrap tests pass, ParseFile, ASCII. Evidence 2026-11-16 ~01:45 UTC: 176 passed, 0 skipped, 0 failed; ParseFile 0 errors; 0 non-ASCII bytes. Note: working tree incl. then-uncommitted T-0052 T2 (now committed as 531c4d8; tests not re-run at 531c4d8); HEAD ParseFile also clean. Post-landing: non-elevated `bootstrap.ps1 -DryRun` exit 0, no WARN/ERROR (on dde8fd8 + T2). Still open: the RebootPending real dry run is not recorded (unit tests 1a, 1b, 4a, 8a, 8b, 8e only).
  - The real dry run stops at step 0 without writing only while RebootPending is set.
  - Re-runs do not reinstall or overwrite backups: exports and before reports are once per label; the download is reused when its hash matches.
- [ ] AC-D: D1-D6 and D8 pass on the real desktop, with evidence (D7 later, per Slice 3 task).
- [ ] AC-WSL (measured, Slice 4; partial: sys-readiness exit 0, sys-update selection-diff in sync, timezone, per final-run-2026-11-16.md; measured 2026-11-16 ~01:50 UTC, non-elevated; open items need the user):
  - sys-install, sys-update, nix flake check: report exit 0, flake check passed; sys-install not run. Post-landing at 531c4d8: `update-all.sh` report exit 0; `--apply --yes` exit 0 (26 ok / 1 warning / 0 errors, Home Manager generation 1 to 2); readiness exit 0, ALL SET (45 OK, 1 TODO: no Docker daemon). `nix flake check` not re-run at 531c4d8: unknown.
  - Docker (when enabled): not enabled (n/a)
  - Claude + Codex: OPEN (login only: Claude Code 2.1.325 and Codex 0.169.0 are installed in ~/.local/bin since 2026-11-16; earlier measurement "not installed", findings #40, is superseded. The 531c4d8 apply warned both are not signed in; login is an owner step; subagent spawn and statusline not exercised)
  - statusline: entry present, not exercised
  - tailnet: OPEN (login only: Tailscale 1.104.7 is installed on Windows, service Running, StartType Automatic, observed 2026-11-16; the earlier "not installed" measurement, findings #41, is superseded; owner step `tailscale up`)
  - restart keeps user/systemd/interop: yes
  - origin not /mnt; ~/Projects on ext4 (findmnt: ext4): yes
  - timezone; substituters: Europe/London; cache.nixos.org
  - Measurements: final-run-2026-11-16.md, "Acceptance measurements".
- [ ] AC-NEG: macOS, linux-desktop, linux-cli unchanged (full bats, flake check, builds). No force-push. No `wsl --unregister` scripted.
  - Partial evidence (2026-11-16 ~01:50 UTC): `nix flake check` passes on the WSL host; `nix build --dry-run` of homeConfigurations.linux-cli and linux-desktop activationPackage exit 0 (evaluation only, not built); macOS not checked (no darwin host).
  - Partial evidence (final-run health check): `--unregister` appears in ops/ only as user-facing text in ops/windows/bootstrap.ps1 (the two "never scripted" `Say` lines; 1100 and 1325 at dde8fd8); no scripted `wsl --unregister`.
  - Partial evidence (final-run B1, from the run agent's log, not re-run): full bats 1766/1766 and `nix flake check` on 8f68d9b. Per-host builds and the no-force-push condition are not recorded: unknown.
- [x] AC-TZ: decided: WSL keeps the sys-setup zone Europe/London and Windows is set to match ("GMT Standard Time", T-0048 windows.yaml). Evidence: evidence/final-run-2026-11-16.md (Europe/London, GMT inside WSL).
- [x] AC-DOCKER-MSG: `ws_ensure_docker` in ops/projects/workspace/config.sh no longer recommends Docker Desktop WSL integration (Slice 2b). Done: `fix(workspace): point the missing-Docker error at sys-setup, not Docker Desktop`.

## Transfer (push/pull)

Commit + push to origin authorised by the user 2026-11-15 (replaces the git bundle).

Transfer-0 (Windows): three commits, order A, B, C (path-contract). Each after `git pull --ff-only` and `bash ops/hooks/pre-commit.sh` (validate-config, gitleaks protect --staged, conflict markers, .env check, ops/doctor.sh); each pushed right after with `git push origin main`.

| Commit | Files | Subject |
|--------|-------|---------|
| A | docs/work/active/T-0048-cross-os-settings/ | `docs(settings): T-0048 Windows settings inventory` |
| B (planned 6 files; actual 2b44a49: 9 files, adding docs/platforms/wsl/expected-results.md and the two h1 evidence files) | docs/work/active/T-0047-nixos-wsl/{ticket,plan}.md, docs/work/index.md, docs/platforms/wsl/setup.md, docs/platforms/wsl/windows-and-wsl.md, docs/platforms/windows/setup.md | `docs(wsl): plan T-0047 NixOS-WSL desktop-first` |
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
