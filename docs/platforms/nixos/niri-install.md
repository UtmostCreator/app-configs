# Install `linux-niri` on the laptop (NixOS with niri, no GNOME desktop)

Draft runbook, 2026-11-22. It follows the stage order of [ADR-0049](../../architecture/decisions/0049-niri-safest-staged-installation-order.md), which also explains why the laptop was chosen over the other two ways of installing.

**It cannot be run yet.** The `linux-niri` host is not written, so steps 4 and 5 have nothing to install (see "Before you start"). Nothing here has been run on hardware. Every step that changes the laptop needs the owner's go-ahead when it is reached.

Use the [shared work-folder convention](../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md#shared-work-folder-convention) when preparing the user environment. [ADR-0050](../../architecture/decisions/0050-nixos-niri-home-layout.md) records the future provisioning checks. At first login, save a screenshot and verify that it lands in `~/Pictures/Screenshots`. Preserve existing project and vault paths during any later data transfer.

The existing PC is not part of the install. Nothing is attached to it and nothing on it is changed.

## Before you start

All of these must hold. The first three are the work that is still open.

- [ ] The `linux-niri` host exists in the flake, builds, and its VM test boots to the text login and into niri (ADR-0046 G27).
- [ ] The host directory holds a placeholder hardware module, which step 4 replaces with the generated one.
- [ ] This runbook has been rehearsed once in a UEFI virtual machine with an empty disk, booted from the same installer image, up to and including the reboot and the passphrase prompt.
- [ ] A USB stick with the official NixOS installer image for x86-64. The minimal image is enough.
- [ ] The laptop's firmware is in UEFI mode with Secure Boot off (the boot loader is not signed).
- [ ] The laptop's disk holds nothing you want. If it does, copy it off first; step 3 erases the disk.
- [ ] A network for the laptop: a cable or a phone's USB tethering is simplest. Wi-Fi works from the installer with `nmtui`.
- [ ] The PC's SSH **public** key, to authorise it on the laptop later. No private key goes onto the laptop or the USB stick.
- [ ] A disk passphrase that types the same on a US keyboard layout: the prompt appears before the keyboard layouts are loaded.
- [ ] This page open on a second device.

## Step 1: boot the installer and check the machine

Boot the laptop from the USB stick, then:

```bash
uname -m                                   # expect x86_64
test -d /sys/firmware/efi && echo UEFI     # expect UEFI
nmtui                                      # only if you need Wi-Fi
ping -c 1 cache.nixos.org
```

Stop if the machine is not x86_64 or did not boot in UEFI mode.

## Step 2: find the disk

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

The installer stick shows `usb` in the `TRAN` column and has mounted partitions. The laptop's own disk does not. Pick the laptop's disk by its `by-id` name, never by `sda` or `nvme0n1`, and read the model and size back to yourself:

```bash
DISK=/dev/disk/by-id/<the laptop's internal disk>
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK"
```

## Step 3: partition, encrypt, format and mount

This erases the disk in `$DISK`. Check step 2's output once more before the first command.

```bash
sudo parted "$DISK" -- mklabel gpt
sudo parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
sudo parted "$DISK" -- set 1 esp on
sudo parted "$DISK" -- mkpart root 1GiB 100%

sudo mkfs.fat -F 32 -n BOOT "${DISK}-part1"
sudo cryptsetup luksFormat --type luks2 "${DISK}-part2"
sudo cryptsetup open "${DISK}-part2" cryptroot
sudo mkfs.ext4 -L nixos /dev/mapper/cryptroot

sudo mount /dev/mapper/cryptroot /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=0077 "${DISK}-part1" /mnt/boot
```

The layout is deliberately plain: one EFI partition, one encrypted ext4 root, no swap partition and no hibernate.

## Step 4: hardware file and the repository

Generate the hardware description on the laptop itself, so it names this machine's disk, drivers and encryption:

```bash
sudo nixos-generate-config --root /mnt
grep -nE 'luks|fileSystems|availableKernelModules' /mnt/etc/nixos/hardware-configuration.nix
```

The file must mention the LUKS device, `/` and `/boot`. Then put the repository on the new disk, not in the installer's memory, and replace the placeholder hardware module with the generated file:

```bash
U=<your user name>
HOST=linux-niri
sudo mkdir -p "/mnt/home/$U/Projects"
sudo git clone <repository URL> "/mnt/home/$U/Projects/app-configs"   # nix-shell -p git, if git is missing
cd "/mnt/home/$U/Projects/app-configs"

HOSTDIR="nix/hosts/$HOST"
sudo cp /mnt/etc/nixos/hardware-configuration.nix "$HOSTDIR/hardware-configuration.nix"
sudo git add "$HOSTDIR/hardware-configuration.nix"
sudo git -c user.name="$U" -c user.email="<your commit email>" commit -m "feat(nix): add the generated hardware module for $HOST"
```

Committing matters: a flake ignores untracked files, and an uncommitted tree records a dirty revision. The commit stays local for now. Later the PC fetches it from the laptop over SSH, so the laptop needs no credentials for the remote.

## Step 5: build and install

```bash
FLAKE="git+file:///mnt/home/$U/Projects/app-configs?dir=nix"

sudo nix --extra-experimental-features 'nix-command flakes' build --no-link \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel"

sudo nixos-install --no-root-passwd --flake "$FLAKE#$HOST"
sudo nixos-enter --root /mnt -c "passwd $U"
```

- Build first. If the build fails, nothing has been installed and the fix is in the repository.
- `--no-root-passwd` leaves the root account locked; you work as your user with `sudo`.
- Do not skip `passwd`. The repository holds no password, and without one you cannot log in after the reboot.

Then leave the installer:

```bash
cd /
sudo umount -R /mnt
sudo cryptsetup close cryptroot
sudo reboot
```

Remove the USB stick when the screen goes dark.

## Step 6: first boot

Expected: the passphrase prompt, then the text login (tuigreet).

- [ ] The passphrase unlocks the disk at a cold boot.
- [ ] `Ctrl+Alt+F2` gives a second text console, and you can log in there with your password. A wrong password is refused.
- [ ] `nmtui` connects the network.
- [ ] `nixos-version --configuration-revision` shows the commit from step 4, without "dirty".
- [ ] `sudo chown -R "$USER":users ~/Projects` makes the checkout yours.

Do **not** log into niri yet. It has no terminal, launcher or config until step 7's user environment is in place.

## Step 7: the remaining stages

Each is one stage of ADR-0049, with its pass check there. Do them in this order and stop at the first one that fails.

| Stage | What you do | Where |
|---|---|---|
| 3 | Add key-only SSH with the PC's public key, rebuild with `boot`, and check that both generations boot. From the checkout, as your user: `nixos-rebuild boot --flake "git+file://$PWD?dir=nix#linux-niri" --sudo` | Text console |
| 3b | `bash ops/install.sh --profile work`. Ignore the closing advice to run the system setup script: that script rewrites `/etc/nixos` and must not run on this machine | Text console |
| 4 | Rehearse every recovery route, including the installer-USB rescue below | Both machines |
| 5 | First niri login from the text greeter | Laptop |
| 6 to 10 | Lock and suspend, portals and secrets, sound and devices, launcher, then the shell trial | Laptop |

Rebuilds run as your user with `--sudo`, so the build happens as the owner of the checkout and only the activation is elevated.

## Rescue from the installer USB

Rehearse this once in stage 4, before anything can lock the screen.

```bash
sudo cryptsetup open "${DISK}-part2" cryptroot
sudo mount /dev/mapper/cryptroot /mnt
sudo mount -o umask=0077 "${DISK}-part1" /mnt/boot
sudo nixos-enter --root /mnt -c 'nix-env -p /nix/var/nix/profiles/system --list-generations'
sudo nixos-enter --root /mnt -c 'nix-env -p /nix/var/nix/profiles/system --switch-generation <N> && /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
```

Then unmount, reboot and confirm generation `<N>` is the default. The rehearsal confirms or corrects the last command.

## If something goes wrong

| What you see | What to do |
|---|---|
| The build in step 5 fails | Nothing is installed. Fix the repository on the PC, pull on the laptop, build again |
| The laptop does not boot from its disk | Boot the installer USB, run the rescue mounts, check that `/mnt/boot` holds `EFI` and `loader`, and that Secure Boot is off |
| The passphrase is refused | Type it as on a US keyboard |
| No login is accepted | The password was not set. Rescue mounts, then `nixos-enter --root /mnt -c "passwd <user>"` |
| A rebuild breaks the system | Pick the previous generation in the boot menu |
| niri shows nothing or crashes | `Ctrl+Alt+F2`, log in on the text console, read `journalctl --user -b -u niri` |
| Anything you cannot fix | The laptop held nothing: repeat from step 3. The PC was never involved |

## What this runbook leaves out, on purpose

- **No GNOME, no GDM.** The fallback is the PC, not a second desktop on the laptop.
- **No disko, no swap partition, no hibernate, no Secure Boot, no TPM unlock.** Each adds a recovery procedure of its own. They can be added to a working install later.
- **No install from the running PC onto an attached disk.** It risks the PC's disks and firmware entries, and describes the wrong machine's hardware (ADR-0049, "Where to install").
- **No assistant in the critical path.** An AI coding assistant arrives with stage 3b like the other tools and is optional. The install, the first boot and every recovery route work without it, and it never runs partitioning, install or activation commands.
