---
adr: 15
title: "WSL distro: NixOS-WSL by default, Ubuntu supported; one profile"
status: decided-unverified
date: 2026-11-15
platforms: [wsl, nixos]
areas: [wsl, distro]
permits: [nixos-wsl-default, ubuntu-supported]
forbids: [distro-profile-multiplication, silent-dual-install, bootstrap-touching-other-distros]
amends: [1]
supersedes: []
superseded_by: []
related: [T-0047]
---
# ADR-0015: WSL distro: NixOS-WSL by default, Ubuntu supported; one profile
Status: decided 2026-11-15 (design ruled; NixOS-WSL implemented and verified on a real PC 2026-11-16, T-0047; Ubuntu path untested) · Date: 2026-11-15 · Amends: ADR-0001 · Sources: session decision 2026-11-15 (architect ruling), user-supplied outside research (unverified where it cites Microsoft docs), `nix/hosts/wsl/home.nix`, `ops/detect-host.sh`, `ops/system-setup.sh`

Amends ADR-0001 (see its Consequences).

## Decision
- Both distros are supported under the one host profile `wsl`. Install only the one a machine needs: NixOS-WSL on the personal PC, Ubuntu where an employer requires a standard distro. They can coexist.
- One extra Home Manager output, wsl-nixos (the wsl home with `targets.genericLinux` forced off). `ops/detect-host.sh --hm-attr` (implemented) is the only place that chooses the output: NixOS gives wsl-nixos, otherwise wsl.
- The Windows bootstrap keeps targeting the distro named NixOS and never touches another distro.
- Ubuntu is installed by short manual steps: `wsl --install -d Ubuntu`, a user, wsl.conf with systemd, clone, `ops/install.sh`. Never sys-setup.

## Why
- Safe to allow: Microsoft supports side-by-side distros with separate filesystems, users and /nix stores (outside research, unverified). Shared (same caveat): the WSL VM (CPU/RAM), the network namespace (port clashes if both run the same service), the global .wslconfig, the Windows default distro.
- Home Manager's genericLinux is meant for non-NixOS distros only: on for Ubuntu, off for NixOS (the user's rule: keep genericLinux for non-NixOS Linux, off on NixOS).
- No profile-name multiplication: everything keyed on the name `wsl` stays.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| NixOS-only `wsl` profile, refuse other distros (first D0 design) | Simplest, but breaks Ubuntu at work. |
| New profile name from detect-host for NixOS-WSL | Touches every wsl-keyed site: chezmoiignore, readiness, install, seed, validators, tests. |
| genericLinux left on for both | Breaks the rule; effect on NixOS unproven. |
| A `-Distro NixOS or Ubuntu` switch in the Windows bootstrap now | Deferred. Trigger: a work machine needs Ubuntu provisioned automatically. Estimated medium effort; needs a second, apt-based system path. |

## Discarded
Separate repos or branches per distro; duplicated Home Manager modules; a generic distro-management framework; copying credentials or projects between distros; silently installing both.

## Consequences
- With both running: watch ports, memory and disk (two /nix stores). Pick the distro with `wsl -d <name>`; run `wsl --set-default NixOS` if Ubuntu was registered first.
- Corporate machines: WSL, the distro, Nix itself, external caches and proxy/certificates need employer approval. Ubuntu does not remove a ban on Nix; the installer must report the blocked dependency, not switch architecture.
- The Ubuntu path is covered only by detect-host, hm-switch and eval tests until someone runs six checks on a real Ubuntu distro: (1) detect-host prints wsl and --hm-attr prints wsl; (2) install dry-run, then real; (3) XDG_DATA_DIRS includes /usr/share; (4) sys-readiness and sys-update; (5) sys-setup refuses "not NixOS"; (6) the NixOS distro is unaffected.
- Supersedes two D0 points in the T-0047 plan: genericLinux is NOT dropped from the wsl home (it stays for Ubuntu; the wsl-nixos output turns it off) and preflight does NOT refuse a non-NixOS wsl host. The NixOS session was told on 2026-11-15; the plan text is updated after the first docs commits land.
