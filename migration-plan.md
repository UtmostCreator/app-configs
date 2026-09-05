# Niri migration plan

> Status: active alternative; no desktop migration is authorized by this plan.
> Sibling plan: `repo-docs/hyprland-migration-plan.md`.
> Decision support: `repo-docs/niri-vs-hyprland-comparison.md`.

This document covers only the possible GNOME-to-Niri migration. Completed
repository-thinning history was removed; Git remains the archive for that work.

## Goals

1. Add an in-repository `nixosConfigurations.linux-desktop` host so the existing
   `nix/modules/nixos/` modules have an explicit system owner.
2. Introduce Niri additively while GNOME remains selectable as the rollback path.
3. Move desktop configuration to the correct owner: NixOS for the system session
   and Home Manager for user configuration.

## Current verified state

- `nix/flake.nix` exposes Home Manager and Darwin configurations, but no
  `nixosConfigurations` output.
- `nix/hosts/linux-desktop/home.nix` imports the current GNOME Home Manager
  modules.
- `ops/validate-config.sh` currently bans `programs.<name>.enable = true` across
  all `nix/modules/`; that rule must be narrowed to Home Manager modules before
  a NixOS Niri module can use `programs.niri.enable`.
- Niri has no existing chezmoi-owned path, so a new Home Manager Niri config does
  not create dual ownership.

Recheck these facts immediately before implementation because desktop and flake
configuration can drift.

## Ownership model

| Concern | Owner |
| --- | --- |
| Display manager, session registration, portals, polkit, audio, graphics, Xwayland | NixOS |
| `niri/config.kdl`, Waybar, notifications, idle/lock, user applications | Home Manager |
| Cross-platform dotfiles and macOS-specific files | chezmoi |
| Bootstrap and repository validation | `ops/` |

The Niri program enablement belongs in `nix/modules/nixos/`. The raw KDL user
configuration belongs under a Home Manager module. No file may be owned by both
Home Manager and chezmoi.

## Decisions required before implementation

- Display manager: Ly or greetd/tuigreet.
- File-picker and portal composition.
- Notification service: mako or swaync.
- Idle and lock services.
- Screenshot workflow.
- Final compositor choice: Niri or Hyprland. Do not implement both plans.

## Migration phases

### 0. Preflight

- Confirm GNOME is the working baseline and record the current NixOS generation.
- Choose the components above.
- Inventory GNOME-specific modules, settings, shortcuts, extensions, and file
  preferences that must be translated or deliberately dropped.
- Define the observable success signal and keep GNOME available for rollback.

### 1. Add the NixOS system layer

- Add `nix/hosts/linux-desktop/system.nix`.
- Add NixOS modules for Niri, the display manager, portals, and the required
  audio/graphics session services.
- Add `nixosConfigurations.linux-desktop` to `nix/flake.nix`.
- Narrow validator rule 6 to `nix/modules/home/` in the same change.
- Stage every new Nix file before evaluating the flake; flakes ignore untracked
  files.
- Build without activating the system.

### 2. Activate and capture hardware state

- Apply on an approved NixOS host.
- Confirm the greeter offers both GNOME and Niri.
- Capture `niri msg outputs` and input-device names for host-specific settings.
- Confirm `WAYLAND_DISPLAY` and the user-session environment reach systemd user
  services.

### 3. Add Home Manager Niri configuration

- Add one Home Manager Niri module and raw `config.kdl` source.
- Configure monitors, keyboard layouts, pointer behavior, and essential binds.
- Keep Waybar, notifications, lock, and idle services disabled until the base
  session is proven.

### 4. Complete the Wayland service graph

- Add exactly one launch path for each bar, notification daemon, polkit agent,
  idle daemon, and lock service.
- Verify portals, file dialogs, screen sharing, audio, and Xwayland applications.

### 5. Reach workflow parity

- Port launcher, clipboard, screenshots, terminal, browser, editor, media,
  workspace, and monitor shortcuts.
- Test every translated bind and record intentionally dropped behavior.

### 6. Cut over from GNOME

Use one revertable commit:

- Remove the GNOME-specific Home Manager modules and their imports.
- Remove GNOME-only blocks from `nix/modules/home/gui.nix` after migrating any
  still-required GTK settings.
- Make Niri the default session while keeping a previous NixOS generation as the
  rollback path.

### 7. Verify and reconcile

```bash
bash ops/validate-config.sh
mise run test:bash
mise run repo:check
```

Also build the NixOS and Home Manager targets, verify chezmoi ownership does not
overlap the new Niri paths, and cold-test login, lock, notifications, portals,
screenshots, audio, and external displays.

## Rollback

- Before cutover, select GNOME at the greeter.
- After activation, boot or switch to the prior NixOS generation.
- Revert the single GNOME-cutover commit and rebuild.

## Definition of done

- Niri starts cleanly and is the chosen default.
- Login, lock, notifications, portals, polkit, screen sharing, screenshots,
  clipboard, audio, and monitor scaling work.
- Every retained shortcut is tested.
- GNOME-specific Home Manager modules and references are gone.
- Repository validation, tests, and relevant Nix builds pass.
