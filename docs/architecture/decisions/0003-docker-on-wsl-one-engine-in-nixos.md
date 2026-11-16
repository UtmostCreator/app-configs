---
adr: 3
title: "Docker on WSL is one declarative engine inside NixOS-WSL"
status: decided-unverified
date: 2026-11-15
platforms: [wsl, nixos]
areas: [docker]
permits: [nixos-docker-engine, explicit-docker-group]
forbids: [automatic-docker-group]
amends: []
supersedes: []
superseded_by: []
related: [T-0047]
---
# ADR-0003: Docker on WSL is one declarative engine inside NixOS-WSL
Status: decided (not yet verified; rootless on WSL unverified) · Date: 2026-11-15 · Sources: T-0047 ticket and plan, docs/platforms/wsl/windows-and-wsl.md, `nix/modules/nixos/docker.nix`

Proposed amendment in ADR-0030 (containers: one CLI owner per host, engine per host; this ADR's engine decision is unchanged).

## Decision
- NixOS `virtualisation.docker` through the existing docker module, enabled by sys-setup on request (off by default on wsl).
- Never added to the docker group automatically: the group is root-equivalent. Access is explicit (`DOCKER_GROUP=1`) or rootless (`DOCKER_ROOTLESS=1`, to be measured).
- Later (Milestone 2): a Windows `docker` command as a docker.cmd shim to the WSL CLI.

## Why
- One engine, one owner: the module already exists for the desktop.
- Declarative: rolls back with the system generation.
- No daemon, binary or TCP listener on the Windows side.
- Refused when Docker Desktop integration is present, so two daemons never meet.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Docker Desktop | Good Windows integration, but a second daemon that conflicts with an engine inside the distro, plus licence terms (T-0041 defers it as a "licence and integration choice"). |
| Ubuntu `docker.io` via a WSL-only script | Imperative, and a WSL-only copy of what the NixOS module already does. |
| `docker.exe` + SSH context | A real Windows client, but needs sshd, keys and a listening port in WSL. |

## Discarded
Daemon on TCP 2375 (unauthenticated root), automatic docker group, a second engine on Windows.

## Consequences
- Paths passed through the future shim (bind mounts, `-f`) must be WSL paths.
- Acceptance exports the distro first (ADR-0007), then measures rootless; fallback is rootful plus group.
- Revisit if rootless fails on WSL or the Windows-side `docker` need outgrows a shim.
