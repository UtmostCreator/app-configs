---
adr: 38
title: "Declarative storage for fresh NixOS hosts"
status: decided-unverified
date: 2026-11-22
platforms: [nixos]
areas: [install, disks, nixos-system, recovery]
permits: [disko-fresh-host, attached-ssd-preparation, vm-test-first]
forbids: [format-source-desktop-disks, disk-path-not-by-id, disko-in-sys-update, implicit-target-host, copied-host-secrets]
amends: []
supersedes: []
superseded_by: []
related: [12, 33, 46, 47, 49, T-0029]
---
# ADR-0038: Declarative storage for fresh NixOS hosts
Status: decided-unverified · Date: 2026-11-22

**Laptop delivery · 24 November 2026 · 75% (3/4) · P0 · high complexity.** Pinned Disko layout. Encrypted VM install. The physical Kingston cold-booted. Finish recording the destination storage and firmware review. Use the isolated target route. Formatting on the daily PC depends separately on tested disk guards. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

## Decision

Use Disko pinned through the project lockfile for the first `linux-niri` installation. The laptop and any blank-disk rehearsal use the same storage declaration. The historical `linux-desktop-pilot` uses placeholder mounts and is unsuitable as a disk specification.

| Layer | Owner and selection |
|---|---|
| Partition table | Disko creates GPT on one explicitly identified whole disk |
| Boot | Dedicated 1 GiB FAT32 EFI System Partition, mounted at `/boot`. Use systemd-boot, with `boot.loader.efi.canTouchEfiVariables = false` persisted in the target |
| System | LUKS2 with an interactive passphrase, containing ext4 mounted at `/` |
| Swap and sleep | NixOS configures zram and disables hibernation. Suspend and lock require a laptop test |
| Hardware | A separate module records the destination's controllers, initrd drivers, firmware and graphics. Disko owns the storage definitions |

Disko formatting is an installation operation. Rescue opens and mounts existing filesystems. Ordinary builds and updates use the already installed layout. Keep formatting out of `sys-update`, activation hooks, bootstrap and normal rebuilds. Additional filesystems, hardware-bound unlock, Secure Boot and remote provisioning with nixos-anywhere can be considered after recovery is proven.

## Two installation routes

**Installer USB on the laptop.** Boot a checksum-verified x86-64 UEFI installer. Identify the laptop disk and installer media separately. Use hardware discovery on the laptop and review the hardware module for duplicate filesystem or LUKS declarations.

**Kingston SSD attached to the running PC.** Use Disko's explicit disk mapping to prepare the Kingston and its own ESP. Resolve the stable by-id path locally and confirm model, serial and capacity against the physical target. Walk parent devices for the source root and ESP, mounted filesystems and active swap. Reject ambiguous identities, the source disks, any mounted descendant, active swap and active device-mapper, RAID or other storage holders. A missing check blocks formatting. Verify the target ESP contains the fallback EFI executable and the source PC keeps its boot entries. Build for the laptop, write only to the SSD and leave the PC running its existing generation. [Disko installation on another workstation](https://github.com/nix-community/disko/blob/master/docs/disko-install.md)

A USB adapter can report a different identity from the internal controller. Keep the installation-time by-id mapping separate from the stable partition identifiers used at boot. Compare identifiers on the destination and test a cold firmware boot, LUKS unlock and authenticated login. Use the destination hardware module for either route.

## Proof before a real installation

Rehearse on an empty disposable UEFI disk, detach the installer and boot the installed system through the passphrase prompt. Rehearse a separate mount-only rescue and boot a distinct recovery generation. Check an independent Kopia restore before risking unique data. At installation time record the exact hardware revision and obtain confirmation of the physical target. The destination and its passphrase remain owner inputs. [Installation runbook](../../platforms/nixos/niri-install.md) · [ADR-0049](0049-niri-safest-staged-installation-order.md)
