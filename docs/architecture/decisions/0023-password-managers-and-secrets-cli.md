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
