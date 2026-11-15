Source: local

# T-0047: WSL2 on NixOS-WSL, desktop-first (feature)

Status: open
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
- Transfer: push/pull (commit + push to origin authorised 2026-11-15; replaces the git bundle). Each session confirms its push authorisation for its own task (AGENTS.md: authorisation does not carry over).
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

## Acceptance criteria
- [ ] AC-B1: `wsl.defaultUser = lib.mkForce "utmostcreator"` in a WSL-only module.
  - Build passes.
  - WSL launches as utmostcreator.
  - A test proves a stock "nixos" value loses.
- [ ] AC-B2: as D2b, plus /etc/nixos file state unchanged after a dry-build or validation failure. On a switch failure, print `nixos-rebuild switch --rollback`.
- [ ] AC-T1: bootstrap tests pass, ParseFile, ASCII.
  - The real dry run stops at step 0 without writing only while RebootPending is set.
  - Re-runs do not reinstall or overwrite backups: exports and before reports are once per label; the download is reused when its hash matches.
- [ ] AC-D: D1-D6 and D8 pass on the real desktop, with evidence (D7 later, per Slice 3 task).
- [ ] AC-WSL (measured, Slice 4):
  - sys-install, sys-update, nix flake check
  - Docker (when enabled)
  - Claude + Codex (+ update services, a subagent spawn)
  - statusline
  - a WSL restart keeps the user, systemd and interop
  - origin not /mnt; ~/Projects on ext4
  - tailnet reachable from WSL via Windows Tailscale
  - timezone; substituters
- [ ] AC-NEG: macOS, linux-desktop, linux-cli unchanged (full bats, flake check, builds). No force-push. No `wsl --unregister` scripted.
- [ ] AC-TZ: decide the timezone in Slice 4 (sys-setup forces Europe/London via mkForce vs Windows' zone) and record the decision.
- [ ] AC-DOCKER-MSG: ops/projects/workspace/config.sh:88-89 no longer recommends Docker Desktop WSL integration (Slice 2b).

## Transfer (push/pull)

The user authorised commit + push to origin (2026-11-15); this replaces the git bundle.

Transfer-0 (Windows): three commits, order A, B, C (path-contract). Each after `git pull --ff-only` and `bash ops/hooks/pre-commit.sh` (validate-config, gitleaks protect --staged, conflict markers, .env check, ops/doctor.sh); each pushed right after with `git push origin main`.

| Commit | Files | Subject |
|--------|-------|---------|
| A | docs/work/active/T-0048-cross-os-settings/ | `docs(settings): T-0048 Windows settings inventory` |
| B (6 files) | docs/work/active/T-0047-nixos-wsl/{ticket,plan}.md, docs/work/index.md, docs/platforms/wsl/setup.md, docs/platforms/wsl/windows-and-wsl.md, docs/platforms/windows/setup.md | `docs(wsl): plan T-0047 NixOS-WSL desktop-first` |
| C | docs/platforms/index.md, docs/platforms/base.md, README.md, docs/index.md | `docs(setup): add the setup index and base requirements` |

- The Windows clone has no hooks installed; run the hook script by hand after staging.
- Each session confirms its push authorisation for its own task (AGENTS.md: authorisation does not carry over).
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
| NixOS (`__AppConfigs_fixes`) | D0 files: nix/modules/nixos/wsl.nix, ops/system-setup.sh, nix/hosts/wsl/home.nix, ops/lib/preflight.sh, ops/readiness.sh, tests/bash/{system-setup,nix-identity,nixos-wsl-module,readiness}.bats; the later Slice 3 files; evidence/d0-*.md and evidence/s3-*.md; the D-table Pass/Fail cells |

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
