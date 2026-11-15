# ADR-0001: WSL2 base is NixOS-WSL, on the desktop path
Status: decided (not yet verified on a real WSL install) · Date: 2026-11-15 · Sources: T-0047 ticket and plan (Decision), docs/platforms/wsl/windows-and-wsl.md, `docs/architecture/tool-ownership.md`

## Decision
- WSL2 runs NixOS-WSL with the stock /etc/nixos, `ops/system-setup.sh` (sys-setup) and the standalone Home Manager `wsl` profile, applied by the shared `ops/install.sh`.
- No `nixosConfigurations` for WSL in this milestone.

## Why
- Same path as the NixOS desktop: reuse the NixOS modules and scripts, no WSL copies.
- systemd is native; whole-system rollback through NixOS generations.
- Drops the WSL-only code: the apt step, the wsl.conf writer, the Ubuntu first-run user, the docker.io script.
- Why Ubuntu lost beyond reuse and parity is not in the repo: session decision 2026-11-15, recorded in T-0047.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Ubuntu + Nix + standalone Home Manager | Mainstream and familiar, but a second system-management model (apt and /etc outside Nix) and more WSL-only code. |
| NixOS-WSL fully in the flake (`nixosConfigurations`, Home Manager as a module) | Most declarative, but a large change that differs from how the desktop works today. Kept as a later milestone with T-0029 (proposed, no migration authorised). |

## Discarded
WSL1 (refused in `docs/architecture/tool-ownership.md`; reason not recorded there).

## Consequences
- Needs WSL 2.4.4 or newer; the NixOS-WSL release is pinned (2605.7.2) with a SHA256 committed in the bootstrap script.
- The default user is switched with `lib.mkForce`, then `nixos-rebuild boot` and a WSL restart; `targets.genericLinux` is removed from the wsl profile only.
- Unverified until the T-0047 acceptance run: flakes on by default, wheelNeedsPassword, removal of the old `nixos` user.
- Revisit when T-0029 is authorised (its sys-setup edits are kept minimal so it can absorb them).
- Runbook: `docs/platforms/wsl/setup.md`.
