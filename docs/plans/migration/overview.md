# Niri migration overview

The first deployment is an x86-64 laptop with its own encrypted disk, Niri session and integrated Home Manager user. The current NixOS/GNOME PC stays available for Claude, builds and recovery throughout installation.

1. Confirm an authenticated Claude session on the working PC. Select the exact configuration revision and record the installer checksum.
2. Build `linux-niri` and its declared user environment. Rehearse installation from a blank UEFI disk and empty home, then prove rollback and offline rescue.
3. Install on the destination laptop. Check first login, laptop hardware, security services and portals before trialling Dux then Noctalia.
4. Validate daily workflows with dummy data and demonstrate Kopia restoration. Enrol account-bound services individually before migrating personal data.

Use the [installation runbook](../../platforms/nixos/niri-install.md) for the two routes and [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md) for results. Package scope and the separate existing-PC backup procedure are in the [migration plan](../niri-migration.md).
