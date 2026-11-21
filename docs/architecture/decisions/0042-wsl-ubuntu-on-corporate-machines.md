---
adr: 42
title: "WSL2 on corporate machines: Ubuntu when IT requires a standard distro, NixOS-WSL otherwise"
status: proposed
date: 2026-11-21
platforms: [wsl]
areas: [wsl, distro, corporate, work-profile]
permits: [ubuntu-on-corporate-wsl, nixos-wsl-on-corporate-when-approved, manual-ubuntu-install]
forbids: [bootstrap-provisioning-ubuntu, system-setup-on-ubuntu, bypassing-employer-approval]
amends: []
supersedes: []
superseded_by: []
related: [1, 11, 15, 19, 21, T-0040]
---
# ADR-0042: WSL2 on corporate machines: Ubuntu when IT requires a standard distro, NixOS-WSL otherwise
Status: proposed 2026-11-21 (awaiting owner decision; the Ubuntu path has never run on a real distro) · Date: 2026-11-21 · Builds on: ADR-0015 (both distros, one `wsl` profile) · Sources: session estimate 2026-11-21, [WSL setup](../../platforms/wsl/setup.md), T-0047 evidence (NixOS-WSL run on a real PC, 2026-11-16)

## Decision
- On a corporate Windows 11 machine, choose the distro by what IT approves:
  - **NixOS-WSL** when IT allows a distro imported from a download (the `nixos.wsl` release) and Nix. Same path as the personal PC: `ops/windows/bootstrap.ps1`.
  - **Ubuntu** (Microsoft Store) when IT requires a standard distro. Installed by the short manual steps of ADR-0015 and [setup.md "Alternative: Ubuntu"](../../platforms/wsl/setup.md#alternative-ubuntu), then `ops/install.sh` with the `work` profile (the WSL default, ADR-0021 P4).
- Ask IT first: WSL, the distro, Nix, admin rights for `wsl --install`, and the proxy or TLS-inspection certificate. No approval, no install; Ubuntu does not get around a ban on Nix.
- Ubuntu stays manual. The Windows bootstrap does not provision it, and `ops/system-setup.sh` never runs on it (ADR-0015).

## Why
| | NixOS-WSL | Ubuntu |
|---|---|---|
| State | Run end to end on a real PC (2026-11-16), readiness ALL SET | Automated tests only; never on a real distro |
| Install | Bootstrap, 3 runs | Manual: `wsl --install`, `wsl.conf`, clone, `install.sh` |
| Hands-on time (approved, no proxy) | about 1.5 to 3 h | about 1 to 2 days (1 to 2 h install plus 0.5 to 1 day first real pass and fixes) |
| Corporate proxy or TLS inspection | plus 0.5 to 1 day | plus 0.5 to 1 day |
| Docker | Repo-managed engine (opt-in, unverified on WSL) | Not repo-managed |
| Approval risk | Higher: imported distro, often unknown to EDR and compliance tools | Lower: standard Store distro |
| Upkeep | `sys-update`, same as the other hosts | apt for the base, Nix for the tools |

Time to IT approval is outside these numbers (days to weeks).

## Strong alternatives
| Option | Why it lost |
|---|---|
| NixOS-WSL only, also at work | Fastest and proven, but fails where IT accepts only a standard distro. |
| A `-Distro Ubuntu` switch in the Windows bootstrap now | Deferred (ADR-0015): needs a second, apt-based system path; a manual install is enough until a work machine needs it repeatedly. Adding it is new Windows-side automation and needs its own ADR citing ADR-0019. |

## Consequences
- The first corporate Ubuntu install doubles as the T-0040 acceptance pass: run the six ADR-0015 checks and record evidence; each failure becomes a ticket.
- No Docker on corporate Ubuntu from this repo until a Docker decision covers it.
- Windows-side work settings (ADR-0020 `-SetupProfile work`, T-0055) are independent and not built yet.
- Becomes `decided-unverified` when the owner accepts it, and `decided` after a real corporate Ubuntu pass.
