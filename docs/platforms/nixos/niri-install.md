# Install and recover linux-niri

**Fresh installation and recovery.** The Kingston installation has booted on the destination laptop. For that working installation, use the [existing-system upgrade instructions](niri-first-boot-handoff.md#adopt-this-profile-on-an-existing-niri-installation). Keep the working NixOS/GNOME PC available throughout. The milestone is a blank target disk, a fresh home, and an authenticated first Niri login with a working terminal, launcher and network. Record build, VM and laptop results separately in [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md).

For an external Kingston alongside Windows, start with the [step-by-step walkthrough](kingston-install-walkthrough.md).

Media preparation has a separate [flash drive and Kingston guide](niri-install-media.md).

## 1. Get Claude working before touching a disk

On the working PC, open a terminal in the reviewed checkout. Run `claude --version` and then `claude`. Complete the interactive sign-in if requested. Ask it to identify the host output, explain the target-disk checks below and find the recovery instructions. A version string proves the binary starts. An answer in that session proves account access. Keep this terminal available while the laptop boots its installer. [Claude Code quickstart](https://code.claude.com/docs/en/quickstart)

The project installer ISO includes Claude Code, Codex CLI, Git and Disko in its live environment. It also carries the built target in its read-only Nix store. After booting it, run `claude --version` and `codex --version` from the live `nixos` account. This account can elevate without a password. Keep Claude in its ordinary shell and run privileged installation commands yourself. On a support PC missing the CLI, use the project package without changing the workstation profile. From the repository root on x86-64 Linux, including a networked installer with the accepted checkout, use:

```bash
nix --extra-experimental-features 'nix-command flakes' run --no-update-lock-file ./nix#install-claude -- --version
nix --extra-experimental-features 'nix-command flakes' run --no-update-lock-file ./nix#install-claude
```

Use an ordinary account. Prefer signing in on the PC so the live USB holds no account credentials. Keep passwords, keys and backup recovery material out of chat, command arguments, Git and evidence. The operator controls disk selection, writes, passwords and reboots. Keep an offline copy of this page for loss of network or assistant access.

## 2. Select and build the deployment

Use a clean checkout at the accepted commit, whose hardware module has been checked against the destination. Reuse the portable module if it covers the storage and boot requirements. For networked installation on a fresh live system, set `CONFIG_SOURCE` to the repository URL or an offline Git bundle containing that commit and `INSTALL_REV` to the full SHA from the working PC. As the ordinary installer user:

```bash
git clone "${CONFIG_SOURCE:?select the repository or offline bundle}" app-configs
cd app-configs
git switch --detach "${INSTALL_REV:?specify the reviewed commit}"
git rev-parse HEAD
git status --porcelain
```

Compare the printed SHA to the deployment record and require an empty status. On the laptop's live USB, `nixos-generate-config --show-hardware-config --no-filesystems` supplies discovery data. Review the storage-controller, firmware, graphics, CPU and initrd requirements against `nix/hosts/linux-niri/hardware.nix`. Keep Disko as the owner of LUKS and mounts. The generic module is only a starting point. For the attached-SSD route collect this information on the laptop before preparing its disk on the PC.

On the working Linux PC, `bash ops/install.sh --host linux-niri --dry-run` previews preparation and `bash ops/install.sh --host linux-niri` builds the system with one Nix job and two build cores. This selector finishes after the build. Formatting, installation and activation have separate steps.

Run the following builds and VM checks **one at a time on the working PC**, from the root of that checkout. Overlapping Nix evaluations, two guests and ISO compression exhausted this workstation’s RAM and swap during preparation. Finish each command before starting the next, including jobs in other terminals. Before each heavy step check `free -h` and `cat /proc/pressure/memory`. Defer the step if the desktop is under memory pressure. Keep the resulting host store path in the deployment record and label it `ACCEPTED_SYSTEM`. Rebuild the image after changing the destination hardware module:

```bash
git rev-parse HEAD
git status --porcelain
sha256sum nix/flake.lock
nix flake check --max-jobs 1 --cores 2 --no-update-lock-file ./nix
nix build --max-jobs 1 --cores 2 --no-update-lock-file --no-link --print-out-paths \
  ./nix#nixosConfigurations.linux-niri.config.system.build.toplevel
nix build --max-jobs 1 --cores 2 --no-update-lock-file --no-link ./nix#disko ./nix#install-claude
installer=$(nix build --max-jobs 1 --cores 2 --no-update-lock-file --no-link --print-out-paths ./nix#niri-installer-iso)
sha256sum "$installer"/iso/*.iso
nix build --max-jobs 1 --cores 2 --no-update-lock-file --no-link -L ./nix#niri-session-vm-test
nix build --max-jobs 1 --cores 2 --no-update-lock-file --no-link -L ./nix#niri-install-test
```

Record the repository SHA, lockfile digest, hardware revision, host output and resulting system store path. Retain the project ISO store path and SHA-256 and verify that digest on the transferred image. Build status, session VM results, UEFI disk rehearsal and hardware acceptance each have their own entry. The deployed system and Home Manager state versions are compatibility choices. Keep them fixed during routine dependency updates.

## 3. Test the VM, then the older laptop

Boot the selected x86-64 installer ISO with UEFI firmware, Secure Boot disabled, a writable virtual EFI variable store and a single empty virtio disk with the serial `niri-rehearsal`. The automated disk rehearsal allocates 48 GiB of virtual disk space and 4 GiB of guest memory. Exclude host disks and home-directory mounts. Verify `uname -m` and `test -d /sys/firmware/efi`. For a networked installation also verify connectivity. For the prepared offline route disconnect the network before booting. Record elapsed time and resource usage for this rehearsal using the [performance checks](../../work/active/T-0032-niri-trial-session/ticket.md#performance-at-each-milestone). Use the CLI available on the ISO to connect, for example `nmtui` on a NetworkManager image. Finish the remaining steps **inside the guest** before repeating the tested procedure on the laptop. The `niri-session-vm-test` output checks the authenticated graphical session. The `niri-install-test` output uses a test installer guest to populate a fresh encrypted disk; a separate UEFI guest boots that disk with its own Nix store. Repeat the runbook from the actual installer ISO to verify its networking, tools and rescue procedure.

The **older laptop is the first physical trial**. Boot the project USB there while the internal disk is still untouched. In the live shell check `uname -m` for `x86_64`, `cat /sys/firmware/efi/fw_platform_size` for `64`, `lsblk` for the internal disk and installer as distinct devices, and `ip link` for network adapters. Check usable video output and keyboard input and establish a network connection. Record the model, RAM, storage controller and graphics driver in the hardware review. If the laptop only offers legacy BIOS or 32-bit UEFI, this image’s x86-64 EFI loader cannot cover it. Record the result before proceeding to disk installation. Repeat hardware discovery and acceptance on any later laptop with different hardware.

| Route after rehearsal | Required evidence before writing |
| --- | --- |
| USB on the destination laptop | Confirm the internal target and its dedicated ESP plan. Identify the installer stick separately. Preserve or disconnect other disks. |
| Kingston SSD attached to the working PC | Confirm the target by its resolved whole-disk by-id path, model, serial and size locally. Protect every underlying disk of the running root, Nix store, boot, ESP and live media. Stop on any ambiguity, mount, active swap, LVM/RAID/crypt holder, name collision or missing disk guard. Leave the source system running throughout. |

Read-only identification on the installing machine:

```bash
lsblk -p -o NAME,PKNAME,TYPE,SIZE,MODEL,SERIAL,FSTYPE,PARTLABEL,MOUNTPOINTS
findmnt --real
swapon --show
ls -l /dev/disk/by-id/
```

Trace device-mapper, RAID and multi-device roots to all backing disks. Check kernel holders for the target and its children, including inactive-looking members claimed by another device. Require a whole disk under `/dev/disk/by-id/`; re-resolve it and repeat the checks immediately before any write. Compare partition labels across every attached disk. A USB bridge may change the by-id name after moving the SSD. Boot and rescue use the destination's actual partition identities. Save any needed data to independent media and verify a restore first.

**Attached-SSD formatting stays blocked until the later installer implements and tests these refusals.** A visual check alone is insufficient on the daily PC. Use only the target ESP; the portable host sets `boot.loader.efi.canTouchEfiVariables = false`. Omit the Disko option for writing firmware entries. Never activate the target on the source PC.

## 4. Install, enrol the account, cold boot

Inside the **disposable guest** use the pinned Disko CLI to prepare the disk, then install the exact system closure you built. Keep the target mounted for password enrolment.

These commands use the project ISO’s prebuilt system. A live RAM overlay can be smaller than the target closure.

Choose one preparation route below. Both use the same disk, mount and system checks and the same installation step. On the live ISO open a dedicated Bash shell and keep it through enrolment. Supply `ACCEPTED_SYSTEM` from the workstation build record. The example disk ID is exclusively for the disposable guest.

```bash
set -euo pipefail
DISK=/dev/disk/by-id/virtio-niri-rehearsal
test -b "$DISK"
test "$(lsblk -dnro TYPE "$DISK")" = disk
test ! -e /dev/mapper/linux-niri-root
test ! -e /dev/disk/by-partlabel/linux-niri-luks
test ! -e /dev/disk/by-partlabel/linux-niri-esp
test ! -L /mnt
mounted=$(findmnt -rn -o TARGET)
if grep -Eq '^/mnt(/|$)' <<<"$mounted"; then echo 'Install mount tree is in use'; exit 1; fi
if [[ -d /mnt && -n "$(ls -A /mnt)" ]]; then echo 'Install mount directory is occupied'; exit 1; fi
read -r system < /etc/app-configs/linux-niri-toplevel
test "$system" = "${ACCEPTED_SYSTEM:?copy the exact toplevel path from the build record}"
test -x "$system/bin/switch-to-configuration"
```

**Networked preparation.** In the accepted clean checkout inside the guest, generate the script for the selected device and read the account name.

```bash
rev=$(git rev-parse HEAD)
flake="git+file://$PWD?dir=nix&rev=$rev"
target_user=$(nix eval --raw -f nix/vars/default.nix username)
preview=$(nix run --max-jobs 1 --cores 2 --no-update-lock-file "$flake#disko" -- --dry-run --mode format,mount \
  --flake "$flake#linux-niri" --argstr targetDisk "${DISK:?select the verified guest disk}")
prepare=${preview##*$'\n'}
[[ "$prepare" == /nix/store/*-disko-format-mount/bin/disko-format-mount && -x "$prepare" ]]
```

**Prepared offline installation.** The live image carries the system closure and Disko tools. The offline rehearsal supplied the generated formatting script on a second read-only virtual CD labelled `NIRIFIX`. The live guest needed neither a checkout nor a flake evaluation. Prepare this kit **on the working PC** from the accepted checkout. For the archived development candidate, reconstruct its recorded Git tree before using the relative flake. The dry run generates a script in the store without touching a disk.

```bash
set -euo pipefail
DISK=/dev/disk/by-id/virtio-niri-rehearsal
kit=$(mktemp -d)
preview=$(nix run --max-jobs 1 --cores 2 --no-update-lock-file ./nix#disko -- \
  --dry-run --mode format,mount --flake ./nix#linux-niri --argstr targetDisk "$DISK")
prepare=${preview##*$'\n'}
[[ "$prepare" == /nix/store/*-disko-format-mount/bin/disko-format-mount && -x "$prepare" ]]
prep_root=${prepare%/bin/*}
nix-store --export "$prep_root" > "$kit/preparation.nar"
printf '%s\n' "${ACCEPTED_SYSTEM:?supply the recorded system path}" > "$kit/expected-target"
sha256sum "$kit/preparation.nar"
printf 'disk=%s\nprep_root=%s\nuser=%s\n' "$DISK" "$prep_root" "$(nix eval --raw -f nix/vars/default.nix username)"
```

Record the printed digest, disk, script root and user independently. To reproduce the virtual CD, use the pinned xorriso on the working PC and attach the resulting image to the guest as a second read-only CD, alongside the project ISO.

```bash
kit_iso="$kit.iso"
xorriso_root=$(nix build --inputs-from ./nix --no-update-lock-file --no-link --print-out-paths \
  --max-jobs 1 --cores 2 'nixpkgs#libisoburn^out')
"$xorriso_root/bin/xorriso" -as mkisofs -V NIRIFIX -R -o "$kit_iso" "$kit"
```

The test exported only the script store output. Its transitive references were already present on this exact live ISO. For the recorded virtio disk the export was 10,232 bytes, SHA-256 `7316c27b0b46a68d3199b76d2c4d32331b4a5dc2c9c72dd8f06d2e01c151f029`. Generate and rehearse a new export for a different disk identity.

**Back on the offline live ISO**, in the shell that completed the common checks, use the values from the trusted build record for `PREP_SHA256`, `PREP_ROOT`, `PREP_DISK` and `TARGET_USER`.

```bash
sudo mkdir -p /run/rehearsal
sudo mount -o ro /dev/disk/by-label/NIRIFIX /run/rehearsal
test "$DISK" = "${PREP_DISK:?supply the recorded by-id path}"
test "$(cat /run/rehearsal/expected-target)" = "$system"
printf '%s  %s\n' "${PREP_SHA256:?supply the recorded archive digest}" /run/rehearsal/preparation.nar | sha256sum -c -
imported=$(sudo nix-store --import < /run/rehearsal/preparation.nar)
test "$imported" = "${PREP_ROOT:?supply the recorded script root}"
prepare="$imported/bin/disko-format-mount"
test -x "$prepare"
nix-store -qR "$imported" | xargs -r nix-store --check-validity
target_user=${TARGET_USER:?supply the recorded account name}
```

**Install from either route.** Inspect that script and the store scripts it calls. Recheck the resolved target against the guest disk identity immediately before writing. Run the next block first on the blank virtual disk. For the later physical trial, use the verified single-target procedure in the [media guide](niri-install-media.md#install-directly-onto-the-kingston-then-move-it). Formatting writes GPT, a 1 GiB FAT32 ESP and LUKS2 with ext4. Enter the encryption passphrase at the prompt. The installed host uses zram and disables hibernation.

```bash
less "$prepare"
sudo "${prepare:?inspect the guest preparation script first}"
test "$(findmnt -n -M /mnt -o FSTYPE)" = ext4
test "$(findmnt -n -M /mnt/boot -o FSTYPE)" = vfat
test "$(readlink -f "$(findmnt -n -M /mnt -o SOURCE)")" = "$(readlink -f /dev/mapper/linux-niri-root)"
test "$(readlink -f "$(findmnt -n -M /mnt/boot -o SOURCE)")" = "$(readlink -f /dev/disk/by-partlabel/linux-niri-esp)"
lsblk -sp -o NAME,TYPE,FSTYPE /dev/mapper/linux-niri-root /dev/disk/by-partlabel/linux-niri-esp
```

Confirm the mounted devices trace to the virtual disk. Install the built system, then set the normal user's password before reboot. Verify the fallback loader on the target ESP. Record the system path and actual commands from the successful rehearsal before promoting the procedure to the laptop.

```bash
[[ "$target_user" =~ ^[a-z_][a-z0-9_-]*$ ]]
sudo nixos-install --no-root-passwd --no-channel-copy --root /mnt --system "${system:?build the target first}"
sudo nixos-enter --root /mnt -c "passwd $target_user"
findmnt /mnt/boot
sudo test -f /mnt/boot/EFI/BOOT/BOOTX64.EFI
```

Unmount the verified target ESP and root, then close its mapper. For the workstation route, move the powered-down SSD to the laptop. Remove the installer, select the target in destination firmware and cold boot. Check the LUKS prompt, tuigreet, wrong-password rejection, normal login, a second TTY and password-backed sudo. Compare `readlink -f /run/current-system` with the installation record. Persist the matching installation bundle and receipt before shutdown as described in the [first-boot handoff](niri-first-boot-handoff.md). The installed user can then recover the reviewed checkout offline.

From the first Niri session, open Ghostty with **Super+T**, Vicinae with **Alt+Space**, clipboard history with **Alt+V** and VS Code recents with **Alt+E**. Run `niri validate`, `nmtui`, `claude --version` and `codex --version`, save a screenshot under `~/Pictures/Screenshots` and log out with **Super+Shift+E**. Confirm the greeter requires authentication again. Home Manager activates with the host. Read the automatic summary in `~/Documents/app-configs-setup/Latest/Summary.txt`. For later changes use the integrated `sys-update` command. For older deployments without that command follow [Adopt this profile](niri-first-boot-handoff.md#adopt-this-profile-on-an-existing-niri-installation).

## 5. Prove recovery before selecting a shell

1. On the installed guest, boot the known-good generation once and record its generation and store path. Protect its system profile generation, boot entry and closure throughout the trial. Keep automatic generation pruning disabled and retain the systemd-boot entry. On the target, record `readlink -f /run/booted-system` and protect the closure with `sudo nix-store --add-root /nix/var/nix/gcroots/linux-niri-known-good --realise "$(readlink -f /run/booted-system)"`. Create that root only after boot-testing this generation. A GC root preserves the store path; keeping the system profile generation also preserves its boot entry.
2. Make a reviewed, reversible change to the target (for example a visible generation label), build from the clean checkout with the same lock and stage with `sys-update --apply` **on the destination only**. Confirm the default entry points to the candidate and preserves the working graphics variant. Check that two different system paths exist. Boot both via systemd-boot and record which path actually ran.
3. In the disposable guest, deliberately break graphical startup in a candidate generation. Use a TTY, or separately enrolled key-only SSH, to recover the working generation. Verify login and logout again. Record what failed and which recovery path worked.
4. Rehearse USB rescue with the network disconnected. After verifying disk identities, mount the existing root and ESP, inspect generations, restore a known-good default and cold boot without the USB. A rebuild only changes declared system and home configuration. Restore mutable files separately.

### Read-only inspection after an EXT4 incident

Use this only for a recurrence or a new integrity concern. The November repair already has a post-repair check. Boot the live installer, isolate the Kingston from other data disks and match its full by-ID link, model and capacity to the independent record. Inspect `lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS`. Stop if the encrypted partition is mounted or already has a mapping. In a fresh Bash shell:

```bash
set -euo pipefail
test -r /etc/app-configs/linux-niri-toplevel
read -rp 'Verified Kingston whole-disk by-ID path: ' DISK
[[ "$DISK" =~ ^/dev/disk/by-id/[A-Za-z0-9_.:+-]+$ && ! "$DISK" =~ -part[0-9]+$ ]]
test "$(lsblk -dnro TYPE "$DISK")" = disk
part="$DISK-part2"
test "$(readlink -e "$part")" = "$(readlink -e /dev/disk/by-partlabel/linux-niri-luks)"
test "$(lsblk -dnro PKNAME "$part")" = "$(lsblk -dnro KNAME "$DISK")"
node=$(lsblk -dnro KNAME "$part")
holders=$(ls -A "/sys/class/block/$node/holders")
test -z "$holders"
test ! -e /dev/mapper/niri-inspect
sudo cryptsetup open --readonly "$part" niri-inspect
mapper=/dev/mapper/niri-inspect
test "$(lsblk -dnro RO "$mapper")" = 1
test "$(lsblk -dnro FSTYPE "$mapper")" = ext4
mounted=$(lsblk -dnro MOUNTPOINTS "$mapper")
test -z "$mounted"
rc=0
sudo e2fsck -fn "$mapper" || rc=$?
printf 'Read-only EXT4 check exit %s\n' "$rc"
sudo cryptsetup close niri-inspect
```

A nonzero exit needs interpretation before any write or repair. If an identity or mount check stops the procedure after opening the mapper, inspect its users and close it only when idle. To retrieve logs without replaying the EXT4 journal, use a separate read-only mapping and `ro,noload` on an empty inspection mount point. Skipping replay can expose an inconsistent view. Unmount it before closing the mapping. [EXT4 mount documentation](https://www.kernel.org/doc/html/latest/admin-guide/ext4.html)

### Restore a known-good generation on a healthy filesystem

Offline rescue uses the live ISO’s existing cryptsetup, mount and nixos-enter commands. It needs neither the formatting kit nor a flake checkout. Use an **empty, unmounted** `/mnt` on the live system. Confirm both partition symlinks belong to the selected disk. Require a free mapper name and no mounts at or below `/mnt` before starting this sequence. If either is occupied, identify the existing mappings and mounts before resuming. Run in a dedicated Bash shell:

```bash
set -euo pipefail
test ! -e /dev/mapper/linux-niri-root
mounted=$(findmnt -rn -o TARGET)
if grep -Eq '^/mnt(/|$)' <<<"$mounted"; then echo 'Rescue mount tree is in use'; exit 1; fi
test ! -L /mnt
sudo mkdir -p /mnt
test -z "$(ls -A /mnt)"
sudo cryptsetup open /dev/disk/by-partlabel/linux-niri-luks linux-niri-root
sudo mount /dev/mapper/linux-niri-root /mnt
sudo mount -o umask=0077 /dev/disk/by-partlabel/linux-niri-esp /mnt/boot
findmnt /mnt
findmnt /mnt/boot
sudo nixos-enter --root /mnt -c 'nix-env -p /nix/var/nix/profiles/system --list-generations'
```

In `sudo nixos-enter --root /mnt`, set `generation` to the boot-tested number you recorded. Restore the boot default with:

```bash
nix-env -p /nix/var/nix/profiles/system --switch-generation "${generation:?select the recorded generation}"
/nix/var/nix/profiles/system/bin/switch-to-configuration boot
```

Exit the chroot. Unmount `/mnt/boot`, then `/mnt`, and close `linux-niri-root` before removing the disk. Rescue never formats.

## 6. Accept the laptop and recover the data

Run `bash ops/niri/acceptance.sh --online` from the destination's Niri session after first login. Save the output locally with the deployment revision and boot entry. Repeat it after a firmware, graphics, system generation, or desktop-shell change. The command collects evidence without staging, locking, suspending, or writing to disks.

| Scope | Evidence to keep |
| --- | --- |
| Per reviewed release | Pin the system and app choices in the same flake. Build the system and ISO from the exact commit and lock, record the image checksum and both graphics variants, and run the session and encrypted recovery VMs. Exercise shell start and stop and the selected launcher workflows when their implementation changes. Once a shell and optional apps pass, include the chosen components in the integrated host and rebuild the install kit from that revision. |
| Per physical laptop and target disk | Review UEFI, storage, firmware and GPU compatibility. Select the disk locally and enrol LUKS and login credentials. Verify a disk-only cold boot, one authenticated TTY and sudo login, access to the USB recovery environment, lock on resume, intended external outputs, and essential devices. A laptop with different hardware needs its own evidence. |
| Per affected workflow | Test screen sharing and dummy-window exclusion when the browser, call app, portal or compositor changes. Retest USB, Bluetooth and A/V when the actual devices change. Enrol each required account locally. Restore a representative project and vault to independent storage before moving real data. |
| Incident follow-up | Journal verification and a targeted SMART test belong to a drive or filesystem incident. Keep the Kingston follow-up attached to that disk. |

The full rollback and write-capable USB recovery procedure belongs to the disposable VM for each release that changes it. On each laptop, confirm the USB can unlock and inspect the correct disk read-only. Exercise physical generation fallback when using staged updates or when a change affects boot or recovery. Keep the boot-tested entry and its closure throughout.

- Check laptop outputs, Wi-Fi, speakers, microphone, brightness, lid and suspend/resume. Lock, reject a wrong password, hotplug an external display while locked and unlock. Check that no unlocked frame appears on resume.
- In the actual browser/call application, share a window and a monitor to another client. Open/save through the GTK chooser. Retrieve a dummy credential after a cold login. Use dummy vault data to verify sensitive-window capture behaviour.
- Trial Dux then Noctalia after baseline recovery passes. Stop at the first candidate that passes the documented workflow, one-owner, pinned/offline configuration and crash tests. Stop its shell process and verify windows, locking and polkit still work. Select the right project with several Code windows open. [Shell trial criteria](../../work/active/T-0032-niri-trial-session/ticket.md)
- Before migrating personal data, restore a project, KeePassXC database, required application state and recovery material from Kopia to an independent destination. Open the restored copies and verify content and access locally. Enable account-bound services individually after enrolment.
- Keep the configuration commit, lock, ISO and checksum, Disko tools, system closure and this recovery procedure offline. Archive flake sources with `nix flake archive` and copy the built system and installer closures with `nix copy`; verify the cache can supply both on independent media. Fresh LUKS metadata, host keys and account state are machine-specific. [Flake sources](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-archive.html) · [Built closures](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-copy.html)


### Offline recovery kit

Use independent storage with room for both the ISO and closures. From the clean checkout, reuse the reviewed `flake`, `system` and `installer` values above. Set `cache` to a file-backed Nix cache on that storage. Archive sources and copy the actual build outputs separately:

```bash
nix flake archive --no-update-lock-file --to "${cache:?select the offline cache}" "$flake"
nix copy --to "$cache" "$system" "$installer" "$flake#disko" "$flake#install-claude"
```

On the machine that generated the verified target preview, copy its store output with `nix copy --to "$cache" "${prepare%/bin/*}"`. Repeat for each target-specific script in the kit. Retain a Git clone or bundle containing the selected commit, the ISO itself, its checksum and the runbook. Record how to access and verify the cache independently of the laptop. Before relying on it, boot the installer without network, import the recorded paths and confirm the exact host and storage tools are available. The running Claude service requires connectivity; the rescue instructions and tools must work offline.

For Kopia, connect to the intended backup repository from a separate account or recovery environment. Select a snapshot by its recorded ID and a **new, empty** restore destination on independent storage:

```bash
kopia repository status
kopia snapshot list
kopia snapshot restore "${snapshot_object:?choose the recorded snapshot object}" "${restore_dir:?choose a new restore destination}"
```

Compare representative project and application files locally, open the restored KeePassXC database, and exercise the recovery instructions without the original machine. Retain the snapshot identifier and outcome with the deployment record. Keep backup passwords, recovery identities and vault contents out of the record.
