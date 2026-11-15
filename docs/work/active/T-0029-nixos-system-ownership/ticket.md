Source: local

# T-0029: NixOS system ownership via nixosConfigurations (feature)

Status: proposed, not started. No migration authorised (`docs/plans/migration/overview.md:3`).
Depends on: none
Blocks: T-0032
Evidence: `docs/research/desktop-migration-claim-audit.md`
Live gate: the first live `/etc/nixos` takeover needs the pre-migration backup gate met and its evidence recorded (section "Mandatory backup before any live change" in docs/plans/niri-migration.md).

## Summary
Add `nixosConfigurations.linux-desktop` so the flake owns the running system.
Today the system comes from a hand-edited `/etc/nixos/configuration.nix` plus
aux modules written by `ops/system-setup.sh`. This ticket is desktop-neutral:
no compositor change.

- Reuse the existing `vars` / `mkHome` conventions in `nix/flake.nix`.
- Host file: T-0029 will create a new `system.nix` module under the Linux desktop host directory, importing `nix/modules/nixos`. The file does not exist yet.
- Take over, so the repo is the only writer of `/etc/nixos`:
  - `/etc/nixos/configuration.nix`;
  - `/etc/nixos/flake.nix` and its own `flake.lock` (the live system is built with `--flake /etc/nixos#nixos`, `ops/system-setup.sh:55`);
  - `app-configs-extra.nix` (written by `ops/system-setup.sh:51`) and `app-configs-docker.nix` (copied by `ops/system-setup.sh:71-72,263`);
  - `app-configs-tailscale.nix` / `-tailscale-host.nix` (written by `ops/tailscale-setup.sh:17,51`, which also edits `/etc/nixos/configuration.nix` and `flake.nix`);
  - `keyd-f1-remap.nix` (copied by hand, `docs/reference/keyboard.md:20,41`).
- Reduce `ops/system-setup.sh` to bootstrap, and bring `ops/tailscale-setup.sh` into scope; otherwise it stays a second `/etc/nixos` writer.

## Owned files
- nix/flake.nix, nix/hosts/linux-desktop/system.nix, nix/modules/nixos/**
- ops/system-setup.sh, ops/tailscale-setup.sh and their tests
- Downstream that goes stale and must be updated or re-checked: `ops/install.sh:397-428`, `ops/readiness.sh:6,92`, `docs/reference/keyboard.md:20,41`

## Findings
- VERIFIED: flake has no `nixosConfigurations` (`nix/flake.nix:170-178`).
- VERIFIED: only `nix/modules/nixos/default.nix` has no flake consumer. `docker.nix` is live through the `ops/system-setup.sh` copy, and `keyd-f1-remap.nix` through a manual copy.
- VERIFIED: `ops/system-setup.sh` edits `/etc/nixos/configuration.nix`, writes `app-configs-extra.nix` (:51), copies `app-configs-docker.nix` (:71-72,:263) and runs `nixos-rebuild switch` (:50, :191, :253-311, :319).
- VERIFIED: `ops/tailscale-setup.sh` writes the tailscale aux modules (:17,:51) and edits `/etc/nixos/configuration.nix` and `flake.nix`.
- VERIFIED (host read, 2026-11-14): the running system is GNOME Shell 50.1; pinned unstable has gnome-shell 51.0.

## Risks (HIGH)
- Switching to the flake moves GNOME 50.1 to 51.0. After the switch, check the Vicinae GNOME extension (1.8.x claims 46-51; the pinned build's metadata is UNVERIFIED) and every GNOME keybinding.
- `hardware-configuration.nix` is `/etc/nixos/hardware-configuration.nix` (VERIFIED, name-only listing); the new host must import or copy it deliberately.
- `nix/modules/nixos/default.nix` is consumed by nothing today, so it is untested as a system.
- Lock ownership: `/etc/nixos` has its own `flake.lock`. Once the repo lock also drives the system closure, define how `sys-update` and `flake.lock` ownership work (see AGENTS.md: `sys-update` owns lock bumps).

## Acceptance criteria
- `nix build ./nix#nixosConfigurations.linux-desktop.config.system.build.toplevel` builds.
- Closure diff against the current system is reviewed (for example `nvd` or `nix store diff-closures`) and shows only expected changes.
- `nixos-rebuild build` first. `test` and `switch` run only with the user's explicit approval at that time; note that `test` moves a running GNOME session from 50.1 to 51.0 components.
- `ops/tailscale-setup.sh` no longer writes `/etc/nixos`; `ops/install.sh` and `ops/readiness.sh` references updated or re-checked.
- The `flake.lock` ownership model with `sys-update` is written down.
- `nix flake check ./nix`, `bats tests/bash` and `bash ops/validate-config.sh` pass.
- The new host preserves bootloader, filesystems, initrd, encryption and GPU/kernel options from the live config; the evaluated diff is reviewed against `/etc/nixos`.
- No secret material from `/etc/nixos` enters git: gitleaks and the pre-commit hooks pass, and files containing credentials are never copied.
- Rollback is proven by booting the previous generation from the boot menu.

Note: niri could technically be trialled through `/etc/nixos`, but that would add another hand-edited writer, which this repo's ownership rule rejects; T-0032 therefore keeps this ticket as a dependency.

## Refs
`docs/plans/future-upgrades.md` section 6; `docs/plans/migration/overview.md` phase 1.

## Open checks
- Hybrid GPU behaviour after the switch: UNVERIFIED.
- GNOME 51.0 behaviour with the pinned extension: UNVERIFIED. Evidence so far: pinned `gnomeExtensions.vicinae` is EGO version 14 (`vicinaedagimg-dot.v14.shell-extension.zip`), and EGO extension-info for pk 8594 maps GNOME 46-51 to version 14; the store `metadata.json` was not read.
