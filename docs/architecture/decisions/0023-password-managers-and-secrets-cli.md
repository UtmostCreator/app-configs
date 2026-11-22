---
adr: 23
title: "Password managers and the secrets CLI: KeePassXC primary, Bitwarden allowed, op for dev secrets"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [password-manager, secrets-cli, tool-selection]
permits: [keepassxc-personal, bitwarden-allowed, op-cli-dev-secrets]
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [19, 21, T-0042]
---
# ADR-0023: Password managers and the secrets CLI: KeePassXC primary, Bitwarden allowed, op for dev secrets
Status: partly-decided (personal vault, Bitwarden and the personal op decisions are decided-unverified, owner 2026-11-16; work rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (KeePassXC narrowed to P; Bitwarden allowed; 1Password desktop still deferred) · Sources: tool-selection design round 3

Amended by ADR-0039 (2026-11-20): the Windows work profile may use KeePassXC, with Bitwarden allowed; install by hand.

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md).

## Owner decisions (2026-11-16, quoted)
- Vault: KeePassXC primary; "keepass or Bitwarden Password manager must be allowed"; "op for dev secrets".

## Decision
One status per row.

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Personal vault: KeePassXC primary | Nix on linux-desktop / deferred: macOS is W and a cask needs the T-0042 group desktopUtilities (Q9) / manual | Bitwarden; 1Password | P | DU | Record (L, Win); Deferred (M) |
| Bitwarden allowed on every OS | installed by hand on any OS; declared nowhere | none | P | DU | Manual |
| op (personal) | Nix on Linux and WSL (`nix/modules/home/dev.nix`, Linux optionals) / cask 1password-cli (state its reason, or move to Nix, unverified) / none | bw; keepassxc-cli | P | DU | Record |
| op (work) | the CLI is installed; the account belongs to the employer | bw; keepassxc-cli | W | Pr | Record |
| Work vault | none | 1Password Business; Bitwarden Enterprise; KeePassXC | W | Pr (unknown: employer policy) | none |

## Consequences
- 1Password desktop stays deferred (ADR-0011). Nothing is installed or removed by this ADR.
- The macOS vault row waits for a T-0042 group (ADR-0021 P5b).

## Niri Secret Service provider comparison (2026-11-22)

The **KeePassXC password-manager decision stays unchanged**. An operating-system **Secret Service daemon** (`org.freedesktop.secrets`) and an XDG **Secret portal backend** (`org.freedesktop.impl.portal.Secret`) are different interfaces from KeePassXC's main database and browser extension. Replacing GNOME Shell does **not** force removal of the GNOME Keyring daemon.

| Candidate | Advantages | Risks / trial outcome |
|---|---|---|
| **GNOME Keyring + existing Secret portal** | Already in the `programs.niri` pilot integration, has established login PAM path; no additional migration | GNOME-named standalone daemon; must assess runtime closure and credential lifecycle separately from GNOME Shell; **baseline, not permanent winner** |
| **[oo7-daemon + oo7-portal](https://github.com/linux-credentials/oo7)** | Cross-desktop Rust Secret Service implementation, own portal and PAM support; can reduce GNOME-specific keyring services | Greetd PAM auto-unlock and exact Nix path/environment require real testing; potential auto-migration of old keyrings; two services need distinct, declared owners; **leading replacement candidate only** |
| **KeePassXC Secret Service** | Consolidates an existing personal password-management app with the system secrets interface | Unlock is tied to the KeePassXC process and database; do not assume portal/PAM feature parity or reliable unattended application startup |
| **KWallet** | Mature integration and service features | Adds KDE framework/daemon and potentially different login-PAM/portal integration, no free migration parity |

**P0 security gate (before changing keyring provider):** use a **disposable isolated test user** and fake secrets; check exact pinned packages and `org.freedesktop.secrets` ownership, startup in a Niri session, greetd/PAM unlock after reboot, Secret portal requests, browser/VS Code/native application secret persistence, lock/suspend state and full rollback. [oo7 greetd report #516](https://github.com/linux-credentials/oo7/issues/516) was **closed in July 2026**; this does **not** prove every pinned Nix package version and greetd environment is safe. Do not test on the real KeePassXC database or migrate real GNOME keyring data without a backup and explicit approval.

**Reproducibility gate:** no package is allowed to silently replace the Secret provider or rewrite portal preferences. The chosen daemon, portal, PAM module, files and environment owner must be declared by Nix and verified with the actual session manager; `gnome-keyring` and `oo7-daemon` must not both claim `org.freedesktop.secrets`. Keep [ADR-0046](0046-niri-desktop-installation-decision-register.md) G18/G22 and [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md) as the installation/retirement gate owners.

