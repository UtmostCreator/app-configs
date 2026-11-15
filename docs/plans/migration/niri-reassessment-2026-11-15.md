# Niri migration reassessment (2026-11-15)

Read-only research at main ed39171, written up as a standalone file because the
tracked migration docs are being refreshed by another session (T-0033, refresh
stale migration docs, not yet committed). This file edits none of them.

Evidence labels: VERIFIED (checked in the repo or by nix eval), WEB (fetched
2026-11-15), INFERRED, ESTIMATE, unverified.

## 1. Status and target

- No migration is authorised. GNOME stays the default session.
- Working target: niri, through the nixpkgs `programs.niri` module (no niri-flake
  needed).
- The current docs have no single target. `docs/plans/migration/overview.md` is
  the niri plan, marked "active alternative". `docs/plans/hyprland-migration.md`
  is a parallel Hyprland plan, and the final choice is an open decision there.
  `docs/plans/migration/implementation.md` is the old dotfiles-migration plan,
  not a compositor plan.
- Hyprland 0.57.2 in the pinned nixpkgs removed `.conf` support (per the
  desktop-migration claim audit, owned by another session and not yet committed),
  so the Hyprland plan's config assumptions are stale.

## 2. What changed since the docs were written (last commit 2026-10-22)

VERIFIED with nix eval on the root nixpkgs input (lock node nixpkgs_2, e126e9e7,
lastModified 2026-11-15). Lock node 674a202 is a different, non-root node.

Package versions in the pinned nixpkgs:

| Group | Versions |
|---|---|
| Compositor and shell | niri 26.04, noctalia 5.5.0, dux-shell 2.1.2 (formerly DankMaterialShell), waybar 0.16.0 (built with the niri modules), swaynotificationcenter 0.12.6, quickshell 0.3.2 |
| GNOME side | gnome-shell 51.0, xdg-desktop-portal-gnome 51.0, gnome-keyring 50.0 |
| Session helpers | xwayland-satellite 0.8.3, swaylock 1.8.6, swayidle 1.9.1, mako 1.11.0, wlsunset 0.4.0 |
| Apps and tools | vicinae 0.29.2, flameshot 15.0.0, grim 1.5.0, slurp 1.5.0, satty 0.22.0, wl-clipboard 2.3.0, cliphist 0.7.0 |

Modules:

- NixOS: `programs.niri` wires sessionPackages, the niri unit, gnome-keyring
  (mkDefault) and portals (default gnome+gtk, Secret via gnome-keyring,
  xdg-desktop-portal-gnome). Also `programs.noctalia` (with recommendedServices)
  and `programs.dux-shell`.
- Home Manager: `wayland.windowManager.niri` (settings, checkConfig),
  `programs.noctalia` (TOML settings, checkConfig, systemd), plus swaync,
  swaylock, swayidle, wlsunset, gammastep and cliphist.

Other changes:

- The T-0042 install selection landed. Its groups are HM options, and the preview
  evaluates `homeConfigurations.<host>.config` only.
- The pinned GNOME is 51.0, while the host runs 50.1 (per T-0029, system
  ownership, owned by another session and not yet committed).
- Default-session trap: the pinned `programs.niri` sets
  `services.displayManager.defaultSession = lib.mkDefault "niri"`, so it must be
  overridden to GNOME's session name.

## 3. Stale claims in the existing docs (for T-0033 to fix)

T-0033 owns these fixes; this file does not edit them.

| Where | Stale claim |
|---|---|
| `docs/plans/migration/overview.md` (lines 79 and 127) | Treats the greeter as a pre-decision. The audit and T-0032 (niri trial session, not yet committed) defer it and keep GDM. |
| `docs/plans/migration/overview.md` (line 71) | "Narrow rule 6" omits rule 11 (xdg allowlist, `ops/validate-config.sh` lines 583-617) and rule 13 (--eval, starts at line 782). |
| `docs/research/niri-vs-hyprland.md` (lines 46, 69-70) and `docs/plans/hyprland-migration.md` (line 339) | Reference niri-flake `programs.niri.settings`, now outdated. |
| `docs/plans/hyprland-migration.md` | Rule 9 and 10 line refs are stale: rule 9 now starts at line 536, rule 10 at 563 in `ops/validate-config.sh`. |
| Migration docs | `nix/modules/nixos` now has 7 files (docker.nix and keyd-f1-remap.nix were added). |
| `docs/plans/future-upgrades.md` (lines 269, 278) | Vicinae extension "46-50". The audit says 46-51; the store metadata is unverified. |
| Audit | Its pins (2074cc67, HM 82ce401) are outdated. The current lock has HM a1293da7. |

## 4. Re-evaluation

### (a) System layer

- `nix/flake.nix` has no `nixosConfigurations` (homeConfigurations at line 181,
  darwinConfigurations only on the Apple side). T-0029 is a hard prerequisite.
  Moving the host to the flake also bumps the GNOME fallback from 50.1 to 51.0,
  which itself needs re-checking.
- The polkit agent is not provided by `programs.niri`. Noctalia: unverified.
- GDM: pin defaultSession to GNOME and check the sessionNames.
- Hybrid GPU: the AMD iGPU drives the screens, the NVIDIA dGPU runs nouveau.
  niri behaviour on it is unverified.

### (b) Shell

- Noctalia v5 collapses about 7-8 pieces (bar, notifications with history,
  launcher, lock, idle, OSD, wallpaper, clipboard history, tray) into 1-2
  (ESTIMATE).
- Night light and the polkit agent were not found built in (unverified).
- Overlap with Vicinae (launcher and clipboard): keep Vicinae as the owner and
  disable Noctalia's equivalents.
- Noctalia's GUI can rewrite its config.toml at runtime, which needs an ownership
  decision.
- Its unit targets graphical-session.target, so it would also start under GNOME
  unless bound to the niri session.
- Fallbacks: dux-shell (NixOS module only in nixpkgs), then Waybar 0.16 with
  SwayNC, swaylock and swayidle (all HM modules).

### (c) Components

| GNOME piece | niri replacement | Owner |
|---|---|---|
| gnome-keybindings dconf (16 bindings, Cyrillic twins) | niri binds in KDL | T-0031, T-0032 |
| vicinae-toggle-app, focus-tracker, resize and vscode-recent-projects D-Bus helpers | niri IPC; no minimise or scratchpad in niri 26.04 | T-0031 |
| vicinae GNOME extension | Dropped (Vicinae uses niri IPC) | T-0031 |
| appindicator | The shell tray | shell choice |
| flameshot | Portal Screenshot API; the multi-monitor fix is not in 26.04, so reproduce first. Alternatives: niri's screenshot action, or grim+slurp+satty | T-0032 |
| wl-clipboard | Unchanged | |
| default-apps, mimeapps | Unchanged | |
| gnome-files dconf | Keep | |
| xkb us,ru with grp:win_space_toggle | niri input xkb | T-0032 |
| audio | Unchanged; volume binds or the Noctalia OSD | |
| screen sharing | portal-gnome via `programs.niri` | T-0029 |
| night light | Not in the repo today; wlsunset or gammastep if wanted | |
| keyring | gnome-keyring via `programs.niri` (KeePassXC is the password manager) | T-0029 |
| multi-monitor | Per-output KDL from `niri msg outputs` | T-0032 |

### (d) Validator (T-0030)

- Rule 6 also checks programs.* in NixOS modules, so `programs.niri` and
  `programs.noctalia` fail today. HM `programs.noctalia` needs the allowlist too.
- Rule 11 needs the niri config.kdl and noctalia config.toml targets, plus rule 13.
- One owner each for the niri package, units, xwayland-satellite and portals.

### (e) T-0042 interplay

Only the media, security, go and macInput groups exist on main. A selectable niri
session works only for the HM half, unless the selection also feeds
nixosConfigurations call sites, with SELECTION_ARGS and preview support.
Recommendation: no selection group for the trial.

### (f) Test and rollback

- GNOME stays default; niri is a selectable session; the system gate is
  build-only; 2-4 weeks of daily use.
- Rollback: boot the previous generation (which also restores GNOME 50.1), plus a
  $HOME data backup.
- Record the HM drvPath baseline before any niri change. Currently
  linux-desktop activationPackage
  /nix/store/5jy9kmpvyihrz5xkjdb5hr5196lndr47-home-manager-generation.drv at
  ed39171; it changes with every lock bump.

## 5. Complexity reassessment (2026-11-15)

Verdict: ROUGHLY THE SAME, BUT SHIFTED. It did not drop.

Dropped:

- One shell replaces 5-7 hand-assembled pieces.
- Upstream NixOS and HM modules exist, with build-time config validation.
- No niri-flake is needed; waybar has niri modules as a fallback.
- The Hyprland churn is out of the decision.

Rose:

- The NixOS layer is still outside the flake, now with the GNOME 51 jump.
- A real validator rescope (rules 6, 11 and 13).
- T-0042's selection and preview are HM-only.
- The window-action rewrite (no minimise or scratchpad).
- Noctalia's youth: v5 stable is about 10 weeks old, and its modules are
  maintained by different people.
- New one-owner conflicts: Vicinae, and the runtime rewriting of config.toml.
- The flameshot gap on niri 26.04.

Effort (ESTIMATE, days; "before" is the audit's estimates):

| Workstream | Before | After |
|---|---|---|
| NixOS ownership (T-0029) | 1-2 | 2-3 |
| Validator (T-0030) | not estimated | 0.5-1 |
| niri minimal session (T-0032) | 3-8 | 3-6 |
| Window actions (T-0031) | not estimated | 2-4 (+2-4 for hide emulation) |
| Shell | hand-built, 5-7 pieces | +2-4 with Noctalia, or about +4-6 with Waybar+SwayNC |
| Selection plumbing (T-0042) | none | 1-2, only if selectable |
| Total | about 6-12 | about 9-17 |

Reading: shell and compositor config got cheaper; ownership, validator,
selection and window-action work got more explicit. The effort is about the same,
shifted from "assemble a desktop" to "own the system layer and the window
helpers".

## 6. Phases with gates

| Phase | Work | Gate |
|---|---|---|
| P0 | T-0029 | The flake builds nixosConfigurations, build only. Review the closure diff. Check GNOME 51. |
| P1 | T-0030 | Validator rescope, with bats. |
| P2 | T-0031 | The spec, plus the GNOME helper refactor, with GNOME behaviour unchanged. |
| P3 | T-0032 | The niri session is built, defaultSession pinned to GNOME, drvPath baseline recorded. |
| P4 | Shell choice | Decision gate. |
| P5 | Daily use | 2-4 weeks, with T-0032's checklist. |
| P6 | Cutover | A separate decision. |

## 7. Risks

- The GNOME 51 jump.
- The flameshot portal gap.
- The hybrid GPU on nouveau.
- Noctalia's age and its runtime config rewriting.
- The Vicinae overlap.
- The T-0042 plumbing.
- Validator duplicates.

## 8. Decisions for the user (recommendation first)

1. Confirm niri as the target, with Hyprland parked and retired after the trial: yes.
2. Shell for the first trial: none at first (niri defaults plus the minimum), then
   Noctalia as a separate step. Fallbacks: dux-shell, then Waybar+SwayNC.
3. Keep Vicinae as the launcher and clipboard owner, and disable Noctalia's
   equivalents: yes.
4. niri config owner: a plain xdg.configFile plus `niri validate` (recommended),
   or the HM module with its package, portal and xwayland-satellite options nulled.
5. Screenshot path: reproduce flameshot first.
6. Window hide on niri: the portable contract only, or an emulation (+2-4 d).
7. No T-0042 selection group for the trial.
8. Keep GDM.
9. Land T-0029 first, accepting the GNOME 50.1 to 51.0 bump.

## 9. Unverified

- Runtime niri on this GPU and on DP-3.
- Ctrl+Space and the ru-layout bindings under niri.
- The Vicinae extension on GNOME 51.
- Noctalia's night light, polkit agent and niri page.
- That niri's default config spawns waybar.
- dux-shell's details and its upstream HM module.
- The rule 13 line numbers beyond its start (line 782 re-checked in this worktree).
- The researcher ran no flake check or bats.

## 10. Notes for T-0033's owner

- Add a pointer from `docs/plans/migration/overview.md` to this file.
- The audit's pins are outdated (see section 3).
- The rule 9 and 10 line numbers in T-0033 are already off (536 and 563).
