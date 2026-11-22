---
adr: 49
title: "Niri on NixOS: safest staged installation order, per-stage choice, pass check and fallback"
status: proposed
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, compositor, installation, migration, recovery, session]
permits: [baseline-first-niri-install, atomic-stage-activation, staged-pass-checks, standalone-security-services, isolated-pc2-comparison]
forbids: [replace-before-cutover, combined-stage-changes, skipping-a-failed-stage, shell-owned-lock-before-trial-pass, first-activation-with-switch, cutover-without-window-parity-signoff]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 23, 27, 28, 33, 36, 38, 41, 45, 46, 47, 48, T-0029, T-0030, T-0031, T-0032, T-0033]
---
# ADR-0049: Niri on NixOS: safest staged installation order, per-stage choice, pass check and fallback
Status: proposed (an ordered path and a recommended choice per stage; nothing is installed, activated or removed until the owner approves the path and then each live stage) · Date: 2026-11-22 · Sources: ADR-0012/0013/0023/0028/0033/0036/0038/0041/0045/0046/0047/0048; T-0029, T-0032; `docs/plans/niri-migration.md` section 6; `docs/plans/niri-two-pc-pilot.md`; `nix/hosts/linux-desktop-pilot/system.nix`; `nix/tests/pilot-vm.nix`; `home/dot_config/niri/config.kdl`; the pinned nixpkgs `programs.niri` module.

## What this ADR is for

[ADR-0046](0046-niri-desktop-installation-decision-register.md) lists every component and gap. It does not say in which order to install them or which candidate to try first. This ADR does: it orders the work from the most vital to the least, names one safest choice per stage, and gives the expected behaviour, the check that lets the migration continue, and the fallback when the check fails.

It does not replace the owner ADRs. Where an owner ADR is `proposed` or `trial`, the choice below is the recommended first attempt for that stage, not a permanent selection. ADR-0046's `—` cells stay empty until a stage passes on real hardware and the owner ADR is amended.

Evidence labels: **VERIFIED** means read in this repo or in the pinned nixpkgs (rev `5d2b81a7`) on 2026-11-22. Everything about behaviour in a real session is **unverified** until its stage runs.

## Decision (proposed)

### Start from the plain `programs.niri` module, then only add

The baseline is niri exactly as the pinned nixpkgs module ships it, next to the working GNOME and GDM. The repo already declares this for PC 2, so no new design is needed. VERIFIED contents of `programs.niri.enable = true` in the pinned module:

| Function | What the module brings | Consequence for the path |
|---|---|---|
| Session | niri session entry for the display manager, `niri.service` user unit | GDM lists niri; the module's `mkDefault "niri"` default session is overridden to `gnome` in the pilot |
| Portals | `xdg-desktop-portal-gnome` and `-gtk`; `default = gnome, gtk`; Access and Notification to gtk; Secret to gnome-keyring | Screen sharing, file chooser and secrets work without any extra choice |
| File chooser | Nautilus D-Bus service (`useNautilus` defaults to true) | Keep the default; do not set `useNautilus = false` during the migration |
| Secrets | `services.gnome.gnome-keyring.enable` | GDM's PAM unlocks it at login; KeePassXC stays separate (ADR-0023) |
| Authentication | `security.polkit.enable`, and `security.pam.services.swaylock` | A polkit agent is still needed (Soteria in the pilot); swaylock can authenticate with no further PAM work |
| Session plumbing | dconf, `services.graphical-desktop`, XDG autostart for window-manager sessions | Existing user units that target `graphical-session.target` also start under niri |
| X11 apps | not enabled by the module | The pilot adds `xwayland-satellite`, which niri starts on demand |

The repo's `config.kdl` is niri's default config with a few edits (US and Russian layouts, Ghostty, Vicinae on Alt+Space, the swaylock bind commented out). It keeps `Mod+Shift+E` and `Ctrl+Alt+Delete` to quit and niri's own `Print` screenshot binds. VERIFIED by reading the file.

### Six rules that make the order safe

1. **Add, do not replace, until after cutover.** Every component that already works (GDM, the GNOME portal, gnome-keyring, Nautilus chooser, Vicinae, Flameshot) stays the owner of its function on both machines. An alternative may be compared on PC 2 before cutover, in isolation and without displacing the working owner (stage 15); it replaces nothing until after cutover.
2. **One stage, one atomic activation.** Each stage that changes a machine is a reviewed change that can be activated and rolled back on its own, so a failure has one cause and one rollback. It need not be exactly one commit or one generation, and a stage that only tests what is already installed needs no new generation. On PC 2 the first install already contains GNOME, niri, Soteria and xwayland-satellite, so stages 3 to 5 share it and differ only in what is tested.
3. **A stage passes only on recorded evidence.** Its checks ran in the real session on the target machine and are recorded under T-0032 (or T-0029 for system takeover). A VM pass or a paper comparison does not pass a hardware stage. A module that evaluates, or a system that builds, shows what is configured, not that it works: portals, secrets, login and lock count as working only after the live checks.
4. **A failed stage stops the path.** Take the stage's fallback, or go back to the last passing generation. Do not continue with later stages to "see what else works".
5. **Security functions stay outside the shell.** Lock and idle, polkit, the secret service and the portals are standalone, session-scoped services. A desktop shell may own the bar, taskbar, notifications, tray and on-screen displays only. A shell crash must not unlock the screen or lose the password prompt. Running the locker as a separate process does not make it safe by itself; stage 6's checks do. This is the default for the pilot, not a permanent ban: a shell's locker may take over once it passes the same checks and T-0032 gates G1 to G3.
6. **GNOME and GDM stay installed and default through every stage up to cutover.** The fallback for any desktop failure is always: log out, pick GNOME at the greeter.

PC 2 runs every stage before PC 1 does. A pass on PC 2 does not clear PC 1's GPU, outputs or `/etc/nixos` takeover (two-PC plan).

## Ordered path

Risk is the damage if the stage goes wrong. Difficulty is the work to do it properly. Stages 0 to 5 are vital: without them the machine can lose data or lock its owner out. Stages 6 to 10 make the session usable. Stages 11 to 14 move the daily machine. Stage 15 is optional.

### Vital: data, boot, login, recovery

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 0 | **Data backup and rollback target** (G13) | The backup gate in `docs/plans/niri-migration.md` section 6, items a to e, for PC 1. Kopia is the recorded tool (ADR-0033), though the gate prescribes none. For PC 2: its original disk disconnected or backed up | Critical if skipped / low | A copy of `$HOME` (projects, KeePassXC database, browser profiles) and `/etc/nixos` exists off the machine and can be read back | One sample directory and the KeePassXC database restored to a scratch location and opened; `EMPTY-DIFF` line for `/etc/nixos`; generation list recorded; evidence file written, no secrets in it | Nothing live starts. No fallback exists for this stage |
| 1 | **Build-only gates** (G14) | The checks that already exist | Low / low (mostly done) | The pilot system and the Home Manager profile build; the VM boots to GDM and starts niri | `nix flake check ./nix`; pilot toplevel build; `pilot-vm-test`; `bats tests/bash`; `bash ops/validate-config.sh`; `chezmoi diff` clean | Fix the build. Nothing has touched a machine yet |
| 2 | **PC 2 disk and install** (G01) | Simple pilot defaults, not a layout policy for other hosts: NixOS live installer, `nixos-generate-config`, then `nixos-install --flake`. ext4 root, own ESP, systemd-boot, LUKS2 with a passphrase, zram and no hibernate. Disks named by `/dev/disk/by-id` | High (wrong disk destroys data) / medium | PC 2 boots NixOS from the spare SSD; the original OS still boots from the firmware menu after its disk is reconnected | Original disk physically disconnected during the install; generated `hardware-configuration.nix` committed for the pilot and both placeholder `fileSystems` entries deleted in the same change; passphrase unlock works at a cold boot; both systems boot | Stop and reinstall on the spare SSD only. Never repartition a disk that holds data |
| 3 | **GNOME baseline on PC 2** | GDM and GNOME as declared, niri not yet used | Medium / low | GDM greeter appears; GNOME logs in. A fresh install has only generation 1, so there is no rollback target yet | GNOME login works; `nixos-version --configuration-revision` shows the commit; one rebuild with `nixos-rebuild boot` creates generation 2 while generation 1 is known good, then generation 1 is selected once in the boot menu and boots | Boot generation 1, or repair from the installer USB (stage 4); fix before niri is tried |
| 4 | **Recovery routes** (G17), proven before anything can lock the screen | Text console login, niri's quit bind, the boot menu, and SSH from PC 1 to PC 2 (needs key-only `services.openssh` in the pilot config, two-PC plan step 3) | High if missing / low | Each route gives a working shell without a reinstall. The boot menu alone is not enough: one more route must not depend on the installed system | `Ctrl+Alt+F3` text login works from the greeter and from inside a graphical session; `loginctl terminate-session` ends a session from the console; key-only SSH from PC 1 works; the known-good generation boots from the menu; the installer USB boots, unlocks the disk and reaches the system with `nixos-enter` | Do not add a locker or shell until every route works |
| 5 | **Bare niri session** (G02, G10) | The module defaults, Soteria, xwayland-satellite and the chezmoi KDL, with no bar, locker or shell | High on this hardware (niri refuses software rendering; hybrid AMD and NVIDIA on nouveau is untested) / low | Choosing niri at GDM gives an empty workspace; `Mod+T` opens Ghostty; `Mod+Shift+Slash` shows the hotkey overlay; `Mod+Shift+E` quits back to GDM | `niri msg outputs` lists every real monitor with the right mode and scale; unplug and replug an external monitor; both keyboard layouts switch with Super+Space; an X11 app opens; `pkexec true` raises exactly one Soteria prompt; every command the KDL binds call resolves on the session `PATH`; `systemctl --user --failed` is empty; GNOME is still the default at the next login | Stay on GNOME. If the GPU or outputs fail, the niri trial ends here (T-0032 exit path); do not try Hyprland or KDE as a quick substitute |

### Usable session: one owner per function

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 6 | **Lock, idle and suspend** (G03, G21) | swaylock and swayidle as one standalone pair for the pilot, started by a user unit bound to `niri.service`: `swayidle -w` with a `before-sleep` hook that runs `swaylock -f`. The `Super+Alt+L` bind is enabled in the KDL with `allow-when-locked=true`, so a new locker can be started when the first one has died | High (a broken locker either exposes the desktop or locks the owner out) / medium | The screen locks on the bind, on idle and before suspend; resume shows the locker, never the desktop. If the locker dies, niri keeps the session locked and shows its own locked background: the desktop stays protected, but nothing accepts a password until a locker runs again | Wrong password refused, right one accepted; suspend from the menu and by `systemctl suspend`, and resume with an external monitor unplugged meanwhile, never shows the desktop; with the locker killed from the console the session stays locked, and both the bind and a locker started from the console restore the password prompt; neither process runs in the GNOME session; exactly one idle daemon | Remove the pair and lock by logging out until fixed. Do not use a shell's locker as the substitute |
| 7 | **Portals and secrets as shipped** (G11, G18) | Keep the module's routing: GNOME portal for ScreenCast, Nautilus chooser, gnome-keyring unlocked by GDM | High for daily use / low (nothing to install) | To be shown, not assumed: the module configures the routing, and only the checks prove that screen sharing, file dialogs and stored credentials work on this machine | Brave and Vesktop share a monitor and a single window, and again after cancel, hotplug and resume; open and save dialogs in Brave, VS Code and Telegram; `busctl --user status org.freedesktop.secrets` shows one owner; a credential saved under GNOME is readable under niri; KeePassXC unlocks and its browser integration fills | Stay on GNOME for calls and sharing. Do not swap a portal or keyring to fix it; record the failure in T-0032 |
| 8 | **Sound, network, removable media** (G24) | The existing PipeWire, NetworkManager, BlueZ and udisks2 services; no new control applications | Medium / low | Volume and microphone keys, Wi-Fi and USB storage behave as under GNOME | `wpctl status` shows the expected sink and source; a call in Vesktop has working microphone; a USB stick mounts and ejects from Nautilus; the existing volume and brightness binds work while locked | Add one missing control tool (for example `pavucontrol`) only for the named gap |
| 9 | **Launcher and clipboard** (G06, G23) | Keep Vicinae with its existing user unit and the Alt+Space bind; no second launcher | Medium / low | Alt+Space toggles Vicinae; clipboard history and recent VS Code projects open | Toggle works after cold login and under both layouts; a recent folder and a `.code-workspace` open the right target; with two Code windows open, picking a project focuses that project's window or reports that it cannot tell, never an unrelated window; exactly one clipboard-history provider runs | Fuzzel as a rescue launcher for applications. It cannot run the recent-projects picker today, which calls `vicinae dmenu` directly; that needs a launcher-neutral menu adapter first (T-0031) |
| 10 | **Shell: bar, taskbar, notifications, tray** (G03, G04) | The approved trial order: Dux first, then Noctalia (ADR-0013). The shell's launcher, clipboard history, locker, idle and polkit agent are switched off; its unit target is set to the niri session, not the default `graphical-session.target` | Medium (young software with open upstream issues; a crash costs the bar, not the session, because of rule 5) / high | Before activation, the user units and XDG autostart entries that niri's session starts are listed and each is marked GNOME-only, niri-only or both. Then: a bar with running windows, a tray and notifications; the session keeps working when the shell is killed | T-0032 gates G4, G5, G7, G9, G10 and G11; `busctl --user status org.freedesktop.Notifications` shows one owner; Telegram and Vesktop notifications and tray icons appear; the shell does not start under GNOME; killing the shell leaves windows, the locker and Soteria working | The next shell in the order, then Waybar with SwayNC (ADR-0013 fallback). A session with no bar remains usable meanwhile |

Window actions (G05, T-0031) and screenshots (G11, G26) run beside stages 9 and 10 and gate cutover, not the stages after them:

- **Window actions:** niri's native binds plus a niri backend for launch-or-focus by most recent use. Hide, show and restore are requirements in ADR-0045, and niri has no native minimise, so this path does not settle them by silence: before cutover the owner signs off G05 with an explicit choice between a parking-workspace workaround that passed its tests, working without hide and show, or holding the cutover.
- **Screenshots:** niri's built-in `Print` actions for the pilot (two-PC plan). Flameshot is tested separately; on the pinned niri 26.04 its portal path is expected to fail on two monitors (T-0032, HIGH). If it does, Satty for annotation is the fallback, added only then.

### Moving the daily machine

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 11 | **PC 1 system takeover, GNOME only** (T-0029, G25) | Stage 0 repeated on the day; `nix-gc.timer` stopped and `nix.gc.automatic = false`; `nixos-rebuild build` and the closure diff, which touch nothing live. Then `test` from a text console: it activates the new system at once and can restart services, so it is a live change that needs its own approval, stage 0 done and the stage 4 routes proven on PC 1. Then `boot` and reboot. Never `switch` first. PC 1's boot loader and disk layout are not changed | Critical (the only daily machine; generation 17 is the single rollback target) / high | PC 1 runs the repo's `linux-desktop` system with GNOME, as before but on GNOME 51 | GDM starts and GNOME logs in; generation 17 is still in the boot menu and boots once, and its system closure is pinned against garbage collection until stage 14 has passed; the installer USB reaches PC 1's system; `nixos-version --configuration-revision` shows the commit; `systemctl --failed` is empty | Boot generation 17. Restore `/etc/nixos` by the plan's replace-directory sequence. Niri waits |
| 12 | **Niri as a second session on PC 1** (T-0032) | The same module set that passed on PC 2, in one separate change; GNOME stays the GDM default | High on PC 1's hybrid GPU and DP-3 output / medium | As stages 5 to 10, on PC 1's hardware | Stages 5 to 10 re-run on PC 1 and recorded; T-0032's acceptance list | Stay on GNOME on PC 1; PC 2 keeps the trial |
| 13 | **Daily trial** | Two to four weeks of real work in niri, GNOME still default | Low / time only | No P0 failure in T-0032's list | The trial checklist: restart, logout, multi-monitor, screen sharing, file dialogs, clipboard, sleep and resume | Stay on GNOME; fix and restart the clock |
| 14 | **Cutover** | Only `services.displayManager.defaultSession = "niri"`. GDM, GNOME, the portals and the keyring all stay installed | Medium / low | GDM preselects niri; GNOME remains one click away | Separate owner approval; window-action parity (G05) and the shell's taskbar requirements (G04, ADR-0045 P0) signed off, including the hide and show choice above; cold boot lands in niri; GNOME still logs in | Set the default back to `gnome`: one line, one generation |

### Optional replacements, one at a time

Stage 15 holds every replacement of a working component. Each is its own change with its own approval and its own rollback, and none blocks anything above.

- **Comparison on PC 2 may start before cutover**, once PC 2 has passed stages 0 to 10. The alternative runs beside the working owner or in a disposable user, the working owner's routing is restored afterwards, and PC 1 is not touched. Items 4 and 5 change PAM, so on PC 2 they also need the stage 4 routes re-proven first.
- **Replacement on either machine waits until after cutover.**

The order is from the least to the most dangerous to get wrong:

1. Launcher: Vicinae against Walker with Elephant (ADR-0048).
2. File chooser and file manager: GTK chooser, Dolphin, Dux Files (ADR-0028).
3. ScreenCast backend: `xdg-desktop-portal-generic` against the GNOME portal (ADR-0047).
4. Secret service: oo7 against gnome-keyring, with a disposable user and fake secrets (ADR-0023).
5. Greeter: greetd with tuigreet (ADR-0041), only after GNOME lock under greetd is proven or the GNOME fallback is retired.
6. GNOME session removal (ADR-0047 retirement gates).

Items 4 and 5 are never done in the same change: both touch PAM, and a failure in either can block login.

## Rejected or deferred for this path

| Option | Verdict | Reason |
|---|---|---|
| niri-screenshare | Deferred, packaging-dependent | No verdict on its function. VERIFIED absent from the pinned nixpkgs, so it needs a reproducible package first; its start-up writes portal preferences that Nix and chezmoi own (ADR-0047), which needs an approved declarative owner. Eligible for stage 15 once both are solved |
| iNiR shell | Deferred, packaging-dependent | No verdict on its function. VERIFIED absent from the pinned nixpkgs; its NixOS guidance is experimental and its module adds groups and can seed the niri config (ADR-0045). It stays the proposed extra trial in ADR-0045 and joins stage 10 only with a reproducible package, a reviewed module and an owner decision amending ADR-0013 |
| `xdg-desktop-portal-generic` | Deferred to stage 15 | In the pinned nixpkgs (1.2.0), but niri's Dynamic Cast Target support is unproven, and the GNOME portal already works |
| oo7 daemon and portal | Deferred to stage 15 | In the pinned nixpkgs (0.7.1, with a NixOS module), but it changes PAM unlock and may migrate the real keyring on first start |
| greetd with tuigreet, ReGreet or gtkgreet | Deferred to stage 15 | GDM is the working login and keeps the GNOME fallback lockable. All three are in the pinned nixpkgs, so the delay costs nothing |
| `programs.niri.useNautilus = false` | Deferred to stage 15 | It reroutes the file chooser; without Nautilus the GNOME portal's chooser fails silently (T-0032) |
| Walker with Elephant | Deferred to stage 15 | Two more services and a second clipboard owner while Vicinae works |
| A shell's own locker, idle daemon or polkit agent | Not the first owner; allowed as an explicit swap | Open upstream issues on lock with monitor hotplug and resume (T-0032 G1 to G3). It may replace the standalone pair after passing stage 6's checks and G1 to G3; rule 5 |
| Hide and minimise emulation | Not built first; decided before cutover | Niri has no native minimise; parking workspaces are shell-specific workarounds (ADR-0045). Tested with the shell in stage 10; the owner's G05 sign-off at stage 14 settles it |
| Btrfs or ZFS, TPM2 or FIDO2 unlock, Lanzaboote, hibernate | Not used for the pilot install | Each adds its own recovery procedure and none helps judge niri. Decide them for PC 1 separately (ADR-0038); PC 1's existing layout is not changed by this path |
| nixos-anywhere for the first install | Not used for the pilot | A remote wipe needs a proven target identity; a local install with the other disk unplugged cannot hit the wrong disk |
| disko for the first install | Optional, not required | Acceptable only after its VM test (ADR-0038). For one machine the generated hardware file is simpler and equally safe with the other disk unplugged |
| niri-flake, UWSM | **Rejected** | The nixpkgs module and `niri-session` already cover both (ADR-0012, ADR-0047) |
| `spawn-at-startup` for services | **Rejected** | Duplicates session-scoped systemd units and escapes their stop-at-logout scope (T-0032) |
| Setting `GDK_BACKEND` or spoofing `XDG_CURRENT_DESKTOP` | **Rejected** | Upstream warns it can break ScreenCast (ADR-0047 gate 4) |
| Removing GNOME, GDM, the GNOME portal or gnome-keyring before cutover | **Rejected** | It removes the fallback that every stage above relies on |
| Installing a full shell first and trimming it afterwards | **Rejected** | It starts with several owners per function and an unknown failure source; rule 2 |

## Owner decisions this ADR needs

- [ ] Approve the path and its six rules. This changes nothing live; it only fixes the order.
- [ ] Rule 5 and stage 6: swaylock and swayidle own lock and idle through the shell trial. This narrows ADR-0013, which compares shell lockers with the standalone pair without preferring either. It is the first owner for the pilot, not a permanent rule. If approved, amend ADR-0013 and T-0032 gate G11 in the same change.
- [ ] Stage 2: LUKS2 with a passphrase on PC 2. Choose no encryption only if PC 2 will never hold a real credential; T-0032 tests KeePassXC and browsers there, so encryption is recommended. Adding it later means an in-place re-encryption, which is possible but risky, or a reinstall.
- [ ] Stage 2: generated hardware file or disko for the first install (ADR-0038 stays `proposed` either way).
- [ ] Each live stage (2, 3, 5 onwards) still needs its own approval when it is reached. Approving the order does not approve any activation.

## Gaps in the committed configuration that the stages will hit

Found by reading the repo on 2026-11-22 (VERIFIED). None is fixed here; each belongs to the ticket named.

| Gap | Evidence | Stage it blocks | Owner |
|---|---|---|---|
| `brightnessctl` and `playerctl` are bound in the KDL but declared nowhere under `nix/` | `home/dot_config/niri/config.kdl` media and brightness binds | 5 (commands on `PATH`) | T-0032 |
| The recent-projects picker is tied to Vicinae | `nix/modules/home/scripts/vscode-recent-projects.sh` pipes into `vicinae dmenu` | 9 (rescue launcher) | T-0031 |
| Project focus can pick the wrong window | The same script matches the folder basename inside window titles, then falls back to a focused or the first Code window | 9 (project focus) | T-0031 |
| Session units are not scoped per desktop | The Flameshot unit is wanted by `graphical-session.target`, which niri's session also starts, together with XDG autostart | 10 (unit audit) | T-0032 |
| The launcher shortcut is recorded two ways | The KDL binds Alt+Space; T-0032's acceptance list tests Ctrl+Space | 9 (one shortcut contract, both layouts) | T-0032 |

## Review amendments (2026-11-22)

A research review of the first version kept the staged order and asked for targeted corrections; all are applied above. Rule 2 now asks for atomic activations, not exactly one generation. `nixos-rebuild test` is treated as a live change. Stage 3 creates the rollback generation that a fresh install lacks, and stage 4 adds the installer USB as a route that does not depend on the installed system. Stage 6 names the suspend ordering and the dead-locker recovery. Alternatives may be compared on PC 2 before cutover. niri-screenshare and iNiR are deferred for packaging, not rejected on function. Cutover needs the window-management sign-off from ADR-0045. The upstream statements behind stage 6 (niri keeps the session locked when the locker dies; `swayidle -w` with `swaylock -f`) come from that review's citations and were not re-fetched here; the stage's checks test them directly.

## Consequences

- ADR-0046 stays the component register and keeps its `—` cells. When a stage passes, amend the owner ADR first, then the register, then tick the stage's evidence in T-0032 or T-0029.
- The trial order Dux then Noctalia (ADR-0013), GDM during the trial (ADR-0041), Vicinae during the trial (ADR-0048) and the GNOME-minimal target (ADR-0047) are unchanged. This ADR only places them in one sequence and moves every replacement behind cutover, while allowing isolated comparison on PC 2 before it.
- The shell is no longer on the critical path. Stages 0 to 9 give a lockable, recoverable niri session with screen sharing, secrets and a launcher before any shell is installed, so a shell that fails its gates delays the taskbar and with it the cutover sign-off, but not the pilot or the PC 1 takeover.
- Not checked here: any runtime behaviour. The versions and module contents above were evaluated from the pinned nixpkgs; no package was installed, no service started and no host changed.
