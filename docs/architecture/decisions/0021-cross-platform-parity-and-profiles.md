---
adr: 21
title: "Cross-platform parity, the native exception, host profiles and one owner per binary"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [tool-selection, parity, profiles, path-owners, audit]
permits: [linux-macos-parity, windows-follows-winget, native-exception-with-owner-approval, per-host-profile, owner-duplicate-allowlist]
forbids: [mandatory-driver-install, removing-hm-copy-of-allowlisted-duplicate]
amends: [11]
supersedes: []
superseded_by: []
related: [14, 19, 20, 34, T-0029, T-0041, T-0042]
---
# ADR-0021: Cross-platform parity, the native exception, host profiles and one owner per binary
Status: partly-decided (P1, P2a, P3a, P4 and the P5a gate are owner-decided 2026-11-16; the P2b test wording, the P3b definitions, P5b and P6 are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 · Sources: tool-selection design round 3, T-0042

Cites [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md) (Windows additions need an owner decision; the quotes below are that decision). This is the parity and profile authority for the per-category tool-selection ADRs 0022 to 0033, 0036 and 0037; they cite it and do not restate it. ADR-0020 (`-SetupProfile`, Windows built-ins), ADR-0034 and ADR-0035 keep their own mechanics.

## Notation
- Status per row: one of D (decided), DU (decided-unverified), Pr (proposed), O<n> (open owner question n).
- Profile: P = personal (the owner's "home", ADR-0020 `-SetupProfile personal`); W = work.
- Tags, separate from status: Ex (R1 native exception), CM (can't match: no supported install owner for the parity pick on that OS), OS (a job on one OS only), Exempt (owner-decision exemption; no R1 test).

## Owner decisions (2026-11-16, quoted)
- Parity: "0021 option A" (Linux and macOS parity; Windows follows when winget has the tool).
- R1: "we must not sacrifice much features if macos or windows 11. so if native app for any of the systems is free and better we might consider it".
- R2: "ensure work profile won't have drivers as mandatory because video card could be AMD or Nvidia so we must be careful home profile Nvidia ok".
- R3: "check other software programming only in work setup for windows so any suspects must be selected carefully for work profile".
- Host profiles: "all should have personal/home work/corporate. focus on simple for now if it adds complexity nixos personal for now as is macos work (only for now OK as is), windows both".
- P5 gate: no host profile changes now; rows that change a host's default derivation are not applied (owner settled this 2026-11-16).

## Decision
One status per row.

| Row | Rule | Status |
|---|---|---|
| P1 Parity | Option A. One tool per job on each in-scope OS that has an unattended install owner (nixpkgs/Home Manager, or a cask that is not disabled; WSL counts for CLIs). Windows follows when winget has the tool. A tool with no Windows build is not disqualified | D 2026-11-16 (owner: "0021 option A") |
| P2a R1 rule | A native, free, better app on macOS or Windows may be considered instead of the parity pick (R1 quote above) | D 2026-11-16 (owner quote) |
| P2b five-part test wording | An Ex row must pass all five tests: (a) free under its licence for that profile; (b) native or built in; (c) closes a named feature gap against the parity pick; (d) is a dated row naming the gap, the replaced pick and a revisit trigger; (e) has a dated owner approval. Without (e) the row stays Pr. CM and Exempt (for example HeidiSQL; no trigger needed) are separate from R1 | Pr |
| P3a Profile rules | R2 and R3 quotes above. Drivers and device software are never mandatory. GPU-vendor items are P only (consistent with ADR-0034's forbids `mandatory-driver-install` and `work-profile-gpu-settings`). A suspect app is in W only through an explicit W row | D 2026-11-16 (owner quotes) |
| P3b W and suspect definition | W = programming plus employer-required work tools; nothing personal. Suspect screening applies on every OS: kernel drivers, personal-use-only licences, LAN listeners, unofficial clients, overlays, meeting recorders, AI or data-egress features | Pr |
| P4 Host profiles | linux-desktop = personal (`nix/hosts/linux-desktop/home.nix:26`). macOS, WSL and linux-cli = work (the default, `nix/modules/home/profile.nix:65`). Windows = chosen per run through ADR-0020's `-SetupProfile personal\|work`, which has no default | D 2026-11-16 (owner quote) |
| P5a Gate | No host profile changes now. Rows that would change a host's default derivation are recorded and not applied | D 2026-11-16 (owner) |
| P5b Applying rows | Applied after acceptance: only owner-decided rows that need no new mechanism. macOS rows that need a profile have no install owner until T-0042 reopens groups: the approved decision allows only the macOS cask group `macInput` (T-0042:238), the extension is still proposed (:256-257), and per-package toggles are out (:218). Such rows are marked "needs a T-0042 group (Q2/Q4/Q9/Q10, T-0042 section 7 :543-555)". Windows built-ins belong to ADR-0020; on macOS and Linux, workComms apps are offered but off by default (T-0042 Q4 and AC-N6, :318, :356, :495, :548). This answers T-0042 open question 2 ("What should each profile actually turn off?", :198) for now: nothing. The P/W columns of ADRs 0022 to 0037 are the target once T-0042's groups land | Pr |
| P6 One owner per binary | ADR-0014 assigns owners per concern; this row adds a per-binary rule with the owner directories and allowlist below, enforced by a planned check | Pr |

## P6: owner directories
1. Home Manager: the `home-manager-path` element of the user's nix profile, and on macOS the nix-darwin HM directory `/etc/profiles/per-user/<user>/bin` (`useUserPackages`, `nix/flake.nix:195-201`).
2. Other imperative nix profile elements: only chezmoi, mise, home-manager and lefthook are allowed. This four-element allowlist is new. Today `live_nix_profile` only flags files that collide with Home Manager (`ops/lib/profile-conflicts.sh:19-46`; `ops/audit.sh:349`, `:368-371`); the planned `live_owner_duplicates` check enforces the allowlist. Known violations today (live inventory): six imperative elements, gcc, gnumake, gnupg, python312, sqlite and yamllint, are installed, so the allowlist is already broken; see the known-violations table below (keep or remove follow-up, proposed).
3. `/run/current-system/sw/bin` (NixOS, and nix-darwin on macOS).
4. The Homebrew prefix: `bin`, plus `opt/*/bin` for keg-only formulae.
5. mise installs and shims.
6. `~/.local/bin`: vendor binaries (ADR-0006) and chezmoi scripts.

Not owners: OS base directories (`/usr/bin`, `/bin`, `/usr/sbin`, the macOS `/usr/bin/git` and `curl` shims, Ubuntu's apt `/usr/bin/docker`). They are ignored; PATH order decides which copy runs. The NixOS base and desktop-module packages (for example xz, man-db, glib, shared-mime-info, wireplumber) also appear in /run/current-system/sw/bin and duplicate Home Manager copies; the NixOS base set is ignored like the OS base directories, so the planned WARN does not flag it. Only packages the repo or the hand-edited system configuration add on top of that set are checked.

## P6: allowlist of intentional duplicates
| Binary | Where it comes from | Why both stay |
|---|---|---|
| fish | NixOS `programs.fish` (`ops/system-setup.sh:512`, programs.fish.enable) and Home Manager (`nix/modules/home/cli.nix:21`) | the system copy is the login shell; the HM copy is the interactive tool set |
| git, curl | HM `nix/modules/common/packages.nix:8-16` on every host; the NixOS-WSL system (`ops/system-setup.sh:503-505`); curl also comes from the NixOS base packages on the desktop, while git is not in the desktop system path | bootstrap needs them before Home Manager exists |
| docker | HM `nix/modules/home/dev.nix:88` and `nix/modules/nixos/docker.nix:59`. The HM `docker` is the full package (CLI plus moby daemon binaries; dockerd resolves to moby), not only the CLI; ADR-0030 proposes docker-client as an optional row | until the 0030 docker-client row is decided, the allowlist covers the full HM docker package (including dockerd, containerd and runc); docker-client still ships the HM docker binary. HM is the only owner on hosts without NixOS (Ubuntu WSL, linux-cli non-NixOS, macOS); on NixOS the daemon module adds a second copy (see ADR-0030) |

The HM copy of an allowlisted duplicate is never removed.

## P6: known violations (not allowlisted)
Found by the live inventory of the linux-desktop host. Each is proposed for removal or a decision; none is applied by this ADR. HM wins on PATH for all system copies.

| Item | Where it comes from | Follow-up | Status |
|---|---|---|---|
| brave, keepassxc, neovim, vscode, opencode, wget (system copies) | the hand-edited /etc/nixos/configuration.nix environment.systemPackages (lines 150-161 as of 2026-11-16; machine-local, will drift). HM wins: vscode 1.119 vs 1.146, neovim 0.12.2 vs 0.12.6, opencode 1.15.13 vs 2.2.6 | remove the system copies: T-0029 | Pr |
| firefox (system copy) | programs.firefox.enable in the hand-edited /etc/nixos/configuration.nix (line 146 as of 2026-11-16; machine-local, will drift) | remove: T-0029 | Pr |
| universal-ctags (system copy) | the hand-edited /etc/nixos/configuration.nix environment.systemPackages, not `nix/modules/nixos/default.nix` (that module has no consumer; see T-0029:34 and :42). Unintended: no reason recorded in commit 315b9f5 | remove the system copy: T-0029 | Pr |
| gcc, gnumake, gnupg, python312, sqlite, yamllint (imperative nix profile elements) | outside the four-element allowlist | per element: keep (move into Home Manager) or remove (new follow-up row). python312: resolved in the repo by `python3` in `nix/modules/home/dev.nix` (owner decision 2026-11-17); live removal pending: `nix profile remove python312` (both provide `bin/python3`; sys-update and `ops/lib/hm-switch.sh` callers stop on the collision, but `hms` or a bare `home-manager switch` does not check and strands PATH, so remove python312 first, then run sys-update; ordered steps in T-0047 ticket). sys-update's package report skips `*-env` paths, so its first run will list lizard and pytest as removed and never show python3 | Pr |
| rg, fd, jq, node, shellcheck, actionlint (mise global shadows of the HM copies) | mise globals | remove: ADR-0014 makes mise per-project only, and ADR-0021 asks for one owner | Pr |
| uv in ~/.local/bin, first on PATH before the HM uv | owner directory 6 allows only vendor binaries (ADR-0006) and chezmoi scripts | remove | Pr |

## P6: the planned check
- `live_owner_duplicates` in `ops/audit.sh --live` (planned, not yet written; the check, not the ADRs). It skips what `live_nix_profile` already reports.
- Severity WARN, not FAIL: the repo-audit timer runs `--live` and raises a toast on any FAIL (`nix/modules/home/scripts/repo-audit.sh:71-77`).
- Tests: planned tests/bash/audit-owner-duplicates.bats (not yet created), with seeded directories, one allowlisted and one unlisted duplicate. A change to `ops/audit.sh` or `ops/lib/*` runs the full `bats tests/bash` suite (AGENTS.md).
- The planned check must define how it recognises the NixOS base and desktop-module set (for example system-path entries not declared by the repo systemPackages or programs.* settings or by the hand-edited configuration, computed from an eval or from a named static list), and the planned audit-owner-duplicates.bats gets a case for it. The method is left to follow-up I-01.

## Consequences
- Nothing is applied by this ADR: no host profile change, no removal, no code. ADR-0011 gets a note.
- ADRs 0022 to 0033, 0036 and 0037 cite this one for parity, profiles and the native exception.
- The P/W split stays a target for macOS until T-0042 groups land; the macOS work host keeps its current apps.
- Unknown: employer policy for W rows; PATH order for allowlisted duplicates (check with `type -a <binary>`).
