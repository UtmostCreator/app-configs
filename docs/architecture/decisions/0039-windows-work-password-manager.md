---
adr: 39
title: "Windows work profile: KeePassXC (Bitwarden allowed) installed by hand with winget"
status: decided-unverified
date: 2026-11-20
platforms: [windows]
areas: [password-manager, windows, tool-selection]
permits: [keepassxc-windows-work, bitwarden-windows-work]
forbids: [vault-in-git, repo-written-vault]
amends: [23]
supersedes: []
superseded_by: []
related: [11, 19, 21, T-0041]
---
# ADR-0039: Windows work profile: KeePassXC (Bitwarden allowed) installed by hand with winget
Status: decided-unverified (owner decision 2026-11-20; the winget ids were not run on a Windows host) · Date: 2026-11-20 · Amends: ADR-0023 (its Windows work-vault row was "none") · Cites: [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md)

## Owner decision (2026-11-20, quoted)
- "add for windos latests keepass or bitwarden"

## Decision
- The Windows work profile may use KeePassXC, the parity pick already used on NixOS (`nix/modules/home/gui.nix`). Bitwarden is the allowed alternative, as on every OS (ADR-0023).
- Install by hand, one command at a time, from the copy-only list (ADR-0011). winget installs the current release by default, so no version is pinned:
  - `winget install -e --id KeePassXCTeam.KeePassXC`
  - alternative: `winget install -e --id Bitwarden.Bitwarden`
- Employer policy wins: if the employer mandates a vault (for example 1Password Business or Bitwarden Enterprise), use that and skip this row.
- The repo installs nothing on Windows and writes no vault, key file or setting. Run `winget show --id <id> --exact` first; both ids are unverified until then.

## Why
- One vault tool on Linux and Windows keeps the same database format and workflow. KeePassXC is free and open source, so it passes the personal-use and licence screening in ADR-0021 P3b.
- Bitwarden stays allowed because the owner named it and ADR-0023 already permits it.

## Consequences
- The vault file and any key file stay out of git and out of the public repo. Back the vault up with the owner's encrypted backup, not with chezmoi (ADR-0033).
- macOS is unchanged: it is a work host with 1Password and no KeePassXC cask (ADR-0023, T-0042 groups).
