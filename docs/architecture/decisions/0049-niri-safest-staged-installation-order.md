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

Every rebuild command below names its flake and host. The form is `git+file://<checkout>?dir=nix#<host>`: VERIFIED to evaluate, whereas `git+file://<checkout>/nix#<host>` fails ("Failed to fetch git repository"), and a plain path reference records no commit. `<host>` is `linux-desktop-pilot` on PC 2 and `linux-desktop` on PC 1.

## Decision (proposed)

### Start from the plain `programs.niri` module, then only add

The baseline is niri exactly as the pinned nixpkgs module ships it, next to the working GNOME and GDM. The repo already declares this for PC 2, so no new design is needed. VERIFIED contents of `programs.niri.enable = true` in the pinned module (what is configured; stage 7 proves what works):

| Function | What the module brings | Consequence for the path |
|---|---|---|
| Session | niri session entry for the display manager, `niri.service` user unit | GDM lists niri; the module's `mkDefault "niri"` default session is overridden to `gnome` in the pilot |
| Portals | `xdg-desktop-portal-gnome` and `-gtk`; `default = gnome, gtk`; Access and Notification to gtk; Secret to gnome-keyring | Screen sharing, file chooser and secrets are configured with no extra choice |
| File chooser | Nautilus D-Bus service (`useNautilus` defaults to true) | Keep the default; do not set `useNautilus = false` during the migration |
| Secrets | `services.gnome.gnome-keyring.enable` | GDM's PAM unlocks it at login; KeePassXC stays separate (ADR-0023) |
| Authentication | `security.polkit.enable`, and `security.pam.services.swaylock` | A polkit agent is still needed (Soteria in the pilot); swaylock can authenticate with no further PAM work |
| Session plumbing | dconf and `services.graphical-desktop`; niri's own `niri.service` pulls in `graphical-session.target` and XDG autostart | Existing user units that target `graphical-session.target` also start under niri |
| X11 apps | not enabled by the module | The pilot adds `xwayland-satellite`, which niri starts on demand |

The repo's `config.kdl` is niri's default config with a few edits (US and Russian layouts, Ghostty, Vicinae on Alt+Space, the swaylock bind commented out). It keeps `Mod+Shift+E` and `Ctrl+Alt+Delete` to quit and niri's own `Print` screenshot binds. VERIFIED by reading the file.

### Six rules that make the order safe

1. **Add, do not replace, until after cutover.** Every component that already works (GDM, the GNOME portal, gnome-keyring, Nautilus chooser, Vicinae, Flameshot) stays the owner of its function on both machines. An alternative may be compared on PC 2 before cutover without displacing the working owner on PC 1 (stage 15); it replaces nothing until after cutover.
2. **One stage, one atomic activation, in a known layer.** Each stage that changes a machine is a reviewed change that can be activated and rolled back on its own, so a failure has one cause and one rollback. It need not be exactly one commit or one generation, and a stage that only tests what is already installed needs no new generation. On PC 2 the first install already contains GNOME, niri, Soteria and xwayland-satellite; stage 3 adds generation 2, and stages 3b to 5 share it and differ only in what is tested. The layer decides which machine a change reaches: the pilot's NixOS files reach PC 2 only, but Home Manager and chezmoi are one shared `linux-desktop` profile, so a change there also reaches PC 1 at its next `sys-update`. Such a change must be inert on a machine without niri (a unit bound to `niri.service`, or a file only niri reads).
3. **A stage passes only on recorded evidence of the right kind.** A build stage (stage 1) passes on build and test output. Every later stage passes only when its checks ran on the target machine, in the real session where the stage has one, and are recorded under T-0032 (or T-0029 for system takeover). A VM pass or a paper comparison does not pass a hardware stage. A module that evaluates, or a system that builds, shows what is configured, not that it works: portals, secrets, login and lock count as working only after the live checks.
4. **A failed stage stops every stage that depends on it** (see "Stage dependencies"). Take the stage's fallback, or go back to the last passing generation. Do not continue with dependent stages to "see what else works".
5. **Security functions stay outside the shell.** Lock and idle, polkit, the secret service and the portals are standalone, session-scoped services. A desktop shell may own the bar, taskbar, notifications, tray and on-screen displays only. A shell crash must not unlock the screen or lose the password prompt. Running the locker as a separate process does not make it safe by itself; stage 6's checks do. This is the default for the pilot, not a permanent ban: a shell's locker may take over once it passes stage 6's checks.
6. **GNOME and GDM stay installed and default through every stage up to cutover.** The fallback for any desktop failure is always: log out, pick GNOME at the greeter.

PC 2 runs every niri stage before PC 1 does. A pass on PC 2 does not clear PC 1's GPU, outputs or `/etc/nixos` takeover (two-PC plan).

## Ordered path

Risk is the damage if the stage goes wrong. Difficulty is the work to do it properly. Stages 0 to 5, with 3b, are vital: without them the machine can lose data or lock its owner out. Stages 6 to 10 make the session usable. Stages 11 to 14 move the daily machine. Stage 15 is optional.

### Vital: data, boot, login, recovery

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 0 | **Data backup and rollback target** (G13) | The backup gate in `docs/plans/niri-migration.md` section 6, items a to e, for PC 1. Kopia is the recorded tool (ADR-0033), though the gate prescribes none. For PC 2: its original disk disconnected | Critical if skipped / low | A copy of `$HOME` (projects, KeePassXC database, browser profiles) and `/etc/nixos` exists off the machine and can be read back | One sample directory and the KeePassXC database restored to a scratch location and opened; `EMPTY-DIFF` line for the local `/etc/nixos` copy, and that copy also placed off the machine and diffed there; generation list recorded; evidence file written, no secrets in it | Nothing live starts. No fallback exists for this stage |
| 1 | **Build-only gates** (G14) | The checks that already exist | Low / low (mostly done) | The pilot system and the Home Manager profile build; the VM boots to GDM and starts niri | `nix flake check ./nix`; pilot toplevel build; `pilot-vm-test`, run by hand (it needs KVM and is not part of `nix flake check`); `bats tests/bash`; `bash ops/validate-config.sh`; `chezmoi diff` clean | Fix the build. Nothing has touched a machine yet |
| 2 | **PC 2 disk and install** (G01) | Simple pilot defaults, not a layout policy for other hosts: NixOS live installer, `nixos-generate-config`, then `nixos-install`. ext4 root, own ESP, systemd-boot, LUKS2 with a passphrase, no disk swap and no hibernate (zram is an opt-in in `desktop-stability.nix` that the shared module does not import; declare it explicitly if wanted) | High (wrong disk destroys data) / medium | PC 2 boots NixOS from the spare SSD and the user can log in; the original OS still boots from the firmware menu after its disk is reconnected | Original disk physically disconnected during the install. Partitioning and `cryptsetup` commands name the disk by `/dev/disk/by-id`; the by-uuid paths that `nixos-generate-config` writes are accepted. The repo is cloned onto the new disk under `/mnt/home/<user>/`, not left in the installer's memory. The generated `hardware-configuration.nix` is a separate module listed beside `system.nix` for the pilot host in `nix/flake.nix`, not imported by `system.nix` (the VM test imports that file and must keep booting); the placeholder `fileSystems` entries are deleted; both are committed as one reviewed change, so the installed system reports a clean commit and later rebuilds cannot bring the placeholders back. The generated file names the LUKS device, root and ESP just created. `pilot-vm-test` and `tests/bash/nixos-pilot.bats` pass with that change (the placeholder test changes with it). The pilot's toplevel builds, then `nixos-install --flake "git+file://<checkout>?dir=nix#linux-desktop-pilot"`. The user's password is set with `nixos-enter --root /mnt -c 'passwd <user>'` before the first reboot (the repo holds none). Passphrase unlock works at a cold boot; both systems boot; the commit reaches the repo PC 1 builds from | Stop and reinstall on the spare SSD only. Never repartition a disk that holds data |
| 3 | **GNOME baseline and a rollback generation on PC 2** | GDM and GNOME as declared, niri not yet used. Generation 2 comes from a real reviewed change, which stage 4 needs anyway: `services.openssh` with PC 1's public key in the user's `openssh.authorizedKeys.keys`, password and keyboard-interactive logins off, root login off. Rebuilt on PC 2 from its own clone: `sudo nixos-rebuild boot --flake "git+file://$PWD?dir=nix#linux-desktop-pilot"` | Medium / low | GDM greeter appears; GNOME logs in. A fresh install has only generation 1, and rebuilding an unchanged configuration creates no new one, so a rollback target has to be made on purpose | Text-console and GNOME login work with the password from stage 2; `nixos-version --configuration-revision` shows a clean commit; `nixos-rebuild list-generations` shows two entries and the boot menu shows both; generation 1 is booted once, then generation 2 again, and generation 2 is left as the default; in the GNOME session `pkexec true` raises exactly one prompt (see the Soteria gap below) | Boot generation 1, or repair from the installer USB (stage 4); fix before niri is tried |
| 3b | **User environment on PC 2** | `bash ops/install.sh --profile work` after the first GNOME login: standalone Home Manager and chezmoi. The work profile leaves out what is bound to personal accounts (see "User services on PC 2"). Never `ops/system-setup.sh` or `ops/tailscale-setup.sh` here, although the installer ends by suggesting the first: both rewrite `/etc/nixos` (T-0029) | Medium (without it niri starts with no terminal, launcher or config; with the personal profile it starts sync and bot services on a test machine) / low | The `linux-desktop` Home Manager output is active with the work profile and chezmoi has deployed the niri config | In a GNOME terminal: `command -v ghostty vicinae niri` all resolve; `~/.config/niri/config.kdl` exists and `niri validate` passes; `chezmoi --source=<checkout> verify` passes (a plain `chezmoi verify` fails on a host whose source directory is not configured); the Vicinae user unit is active; `syncthing.service` and `openclaw-gateway.service` do not exist. The installer's "system layer" warning (login shell, GC timer, time zone) is expected here and is not acted on. A successful build of the activation package does not count: the profile must be activated on PC 2 | Stay on GNOME and fix the install. Undo with Home Manager's own generations (`home-manager generations`, then the previous one's `activate`); a NixOS rollback does not undo it |
| 4 | **Recovery routes** (G17), proven before anything can lock the screen | Text console login, the boot menu, key-only SSH from PC 1 into PC 2 (declared in stage 3), and the installer USB | High if missing / medium | Each route gives a working shell without a reinstall. The boot menu alone is not enough: one more route must not depend on the installed system | `Ctrl+Alt+F3` text login works from the greeter and from inside a graphical session; `loginctl terminate-session` ends a session from the console; SSH from PC 1 works with the key, and a password login and a root login are both refused; the known-good generation boots from the menu. Installer USB, written down and run once in full: `cryptsetup open` the LUKS partition, mount the root at `/mnt` and the ESP at `/mnt/boot`, then `nixos-enter --root /mnt -c 'nix-env -p /nix/var/nix/profiles/system --switch-generation <N> && /nix/var/nix/profiles/system/bin/switch-to-configuration boot'`, reboot, and confirm generation `<N>` is the default. The rehearsal confirms or corrects that command | Do not add a locker or shell until every route works |
| 5 | **Bare niri session** (G02, G10) | The module defaults, Soteria, xwayland-satellite and the chezmoi KDL, with no bar, locker or shell | High (niri refuses software rendering, and PC 2's GPU is unverified) / low | Choosing niri at GDM gives an empty workspace; `Mod+T` opens Ghostty; `Mod+Shift+Slash` shows the hotkey overlay; `Mod+Shift+E` quits back to GDM | `niri msg outputs` lists every real monitor with the right mode and scale; unplug and replug an external monitor; both keyboard layouts switch with Super+Space; an X11 app opens; `pkexec true` raises exactly one Soteria prompt; every command the KDL binds call resolves on the session `PATH`; both quit binds end at the GDM greeter, never at a logged-in console; `systemctl --user --failed` is empty; GNOME is still the default at the next login | Stay on GNOME. A GPU or output failure ends the trial on PC 2; PC 1's own hardware is judged in stage 12. Do not try Hyprland or KDE as a quick substitute |

### Usable session: one owner per function

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 6 | **Lock, idle and suspend** (G03, G21) | swaylock and swayidle as one standalone pair for the pilot, started by a Home Manager user unit bound to `niri.service` (inert on a machine without niri): `swayidle -w` with a `timeout` that locks, a `lock` hook for logind, and a `before-sleep` hook, each running `swaylock -f`. The `Super+Alt+L` bind is enabled in the KDL with `allow-when-locked=true`, so a new locker can be started when the first one has died | High (a broken locker either exposes the desktop or locks the owner out) / medium | The screen locks on the bind, on idle, on a logind lock request and before suspend; resume shows the locker, never the desktop. If the locker dies, niri keeps the session locked and shows its own locked background: the desktop stays protected, but nothing accepts a password until a locker runs again | Wrong password refused, right one accepted. Each trigger locks: the bind, the idle timeout (shortened for the test), `loginctl lock-session`, `systemctl suspend`, the menu's suspend, and closing the lid on a laptop. Resume with an external monitor unplugged meanwhile never shows the desktop. With the locker killed from the console the session stays locked, and both the bind and a locker started from the console restore the password prompt. Quitting niri while locked ends at the greeter, not at a logged-in console. Neither process runs in the GNOME session. Exactly one idle controller and one locker run (swayidle and swaylock together are that one pair) | Remove the pair and lock by logging out until fixed. Do not use a shell's locker as the substitute |
| 7 | **Portals and secrets as shipped** (G11, G18) | Keep the module's routing: GNOME portal for ScreenCast, Nautilus chooser, gnome-keyring unlocked by GDM | High for daily use / low (nothing to install) | To be shown, not assumed: the module configures the routing, and only the checks prove that screen sharing, file dialogs and stored credentials work on this machine | Brave and Vesktop share a monitor and a single window, and again after cancel, hotplug and resume (Vesktop needs the personal profile, see stage 3b); open and save dialogs in Brave and VS Code; `busctl --user status org.freedesktop.secrets` shows one owner; a credential saved under GNOME is readable under niri; KeePassXC unlocks and its browser integration fills | Stay on GNOME for calls and sharing. Do not swap a portal or keyring to fix it; record the failure in T-0032 |
| 8 | **Sound, network, removable media** (G24) | The existing PipeWire, NetworkManager, BlueZ and udisks2 services; no new control applications | Medium / low | Volume and microphone keys, Wi-Fi and USB storage behave as under GNOME | `wpctl status` shows the expected sink and source; a call has a working microphone; a USB stick mounts and ejects from Nautilus; the existing volume and brightness binds work while locked | Use the mixer that is already installed (`pavucontrol`); add a tool only for a gap that is named |
| 9 | **Launcher and clipboard** (G06, G23) | Keep Vicinae with its existing user unit and the Alt+Space bind; no second launcher. Add niri binds for clipboard history and the recent-projects picker, which today exist only under GNOME | Medium / low | Alt+Space toggles Vicinae; clipboard history and recent VS Code projects open from their own keys | Each bind works after cold login and under both layouts; a recent folder and a `.code-workspace` open the right target; with two Code windows open, picking a project focuses that project's window. As an interim pass for the pilot it may instead report that it cannot tell, but it never focuses an unrelated window (exact focus stays the P0 target in ADR-0048, built in T-0031). Exactly one clipboard-history provider runs | Fuzzel as a rescue launcher for applications. It cannot run the recent-projects picker today, which calls `vicinae dmenu` directly; that needs a launcher-neutral menu adapter first (T-0031) |
| 10 | **Shell: bar, taskbar, notifications, tray** (G03, G04) | The approved trial order: Dux first, then Noctalia (ADR-0013). The shell's launcher, clipboard history, locker, idle and polkit agent are switched off; its unit target is set to the niri session, not the default `graphical-session.target`. Module extras are reviewed first: the pinned Dux module turns on i2c and accounts-daemon by default, and the pinned Noctalia installs plugins by cloning repositories at run time | Medium (young software with open upstream issues; a crash costs the bar, not the session, because of rule 5) / high | Before activation, the user units and XDG autostart entries that niri's session starts are listed and each is marked GNOME-only, niri-only or both. Then: a bar with running windows, a tray and notifications; the session keeps working when the shell is killed | T-0032's shell trial gates G1 to G11, all of them (G8 only with a security key, G6 with the screenshot track below; G1 to G3 exercise the shell process while the standalone pair holds the lock); `busctl --user status org.freedesktop.Notifications` shows one owner; notifications and tray icons from the chat apps appear; the shell does not start under GNOME; killing the shell leaves windows, the locker and Soteria working | The next shell in the order, then Waybar with SwayNC (ADR-0013 fallback). A session with no bar remains usable meanwhile |

Window actions (G05, T-0031) and screenshots (G11, G26) run beside stages 9 and 10 and gate cutover, not the stages after them:

- **Window actions:** niri's native binds plus a niri backend for launch-or-focus by most recent use; the helper supports only the GNOME backend today. Hide, show and restore are requirements in ADR-0045, and niri has no native minimise, so this path does not settle them by silence: before cutover the owner signs off G05 with an explicit choice between a parking-workspace workaround that passed its tests, working without hide and show, or holding the cutover.
- **Screenshots:** judged by capability (area, last region, pin, clipboard, annotation), not by tool (ADR-0036). niri's built-in `Print` actions are already bound and cover area, screen and window. Flameshot's hotkeys exist only under GNOME, and on the pinned niri 26.04 its portal path is expected to fail on two monitors (T-0032, HIGH). Satty would cover annotation only; pin and last region would then need their own answer before Flameshot is dropped.

### User services on PC 2

The Home Manager output for `linux-desktop` hard-codes the personal profile, which would start account-bound services on the test machine. The install selection can force the work profile (`--profile work` sets `myConfig.profile` with `mkForce`), and both account-bound services are gated on the personal profile. VERIFIED by reading `nix/modules/home/profile.nix`, `gui.nix` and `openclaw.nix`; unverified on PC 2.

| User unit | With `--profile work` | On PC 2 |
|---|---|---|
| Vicinae, Flameshot | present | Wanted |
| `vicinae-focus-tracker` | present, runs only when `XDG_CURRENT_DESKTOP=GNOME` | Wanted under GNOME; inert under niri |
| `syncthing` | absent (personal only) | Off until the owner pairs PC 2 on purpose |
| `openclaw-gateway` | absent (personal only) | Off: a second gateway on the same account is not a test |
| Telegram, Vesktop (apps) | absent (personal only) | Added later with `--profile personal`, as its own approved step, when T-0032's chat and call checks are due |
| `codebase-memory-mcp-*`, `repo-audit` timer, AI CLI update timers | present | Local only; allowed |

### Moving the daily machine

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 11 | **PC 1 system takeover, GNOME only** (T-0029, G25) | Needs `nixosConfigurations.linux-desktop`, which does not exist yet (T-0029). Stage 0 repeated on the day; `nix-gc.timer` stopped and `nix.gc.automatic = false`. `sudo nixos-rebuild build --flake "git+file://$PWD?dir=nix#linux-desktop"` and the closure diff touch nothing live. Then the same target with `test`, from a text console, followed by `systemctl restart display-manager`: `test` activates the new system at once but does not restart GDM, so without the restart it proves nothing about GNOME 51. It is a live change that needs its own approval, stage 0 done, and PC 1's own routes proven: text console, boot menu and installer USB (PC 1 gets no SSH listener). Then the same target with `boot`, and a reboot. Never `switch` first. PC 1's boot loader and disk layout are not changed | Critical (the only daily machine; generation 17 is the single rollback target) / high | PC 1 runs the repo's `linux-desktop` system with GNOME, as before but on GNOME 51 | GDM starts and GNOME logs in; generation 17 is still in the boot menu and boots once, and garbage collection stays off, with generation 17's closure kept, until stage 14 has passed and the rollback is accepted; the installer USB reaches PC 1's system; `nixos-version --configuration-revision` shows the commit; `systemctl --failed` is empty | Boot generation 17. Restore `/etc/nixos` by the plan's replace-directory sequence. Niri waits |
| 12 | **Niri as a second session on PC 1** (T-0032) | The same module set that passed on PC 2, in one separate change; GNOME stays the GDM default. The Home Manager and chezmoi parts of stages 6 to 10 will already be on PC 1 through `sys-update`, inert until niri exists (rule 2) | High on PC 1's hybrid GPU (AMD with NVIDIA on nouveau) and DP-3 output / medium | As stages 5 to 10, on PC 1's hardware | Stages 5 to 10 re-run on PC 1 and recorded; T-0032's acceptance list | Stay on GNOME on PC 1; PC 2 keeps the trial |
| 13 | **Daily trial** | Two to four weeks of real work in niri, GNOME still default | Low / time only | No P0 failure in T-0032's list | The trial checklist: restart, logout, multi-monitor, screen sharing, file dialogs, clipboard, sleep and resume | Stay on GNOME; fix and restart the clock |
| 14 | **Cutover** | Only `services.displayManager.defaultSession = "niri"`. GDM, GNOME, the portals and the keyring all stay installed | Medium / low | GDM preselects niri; GNOME remains one click away | Separate owner approval; window-action parity (G05) and the shell's taskbar requirements (G04, ADR-0045 P0) signed off, including the hide and show choice above; cold boot lands in niri; GNOME still logs in | Set the default back to `gnome`: one line, one generation |

### Stage dependencies

- **Stages 0 to 10 run in order on PC 2.** A failure stops the later ones there.
- **Stage 11 does not wait for niri.** It depends on stage 0 for PC 1, stage 1, the `linux-desktop` host existing, and stages 2 to 4 having been rehearsed on PC 2 (install, rollback generation, rescue). It does not depend on stages 5 to 10: the takeover is GNOME only. ADR-0046's gate order still lists the shell decision before the PC 1 takeover, so this is an owner decision below; until it is taken, ADR-0046's order stands.
- **Stage 12 depends on stage 11 and on stages 5 to 10 having passed on PC 2.**
- **Stage 14 depends on stage 13 and on the sign-offs in its row.** A shell that fails its gates therefore blocks the cutover, not the PC 2 pilot or the GNOME-only takeover.

### Optional replacements, one at a time

Stage 15 holds every replacement of a working component. Each is its own change with its own approval and its own rollback, and none blocks anything above.

- **Comparison on PC 2 may start before cutover**, once PC 2 has passed stages 0 to 10. Where it can, the alternative runs beside the working owner and the owner's routing is restored afterwards. Two cannot run beside it, and replace the owner on PC 2 for the length of the trial, each with a rollback generation ready and the stage 4 routes re-proven first:
  - **oo7:** the pinned `services.oo7` module is system-wide (a user unit on `default.target` for every user, and PAM on `login`), and enabling it leaves gnome-keyring on and the Secret portal routed to it. A disposable user isolates nothing. Trial it only while PC 2 holds no real keyring, with gnome-keyring off and the Secret portal rerouted in that trial generation.
  - **A greetd greeter:** greetd takes over `display-manager.service`, so it cannot run next to GDM.
- **Replacement on PC 1 waits until after cutover.**

The order is from the least to the most dangerous to get wrong:

1. Launcher: Vicinae against Walker with Elephant (ADR-0048).
2. File chooser and file manager: GTK chooser, Dolphin, Dux Files (ADR-0028).
3. ScreenCast backend against the GNOME portal: `xdg-desktop-portal-generic` first, because it is in the pin; niri-screenshare once it has a reproducible package (ADR-0047).
4. Secret service: oo7 against gnome-keyring, with fake secrets (ADR-0023).
5. Greeter: greetd with tuigreet (ADR-0041). On PC 1 only after GNOME lock under greetd has been proven on PC 2, or after item 6. Stage 5's quit check and stage 6's quit-while-locked check are repeated under the new greeter: both must still end at an authenticated prompt.
6. GNOME session removal (ADR-0047 retirement gates).

Items 4 and 5 are never done in the same change: both touch PAM, and a failure in either can block login.

## Rejected or deferred for this path

| Option | Verdict | Reason |
|---|---|---|
| niri-screenshare | Deferred, packaging-dependent | No verdict on its function. VERIFIED absent from the pinned nixpkgs, so it needs a reproducible package first; its start-up writes portal preferences that Nix and chezmoi own (ADR-0047), which needs an approved declarative owner. Eligible for stage 15 once both are solved |
| iNiR shell | Deferred, packaging-dependent | No verdict on its function. VERIFIED absent from the pinned nixpkgs; its NixOS guidance is experimental and its module adds groups and can seed the niri config (ADR-0045). It stays the proposed extra trial in ADR-0045 and joins stage 10 only with a reproducible package, a reviewed module and an owner decision amending ADR-0013 |
| `xdg-desktop-portal-generic` | Deferred to stage 15 | In the pinned nixpkgs (1.2.0), but niri's Dynamic Cast Target support is unproven, and the GNOME portal already works |
| oo7 daemon and portal | Deferred to stage 15 | In the pinned nixpkgs (0.7.1, with a NixOS module), but the module is system-wide, changes PAM unlock and may migrate the real keyring on first start |
| greetd with tuigreet, ReGreet or gtkgreet | Deferred to stage 15 | GDM is the working login and keeps the GNOME fallback lockable. All three are in the pinned nixpkgs, so the delay costs nothing |
| `programs.niri.useNautilus = false` | Deferred to stage 15 | It reroutes the file chooser from Nautilus to the GTK portal: a change of owner that nothing has tested |
| Walker with Elephant | Deferred to stage 15 | Two more services and a second clipboard owner while Vicinae works |
| A shell's own locker, idle daemon or polkit agent | Not the first owner; allowed as an explicit swap | Open upstream issues on lock with monitor hotplug and resume (T-0032 shell gates G1 to G3). It may replace the standalone pair after passing stage 6's checks; rule 5 |
| Hide and minimise emulation | Not built first; decided before cutover | Niri has no native minimise; parking workspaces are shell-specific workarounds (ADR-0045). Tested with the shell in stage 10; the owner's G05 sign-off at stage 14 settles it |
| Btrfs or ZFS, TPM2 or FIDO2 unlock, Lanzaboote, hibernate | Not used for the pilot install | Each adds its own recovery procedure and none helps judge niri. PC 1's existing layout is not changed by this path; changing it would be a separate decision after the backup gate (ADR-0038 covers fresh hosts only) |
| nixos-anywhere for the first install | Not used for the pilot | A remote wipe needs a proven target identity; a local install with the other disk unplugged cannot hit the wrong disk |
| disko for the first install | Optional, not required | Acceptable only after its VM test (ADR-0038). For one machine the generated hardware file is simpler and equally safe with the other disk unplugged |
| Pushing system closures from PC 1 with the user in `nix.settings.trusted-users` | Not the default | A trusted Nix user is root-equivalent on that machine. Rebuilding on PC 2 from its own clone needs no such grant. Use a push only by owner decision, and prefer signed closures over a trusted user |
| niri-flake | **Rejected** | The nixpkgs module is enough (ADR-0012) |
| UWSM | Deferred, only for a proven need | `niri-session` already manages the session (ADR-0047) |
| `spawn-at-startup` for services | **Rejected** | Duplicates session-scoped systemd units and escapes their stop-at-logout scope (T-0032) |
| Setting `GDK_BACKEND` or spoofing `XDG_CURRENT_DESKTOP` | **Rejected** | Upstream warns it can break ScreenCast (ADR-0047 gate 4) |
| Removing GNOME, GDM, the GNOME portal or gnome-keyring before cutover | **Rejected** | It removes the fallback that every stage above relies on |
| Installing a full shell first and trimming it afterwards | **Rejected** | It starts with several owners per function and an unknown failure source; rule 2 |

## Owner decisions this ADR needs

- [ ] Approve the path and its six rules. This changes nothing live; it only fixes the order.
- [ ] Rule 5 and stage 6: swaylock and swayidle own lock and idle through the shell trial. This narrows ADR-0013, which compares shell lockers with the standalone pair without preferring either. It is the first owner for the pilot, not a permanent rule. If approved, amend ADR-0013 and T-0032 shell gate G11 in the same change.
- [ ] Stage 2: LUKS2 with a passphrase on PC 2. Choose no encryption only if PC 2 will never hold a real credential; T-0032 tests KeePassXC and browsers there, so encryption is recommended. Adding it later means an in-place re-encryption, which is possible but risky, or a reinstall.
- [ ] Stage 2: generated hardware file or disko for the first install (ADR-0038 stays `proposed` either way).
- [ ] Stage 3: how system changes reach PC 2. Recommended: rebuild on PC 2 from its own clone. A push from PC 1 needs either signed closures or a root-equivalent trusted user, and `--ask-sudo-password` for the remote sudo.
- [ ] Stage 3b: the work profile for PC 2's first activation, and the later, separate switch to the personal profile.
- [ ] Stage dependencies: the GNOME-only PC 1 takeover need not wait for the shell decision. This relaxes ADR-0046's gate order; if approved, amend that order in the same change.
- [ ] Each live stage (2, 3, 3b, 4, 5 onwards) still needs its own approval when it is reached. Approving the order does not approve any activation.

## Gaps in the committed configuration that the stages will hit

Found by reading the repo and the pinned nixpkgs on 2026-11-22 (VERIFIED). None is fixed here; each belongs to the ticket named.

| Gap | Evidence | Stage it blocks | Owner |
|---|---|---|---|
| The pilot host imports no hardware file yet | `nix/hosts/linux-desktop-pilot/system.nix` carries placeholder `fileSystems` entries, by design until PC 2 exists; `tests/bash/nixos-pilot.bats` asserts them | 2 (install) | T-0029 |
| The pilot host declares no SSH service or authorised key | The same file has no `services.openssh` | 3 and 4 (rollback generation, SSH route) | T-0029 |
| Two polkit agents under GNOME on the pilot | The pinned Soteria unit is wanted by `graphical-session.target`, which GNOME also reaches, and GNOME Shell has its own agent; the VM test checks Soteria only under niri | 3 (one prompt under GNOME) | T-0032 |
| `brightnessctl` and `playerctl` are bound in the KDL but declared nowhere under `nix/` | `home/dot_config/niri/config.kdl` media and brightness binds | 5 (commands on `PATH`) | T-0032 |
| Lock and idle are not configured | The KDL's swaylock bind is commented out; no swayidle or swaylock unit exists | 6 | T-0032 |
| Clipboard history and the recent-projects picker have no niri bind | GNOME binds Alt+V and Alt+E in `gnome-keybindings.nix`; the KDL binds only Alt+Space | 9 | T-0032 |
| The recent-projects picker is tied to Vicinae | `nix/modules/home/scripts/vscode-recent-projects.sh` pipes into `vicinae dmenu` | 9 (rescue launcher) | T-0031 |
| Project focus can pick the wrong window | The same script matches the folder basename inside window titles, then falls back to a focused or the first Code window | 9 (project focus) | T-0031 |
| Session units are not scoped per desktop | The Flameshot unit is wanted by `graphical-session.target`, which niri's session also starts, together with XDG autostart | 10 (unit audit) | T-0032 |
| The window helper has no niri backend | `nix/modules/home/scripts/window-backend.sh` accepts only `gnome` | 14 (G05 sign-off) | T-0031 |
| The sensitive-window rule is switched off | The KDL's KeePassXC `block-out-from "screen-capture"` rule is disabled with `/-` | 14 (G26, capture privacy) | T-0032 |
| PC 1 has no flake host | `nix/flake.nix` declares only `nixosConfigurations.linux-desktop-pilot` | 11 | T-0029 |
| The validator rejects `programs.<name>.enable` in shared NixOS modules | Rule 6 in `ops/validate-config.sh` (T-0030); today `programs.niri` is declared in the pilot host file, not in a shared module | 12 (a shared niri module for both hosts) | T-0030 |

## Review amendments (2026-11-22)

A research review of the first version kept the staged order and asked for targeted corrections; all are applied above. Rule 2 now asks for atomic activations, not exactly one generation. `nixos-rebuild test` is treated as a live change. Stage 3 creates the rollback generation that a fresh install lacks, and stage 4 adds the installer USB as a route that does not depend on the installed system. Stage 6 names the suspend ordering and the dead-locker recovery. Alternatives may be compared on PC 2 before cutover. niri-screenshare and iNiR are deferred for packaging, not rejected on function. Cutover needs the window-management sign-off from ADR-0045. The upstream statements behind stage 6 (niri keeps the session locked when the locker dies; `swayidle -w` with `swaylock -f`) come from the reviews' citations of the niri and swayidle documentation and were not re-fetched here; the stage's checks test them directly.

A second review found that the procedure could fail even with working tools. Applied above: stage 2 requires the generated hardware file to be tracked and built before the install, and the user's password to be set before the first reboot. Stage 3 makes generation 2 from a real change, because rebuilding an unchanged configuration creates none. Stage 3b activates Home Manager and chezmoi before niri is tried, since the pilot system itself installs neither Ghostty nor Vicinae. Stage 4 spells out the encrypted rescue from the installer USB and the SSH policy. Stage 6 adds the idle timeout, the logind lock request, the lid and quitting while locked. Rule 3 separates build evidence from hardware evidence.

A third round (two more reviews and an independent read of all fourteen Niri ADRs against the repo and the pinned nixpkgs) changed the following. Every rebuild names its flake and host, in the one form that evaluates. The hardware file is a module beside `system.nix`, committed and kept on the installed disk, so the VM test still boots and no later rebuild restores the placeholders. Stage 3 declares the authorised key and rebuilds on PC 2; pushing closures with a trusted user is no longer assumed. Stage 3b uses the work profile so that sync and bot services stay off the test machine. Stage 4 names the command that restores the boot default and no longer lists a niri bind before niri runs. Stage 10 runs all of T-0032's shell gates. Stage 11 states its prerequisite, restarts the display manager after `test`, and keeps generation 17 until cutover. The stage dependencies are explicit, which removes the earlier contradiction between "a failed stage stops the path" and the claim that the shell does not hold up PC 1. oo7 and a greetd greeter are recognised as trials that replace the owner on PC 2. The gap table grew from seven rows to thirteen.

## Consequences

- ADR-0046 stays the component register and keeps its `—` cells. When a stage passes, amend the owner ADR first, then the register, then tick the stage's evidence in T-0032 or T-0029.
- The trial order Dux then Noctalia (ADR-0013), GDM during the trial (ADR-0041), Vicinae during the trial (ADR-0048) and the GNOME-minimal target (ADR-0047) are unchanged. This ADR only places them in one sequence and moves every replacement behind cutover, while allowing comparison on PC 2 before it.
- Stages 0 to 9 give a lockable, recoverable niri session with screen sharing, secrets and a launcher before any shell is installed. A shell that fails its gates delays the taskbar and with it the cutover sign-off; whether it also delays the GNOME-only PC 1 takeover is the owner decision under "Stage dependencies".
- The physical install is not ready to start: the first two rows of the gap table are prerequisites of stages 2 and 3.
- Not checked here: any runtime behaviour. The versions and module contents above were evaluated from the pinned nixpkgs; no package was installed, no service started and no host changed.
