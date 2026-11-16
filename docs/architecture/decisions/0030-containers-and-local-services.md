---
adr: 30
title: "Containers and local services: one CLI owner, engine per host, Docker Desktop discarded"
status: proposed
date: 2026-11-16
platforms: [cross, windows]
areas: [containers, docker, local-services, tool-selection]
permits: []
forbids: [docker-desktop]
amends: [3, 11]
supersedes: []
superseded_by: []
related: [15, 19, 21, T-0038, T-0042]
---
# ADR-0030: Containers and local services: one CLI owner, engine per host, Docker Desktop discarded
Status: proposed (no row is owner-decided; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0003 and ADR-0011 (ADR-0011's Docker Desktop deferral becomes a discard) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). The WSL engine is ADR-0003's; the distro choice is ADR-0015's.

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| CLI | Home Manager docker plus buildx on every Unix host (`nix/modules/home/dev.nix:88`). Which copy runs: the HM user profile is expected to come before `/run/current-system/sw/bin` and `/usr/bin` on PATH (unverified; check with `type -a docker`), so the HM CLI talks to the NixOS or distro daemon; API version negotiation absorbs the skew. An allowlisted duplicate (ADR-0021 P6) | Podman CLI | P+W | Pr | Record |
| compose, Linux | HM composeSupport (T-0038 AC2, unverified) | none | P+W | Pr | Record |
| compose, macOS | brew docker-compose (`nix/modules/darwin/homebrew.nix:98`, reason stated); a possible duplicate if the Nix darwin docker also ships compose (unverified) | none | P+W | Pr | Record; verify (I-08) |
| Engine, NixOS and NixOS-WSL | the NixOS module (ADR-0003) | Podman; rootless Docker | P+W | Pr | Record |
| Engine, Ubuntu WSL and linux-cli | the distro's engine, installed by the user; the repo ships only the CLI | same | P+W | Pr | Record |
| Engine, macOS | Colima. It is darwin-only as the target state under T-0038; `nix/modules/home/dev.nix:87` installs it on every host today | OrbStack | P+W | Pr | Record |
| Engine, Windows host | none; use the WSL engine. A docker.cmd shim needs its own ADR (ADR-0019) | none | P+W | Pr | Record |
| Discard | Docker Desktop; XAMPP. Laravel Herd on macOS is undeclared, so inventory it first | none | none | Pr | none |

## Consequences
- ADR-0003 and ADR-0011 are amended in notes only; no engine changes.
