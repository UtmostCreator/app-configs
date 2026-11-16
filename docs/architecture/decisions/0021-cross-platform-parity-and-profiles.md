---
adr: 21
title: "Cross-platform parity, the native exception, host profiles and one owner per binary"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [tool-selection, parity, profiles, path-owners, audit]
permits: [linux-macos-parity, windows-follows-winget, native-exception-with-owner-approval, per-host-profile, owner-duplicate-allowlist]
forbids: [mandatory-driver-install, removing-home-manager-copies]
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
2. Other imperative nix profile elements: only chezmoi, mise, home-manager and lefthook are allowed. This four-element allowlist is new. Today `live_nix_profile` only flags files that collide with Home Manager (`ops/lib/profile-conflicts.sh:19-46`; `ops/audit.sh:349`, `:368-371`); the planned `live_owner_duplicates` check enforces the allowlist.
3. `/run/current-system/sw/bin` (NixOS, and nix-darwin on macOS).
4. The Homebrew prefix: `bin`, plus `opt/*/bin` for keg-only formulae.
5. mise installs and shims.
6. `~/.local/bin`: vendor binaries (ADR-0006) and chezmoi scripts.

Not owners: OS base directories (`/usr/bin`, `/bin`, `/usr/sbin`, the macOS `/usr/bin/git` and `curl` shims, Ubuntu's apt `/usr/bin/docker`). They are ignored; PATH order decides which copy runs.

## P6: allowlist of intentional duplicates
| Binary | Where it comes from | Why both stay |
|---|---|---|
| fish | NixOS `programs.fish` (`ops/system-setup.sh:513`) and Home Manager (`nix/modules/home/cli.nix:21`) | the system copy is the login shell; the HM copy is the interactive tool set |
| git, curl | HM `nix/modules/common/packages.nix:8-16` on every host, and the NixOS-WSL system (`ops/system-setup.sh:504-506`) | bootstrap needs them before Home Manager exists |
| universal-ctags | HM `nix/modules/common/packages.nix` and `nix/modules/nixos/default.nix:3` | none recorded in commit 315b9f5; unintended, remove the system copy later (follow-up) |
| docker CLI | HM `nix/modules/home/dev.nix:88` and `nix/modules/nixos/docker.nix:59` | HM is the only CLI owner on hosts without NixOS (Ubuntu WSL, linux-cli, macOS); on NixOS the daemon module adds a second copy (see ADR-0030) |

The HM copies are never removed.

## P6: the planned check
- `live_owner_duplicates` in `ops/audit.sh --live` (planned, not yet written; the check, not the ADRs). It skips what `live_nix_profile` already reports.
- Severity WARN, not FAIL: the repo-audit timer runs `--live` and raises a toast on any FAIL (`nix/modules/home/scripts/repo-audit.sh:71-77`).
- Tests: planned tests/bash/audit-owner-duplicates.bats (not yet created), with seeded directories, one allowlisted and one unlisted duplicate. A change to `ops/audit.sh` or `ops/lib/*` runs the full `bats tests/bash` suite (AGENTS.md).

## Consequences
- Nothing is applied by this ADR: no host profile change, no Home Manager removal, no code. ADR-0011 gets a note.
- ADRs 0022 to 0033, 0036 and 0037 cite this one for parity, profiles and the native exception.
- The P/W split stays a target for macOS until T-0042 groups land; the macOS work host keeps its current apps.
- Unknown: employer policy for W rows; PATH order for allowlisted duplicates (check with `type -a <binary>`).
