---
adr: 29
title: "Networking and remote access: no Tailscale on work hosts, SSH, WinSCP"
status: partly-decided
date: 2026-11-16
platforms: [linux, nixos, macos, wsl, windows]
areas: [networking, vpn, remote-access, tool-selection]
permits: [winscp-exception, openssh]
forbids: [tailscale-on-work-hosts]
amends: [4]
supersedes: []
superseded_by: []
related: [11, 19, 21, T-0029]
---
# ADR-0029: Networking and remote access: no Tailscale on work hosts, SSH, WinSCP
Status: partly-decided (no Tailscale on work hosts and the WinSCP exception are decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0004 (Tailscale is personal-profile only) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). The NixOS system layer is T-0029's.

## Owner decisions (2026-11-16, quoted)
- Tailscale on work hosts: "no" (work hosts get no Tailscale; the employer VPN applies).
- "remove deepseek harness for now": recorded in ADR-0032 (the repo part was removed in e889726, T-0056).
- O2: all native exceptions approved (here: WinSCP).

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Tailscale on W | none on any work host; W uses the employer VPN | none | W | DU | Deferred (follow-up below) |
| Tailscale, NixOS desktop | system service, `ENABLE_TAILSCALE` defaults to 1 (`ops/system-setup.sh:219`) | NetBird; ZeroTier; Headscale | P | Pr | Record |
| Tailscale, macOS | none (the macOS host is W per ADR-0021 P4; a cask would need a T-0042 group) | same | P | Pr | Record |
| Tailscale, WSL | off (ADR-0004; the WSL host is W per ADR-0021 P4) | same | P | Pr | Record |
| Tailscale, Windows | manual | same | P | Pr | Manual |
| SSH | OpenSSH everywhere; discard PuTTY | Termius | P+W | Pr | Record |
| SFTP GUI (Windows, Ex) | WinSCP | Cyberduck; FileZilla (its installer bundles offers, so it is a suspect) | P+W | DU | Manual |
| SFTP GUI, Linux and macOS | the file managers' SFTP | same | P+W | Pr | Record |
| RDP | built in on Windows; Remmina or Windows App if needed | none | P+W | Pr | Record |

## R1 test for the Ex row: WinSCP
- (a) licence: free, GPL, both profiles.
- (b) native or built in: native Windows app (not built in; no built-in SFTP GUI exists).
- (c) named gap against the parity pick (the file managers' SFTP): folder sync and editor integration.
- (d) dated 2026-11-16; replaced pick: the file managers' SFTP; revisit if a parity GUI gains those features on Windows.
- (e) owner approval 2026-11-16 (O2).

## Today's behaviour and the follow-up
- `ops/system-setup.sh:219` defaults `ENABLE_TAILSCALE` to 1 except on WSL, so a NixOS linux-cli work host gets Tailscale today.
- `ops/readiness.sh:166-168` reports a pending rebuild if tailscaled is inactive on a non-WSL host.
- Follow-up: T-0057 (landed on main b1699c0; owner checks pending). Work-host detection: `ENABLE_TAILSCALE` defaults to 1 only when HOST_PROFILE is linux-desktop (the pattern of ENABLE_DESKTOP_STABILITY, `ops/system-setup.sh:212`); `ops/readiness.sh:166` checks for linux-desktop instead of a non-WSL host; `ops/tailscale-setup.sh` stays a manual opt-in. Files to update: `ops/system-setup.sh`, `ops/readiness.sh`, `ops/tailscale-setup.sh` with `mise.toml:251-252` (the live path /etc/nixos/app-configs-tailscale*.nix), `docs/guides/tailscale-local-services.md`, `tests/bash/readiness.bats:52-60` and `tests/bash/fixtures/system-setup-desktop-snippet.golden:29`. T-0029 owns the NixOS system layer, so the ticket should be coordinated with it.

## Consequences
- This ADR changes no file. Unknown: employer policy for any remote-access tool.
