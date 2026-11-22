---
adr: 38
title: "Declarative disks and installs for fresh NixOS hosts: disko and nixos-anywhere"
status: proposed
date: 2026-11-20
platforms: [nixos]
areas: [install, disks, nixos-system, recovery]
permits: [disko-fresh-host, nixos-anywhere-fresh-host, vm-test-first]
forbids: [disko-on-live-desktop, disk-path-not-by-id, disko-in-sys-update, implicit-target-host, copied-host-secrets]
amends: []
supersedes: []
superseded_by: []
related: [12, 33, T-0029, 46]
---
# ADR-0038: Declarative disks and installs for fresh NixOS hosts: disko and nixos-anywhere
Status: proposed (the owner asked for this record on 2026-11-20; the layout questions below are open and nothing is built) · Date: 2026-11-20 · Sources: `docs/plans/future-upgrades.md` (section 6), `docs/work/active/T-0029-nixos-system-ownership/ticket.md`, `docs/plans/niri-migration.md` (backup gate)

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

## Context
A second NixOS machine (the niri trial host, ADR-0012) should be installable from this repository alone, so a fresh install also tests reproducibility. Today the repo has no `nixosConfigurations` and the desktop runs a hand-edited `/etc/nixos` (T-0029). disko declares partitions, encryption and filesystems in Nix; nixos-anywhere installs a flake host onto a machine booted from the installer over SSH. Both are in the pinned nixpkgs (1.13.0). Both erase the target disk.

## Decision (proposed)
- Use disko and nixos-anywhere only for hosts that are installed from scratch: a spare or disposable laptop, and VMs. The disk layout lives next to the host, for example a `disk.nix` in the host's directory under `nix/hosts/`.
- The current desktop is out of scope. disko never runs against its disks. Changing its layout needs a separate decision after the backup gate in `docs/plans/niri-migration.md` is met (Kopia, ADR-0033).
- Name disks by `/dev/disk/by-id/...`, never `/dev/sdX` or `/dev/nvmeXnY`, which can change between boots.
- Test in a VM first: `nixos-anywhere --vm-test`, or disko's `vmWithDisko` build, before the first install on real hardware.
- Run by hand only, with an explicit target: `nixos-anywhere --flake <repo>#<host> --target-host root@<address>`. Never from `sys-update`, `sys-install`, bootstrap or a hook.
- Generate `hardware-configuration.nix` on the new machine (`--generate-hardware-config`); never copy it from another host.
- Give the new host its own SSH host keys and credentials. Never copy keys or secrets from the primary desktop through `--extra-files`.
- Depends on T-0029 (`nixosConfigurations` with a reusable system layer). Without it there is no flake host to install.

## Open questions (owner)
- Filesystem: ext4 (simple) or btrfs with subvolumes (snapshots).
- Disk encryption: LUKS with a passphrase is the recommendation; the alternative is none on a disposable host.
- Swap: a swap partition, a swap file or zram (`nix/modules/nixos/desktop-stability.nix` has zram opt-in).
- Secure Boot (lanzaboote, `docs/plans/future-upgrades.md` item 8): later, or with the first install.
- disko from nixpkgs only, or also the disko flake input for its NixOS module. A new input changes `nix/flake.lock`; land it as its own reviewed change, not as a lock bump.

## Why
- A from-scratch install that works is the strongest test that the repo reproduces a machine. A hand-partitioned install hides manual steps.
- The tools are destructive, so the scope, the by-id rule, the VM test and the explicit target keep them away from the machine in daily use.

## Consequences
- The second machine's disk layout becomes reviewable code, and a reinstall is one command after booting the installer.
- Until T-0029 lands, this ADR records intent only.
