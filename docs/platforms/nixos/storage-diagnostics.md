# Linux storage read and write checks

Use these checks after a storage incident or when accepting a test disk. Preserve anything you need on independent storage before stressing a drive that has reported I/O errors. Keep diagnostics private because SMART can include device identifiers.

## Scan the Kingston read-only

Copy `ops/niri/scan-kingston.sh` to the writable evidence flash drive. Boot separate Linux live media and leave the 960 GB Kingston connected. Keep its partitions unmounted and its LUKS mapping closed. Mount the evidence drive and run from its root:

```bash
bash ./scan-kingston.sh --list
bash ./scan-kingston.sh
```

Select the Kingston by number. The script checks the disk identity, mounts and holders, optionally collects SMART, and reads every host-visible logical sector. It saves `kingston-scan-*.log` beside the script. A complete result shows the entire block range, `Pass completed`, and the final bad-block and error counts. Check the counts as well as the exit status. With USB attached, the result covers the drive, bridge, cable and host connection together. Repeat on a known-good connection to isolate a recurring fault.

## Check writes on a mounted filesystem

Copy `ops/niri/check-filesystem-write.sh` to the live media or evidence drive. Supply a writable directory on the **mounted test filesystem**. Use `findmnt` to verify which filesystem the directory belongs to. Run as a user with permission to write there:

```bash
findmnt -T /path/on/test-filesystem
bash ./check-filesystem-write.sh /path/on/test-filesystem
```

The probe creates one 16 MiB temporary file, flushes it, compares a direct readback checksum and removes the file. It never takes a block device as input. A pass samples the selected filesystem and connection. It does not exercise writes across the whole device. A filesystem without direct-read support leaves the probe incomplete. Keep an installed root in its current mount mode if it reports read-only or emergency read-only and investigate from the live environment. [Offline EXT4 inspection](niri-install.md#read-only-inspection-after-an-ext4-incident)
