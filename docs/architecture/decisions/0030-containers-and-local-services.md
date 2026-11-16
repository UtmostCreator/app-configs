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
| CLI | Home Manager docker plus buildx on every Unix host (`nix/modules/home/dev.nix:88`). The HM `docker` is the full package (CLI plus moby daemon binaries; dockerd resolves to moby), not only the CLI. Which copy runs: on the desktop the login fish puts ~/.nix-profile/bin before /run/current-system/sw/bin (verified for docker and fish; other hosts unverified, check with `type -a docker`), so the HM CLI talks to the NixOS or distro daemon; API version negotiation absorbs the skew. An allowlisted duplicate (ADR-0021 P6) | Podman CLI | P+W | Pr | Record |
| compose, Linux | HM composeSupport: on the desktop the HM docker sets DOCKER_CLI_PLUGIN_DIRS to docker-compose-5.7.0 and `docker compose version` exits 0 (verified); T-0038 AC2 on WSL not run | none | P+W | Pr | Record |
| docker-client (optional) | replace the full HM `docker` package with docker-client, which exists in the pin, so no daemon binaries ship from Home Manager | keep the full package | P+W | Pr | Deferred |
| compose, macOS | brew docker-compose (`nix/modules/darwin/homebrew.nix:98`, reason stated); a possible duplicate if the Nix darwin docker also ships compose (unverified) | none | P+W | Pr | Record; verify (I-08) |
| Engine, NixOS and NixOS-WSL | the NixOS module (ADR-0003) | Podman; rootless Docker | P+W | Pr | Record |
| Engine, Ubuntu WSL and linux-cli (non-NixOS) | the distro engine, installed by the user; the repo ships only the CLI | same | P+W | Pr | Record |
| Engine, linux-cli on NixOS | the NixOS module: `ops/system-setup.sh` enables docker there (ENABLE_DOCKER, default on) | same | P+W | Pr | Record |
| Engine, macOS | Colima. It is darwin-only as the target state under T-0038; `nix/modules/home/dev.nix:87` installs it on every host today | OrbStack | P+W | Pr | Record |
| Engine, Windows host | none; use the WSL engine. A docker.cmd shim needs its own ADR (ADR-0019) | none | P+W | Pr | Record |
| Discard | Docker Desktop; XAMPP. Laravel Herd on macOS is undeclared, so inventory it first | none | none | Pr | none |

## Consequences
- ADR-0003 and ADR-0011 are amended in notes only; no engine changes.
