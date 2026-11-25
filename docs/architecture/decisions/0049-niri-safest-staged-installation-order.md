---
adr: 49
title: "Staged installation and recovery of linux-niri"
status: decided-unverified
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, compositor, installation, migration, recovery, session]
permits: [gnome-free-niri-install, baseline-first-niri-install, integrated-home-manager, staged-pass-checks, standalone-security-services, isolated-comparison-before-cutover]
forbids: [gnome-desktop-on-the-niri-install, changing-the-existing-system-during-the-install, skipping-a-failed-stage, shell-owned-lock-before-trial-pass, first-activation-with-switch, cutover-without-window-parity-signoff]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 23, 27, 28, 33, 36, 38, 41, 45, 46, 47, 48, T-0029, T-0030, T-0031, T-0032, T-0033]
---
# ADR-0049: Staged installation and recovery of linux-niri
Status: decided-unverified · Date: 2026-11-22

**Laptop delivery · 24 November 2026 · 67% (4/6) · P0 · high complexity.** Locked system built. Blank-disk VM booted. Offline VM rescue passed. The physical installation and cold boot are operator-verified. Bind the complete artifact record to the destination and recover the known-good generation on the laptop. Keep the verified installer available through the first physical recovery. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

## Decision

The deployment unit is `nixosConfigurations.linux-niri`, including Home Manager, Disko, a login account and a complete minimal Niri session. The existing GNOME PC stays available for work, installer assistance and recovery while the laptop is tested. The historical GNOME pilot provides reference code and a smoke test for that pilot.

**First task for the operator:** get Claude Code working as an ordinary user before disk work. Follow the runbook's Claude preparation step, confirm the executable and version, sign in interactively and open the installation instructions from the reviewed checkout. Keep the runbook and rescue media accessible independently. Include Claude in the installed environment so a TTY remains useful after a desktop failure. Credentials and account enrolments are local inputs. [Installation runbook](../../platforms/nixos/niri-install.md)

## First-generation contract

- NixOS owns greetd and tuigreet, the normal user with interactive authentication and sudo, console networking, PipeWire/WirePlumber, native `programs.niri`, Soteria, and GNOME Keyring. Launch the authenticated session through `niri-session`. Use the same locked nixpkgs for Niri and graphics.
- The host integrates Home Manager with `useGlobalPkgs` and `useUserPackages`. Audit shared modules for `nixpkgs.*` before importing them. Home Manager owns the installed user's Niri KDL and session declarations. Configure an exclusive writer for every managed path. [Home Manager NixOS module](https://nix-community.github.io/home-manager/installation/nixos.html)
- Include Ghostty and its shortcut, Vicinae and its launcher shortcut, the commands invoked by KDL including `brightnessctl` and `playerctl`, directories, initial MIME handlers and `~/Pictures/Screenshots`. Declare swaylock and swayidle and use Niri's integration for `xwayland-satellite`. [Xwayland in Niri](https://niri-wm.github.io/niri/Xwayland.html)
- Keep account enrolments independent of desktop and app selection. Enable sync, gateways and personal background services individually after the baseline. `bash ops/install.sh --host linux-niri` builds the system toplevel. Add `--dry-run` to preview the build. On the installed system, the host marker rejects legacy standalone bootstrap. Disk preparation remains a separate operator action. The initial deployment must work directly from the flake.
- Disko owns GPT, a dedicated ESP and the LUKS2/ext4 root. The same definition serves installer USB on the laptop and preparation of the Kingston SSD on the running PC. Each route requires the destination hardware module and its own target identity checks. [ADR-0038](0038-disko-nixos-anywhere-fresh-hosts.md)

## Installation and recovery gates

| Gate | Evidence required to advance | If the check fails |
|---|---|---|
| A. Complete configuration | Build the exact host toplevel and run the flake checks with the lock unchanged. Validate the installed KDL with its Niri binary. Inspect the integrated user's packages, bound commands, evaluated sessions and closure against ADR-0047. | Fix the source and rebuild before writing a disk. |
| B. Fresh installation | Start from a disposable blank UEFI disk and an empty home. Install the same reviewed host and storage layout, establish a user password, detach install media and cold boot. Unlock LUKS, authenticate at tuigreet, start Niri, open Ghostty via its bind, connect via console networking, launch Vicinae and log out to authenticated login. | Keep the VM/disk evidence separate from build results. Correct the runbook and rehearse again. |
| C. Recovery | Introduce a controlled, reversible desktop fault in a genuinely different generation. Use a TTY or enrolled key-only SSH to recover, boot the previous known-good generation and protect it from routine GC. Rehearse USB rescue by unlocking and mounting the existing root and ESP and restoring the bootable generation. Repeat recovery on the laptop after installation. | Keep using the known-good generation. Record the failing route before further shell or data changes. |
| D. Destination usability | Cold boot the actual laptop. Check graphics and display hotplug, Wi-Fi, audio/mic, lid, lock, suspend/resume, portals and required apps. Run the shell comparison only after installation and recovery pass. | Continue daily work on the GNOME PC while the laptop issue is reproduced. |

Record each result in T-0032 with the environment (build, disposable VM or laptop), revision, result and evidence. Keep gaps open whenever the relevant environment has yet to be exercised. [Trial ticket](../../work/active/T-0032-niri-trial-session/ticket.md)

## Shell trial and daily workflows

Trial Dux first, then Noctalia if needed. Select the first candidate that passes the required workflows, reproduces its configuration with pinned assets, respects service ownership and recovers after a crash. The shell owns the bar, tray, notifications and OSD. Keep Vicinae as launcher and clipboard-history provider during the trial. Keep lock/idle and polkit independent of the shell. [ADR-0013](0013-desktop-shell-bar-notifications-trial.md) · [ADR-0045](0045-niri-windows-like-desktop-shell-ux.md)

Record an incorrect and a successful unlock, suspend and resume, and a monitor reconnect while locked. Share a window and a monitor in the real browser/call app, open and save via the GTK chooser, and retrieve a dummy credential after cold login. Stop the shell and check that windows, locking and authentication still work. With multiple Code projects open, select and focus the requested one. Try sensitive-window capture exclusion using dummy content before introducing the vault. Optional greeters and replacement portal or credential providers follow this trial. [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md) · [ADR-0048](0048-niri-launcher-vscode-project-workflows.md)

## What to retain

Keep the repository commit, its exact lockfile, host output, destination-hardware revision, installer image and checksum, resulting system store path, and recovery instructions together. Keep `system.stateVersion` and `home.stateVersion` as compatibility settings. Dependency updates receive separate review. Archive the flake inputs and copy the built closure and installer dependencies separately when preparing offline recovery.

An installed generation recovers declared software and configuration. Restore a project tree, a test copy of the KeePassXC database, required application data and access-recovery material from an independent Kopia repository. Keep credentials and the recovery identity outside the disk being recovered. Move personal data after these restore tests, hardware checks and daily workflows pass. [Backup decision](0033-communication-sync-notes-and-backup.md)
