# Prepare a Niri installer USB or a bootable Kingston SSD

The flash drive carries the installer. The Kingston holds the installed, encrypted NixOS system. Both operations overwrite the selected device. Start from the [build and test record](../../work/active/T-0032-niri-trial-session/ticket.md#verification-record) for the exact image, checksum and target system. The older laptop is the first physical trial.

For an existing Kingston or a suspected transport problem, use the [Linux storage read and write checks](storage-diagnostics.md) with separate live media and an evidence stick.

## Write the installer to a flash drive

1. Leave the Kingston disconnected from the working PC. The prepared checkout retains the image with a Git-ignored Nix garbage-collection root. From the repository root, use `ISO="$PWD/nix/result-niri-installer/iso/nixos-minimal-26.11.20261114.5d2b81a-x86_64-linux.iso"` for this build. For a later build use its verified ISO instead. Run `sha256sum "$ISO"` and compare it with the record. An 8 GB or larger flash drive fits this image. Back up anything you want to keep.
2. Run `lsblk -dp -o NAME,TRAN,TYPE,SIZE,MODEL,SERIAL` before and after inserting the flash drive. Match the newly appeared whole device, its size and model. Identify its whole-disk link under `/dev/disk/by-id/`. Stop if there is any ambiguity.
3. On the current GNOME workstation, run `gnome-disks --restore-disk-image="$ISO"`. Select the identified **flash drive**, check the destination again in the confirmation dialog and start the restore. Wait for completion, eject the drive and reinsert it.
4. Set `USB` to that verified flash drive’s whole-disk by-id path. Verify the bytes that will boot with the read-only comparison below. Exit status zero means they match. Eject the device after verification.

```bash
test -f "${ISO:?select the recorded project ISO}" &&
  test -b "${USB:?select the verified flash drive by-id}" &&
  sudo cmp --bytes="$(stat -c %s "$ISO")" -- "$ISO" "$USB"
```

On the older laptop use its one-time boot menu to select the UEFI USB entry. At the live console check the firmware, keyboard, video and network before changing storage. The current image targets x86-64 with 64-bit UEFI and Secure Boot disabled. [Older-laptop preflight and install](niri-install.md#3-test-the-vm-then-the-older-laptop) · [NixOS USB boot instructions](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb)

## Install directly onto the Kingston, then move it

Use the live USB on the older laptop or on a separate UEFI helper PC. For the first physical run, power down the installing machine and disconnect other writable system/data disks. Attach the Kingston as the sole installation target. This route lets the working GNOME PC stay online.

1. Capture hardware information on the **destination laptop** and review its hardware module before the final image build. When using a helper PC, retain the laptop’s configuration.
2. Boot the helper or laptop from the verified flash drive. Confirm the USB and the Kingston by model, serial, size and whole-disk by-id link. Verify the Kingston has no mounts, swap or active holders. Confirm its contents can be erased.
3. In the [installation procedure](niri-install.md#4-install-enrol-the-account-cold-boot), replace the VM-only `DISK=/dev/disk/by-id/virtio-niri-rehearsal` with the verified **Kingston** whole-disk by-id. Preview the resulting Disko script. Check both target mounts, install the recorded closure, enrol the user password and verify the fallback loader. Enter the disk passphrase locally.
4. Unmount the target, close its LUKS mapper and power down. If prepared on a helper, move the Kingston into the older laptop. Remove the flash drive. Cold boot using the laptop’s firmware, unlock the SSD, log into Niri and compare the running system path against the record. Keep the flash drive for rescue.

Writing the live ISO to the Kingston would turn it into installer media. An installed Kingston has its own ESP, LUKS2 volume, user account and system generation. Formatting the Kingston **while it is attached to the running daily PC** remains deferred until its automatic source-disk, mount, swap and holder refusals have been tested. [Storage decision](../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md)

## Sign in to the assistants

As the ordinary live user, check `claude --version` and `codex --version`. For the durable account setup, repeat these checks after booting from the Kingston and sign in as the installed user. Run `claude` for Claude Code or `codex login` for Codex. In a text-only session, `codex login --device-auth` offers device sign-in when enabled for the account. Check Codex locally with `codex login status`. Live-USB sign-in is temporary. Keep account credentials off the installer image.
