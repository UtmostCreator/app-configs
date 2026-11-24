# NixOS and Niri migration

Build one locked `nixosConfigurations.linux-niri` for the laptop, with a dedicated integrated Home Manager user and Disko storage. The existing NixOS/GNOME PC is the working machine throughout preparation, installation and recovery. It can build the target and run Claude while the destination reboots. Start with the [installation runbook](../platforms/nixos/niri-install.md).

## Milestones

| Order | Deliverable | Evidence to advance |
| --- | --- | --- |
| 0 | Claude accessible on the working PC before touching a disk; packaged CLI available to the installer and installed user | Ordinary user runs the CLI and completes one authenticated session. Keep the offline runbook handy. |
| A | System, storage, session and home from the same locked configuration | Build the actual toplevel, validate the installed KDL and bound commands, inspect forbidden desktop dependencies and session units. |
| B | Fresh install to a disposable UEFI disk | Unlock after a cold boot, authenticate at greetd, open Ghostty and Vicinae, connect from a TTY, capture a screenshot and log out. Start with an empty home. |
| C | Recovery | Boot two different generations. Break graphical startup in the guest and recover via TTY or enrolled SSH. Rescue from USB without formatting. |
| D | Older laptop first | Boot the USB and check 64-bit UEFI, storage, graphics and network before writing. Repeat installation and recovery there. Check GPU, outputs, input, Wi-Fi, audio, lock and suspend on each laptop selected for daily use. |
| Daily use | Shell, workflows, then personal state | Trial Dux then Noctalia, accept the first passing candidate. Use dummy data for multi-window Code, sharing and capture tests. Open restored Kopia copies before enrolling sync or migrating the real vault. |

[ADR-0046](../architecture/decisions/0046-niri-desktop-installation-decision-register.md) names the component owners. [T-0032](../work/active/T-0032-niri-trial-session/ticket.md) holds acceptance and evidence. [ADR-0049](../architecture/decisions/0049-niri-safest-staged-installation-order.md) governs installation order.

At every milestone run the functional check and record a comparable performance sample. Repeat on the same hardware and inputs after a change, and keep a measured improvement only if the workflow still passes. [Performance baselines](../work/active/T-0032-niri-trial-session/ticket.md#performance-at-each-milestone)

## Application preparation

| Stage | Packages or functions | Configuration and acceptance |
| --- | --- | --- |
| First install | Claude Code, Codex CLI, Git, networking CLI, native Niri, Ghostty, Vicinae, brightnessctl, playerctl, PipeWire/WirePlumber, xwayland-satellite | Build from the target package set. Check console networking, keys and graphical startup without downloads. |
| Authentication and portals | greetd/tuigreet, swaylock/swayidle, one polkit agent, GNOME Keyring, GNOME ScreenCast portal and GTK chooser | Verify actual PAM, D-Bus, file selection and screen-sharing behaviour. Keep these providers through shell trials. |
| Daily applications | Browser and Code, KeePassXC and Kopia, file manager, Obsidian, communication tools, Android Studio, diagnostics and screenshot tools | Audit against the individual app ADRs. Install needed packages separately from enabling machine-specific accounts or background jobs. Verify the MIME handler and application itself. |
| Optional desktop features | Bar, notifications, tray, OSD, clipboard and window actions | Follow ADR-0045 and ADR-0048. Pin shell assets and plugins; keep one owner per function and test service crash/restart. |

Prebuild the [daily workflow packages](../../nix/hosts/linux-niri/workflow-apps.nix) with `nix build --no-link --no-update-lock-file ./nix#niri-workflow-apps`. This output groups the actual locked packages for offline copying. It neither installs a profile nor starts a client. After recovery, add the chosen packages to the integrated home in a reviewed generation. Configure sharing, sync and application accounts separately.

The Home Manager configuration under `nix/hosts/linux-niri/` is the package manifest for the initial user. Existing `linux-desktop` modules mix application choices with GNOME extensions and account services. Import a module only after checking its dependencies and activation behaviour. Keep mutable app preferences and personal databases in the backup scope.

## Release transition

Keep the GNOME configuration available in releases while the owner tests the separate Niri installation. Once the owner confirms NixOS + Niri works for daily use on the laptop, tag the last verified GNOME-capable revision with its lockfile. Subsequent releases can then remove the GNOME desktop target and desktop-specific modules. Keep the tag as the reproducible reference for the older setup. The new host imports its own system, storage, hardware, home and KDL from `nix/hosts/linux-niri/`. It shares the desktop-neutral MIME defaults and package definitions. The Niri screen-sharing portal and credential provider remain explicit support components. A source-isolation rehearsal produced the identical installed closure with all GNOME host and desktop module files absent. [Verification record](../work/active/T-0032-niri-trial-session/ticket.md#verification-record)

## Existing PC and any later in-place cutover

The blank-disk milestone has no dependency on upgrading GNOME or adopting the PC's live `/etc/nixos` into the repository. T-0029 and the following historical backup procedure concern a separately approved change **to that PC**. Check its current paths, timers and generation numbers afresh at that point.

### Mandatory backup before any live change

For a later change to the working PC, follow the [T-0029 backup and rollback procedure](../work/active/T-0029-nixos-system-ownership/ticket.md#existing-pc-backup-and-rollback). The laptop has its own [install and recovery rehearsal](../platforms/nixos/niri-install.md).
