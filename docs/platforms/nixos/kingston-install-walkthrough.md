# Install NixOS on an external Kingston and keep Windows bootable

Use two devices. The small USB flash drive boots the **project installer ISO**. The external Kingston receives a full NixOS installation with its own EFI System Partition (ESP), encrypted root, account and checkout. The Windows SSD keeps its own bootloader. Leave all backup disks disconnected throughout.

## 1. Get the matching ISO and deployment record

On the working Linux PC open **Terminal**, change to the reviewed app-configs checkout and follow the build and VM checks in the deployment revision’s [installation runbook](niri-install.md). Use the project's `niri-installer-iso` output. A generic NixOS ISO lacks the prebuilt system and project tooling. The trial build can be used for read-only laptop discovery. Before installation, require a clean reviewed commit containing the destination hardware configuration, a passing installation rehearsal, and the matching ISO, SHA-256, system store path and full Git commit. Keep those values on the support PC. Include this guide and `ops/niri/verify-first-boot.sh` in the selected revision. A guide-only commit does not supply a deployable host.

For read-only discovery, the current build PC retains the trial image under `nix/result-niri-installer/iso/`. From the repository root, start a Bash shell and run:

```bash
ISO="$PWD/nix/result-niri-installer/iso/nixos-minimal-26.11.20261114.5d2b81a-x86_64-linux.iso"
printf '%s  %s\n' 9770b226d1a5216aaa245a8ecc2dc20f0f2cbd44524790f08ab29d5c14ae3022 "$ISO" | sha256sum -c -
```

Expect `OK`. For the final installation, use the destination build's filename and checksum. If the retained path is absent, build the ISO from the reviewed installer checkout. In Bash, `nix build --max-jobs 1 --cores 2 --no-update-lock-file --out-link result-kingston-iso ./nix#niri-installer-iso` leaves the image under `result-kingston-iso/iso/`. A missing output means the selected revision cannot supply the installer.

### Carry the committed repository on the bootable USB

The project image above contains NixOS, the prebuilt Niri system, Git, Claude Code and Codex. To carry app-configs on the same stick, add a read-only Git bundle to a **new** ISO before flashing. From the repository root, after committing the files you want to take, run the following in Bash with `ISO` set to the verified base image. The bundle includes the files and history reachable from local `main`. For a deployment, confirm that revision also contains the reviewed host and hardware configuration.

```bash
set -euo pipefail
kit=$(mktemp -d "$PWD/result-niri-usb.XXXXXXXX")
git bundle create "$kit/app-configs.bundle" refs/heads/main
git bundle verify "$kit/app-configs.bundle"
git bundle list-heads "$kit/app-configs.bundle" refs/heads/main | cut -d' ' -f1 > "$kit/REVISION"
tool=$(nix build --inputs-from ./nix --no-update-lock-file --no-link --print-out-paths 'nixpkgs#libisoburn^out')
"$tool/bin/xorriso" -indev "$ISO" -outdev "$kit/app-configs-usb.iso" \
  -map "$kit/app-configs.bundle" /app-configs.bundle -map "$kit/REVISION" /APP-CONFIGS-REVISION \
  -boot_image any replay -commit -end
ISO="$kit/app-configs-usb.iso"
(cd "$kit" && sha256sum app-configs-usb.iso > SHA256SUMS && sha256sum -c SHA256SUMS)
printf 'Flash this image: %s\n' "$ISO"
```

Flash **that output ISO** in step 2. Its checksum differs from the base image. After boot, open the repository offline from the live user's home:

```bash
media=$(findmnt -rn -t iso9660 -o TARGET)
git clone -b main "$media/app-configs.bundle" "$HOME/app-configs" &&
  test "$(git -C "$HOME/app-configs" rev-parse HEAD)" = "$(cat "$media/APP-CONFIGS-REVISION")"
```

Exit 0 confirms the checkout matches the bundled revision. Open `~/app-configs/README.md` to continue. In step 4, use `$media/app-configs.bundle` as the checkout source in a fresh working directory.

## 2. Write the small flash drive

Unplug the Kingston. Insert an expendable flash drive of at least 8 GB. Check its capacity and model. Flashing erases it.

* **Windows:** Copy the verified ISO to Windows. Open **PowerShell**. Run `Get-FileHash -Algorithm SHA256 -LiteralPath (Read-Host 'Full path to the project ISO')` and compare the entire hash with the build record. Open **balenaEtcher** → **Flash from file** → select the ISO → **Open** → **Select target**. Tick only the small USB stick and click **Select** → **Flash!**. Approve the Windows elevation prompt after rechecking the target. Wait for flashing **and validation** to finish successfully. Cancel any Windows prompt to format an unreadable partition, then eject the stick. Etcher writes the partition layout from the image. [balenaEtcher](https://etcher.balena.io/)
* **Linux/GNOME:** Set `ISO` to the full path of the matched image. Run `sha256sum "$ISO"`, compare, then run `gnome-disks --restore-disk-image="$ISO"`. In **Restore Disk Image**, select the small flash drive under **Destination**, click **Start Restoring…**, check the confirmation and start. After it finishes, eject and reinsert the stick. Set `USB` to its verified whole-disk by-id path. Run `sudo cmp --bytes="$(stat -c %s "$ISO")" -- "$ISO" "$USB"`. Success is exit 0 with no output.

## 3. Boot the laptop without writing to storage

1. Keep the Kingston unplugged for initial discovery. If Windows uses BitLocker or device encryption, ensure the recovery key is accessible privately before changing firmware settings. Record the original Secure Boot setting. Shut down Windows fully.
2. Insert the flashed stick. Power on and tap the manufacturer's **one-time boot menu** key shown at startup (often F12, Esc or F9). Select the **UEFI** entry for the small USB. If Secure Boot blocks this image, use firmware setup to disable it temporarily, then use the one-time menu again. Choose the default NixOS installer entry and wait for the live console. [Microsoft Secure Boot guidance](https://support.microsoft.com/en-us/servicing/os/secure-boot/2026/03/secure-boot-troubleshooting-guide)
3. Run the commands below. Expect readable video, working keyboard, `x86_64`, firmware size `64`, the installer marker with a system path and usable network hardware. If the marker is missing, check the ISO. If firmware size is absent, try the UEFI menu entry. This image requires 64-bit UEFI.

   ```bash
   uname -m
   cat /sys/firmware/efi/fw_platform_size
   cat /etc/app-configs/linux-niri-toplevel
   lsblk -e7 -o NAME,PATH,TYPE,SIZE,MODEL,SERIAL,TRAN,FSTYPE,MOUNTPOINTS
   ip -br link
   nixos-generate-config --show-hardware-config --no-filesystems
   ```
4. Compare the discovered controller, initrd, firmware and graphics requirements to the project hardware module on the support PC. If edits are needed, review them, build, rehearse and reflash the matching ISO. The installer copies that exact system. Booting a helper PC cannot detect the destination laptop's hardware.
5. For the write phase, power off. **Physically disconnect the Windows SSD** and other data drives, or use a separate isolated UEFI helper with its own drives disconnected. If neither is possible, stop after discovery. Connect the Kingston externally and boot the small USB again. Keep the Kingston connected through installation and the subsequent NixOS boot. The helper route still requires the destination hardware review.

## 4. Identify the Kingston and prepare the live checkout

Use the networked route below on the isolated machine. For Wi-Fi, if the ISO provides `nmtui`, choose **Activate a connection**, select the SSID, choose **Activate**, enter the Wi-Fi password locally, then **Back** → **Quit**. Wired Ethernet is another option. Test DNS with `getent hosts github.com`. Without connectivity use the “Prepared offline installation” in the candidate [installation runbook](niri-install.md) and the [verified Git bundle](niri-first-boot-handoff.md#prepare-the-offline-checkout). On that route, use the local bundle for the checkout, perform the same physical disk checks below, and use the runbook’s verified kit import in place of the `nix eval` and `nix run` preparation lines. The import supplies `target_user` and `prepare` for step 5. Generate the offline Disko kit for the actual Kingston by-id, never the VM example.

In a new **Bash** shell on the live system, run the following. Use the commit and system path from the build record. The repository URL must serve that exact commit, or use the path to its verified Git bundle.

```bash
set -euo pipefail
read -rp 'Repository URL or verified bundle path: ' CONFIG_SOURCE
read -rp 'Full reviewed deployment commit: ' INSTALL_REV
read -rp 'Recorded system store path: ' ACCEPTED_SYSTEM
[[ "$INSTALL_REV" =~ ^[0-9a-f]{40}$ ]]
git clone "$CONFIG_SOURCE" app-configs
cd app-configs
git switch --detach "$INSTALL_REV"
test "$(git rev-parse HEAD)" = "$INSTALL_REV"
test -z "$(git status --porcelain)"
test -f nix/hosts/linux-niri/system.nix
test -f ops/niri/verify-first-boot.sh
read -r system < /etc/app-configs/linux-niri-toplevel
test "$system" = "$ACCEPTED_SYSTEM"
test -x "$system/bin/switch-to-configuration"
lsblk -e7 -o NAME,PATH,TYPE,SIZE,MODEL,SERIAL,TRAN,FSTYPE,MOUNTPOINTS
findmnt -t iso9660
swapon --show
ls -l /dev/disk/by-id/
```

Identify the small stick by its mounted ISO. Identify the Kingston independently by physical label, model, serial and capacity. Both may say USB. Stop if a Windows disk or any other writable data disk is visible, or a USB enclosure makes identification ambiguous. Do not guess by device order.

```bash
read -rp 'Kingston whole-disk /dev/disk/by-id/ path: ' DISK
[[ "$DISK" =~ ^/dev/disk/by-id/[^/]+$ && ! "$DISK" =~ -part[0-9]+$ ]]
test -b "$DISK"
test "$(lsblk -dnro TYPE "$DISK")" = disk
disk_node=$(readlink -e "$DISK")
lsblk -p -o NAME,TYPE,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$disk_node"
check_disks() {
  local live_source live_disk disk_list nodes node
  live_source=$(findmnt -rn -t iso9660 -o SOURCE) || return 1
  [[ -b "$live_source" ]] || return 1
  live_disk=$(lsblk -snrpo NAME,TYPE "$live_source" | awk '$2 == "disk" {print $1}') || return 1
  [[ -b "$live_disk" && "$live_disk" != "$disk_node" ]] || return 1
  disk_list=$(lsblk -dnrpo NAME,TYPE | awk '$2 == "disk" && $1 !~ /^\/dev\/zram[0-9]+$/ {print $1}' | sort) || return 1
  [[ "$disk_list" == "$(printf '%s\n' "$disk_node" "$live_disk" | sort)" ]] || return 1
  [[ "$(readlink -e "$DISK")" == "$disk_node" ]] || return 1
  nodes=$(lsblk -nr -o KNAME "$disk_node") || return 1
  for node in $nodes; do
    [[ -d "/sys/class/block/$node/holders" ]] || return 1
    [[ -z "$(ls -A "/sys/class/block/$node/holders")" ]] || return 1
    [[ -z "$(lsblk -dnro MOUNTPOINTS "/dev/$node")" ]] || return 1
  done
}
check_disks
test ! -e /dev/mapper/linux-niri-root
test ! -e /dev/disk/by-partlabel/linux-niri-luks
test ! -e /dev/disk/by-partlabel/linux-niri-esp
test ! -L /mnt
mounts=$(findmnt -rn -o TARGET)
if grep -Eq '^/mnt(/|$)' <<<"$mounts"; then echo '/mnt is in use'; exit 1; fi
if [[ -d /mnt ]]; then test -z "$(ls -A /mnt)"; fi
target_user=$(nix eval --raw -f nix/vars/default.nix username)
[[ "$target_user" =~ ^[a-z_][a-z0-9_-]*$ ]]
flake="git+file://$PWD?dir=nix&rev=$INSTALL_REV"
preview=$(nix run --max-jobs 1 --cores 2 --no-update-lock-file "$flake#disko" -- \
  --dry-run --mode format,mount --flake "$flake#linux-niri" --argstr targetDisk "$DISK")
prepare=${preview##*$'\n'}
[[ "$prepare" == /nix/store/*-disko-format-mount/bin/disko-format-mount && -x "$prepare" ]]
less "$prepare"
```

The two-disk check expects a directly flashed stick mounted as ISO9660 and one external Kingston. If it fails, inspect the device list and boot medium before proceeding. Read the generated script and its referenced device scripts. Press **q** to close the pager. The preview must name the chosen Kingston. Any existing filesystem you did not expect, active swap, mount, holder, duplicate label, changed disk identity or failed check means **stop before formatting**. Leave the drives connected in the same ports. In this shell initialize the [private installation logger](niri-first-boot-handoff.md#keep-a-private-installation-log). Run `type log_install_step` to confirm it is available.

## 5. Install the system and seed the checkout

**The next privileged command erases the selected Kingston.** Display its identity again, compare to the physical device and verify the Windows SSD is disconnected. Run each block separately. Enter the new LUKS passphrase directly at the Disko prompt and keep it for every cold boot.

```bash
check_disks
lsblk -dp -o NAME,SIZE,MODEL,SERIAL "$DISK"
read -rp 'Type the verified Kingston whole-disk by-id again to erase it: ' confirm_disk
test "$confirm_disk" = "$DISK"
check_disks
sudo "$prepare"
test "$(findmnt -nro FSTYPE -M /mnt)" = ext4
test "$(findmnt -nro FSTYPE -M /mnt/boot)" = vfat
for spec in '/mnt /dev/mapper/linux-niri-root' '/mnt/boot /dev/disk/by-partlabel/linux-niri-esp'; do
  read -r mount_at expected <<<"$spec"
  source_dev=$(findmnt -nro SOURCE -M "$mount_at")
  test "$(readlink -e "$source_dev")" = "$(readlink -e "$expected")"
  lsblk -snrpo NAME "$source_dev" | grep -Fx "$disk_node"
done
```

Both checks must trace back to the same Kingston. Run the following to copy the recorded system, persist the installer log even if the copy fails, enrol the ordinary user and verify the portable EFI loader. Enter the new **login password** at the password prompt. It is separate from the disk passphrase.

```bash
sudo install -d -m 0700 /mnt/var/log/app-configs
persisted_log=$(sudo mktemp /mnt/var/log/app-configs/install-XXXXXXXX.log)
printf '%s\n' "commit=$INSTALL_REV" "system=$system" >> "$install_log"
sudo -v
rc=0
log_install_step 'Install recorded generation' sudo -n nixos-install \
  --no-root-passwd --no-channel-copy --root /mnt --system "$system" || rc=$?
sudo install -m 0600 "$install_log" "$persisted_log"
printf 'Installed log: %s\n' "${persisted_log#/mnt}"
test "$rc" = 0
rc=0
sudo nixos-enter --root /mnt -c "passwd $target_user" || rc=$?
printf '%s  EXIT %s  Enrol account\n' "$(date -u +%FT%TZ)" "$rc" >> "$install_log"
sudo install -m 0600 "$install_log" "$persisted_log"
test "$rc" = 0
log_install_step 'Verify EFI fallback loader' sudo -n test -s /mnt/boot/EFI/BOOT/BOOTX64.EFI
sudo install -m 0600 "$install_log" "$persisted_log"
printf 'Installed login name: %s\n' "$target_user"
git bundle create "$install_log_dir/app-configs.bundle" HEAD
git bundle verify "$install_log_dir/app-configs.bundle"
sudo install -d -m 0755 /mnt/var/lib/app-configs
sudo install -m 0644 "$install_log_dir/app-configs.bundle" /mnt/var/lib/app-configs/install.bundle
printf '%s\n' "$INSTALL_REV" | sudo tee /mnt/var/lib/app-configs/install-revision
sudo nixos-enter --root /mnt -c "su - $target_user"
```

You are now the installed ordinary user. Start `bash`, run the [fresh-home folder block](niri-first-boot-handoff.md#seed-and-verify-the-installed-users-home), and check that it exits successfully. In that Bash shell run the following. If the destination already exists, inspect it and compare its revision before proceeding. The portable bundle supports the first checkout offline.

```bash
test "$(id -u)" -ne 0 &&
  test ! -e "$HOME/Projects/app-configs" && test ! -L "$HOME/Projects/app-configs" &&
  git clone /var/lib/app-configs/install.bundle "$HOME/Projects/app-configs" &&
  test "$(git -C "$HOME/Projects/app-configs" rev-parse HEAD)" = "$(cat /var/lib/app-configs/install-revision)"
```

Type `exit` twice (inner Bash, then installed user's login shell). Back in the live shell, confirm the install log and loader, then power down:

```bash
installed_rev=$(sudo nixos-enter --root /mnt -c "su - $target_user -c 'git -C ~/Projects/app-configs rev-parse HEAD'")
log_install_step 'Verify installed checkout' test "$installed_rev" = "$INSTALL_REV"
sudo install -m 0600 "$install_log" "$persisted_log"
sudo test -s "$persisted_log"
sudo test -s /mnt/boot/EFI/BOOT/BOOTX64.EFI
sync
sudo umount /mnt/boot
sudo umount /mnt
sudo cryptsetup close linux-niri-root
sudo poweroff
```

## 6. First boot and functional checks

1. Remove the small flash drive. Connect the Kingston to the destination laptop. Use its one-time **UEFI** boot menu and select the Kingston. At the encryption prompt enter the LUKS passphrase. At **tuigreet** enter the enrolled username, **Enter**, login password, **Enter**. If the installer console returns, remove the flash drive. If the external boot entry is missing, check that firmware allows USB boot and use the [USB rescue procedure](niri-install.md). Keep the installed partitions intact during rescue.
2. Press **Super+T** to open Ghostty. Run `cd ~/Projects/app-configs`, then `bash ops/niri/verify-first-boot.sh /nix/store/… FULL_COMMIT`, replacing **both** arguments with the exact values from the independent deployment record. Each line names the check. Exit 0 means every listed check passed. For the copy log run `sudo ls -lt /var/log/app-configs`, then `sudo less /var/log/app-configs/<printed-filename>`. For boot failures on the installed system use `sudo journalctl -b -p warning`. Keep logs private.
3. Test ordinary-user networking: `nmtui` → **Activate a connection** → select the required Wi-Fi → **Activate**. Run `getent hosts github.com` for DNS and `git ls-remote https://github.com/UtmostCreator/app-configs.git HEAD` for HTTPS access. Both should return results. In the checkout, use `git remote set-url origin https://github.com/UtmostCreator/app-configs.git` once ready to fetch updates.
4. As the installed user, run `codex login`, follow the sign-in prompt and run `codex login status`. Run `claude` and complete its sign-in. Ask each to identify the installation runbook in the local checkout. Successful responses exercise account access as well as the binaries. Keep credentials out of the log.
5. Press **Alt+Space**, finish any launcher welcome screen, search for **Ghostty**, select it and press **Enter**. Confirm a new terminal appears. Test screen lock/unlock, suspend/resume, sound and a real screenshot in `~/Pictures/Screenshots` on the laptop. Record results in the [trial ticket](../../work/active/T-0032-niri-trial-session/ticket.md).
6. To verify Windows independently, shut down, disconnect the Kingston, reconnect the original SSD and restore the original firmware settings. Select **Windows Boot Manager** and verify normal sign-in. To use NixOS with both drives connected later, select the external Kingston in the one-time menu with the firmware settings required by the project image. Recheck BitLocker recovery access before switching Secure Boot settings.


## Plan the remaining time

Allow roughly **20–45 minutes** to flash, validate, boot and inventory the laptop, **30–90 minutes** for the isolated install, account and checkout once a matched kit is ready, and **30–60 minutes** for cold boot, networking and assistant sign-in. These are operator planning estimates. Download speed, rebuilds and hardware fixes can extend them. Schedule the desktop workflow and independent restore separately after first boot. The highest-value first milestone is a terminal on the Kingston that can open this checkout and use a signed-in assistant.
