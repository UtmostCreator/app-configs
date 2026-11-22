---
adr: 49
title: "Niri on NixOS without the GNOME desktop: safest staged installation order, per-stage choice, pass check and fallback"
status: proposed
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, compositor, installation, migration, recovery, session]
permits: [gnome-free-niri-install, baseline-first-niri-install, atomic-stage-activation, staged-pass-checks, standalone-security-services, isolated-comparison-before-cutover]
forbids: [gnome-desktop-on-the-niri-install, changing-the-existing-system-during-the-install, combined-stage-changes, skipping-a-failed-stage, shell-owned-lock-before-trial-pass, first-activation-with-switch, cutover-without-window-parity-signoff]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 23, 27, 28, 33, 36, 38, 41, 45, 46, 47, 48, T-0029, T-0030, T-0031, T-0032, T-0033]
---
# ADR-0049: Niri on NixOS without the GNOME desktop: safest staged installation order, per-stage choice, pass check and fallback
Status: proposed (the owner's direction of 2026-11-22, a Niri install without the GNOME desktop where that is safe, is recorded; the order and the choice per stage are a proposal; nothing is installed, activated or removed until each live stage is approved) · Date: 2026-11-22 · Sources: ADR-0012/0013/0023/0028/0033/0036/0038/0041/0045/0046/0047/0048; T-0029, T-0032; `docs/plans/niri-migration.md` section 6; `docs/plans/niri-two-pc-pilot.md`; `nix/hosts/linux-desktop-pilot/system.nix`; `home/dot_config/niri/config.kdl`; the pinned nixpkgs modules for niri, greetd, gnome-keyring and Soteria.

## What this ADR is for

[ADR-0046](0046-niri-desktop-installation-decision-register.md) lists every component and gap. This ADR orders the work from the most vital to the least, names one safest choice per stage, and gives the expected behaviour, the check that lets the work continue, and the fallback when the check fails.

**Owner direction (2026-11-22):** install NixOS with niri and without the GNOME desktop, where that is safe, so that no desktop is carried along only as a spare. Earlier versions of this ADR kept GNOME and GDM beside niri on the new install as its fallback. That is replaced: the fallback is the existing system, which this path never touches.

It does not replace the owner ADRs. Where an owner ADR is `proposed` or `trial`, the choice below is the recommended first attempt for that stage, not a permanent selection.

Evidence labels: **VERIFIED** means read in this repo, or evaluated from the pinned nixpkgs (rev `5d2b81a7`), on 2026-11-22. Everything about behaviour in a real session is **unverified** until its stage runs.

Two terms: **the new install** is NixOS with niri on the laptop, which has no operating system and no data, installed from the NixOS installer USB (see "Where to install"). **The existing system** is today's GNOME installation on the PC. The step-by-step commands are in the [runbook](../../platforms/nixos/niri-install.md).

Every rebuild command names its flake and host: `git+file://<checkout>?dir=nix#linux-niri`. That form is VERIFIED to evaluate, whereas `git+file://<checkout>/nix#linux-niri` fails. `linux-niri` is the niri-only host (see "The name" below). It is not declared yet: the committed `linux-desktop-pilot` still enables GNOME and GDM (see the gap table).

## Decision (proposed)

### The target: niri with no GNOME desktop

| | On the new install |
|---|---|
| **Not installed** | GNOME Shell, Mutter, GDM, Nautilus, the GNOME application set, GNOME Shell extensions |
| **Kept, GNOME by name only** | `xdg-desktop-portal-gnome`, which niri needs for screen sharing, and `gnome-keyring`, the Secret Service. Neither is the GNOME desktop |
| **Replaces GDM** | greetd with tuigreet, a text login that needs no graphics stack (ADR-0041) |
| **Replaces the Nautilus file chooser** | The GTK portal, through `programs.niri.useNautilus = false` |

VERIFIED by evaluating the committed pilot with GNOME and GDM switched off, greetd on and `useNautilus = false` (evaluation only; nothing was built or installed):

- It evaluates. The only login session is `niri`.
- System packages fall from 239 to 149. GNOME-named system packages fall from 45 to 2: `gnome-keyring` and `xdg-desktop-portal-gnome`.
- The runtime closure of `xdg-desktop-portal-gnome` holds one other GNOME-named path, the `gnome-desktop` library. It does not pull in GNOME Shell, Mutter, GDM or Nautilus. The closure of `gnome-keyring` holds none.
- The file chooser routes to the GTK portal; ScreenCast stays on the GNOME portal; Secret stays on gnome-keyring.
- greetd's PAM stack includes `login`, and the keyring's unlock hook is enabled on `login`, so the keyring is configured to unlock at a greetd login.

Removing those last two would need another screen-sharing backend and another Secret Service. Both exist as candidates and both are less proven than what they would replace, so they stay until after cutover (stage 15).

### The name: `linux-niri`

The niri-only install is called **`linux-niri`**: the host directory of that name under `nix/hosts/` (planned, not created yet), the `nixosConfigurations` output, the Home Manager profile, the value `ops/detect-host.sh` returns, and the machine's network name. The rules behind the choice, for this and later hosts:

1. **Name the role, not the hardware.** No disk or machine brand, model, serial number or room. Hardware is replaced; the name has to outlive it, and a public repo should not list the inventory.
2. **Follow the existing family, `<os>-<role>`:** `linux-desktop`, `linux-cli`, `wsl`, `macos`. `linux-niri` sits beside them.
3. **One name in every layer,** so nobody needs a table to map a host to its profile. `linux-desktop-pilot`, which uses the `linux-desktop` profile, is the exception this avoids.
4. **A valid host name:** lowercase letters, digits and hyphens, starting with a letter, at most 63 characters.
5. **No word for a phase or an activity** ("setup", "new", "test", "pilot") in a name meant to last. `linux-desktop-pilot` may carry one because that host is meant to be deleted.

Not chosen: `niri-setup` names an activity and drops the family prefix; `linux-desktop-niri` would read as a variant of `linux-desktop`, which is the GNOME profile and shares none of its GNOME modules. If a second machine ever uses the profile, the profile keeps its name and only `networking.hostName` gets a per-machine suffix.

### Where to install: the laptop, from the installer USB

Three ways were on the table. The laptop is the safest and also the simplest.

| Option | Verdict | Why |
|---|---|---|
| **A. On the laptop, booted from the NixOS installer USB** | **Chosen** | The laptop holds nothing, so nothing can be lost and a failed attempt is simply repeated. The PC is not involved: no disk is attached to it and its boot entries are not touched. The hardware file is generated on the machine that will run it, the boot entry is written to that machine's own firmware, and what gets tested is what will be used. It needs no tooling beyond the standard installer |
| **B. Onto a disk attached to the running PC, then moved to the laptop** | Not chosen | It adds four risks that A does not have: a disk is wiped on a machine whose own disks are mounted; the install can write boot entries into the PC's firmware unless that is switched off; the generated hardware file describes the PC, not the laptop; and a disk that boots on the PC is not proven to boot on the laptop. Doing it safely means a guarded installer (disko-install or a script that refuses mounted disks), which is more to build and test than A |
| **C. Adding niri to the existing GNOME system first** | Not chosen | It changes the only daily machine, which is built from a hand-kept `/etc/nixos` with a single generation to roll back to and would first need the T-0029 takeover. A session beside GNOME is not the GNOME-free target, and a pass there says little about the laptop |

**"We cannot test many things" is answered by where each thing is tested, not by installing somewhere else.** Before the laptop is touched: the host builds, a VM boots it to the text login and into niri, and the [runbook](../../platforms/nixos/niri-install.md) is rehearsed once in a UEFI VM with an empty disk, through the encrypted reboot. What no VM can show (graphics, outputs, Wi-Fi, sound, suspend, the lid) is tested on the laptop in stages 5 to 8, where a failure costs time and nothing else.

Option B stays possible later for a machine that cannot boot from USB, with these gates: the target named by `/dev/disk/by-id` and refused if any of its partitions is mounted; `boot.loader.efi.canTouchEfiVariables = false`, relying on the fallback loader that systemd-boot installs on the disk's own EFI partition; the hardware file generated on the destination machine; and a cold boot on the destination recorded as its own evidence.

### Is it safe?

**Yes, on these conditions.**

1. It is a fresh install on the laptop, which holds nothing. The PC is not part of the install: nothing is attached to it and nothing on it is changed.
2. The login is text, so a broken graphics stack still leaves a working login prompt.
3. The recovery routes in stage 4 are proven before anything can lock the screen.
4. The PC stays as it is and is the place to work if the new install fails. That is the price of dropping the GNOME session: the new install has no second graphical desktop to fall back to.

**Not safe, and not part of this path:** removing GNOME from the existing system in place before the new install has passed. There GNOME is the only working desktop.

### What GNOME was quietly providing

Switching the GNOME module off also switches off services it enabled by default. VERIFIED by the same evaluation: PipeWire, WirePlumber, NetworkManager, polkit, dconf, graphics and the default fonts stay on; these do not:

| Service | Needed on the new install? |
|---|---|
| `hardware.bluetooth` | Yes, if Bluetooth devices are used |
| `services.udisks2` and `services.gvfs` | Yes: USB sticks and network mounts in a file manager |
| `services.upower` | Yes: battery and power state for the shell's indicators |
| `services.power-profiles-daemon` | On a laptop |
| `security.rtkit` | Yes: real-time priority for PipeWire |
| `services.accounts-daemon`, `avahi`, `colord`, `geoclue2` | Only for a named need |

The niri-only host declares the ones it needs. Leaving them out fails quietly (no Bluetooth, no USB mounts), which is why stage 8 checks them.

### What `programs.niri` already brings

VERIFIED contents of the pinned module (what is configured; stage 7 proves what works):

| Function | What the module brings | Consequence for the path |
|---|---|---|
| Session | niri session entry, `niri.service` user unit; default session `niri` | greetd starts `niri-session`; nothing to override |
| Portals | `xdg-desktop-portal-gnome` and `-gtk`; Access and Notification to gtk; Secret to gnome-keyring | Screen sharing and secrets are configured with no extra choice |
| File chooser | Nautilus unless `useNautilus = false`, which routes it to gtk | Set it to false: no Nautilus |
| Secrets | `services.gnome.gnome-keyring.enable` | Unlocked at login through PAM; KeePassXC stays separate (ADR-0023) |
| Authentication | `security.polkit.enable`, and `security.pam.services.swaylock` | A polkit agent is still needed (Soteria); swaylock can authenticate with no further PAM work |
| Session plumbing | dconf and `services.graphical-desktop`; niri's own `niri.service` pulls in `graphical-session.target` and XDG autostart | User units that target `graphical-session.target` start under niri |
| X11 apps | not enabled by the module | Add `xwayland-satellite`, which niri starts on demand |

The repo's `config.kdl` is niri's default config with a few edits (US and Russian layouts, Ghostty, Vicinae on Alt+Space, the swaylock bind commented out). It keeps `Mod+Shift+E` and `Ctrl+Alt+Delete` to quit and niri's own `Print` screenshot binds. VERIFIED by reading the file.

### Six rules that make the order safe

1. **Start minimal and only add.** Each function gets one owner from the first boot. Nothing is installed "to be safe", and nothing on the existing system is changed. An alternative to a working owner may be compared before cutover (stage 15); it replaces the owner only after cutover.
2. **One stage, one atomic activation, in a known layer.** Each stage that changes the machine is a reviewed change that can be activated and rolled back on its own, so a failure has one cause and one rollback. A stage that only tests what is already installed needs no new generation. The layer decides which machine a change reaches: the niri-only host's NixOS files reach the new install only, but Home Manager and chezmoi are one shared `linux-desktop` profile, so a change there also reaches the existing system at its next `sys-update`. Such a change must be inert without niri (a unit bound to `niri.service`, or a file only niri reads).
3. **A stage passes only on recorded evidence of the right kind.** A build stage (stage 1) passes on build and test output. Every later stage passes only when its checks ran on the target machine, in the real session where the stage has one, and are recorded under T-0032. A VM pass or a paper comparison does not pass a hardware stage. A module that evaluates, or a system that builds, shows what is configured, not that it works.
4. **A failed stage stops every stage that depends on it** (see "Stage dependencies"). Take the stage's fallback, or go back to the last passing generation.
5. **Security functions stay outside the shell.** Lock and idle, polkit, the secret service and the portals are standalone, session-scoped services. A desktop shell may own the bar, taskbar, notifications, tray and on-screen displays only. A shell crash must not unlock the screen or lose the password prompt. Running the locker as a separate process does not make it safe by itself; stage 6's checks do. This is the default for the first install, not a permanent ban: a shell's locker may take over once it passes stage 6's checks.
6. **The fallback is the existing system, not a second desktop.** Until cutover the existing system is not modified: not its disk, its boot loader or its configuration. If the new install fails at any stage, work continues there.

## Ordered path

Risk is the damage if the stage goes wrong. Difficulty is the work to do it properly. Stages 0 to 5, with 3b, are vital: without them the machine can lose data or lock its owner out. Stages 6 to 10 make the session usable. Stages 13 and 14 make it the daily system. Stage 15 is optional. Stages 11 and 12 belong to the alternative path at the end.

### Vital: data, boot, login, recovery

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 0 | **A laptop with nothing to lose** (G13) | Confirm the laptop's disk holds nothing wanted; if it does, copy it off first. The PC needs no backup for the install, because the install does not touch it; its data backup (Kopia, ADR-0033) is due before cutover, stage 14 | Critical if skipped / low | Erasing the laptop's disk loses nothing | The laptop's disk contents reviewed and recorded as disposable; firmware in UEFI mode with Secure Boot off; the installer USB boots; the PC's SSH public key is at hand, and no private key is on the USB stick | Nothing live starts until the disk is known to be disposable |
| 1 | **Build-only gates** (G14) | The niri-only host builds, a VM test boots it to the text greeter and into niri, and the runbook is rehearsed once in a UEFI VM with an empty disk, booted from the same installer image, through the encrypted reboot. None of these exists yet (gap table) | Low / medium | The system and the Home Manager profile build; the VM reaches tuigreet and starts niri | `nix flake check ./nix`; the niri-only toplevel builds; its VM test, run by hand (it needs KVM and is not part of `nix flake check`); evaluated options show GNOME and GDM off and exactly one session, `niri`; `bats tests/bash`; `bash ops/validate-config.sh` | Fix the build. Nothing has touched a machine yet |
| 2 | **Disk and install** (G01) | The [runbook](../../platforms/nixos/niri-install.md), steps 1 to 5, from the NixOS installer USB. Simple defaults, not a layout policy for other hosts: GPT, one EFI partition, LUKS2 with a passphrase, ext4 root, systemd-boot, no disk swap and no hibernate (zram is an opt-in in `desktop-stability.nix` that the shared module does not import; declare it explicitly if wanted) | Medium (the only disk that can be erased is the laptop's own; the installer stick is the one thing to avoid) / medium | The laptop boots NixOS from its disk, asks for the passphrase and shows a text login | The disk is chosen by `/dev/disk/by-id` and its model and size are read back before the first destructive command. `nixos-generate-config --root /mnt` runs on the laptop, and its file names the LUKS device, root and EFI partition just created. The repo is cloned onto the new disk under `/mnt/home/<user>/`, not left in the installer's memory. The generated file replaces the host's placeholder hardware module (a separate module beside `system.nix`, so the VM test keeps booting) and is committed, so the installed system reports a clean commit. The toplevel builds, then `nixos-install --no-root-passwd --flake "git+file://<checkout>?dir=nix#linux-niri"`. The user's password is set with `nixos-enter --root /mnt -c 'passwd <user>'` before the first reboot (the repo holds none). The passphrase, typed as on a US keyboard, unlocks the disk at a cold boot | Repeat from the partitioning step. The laptop holds nothing and the PC was never involved |
| 3 | **Text login and a rollback generation** | greetd with tuigreet as the only display manager, starting `niri-session`, with `services.greetd.useTextGreeter` so boot messages do not overwrite the prompt. Generation 2 comes from a real reviewed change, which stage 4 needs anyway: `services.openssh` with the other machine's public key in the user's `openssh.authorizedKeys.keys`, password and keyboard-interactive logins off, root login off. Rebuilt on the laptop from its own clone, as the normal user: `nixos-rebuild boot --flake "git+file://$PWD?dir=nix#linux-niri" --sudo`, so the build runs as the owner of the checkout and only the activation is elevated | Medium / low | The tuigreet prompt appears after boot. A fresh install has only generation 1, and rebuilding an unchanged configuration creates no new one, so a rollback target has to be made on purpose | tuigreet shows at boot and a second text console (`Ctrl+Alt+F2`) gives a login with the password from stage 2; a wrong password is refused; `nixos-version --configuration-revision` shows a clean commit; `nixos-rebuild list-generations` shows two entries and the boot menu shows both; generation 1 is booted once, then generation 2 again, and generation 2 is left as the default; `nmtui` connects the network without a graphical settings tool | Boot generation 1, or repair from the installer USB (stage 4) |
| 3b | **User environment** | From a text console, before niri is first started: `bash ops/install.sh --profile work`. Standalone Home Manager and chezmoi; the work profile leaves out what is bound to personal accounts (see "User services on the new install"). Never `ops/system-setup.sh` or `ops/tailscale-setup.sh` here, although the installer ends by suggesting the first: both rewrite `/etc/nixos` (T-0029) | Medium (without it niri starts with no terminal, launcher or config) / low | The Home Manager profile is active and chezmoi has deployed the niri config | `command -v ghostty vicinae niri` all resolve; `~/.config/niri/config.kdl` exists and `niri validate` passes; `chezmoi --source=<checkout> verify` passes (a plain `chezmoi verify` fails on a host whose source directory is not configured); `syncthing.service` and `openclaw-gateway.service` do not exist. The installer's "system layer" warning (login shell, GC timer, time zone) is expected here and is not acted on. A successful build of the activation package does not count: the profile must be activated on this machine | Fix the install from the text console. Undo with Home Manager's own generations (`home-manager generations`, then the previous one's `activate`); a NixOS rollback does not undo it |
| 4 | **Recovery routes** (G17), proven before anything can lock the screen | Text console login, the boot menu, key-only SSH from the PC (declared in stage 3), and the installer USB | High if missing / medium | Each route gives a working shell without a reinstall. The boot menu alone is not enough: one more route must not depend on the new install | `Ctrl+Alt+F3` text login works from the greeter and from inside a graphical session; `loginctl terminate-session` ends a session from the console; SSH works with the key, and a password login and a root login are both refused; the known-good generation boots from the menu. Installer USB, written down and run once in full: `cryptsetup open` the LUKS partition, mount the root at `/mnt` and the ESP at `/mnt/boot`, then `nixos-enter --root /mnt -c 'nix-env -p /nix/var/nix/profiles/system --switch-generation <N> && /nix/var/nix/profiles/system/bin/switch-to-configuration boot'`, reboot, and confirm generation `<N>` is the default. The rehearsal confirms or corrects that command | Do not add a locker or shell until every route works |
| 5 | **Bare niri session** (G02, G10) | The module defaults, Soteria, xwayland-satellite and the chezmoi KDL, with no bar, locker or shell | High (niri refuses software rendering, and the graphics hardware is unverified until this stage) / low | Logging in at tuigreet gives an empty workspace; `Mod+T` opens Ghostty; `Mod+Shift+Slash` shows the hotkey overlay; `Mod+Shift+E` quits back to the login prompt | `niri msg outputs` lists every real monitor with the right mode and scale; unplug and replug an external monitor; both keyboard layouts switch with Super+Space; an X11 app opens; `pkexec true` raises exactly one Soteria prompt; every command the KDL binds call resolves on the session `PATH`; both quit binds end at the tuigreet prompt, never at a logged-in console; `systemctl --user --failed` is empty | There is no graphical fallback on this install: log in on a text console to investigate, and work on the existing system meanwhile. A graphics failure that cannot be fixed ends the trial on this hardware. Do not add GNOME, Hyprland or KDE as a quick substitute |

### Usable session: one owner per function

Follow the [shared work-folder convention](0040-macos-home-layout-and-cleanup-policy.md#shared-work-folder-convention) and [ADR-0050's first-login checks](0050-nixos-niri-home-layout.md). Evaluate the proposed provisioning separately from the disk and recovery gates above.

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 6 | **Lock, idle and suspend** (G03, G21) | swaylock and swayidle as one standalone pair, started by a Home Manager user unit bound to `niri.service` (inert on a machine without niri): `swayidle -w` with a `timeout` that locks, a `lock` hook for logind, and a `before-sleep` hook, each running `swaylock -f`. The `Super+Alt+L` bind is enabled in the KDL with `allow-when-locked=true`, so a new locker can be started when the first one has died | High (a broken locker either exposes the desktop or locks the owner out) / medium | The screen locks on the bind, on idle, on a logind lock request and before suspend; resume shows the locker, never the desktop. If the locker dies, niri keeps the session locked and shows its own locked background: the desktop stays protected, but nothing accepts a password until a locker runs again | Wrong password refused, right one accepted. Each trigger locks: the bind, the idle timeout (shortened for the test), `loginctl lock-session`, `systemctl suspend`, and closing the lid on a laptop. Resume with an external monitor unplugged meanwhile never shows the desktop. With the locker killed from the console the session stays locked, and both the bind and a locker started from the console restore the password prompt. Quitting niri while locked ends at the login prompt, not at a logged-in console. Exactly one idle controller and one locker run (swayidle and swaylock together are that one pair) | Remove the pair and lock by logging out until fixed. Do not use a shell's locker as the substitute |
| 7 | **Portals and secrets** (G11, G18) | The module's routing with `useNautilus = false`: GNOME portal for ScreenCast, GTK portal for the file chooser, gnome-keyring unlocked at the greetd login | High for daily use / low | To be shown, not assumed: the module configures the routing, and only the checks prove that screen sharing, file dialogs and stored credentials work on this machine | Brave shares a monitor and a single window, and again after cancel, hotplug and resume (Vesktop is checked once the personal profile is on, see stage 3b); open and save dialogs in Brave and VS Code; `busctl --user status org.freedesktop.secrets` shows one owner; a test secret can be stored and read after login with no second password prompt; KeePassXC unlocks and its browser integration fills | File dialogs: set `useNautilus = true`, which brings Nautilus back, one line. Screen sharing or the keyring: use the existing system for that task and record the failure in T-0032; do not swap the backend to fix it |
| 8 | **Sound, network, devices** (G24) | PipeWire and NetworkManager as they are, plus the services the GNOME module used to switch on, declared on the niri-only host: Bluetooth, udisks2 with GVfs, UPower, rtkit, and power-profiles-daemon on a laptop | Medium / low | Volume and microphone keys, Wi-Fi, Bluetooth and USB storage work | `wpctl status` shows the expected sink and source; a call has a working microphone; `bluetoothctl show` reports a powered controller where one exists; a USB stick mounts and ejects from the file manager (Double Commander is already in the profile); the existing volume and brightness binds work while locked | Use the mixer that is already installed (`pavucontrol`); declare a missing service only for a gap that is named |
| 9 | **Launcher and clipboard** (G06, G23) | Keep Vicinae with its existing user unit and the Alt+Space bind; no second launcher. Add niri binds for clipboard history and the recent-projects picker, which today exist only in the GNOME keybindings | Medium / low | Alt+Space toggles Vicinae; clipboard history and recent VS Code projects open from their own keys | Each bind works after cold login and under both layouts; a recent folder and a `.code-workspace` open the right target; with two Code windows open, picking a project focuses that project's window. As an interim pass it may instead report that it cannot tell, but it never focuses an unrelated window (exact focus stays the P0 target in ADR-0048, built in T-0031). Exactly one clipboard-history provider runs | Fuzzel as a rescue launcher for applications. It cannot run the recent-projects picker today, which calls `vicinae dmenu` directly; that needs a launcher-neutral menu adapter first (T-0031) |
| 10 | **Shell: bar, taskbar, notifications, tray** (G03, G04) | The approved trial order: Dux first, then Noctalia (ADR-0013). The shell's launcher, clipboard history, locker, idle and polkit agent are switched off. Module extras are reviewed first: the pinned Dux module turns on i2c and accounts-daemon by default, and the pinned Noctalia installs plugins by cloning repositories at run time. A shell declared in Home Manager is bound to the niri session, so it cannot start on the existing GNOME system through the shared profile | Medium (young software with open upstream issues; a crash costs the bar, not the session, because of rule 5) / high | Before activation, the user units and XDG autostart entries that niri's session starts are listed. Then: a bar with running windows, a tray and notifications; the session keeps working when the shell is killed | T-0032's shell trial gates G1 to G11, all of them (G8 only with a security key, G6 with the screenshot track below; G1 to G3 exercise the shell process while the standalone pair holds the lock); `busctl --user status org.freedesktop.Notifications` shows one owner; notifications and tray icons from the chat apps appear; killing the shell leaves windows, the locker and Soteria working | The next shell in the order, then Waybar with SwayNC (ADR-0013 fallback). A session with no bar remains usable meanwhile |

Window actions (G05, T-0031) and screenshots (G11, G26) run beside stages 9 and 10 and gate cutover, not the stages after them:

- **Window actions:** niri's native binds plus a niri backend for launch-or-focus by most recent use; the helper supports only the GNOME backend today. On an install with no GNOME session there is no other backend to fall back to, so this is required before the install can be the daily system. Hide, show and restore are requirements in ADR-0045, and niri has no native minimise: before cutover the owner signs off G05 with an explicit choice between a parking-workspace workaround that passed its tests, working without hide and show, or holding the cutover.
- **Screenshots:** judged by capability (area, last region, pin, clipboard, annotation), not by tool (ADR-0036). niri's built-in `Print` actions are already bound and cover area, screen and window. Flameshot's hotkeys exist only in the GNOME keybindings, and on the pinned niri 26.04 its portal path is expected to fail on two monitors (T-0032, HIGH). Satty would cover annotation only; pin and last region would then need their own answer before Flameshot is dropped.

### User services on the new install

The Home Manager output for `linux-desktop` hard-codes the personal profile, which would start account-bound services on a test install. The install selection can force the work profile (`--profile work` sets `myConfig.profile` with `mkForce`), and both account-bound services are gated on the personal profile. VERIFIED by reading `nix/modules/home/profile.nix`, `gui.nix` and `openclaw.nix`; unverified on the machine.

| User unit or package | With `--profile work` | On the new install |
|---|---|---|
| Vicinae, Flameshot | present | Wanted |
| `vicinae-focus-tracker` | present, runs only when `XDG_CURRENT_DESKTOP=GNOME` | Never runs; harmless |
| GNOME Shell extensions (Vicinae, AppIndicator), GNOME dconf settings and keybindings | present: the profile imports the GNOME modules | Unused. They are the one extra dependency left, and go when the `linux-niri` Home Manager profile exists (gap table) |
| `syncthing` | absent (personal only) | Off until the owner pairs this machine on purpose |
| `openclaw-gateway` | absent (personal only) | Off: a second gateway on the same account is not a test |
| Telegram, Vesktop | absent (personal only) | Added later with `--profile personal`, as its own approved step, when T-0032's chat and call checks are due |
| `codebase-memory-mcp-*`, `repo-audit` timer, AI CLI update timers | present | Local only; allowed |

### Making it the daily system

| # | Stage | Safest choice | Risk / difficulty | Expected behaviour | Pass check (all must hold) | On failure |
|---|---|---|---|---|---|---|
| 13 | **Daily trial** | Two to four weeks of real work on the new install. The existing system is left as it is | Low / time only | No P0 failure in T-0032's list | The trial checklist: restart, logout, multi-monitor, screen sharing, file dialogs, clipboard, sleep and resume | Work on the existing system; fix and restart the clock |
| 14 | **Cutover** | The laptop becomes the daily machine. Before it, the PC's data is backed up (Kopia, ADR-0033) and a sample is restored; then the data is brought over from that backup. The PC is kept, unchanged, until the owner decides to retire it or to reinstall it the same way | Medium / low | Daily work happens in niri on the laptop; the PC is still there | Separate owner approval; window-action parity (G05) and the shell's taskbar requirements (G04, ADR-0045 P0) signed off, including the hide and show choice above; a sample directory and the KeePassXC database restored from the backup and opened; the PC still boots | Go back to working on the PC |

### Stage dependencies

- **Stages 0 to 10 run in order.** A failure stops the later ones.
- **Stage 13 depends on stages 0 to 10, stage 14 on stage 13 and on the sign-offs in its row.** A shell that fails its gates therefore blocks the cutover, not the install or the bare session.
- **Stages 11 and 12 are not on this path.** They belong to the alternative below.

### Optional replacements, one at a time

Stage 15 holds every replacement of a working component. Each is its own change with its own approval and its own rollback, and none blocks anything above. A comparison may start once stages 0 to 10 have passed; a replacement waits until after cutover.

1. Launcher: Vicinae against Walker with Elephant (ADR-0048).
2. File manager: Dolphin, Dux Files or another against Double Commander (ADR-0028). The file chooser is already the GTK portal.
3. ScreenCast backend against the GNOME portal: `xdg-desktop-portal-generic` first, because it is in the pin; niri-screenshare once it has a reproducible package (ADR-0047). This is what would remove the GNOME portal.
4. Secret service: oo7 against gnome-keyring, with fake secrets (ADR-0023). This is what would remove gnome-keyring. The pinned `services.oo7` module is system-wide (a user unit on `default.target` for every user, and PAM on `login`) and leaves gnome-keyring on, so a test user isolates nothing: trial it only while the machine holds no real keyring, with gnome-keyring off and the Secret portal rerouted in that trial generation.
5. A graphical greeter: ReGreet or gtkgreet in place of tuigreet (ADR-0041). Stage 5's quit check and stage 6's quit-while-locked check are repeated under it.

Items 4 and 5 are never done in the same change: both touch PAM, and a failure in either can block login. Items 3 and 4 are the only way to reach an install with no GNOME-named component at all. They are optional, and neither is worth a weaker screen-sharing or credential path.

### Alternative: converting the existing GNOME system in place

Not the chosen path. It is kept because T-0029 already describes it, and because the existing system may one day be brought under the repo's flake. There GNOME is the only working desktop, so it stays installed until niri has passed on that hardware.

| # | Stage | What it is |
|---|---|---|
| 11 | **System takeover, GNOME only** (T-0029, G25) | Needs `nixosConfigurations.linux-desktop`, which does not exist. Stage 0 repeated on the day; garbage collection off. `sudo nixos-rebuild build --flake "git+file://$PWD?dir=nix#linux-desktop"` and the closure diff touch nothing live. Then the same target with `test` from a text console, followed by `systemctl restart display-manager`: `test` activates the new system at once but does not restart GDM. It is a live change that needs its own approval and that machine's own routes proven (text console, boot menu, installer USB). Then `boot`, and a reboot. Never `switch` first. Generation 17 is kept until that machine's cutover has passed |
| 12 | **Niri as a second session there** | The module set that passed on the new install, with GNOME still the GDM default. After a daily trial, the default session changes, and GNOME is removed afterwards under ADR-0047's gates |

## Rejected or deferred for this path

| Option | Verdict | Reason |
|---|---|---|
| GNOME and GDM on the new install as a fallback session | **Rejected** (owner direction, 2026-11-22) | It adds some ninety system packages and a second desktop to maintain, only to hold a spare that the existing system already provides. It also creates problems of its own: two polkit agents in the GNOME session, GNOME-only units, and the default-session override |
| Installing onto a disk attached to the running PC | Not chosen | Option B above: it puts the PC's disks and firmware entries at risk and describes the wrong machine's hardware |
| Adding niri to the existing GNOME system first | Not chosen | Option C above: it changes the only daily machine and is not the GNOME-free target |
| A machine-readable task register with plan, doctor, verify and install commands | Not adopted | For one laptop it is more to build and test than the install itself. The stages here and the checklist in T-0032 do that job |
| One shared desktop module with gnome, dual and niri modes | Not adopted now | Useful only if the PC is later converted in place. A single `linux-niri` host needs no mode switch, and the validator would have to allow it first (T-0030) |
| An AI coding assistant as part of the install | Optional, never a prerequisite | It arrives with stage 3b like the other tools (ADR-0006 keeps its installation outside Nix). The install, the first boot and every recovery route work without it, and it never runs partitioning, install or activation commands |
| Removing GNOME from the existing system before cutover | **Rejected** | It removes the fallback that every stage above relies on |
| Removing `xdg-desktop-portal-gnome` or `gnome-keyring` now | Deferred to stage 15 | niri needs the first for screen sharing and applications need the second; the replacements are less proven |
| GDM as the greeter | **Rejected** for the new install | GDM brings GNOME Shell with it |
| ReGreet or gtkgreet as the first greeter | Deferred to stage 15 | A graphical greeter needs its own compositor and fails with the graphics stack; tuigreet does not |
| niri-screenshare | Deferred, packaging-dependent | No verdict on its function. VERIFIED absent from the pinned nixpkgs, so it needs a reproducible package first; its start-up writes portal preferences that Nix and chezmoi own (ADR-0047), which needs an approved declarative owner |
| iNiR shell | Deferred, packaging-dependent | No verdict on its function. VERIFIED absent from the pinned nixpkgs; its NixOS guidance is experimental and its module adds groups and can seed the niri config (ADR-0045). It joins stage 10 only with a reproducible package, a reviewed module and an owner decision amending ADR-0013 |
| `xdg-desktop-portal-generic` | Deferred to stage 15 | In the pinned nixpkgs (1.2.0), but niri's Dynamic Cast Target support is unproven, and the GNOME portal already works |
| oo7 daemon and portal | Deferred to stage 15 | In the pinned nixpkgs (0.7.1, with a NixOS module), but the module is system-wide, changes PAM unlock and may migrate a real keyring on first start |
| Walker with Elephant | Deferred to stage 15 | Two more services and a second clipboard owner while Vicinae works |
| A shell's own locker, idle daemon or polkit agent | Not the first owner; allowed as an explicit swap | Open upstream issues on lock with monitor hotplug and resume (T-0032 shell gates G1 to G3). It may replace the standalone pair after passing stage 6's checks; rule 5 |
| Hide and minimise emulation | Not built first; decided before cutover | Niri has no native minimise; parking workspaces are shell-specific workarounds (ADR-0045). Tested with the shell in stage 10; the owner's G05 sign-off at stage 14 settles it |
| Btrfs or ZFS, TPM2 or FIDO2 unlock, Lanzaboote, hibernate | Not used for this install | Each adds its own recovery procedure and none helps judge niri |
| nixos-anywhere for the first install | Not used | A remote wipe needs a proven target identity; a local install with the other disk unplugged cannot hit the wrong disk |
| disko for the first install | Optional, not required | Acceptable only after its VM test (ADR-0038). For one machine the generated hardware file is simpler and equally safe with the other disk unplugged |
| Pushing system closures from another machine with the user in `nix.settings.trusted-users` | Not the default | A trusted Nix user is root-equivalent on that machine. Rebuilding on the machine from its own clone needs no such grant. Use a push only by owner decision, and prefer signed closures over a trusted user |
| niri-flake | **Rejected** | The nixpkgs module is enough (ADR-0012) |
| UWSM | Deferred, only for a proven need | `niri-session` already manages the session (ADR-0047) |
| `spawn-at-startup` for services | **Rejected** | Duplicates session-scoped systemd units and escapes their stop-at-logout scope (T-0032) |
| Setting `GDK_BACKEND` or spoofing `XDG_CURRENT_DESKTOP` | **Rejected** | Upstream warns it can break ScreenCast (ADR-0047 gate 4) |
| Installing a full shell first and trimming it afterwards | **Rejected** | It starts with several owners per function and an unknown failure source; rule 2 |

## Owner decisions

Recorded:

- [x] 2026-11-22: the Niri install carries no GNOME desktop, where that is safe. This ADR's answer to "where that is safe" is the four conditions above; it follows that greetd replaces GDM and the GTK portal replaces the Nautilus chooser on that install.

Still needed:

- [ ] Approve the path and its six rules. This changes nothing live; it only fixes the order.
- [ ] Rule 5 and stage 6: swaylock and swayidle own lock and idle through the shell trial. This narrows ADR-0013, which compares shell lockers with the standalone pair without preferring either. If approved, amend ADR-0013 and T-0032 shell gate G11 in the same change.
- [ ] Stage 2: LUKS2 with a passphrase. Choose no encryption only if the install will never hold a real credential. Adding it later means an in-place re-encryption, which is possible but risky, or a reinstall.
- [ ] Where to install: the laptop, from the installer USB (recommended above), with the generated hardware file. disko stays optional (ADR-0038 stays `proposed` either way).
- [ ] Stage 3: how system changes reach the machine. Recommended: rebuild on it from its own clone. A push from another machine needs either signed closures or a root-equivalent trusted user, and `--ask-sudo-password` for the remote sudo.
- [ ] Stage 3b: the work profile for the first activation, and the later, separate switch to the personal profile.
- [ ] Each live stage (2, 3, 3b, 4, 5 onwards) still needs its own approval when it is reached. Approving the order does not approve any activation.

## Gaps in the committed configuration that the stages will hit

Found by reading the repo and the pinned nixpkgs on 2026-11-22 (VERIFIED). None is fixed here; each belongs to the ticket named.

| Gap | Evidence | Stage it blocks | Owner |
|---|---|---|---|
| `linux-niri` does not exist | No host directory, flake output, Home Manager profile or `detect-host` value by that name. `nix/flake.nix` declares only `linux-desktop-pilot`, which enables GDM and the GNOME desktop; `tests/bash/nixos-pilot.bats` and `nix/tests/pilot-vm.nix` assert both | 1 | T-0029, T-0032 |
| The services the GNOME module enabled are not declared | Bluetooth, udisks2, GVfs, UPower, rtkit and power-profiles-daemon are off once GNOME is off | 8 | T-0029 |
| No hardware file, and placeholder disks | The pilot host carries placeholder `fileSystems` entries, by design until the disk exists | 2 | T-0029 |
| No SSH service or authorised key | The pilot host has no `services.openssh` | 3 and 4 | T-0029 |
| The Home Manager profile brings GNOME-only modules | `nix/hosts/linux-desktop/home.nix` imports `gnome-extensions.nix`, `gnome-keybindings.nix` and `gnome-files.nix`; `gui.nix` installs two GNOME Shell extensions | None: unused there, but an extra dependency | T-0042, T-0032 |
| The installer does not know `linux-niri` | `ops/detect-host.sh` returns `linux-desktop` or `linux-cli`, so the first activation uses the `linux-desktop` profile; the installer then suggests `ops/system-setup.sh`, which must not run here | 3b (works, with the warning ignored) | T-0042 |
| `brightnessctl` and `playerctl` are bound in the KDL but declared nowhere under `nix/` | `home/dot_config/niri/config.kdl` media and brightness binds | 5 | T-0032 |
| Lock and idle are not configured | The KDL's swaylock bind is commented out; no swayidle or swaylock unit exists | 6 | T-0032 |
| Clipboard history and the recent-projects picker have no niri bind | The GNOME keybindings bind Alt+V and Alt+E; the KDL binds only Alt+Space | 9 | T-0032 |
| The recent-projects picker is tied to Vicinae | `nix/modules/home/scripts/vscode-recent-projects.sh` pipes into `vicinae dmenu` | 9 (rescue launcher) | T-0031 |
| Project focus can pick the wrong window | The same script matches the folder basename inside window titles, then falls back to a focused or the first Code window | 9 | T-0031 |
| Session units are not scoped per desktop | The Flameshot unit is wanted by `graphical-session.target`, together with XDG autostart | 10 (unit audit) | T-0032 |
| The window helper has no niri backend | `nix/modules/home/scripts/window-backend.sh` accepts only `gnome` | 14 (G05 sign-off) | T-0031 |
| The sensitive-window rule is switched off | The KDL's KeePassXC `block-out-from "screen-capture"` rule is disabled with `/-` | 14 (G26) | T-0032 |
| The validator rejects `programs.<name>.enable` in shared NixOS modules | Rule 6 in `ops/validate-config.sh` (T-0030); today `programs.niri` is declared in the pilot host file, not in a shared module | A shared niri module | T-0030 |

One gap from the earlier version is gone: on the GNOME pilot, Soteria and GNOME Shell's own polkit agent would both run in the GNOME session. With no GNOME session there is one agent.

## Review amendments (2026-11-22)

Three review rounds shaped the stages. The first kept the staged order and asked for atomic activations, `nixos-rebuild test` treated as a live change, a rollback generation made on purpose, an installer-USB route, and the suspend ordering and dead-locker recovery in stage 6. The second required the generated hardware file to be tracked and built before the install, the password set before the first reboot, Home Manager activated before niri is tried, and the encrypted rescue spelled out. The third, which included an independent read of all fourteen Niri ADRs against the repo and the pinned nixpkgs, named the flake and host in every rebuild, moved the hardware file out of the file the VM test imports, declared the authorised key, switched the first activation to the work profile, ran all of T-0032's shell gates, and made the stage dependencies explicit. The upstream statements behind stage 6 (niri keeps the session locked when the locker dies; `swayidle -w` with `swaylock -f`) come from the reviews' citations of the niri and swayidle documentation and were not re-fetched here; the stage's checks test them directly.

A further set of reviews compared three places to install. The laptop, booted from the installer USB, was chosen; installing onto a disk attached to the running PC and adding niri to the existing GNOME system were not. From those reviews: Secure Boot off, a passphrase that types the same on a US layout, `--no-root-passwd` with the user's password set before the first reboot, and a rehearsal of the whole runbook in a VM. Not taken: disko-install, a task-register tool, a three-mode desktop module, and an assistant in the critical path.

The owner's direction then removed GNOME and GDM from the new install. That changed rule 6, stages 3, 5, 7 and 8, the cutover, and the rejected table, and moved the in-place conversion of the existing system to an alternative.

## Consequences

- ADR-0046 stays the component register and keeps its `—` cells. When a stage passes, amend the owner ADR first, then the register, then tick the stage's evidence in T-0032.
- The trial order Dux then Noctalia (ADR-0013) and Vicinae during the trial (ADR-0048) are unchanged. ADR-0012, ADR-0041 and ADR-0047 are amended in the same change to record the GNOME-free install.
- Stages 0 to 9 give a lockable, recoverable niri session with screen sharing, secrets and a launcher before any shell is installed.
- The install cannot start yet: the first four rows of the gap table are prerequisites of stages 1 to 3.
- Not checked here: any runtime behaviour. Options, package counts and closures were evaluated from the pinned nixpkgs; no package was built for this, no service started and no host changed.
