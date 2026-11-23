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
related: [12, 33, 46, 47, 49, T-0029]
---
# ADR-0038: Declarative disks and installs for fresh NixOS hosts: disko and nixos-anywhere
Status: proposed (the owner asked for this record on 2026-11-20; the layout questions below are open and nothing is built) · Date: 2026-11-20 · Sources: `docs/plans/future-upgrades.md` (section 6), `docs/work/active/T-0029-nixos-system-ownership/ticket.md`, `docs/plans/niri-migration.md` (backup gate)

**Laptop delivery · 23 November 2026 · 50% (2/4) · P0 · high complexity.** Pinned Disko layout. Encrypted VM install. Review laptop storage and firmware, then cold-boot the physical Kingston. Use the isolated target route. Formatting on the daily PC depends separately on tested disk guards. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

## Context
A second NixOS machine (the niri trial host, ADR-0012) should be installable from this repository alone, so a fresh install also tests reproducibility. When this was written (2026-11-20) the repo had no `nixosConfigurations`; since 2026-11-21 it has the build-only pilot host `linux-desktop-pilot`, while the desktop still runs a hand-edited `/etc/nixos` (T-0029). disko declares partitions, encryption and filesystems in Nix; nixos-anywhere installs a flake host onto a machine booted from the installer over SSH. Both are in the pinned nixpkgs (1.13.0). Both erase the target disk.

## Decision (proposed)
- Use disko and nixos-anywhere only for hosts that are installed from scratch: a spare or disposable laptop, and VMs. The disk layout lives next to the host, for example a `disk.nix` in the host's directory under `nix/hosts/`.
- The current desktop is out of scope. disko never runs against its disks. Changing its layout needs a separate decision after the backup gate in `docs/plans/niri-migration.md` is met (Kopia, ADR-0033).
- Name disks by `/dev/disk/by-id/...`, never `/dev/sdX` or `/dev/nvmeXnY`, which can change between boots.
- Test in a VM first: `nixos-anywhere --vm-test`, or disko's `vmWithDisko` build, before the first install on real hardware. In the pinned nixos-anywhere 1.13.0, `--vm-test` cannot be combined with `--generate-hardware-config` or `--disk-encryption-keys`, so the VM test runs with a VM-only hardware module and no key file. It tests the disk layout, not the generated hardware file or the LUKS unlock.
- Run by hand only, with an explicit target: `nixos-anywhere --flake <repo>/nix#<host> --target-host root@<address>` (the flake lives in `nix/`, not at the repository root). Never from `sys-update`, `sys-install`, bootstrap or a hook.
- Generate `hardware-configuration.nix` on the new machine (`--generate-hardware-config nixos-generate-config <path>`; the pinned version requires the backend and the path); never copy it from another host.
- Give the new host its own SSH host keys and credentials. Never copy keys or secrets from the primary desktop through `--extra-files`.
- Depends on T-0029 (`nixosConfigurations` with a reusable system layer). The pilot host exists since 2026-11-21; it still carries placeholder disks.

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


## Physical pilot alternatives and explicit open choices (2026-11-22)

| Topic | Candidates and trade-off | Recommendation for investigation |
|---|---|---|
| Installation | **NixOS live installer + disko**: interactive verification and reproducible disk mapping; **nixos-anywhere + disko**: repeatable remote deployment, requires proven target selection/SSH; **manual partitioning + nixos-install**: transparent but harder to reproduce | Local NixOS installer. [ADR-0049](0049-niri-safest-staged-installation-order.md) stage 2 proposes the generated hardware file as the pilot default and disko only after its VM test; **owner choice pending, nothing selected until actual PC 2 hardware is identified** |
| Filesystem | **ext4**: simpler/robust, no built-in snapshots; **Btrfs**: snapshots/compression, needs subvolume/recovery policy; **ZFS**: advanced features, heavier kernel/maintenance | Decide only after requirements for snapshot, performance and restore have been measured |
| Encryption | **LUKS2**: protects at rest, recovery key and unlock process needed; **TPM2/FIDO2 via systemd-cryptenroll**: convenience, platform/recovery complexity; **none**: only for explicitly disposable hardware | LUKS2 preferred to evaluate, not approved |
| Swap | **zram**: compressed RAM, no hibernate persistence; **encrypted disk swap**: hibernate possible with correct initrd/config; **swapfile**: flexible with filesystem-specific caveats | Evaluate actual RAM/hibernate needs |
| Boot and Secure Boot | **systemd-boot**: already declared in pilot; **GRUB**: dual-boot flexibility; **Lanzaboote**: Secure Boot management but extra key lifecycle | **Preserve current PC 1 boot config**; do not change for cosmetic Niri migration |
| Backup tool | **Kopia** (existing ADR-0033 selection), **restic**, **Borg**; Btrfs snapshots only complement remote copies | Require restore evidence first; do not silently switch to restic |

**First target (2026-11-22):** the laptop, which has no operating system, installed from the NixOS installer USB with a generated hardware file; commands in the [runbook](../../platforms/nixos/niri-install.md). Installing onto a disk attached to the running PC was compared and not chosen ([ADR-0049](0049-niri-safest-staged-installation-order.md), "Where to install"); if it is ever used, it needs `canTouchEfiVariables = false`, a target that is refused when any of its partitions is mounted, and a hardware file generated on the destination. disko-install fits that case and is not needed for the laptop.

**GNOME-free install (ADR-0012, owner direction 2026-11-22):** the host installed this way is the niri-only host, `linux-niri`, with greetd and no GNOME desktop; the committed pilot host still enables GNOME and GDM and is not the one to install.

**P0 before physical installation:** identify exact host, hardware, EFI partition, disko target by stable `/dev/disk/by-id`, filesystem labels, disk encryption recovery material and independent restore method. The pilot's root and /boot placeholders are **not safe to apply as a real disk layout**. Generating the hardware file is not enough: it must be a module of the host (listed beside `system.nix`, which the VM test also imports), committed, kept on the installed disk, and that exact configuration must build before the install. The by-id rule above covers partitioning, `cryptsetup` and disko targets; the by-uuid paths that `nixos-generate-config` writes into the hardware file are accepted; the user's password is set before the first reboot; a fresh install has a single generation, so a rollback target has to be created and booted on purpose ([ADR-0049](0049-niri-safest-staged-installation-order.md) stages 2 to 4). Disabling the disk safety gate is not permitted by this document. See [ADR-0046](0046-niri-desktop-installation-decision-register.md) G01/G13 and [T-0029](../../work/active/T-0029-nixos-system-ownership/ticket.md).
