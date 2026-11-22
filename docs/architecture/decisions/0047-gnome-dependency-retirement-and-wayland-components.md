---
adr: 47
title: "Niri desktop without the GNOME desktop: what is excluded, what stays, and the feature-based replacement audit"
status: partly-decided
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, gnome, replacement, session, portals, services, migration]
permits: [gnome-free-niri-install, gnome-dependency-inventory, comparative-replacement-research, staged-gnome-retirement]
forbids: [blanket-gnome-purge, untested-portal-replacement, premature-gnome-removal, duplicate-desktop-service-ownership]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 21, 23, 27, 28, 33, 36, 38, 41, 45, 46, 48, 49, T-0029, T-0030, T-0031, T-0032, T-0033]
---
# ADR-0047: Niri desktop without the GNOME desktop: what is excluded, what stays, and the feature-based replacement audit
Status: partly-decided (the niri install carries no GNOME desktop, by the owner's direction of 2026-11-22; the evaluation rule is chosen; the replacement products for the two remaining GNOME-named services, and GNOME removal on the existing system, remain open) · Date: 2026-11-22 · Sources: ADR-0012/0013/0041/0046/0048; [Niri upstream Important Software](https://github.com/niri-wm/niri/wiki/Important-Software); [Niri packaging](https://github.com/niri-wm/niri/blob/main/docs/wiki/Packaging-niri.md).

## Decision and boundary

**Long-term architecture preference: Niri without the GNOME desktop environment.** A GNOME package/service is **not kept solely because it is installed today** or supplied by a desktop metapackage. A GNOME component may be retained if it (a) supplies a required, independently useful capability; (b) **outperforms or is more reliable/compatible than available non-GNOME substitutes in a documented comparison**, or (c) is an unavoidable tested compatibility dependency for the selected Niri integration. Prefer the smallest retained GNOME *component*, not a full GNOME session.

For the **existing GNOME system** this is a future-state policy, **not** a removal authorisation: its GNOME+GDM stay until an owner-approved, backup-protected change completes. For the **new niri install** the owner's direction of 2026-11-22 applies: it is built without the GNOME desktop from the start (see the next section). ADR-0041's greetd preference and ADR-0048's launcher comparison likewise cannot silently change currently running software. Every row below must differentiate **user-facing GNOME applications, GNOME Shell/session, freedesktop portal backends, keyring daemons and GTK libraries**: depending on GTK or a GNOME portal does **not** imply installing the GNOME desktop.

**Selection test:** keep a GNOME component only if it passes the same functionality/reliability/reproducibility assessment as its competitors, or a proven compatibility block exists. A preference for a lighter candidate does not waive P0 security, screen sharing, login/recovery or required app workflows.

## The GNOME-free niri install (owner direction, 2026-11-22)

"GNOME-free" means no GNOME desktop: no GNOME Shell, Mutter, GDM, Nautilus, GNOME applications or GNOME Shell extensions. It does not mean no package with GNOME in its name. Evaluated from the pinned nixpkgs on 2026-11-22, by switching GNOME and GDM off in the committed pilot, turning greetd on and setting `programs.niri.useNautilus = false` (evaluation only):

| Question | Result |
|---|---|
| Does it evaluate? | Yes; the only login session is `niri` |
| System packages | 239 fall to 149 |
| GNOME-named system packages | 45 fall to 2: `xdg-desktop-portal-gnome` and `gnome-keyring` |
| Does the GNOME portal pull in the desktop? | No. Its runtime closure holds one other GNOME-named path, the `gnome-desktop` library |
| Does gnome-keyring pull in the desktop? | No GNOME-named path besides itself |
| File chooser | GTK portal; Nautilus is not installed |
| Keyring unlock at login | Configured: greetd's PAM includes `login`, where the keyring hook is enabled |

**Why the two stay.** niri's screen sharing goes through `xdg-desktop-portal-gnome`, and applications expect a Secret Service. Their replacements (`xdg-desktop-portal-generic` or niri-screenshare; oo7) are candidates below and are less proven. Removing either is optional and comes after cutover.

**What the GNOME module was switching on.** With GNOME off, these are off too and must be declared where needed: `hardware.bluetooth`, `services.udisks2`, `services.gvfs`, `services.upower`, `services.power-profiles-daemon`, `security.rtkit`, and, only for a named need, `services.accounts-daemon`, `avahi`, `colord` and `geoclue2`. PipeWire, WirePlumber, NetworkManager, polkit, dconf, graphics and the default fonts stay on.

**What the GNOME application set was covering.** The pilot's GNOME desktop installs, among others, Loupe (images), Papers (PDF), Showtime and Decibels (video and audio), GNOME Text Editor, Console, Calculator, System Monitor, Disks and the Settings application. On the GNOME-free install the profile already covers terminal (Ghostty), editor (VS Code), system monitor (btop), disk usage (QDirStat), file manager (Double Commander), calculator (Vicinae) and PDF (Brave is the handler). It has no image viewer, no media player and no archive tool with a window; ADR-0036 and ADR-0028 own those choices, and each is added only when it is missed. The Settings application is also what niri's documentation names for the GlobalShortcuts portal, so that portal is untested without it (ADR-0046 G18).

The stage order, the safety conditions and the pass checks are in [ADR-0049](0049-niri-safest-staged-installation-order.md).


## GNOME dependency and replacement matrix

**Legend:** `CURRENT` = existing live app or declared PC 2 integration; `TRIAL` = candidate, not selected; `—` = no permanent choice. **P0** blocks the affected safe-session or parity gate; **P1** daily feature parity; **P2** optional polish. Links identify owning decisions; the central installation table and gap IDs belong to [ADR-0046](0046-niri-desktop-installation-decision-register.md).

### P0 — compositor, login, security and session plumbing

| Existing GNOME element / role | Non-GNOME choices (quick pros / cons) | Long-term target | Condition / owner |
|---|---|---|---|
| **GNOME Shell / Mutter** window manager, overview, panels | **Niri** scrolling tiling and IPC (selected trial target, not native minimise); Hyprland (broader effects/rules, different migration risk); KDE Plasma (full DE, more stack) | **Niri**, trial only | Already chosen for investigation; full GNOME Shell should eventually be dispensable if window close/focus/restore and P0 pass. [ADR-0012](0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0045](0045-niri-windows-like-desktop-shell-ux.md) |
| **GDM** graphical login, GNOME fallback integration | **greetd+tuigreet** (TTY, no graphical compositor dependency); **greetd+gtkgreet** (GTK interface, needs greeter compositor); **greetd+ReGreet** (richer graphical theming, requires compositor). | **greetd + tuigreet** on the GNOME-free niri install (unverified on hardware); **ReGreet** (feature-rich) and **gtkgreet** (lean) compared later, neither ranked | GDM stays on the existing GNOME system. See [ADR-0041](0041-login-greeter-gdm-greetd-tuigreet-regreet.md). |
| **GNOME Shell extensions** (Vicinae GNOME extension, AppIndicator, focus helpers) | Niri IPC and native event stream; shell taskbar/system tray; freedesktop StatusNotifier; compositor-neutral [T-0031](../../work/active/T-0031-compositor-neutral-window-actions/ticket.md) | **Not needed on the GNOME-free niri install** (the shared Home Manager profile still installs two of them there, unused, until a niri-only profile exists); the existing GNOME system keeps its required extensions | Do not remove required GNOME extension before the fallback session is retired; do not let GNOME-only pollers start under Niri. |
| **gnome-settings-daemon** settings and desktop global keys | Native Niri KDL, XKB/libinput, keyd for existing F1 remap; portal GlobalShortcuts for requesting apps | **Niri KDL + existing keyd**, application GlobalShortcuts still **—** | Separate compositor shortcuts from app-registered GlobalShortcuts; required portal may involve a small GNOME dependency. [T-0031](../../work/active/T-0031-compositor-neutral-window-actions/ticket.md) |
| **xdg-desktop-portal-gnome** ScreenCast/Screenshot provider | Niri-documented **GNOME portal** (compatible, selected PC 2 backend); `xdg-desktop-portal-gtk` (basic fallback, not a screencast replacement); KDE/wlroots provider (test feature compatibility, not equivalent by name) | **Keep GNOME portal conditionally**, not GNOME Shell | Niri upstream currently describes the GNOME portal as required for screencasting. **Do not remove** until browser/Vesktop monitor/window share, hotplug and security pass with a proven alternative. [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md). |
| **gnome-control-center** GlobalShortcuts settings dependency | Keep minimal `gnome-control-center` if required; implement/choose a tested portal alternative; skip only if no essential app depends on this interface | **—** | Niri upstream specifically lists GNOME Control Center for GlobalShortcuts. Audit request/consent/persistence with actual apps; package may remain as a narrow compatibility exception **without the GNOME session**. |
| **gnome-keyring** Secret portal and login integration | `oo7-portal` (Niri-documented Secret alternative, different keyring lifecycle); KeePassXC Secret Service (existing password database, unlock/portal considerations); KWallet (larger KDE integration) | **—**; retain GNOME Keyring in pilot | Password manager **KeePassXC** remains separate from Secret portal. Switching requires re-test of PAM, Secret portal, stored application credentials and login/unlock ordering. [ADR-0023](0023-password-managers-and-secrets-cli.md), [ADR-0041](0041-login-greeter-gdm-greetd-tuigreet-regreet.md). |
| **GNOME Shell's built-in polkit agent** (always present in the GNOME session) | **Soteria** (already enabled in PC 2), shell-owned polkit agent (integrated, risk of duplicate), `lxqt-policykit` (standalone) | **Soteria pilot**, permanent **—** | Do not start two polkit authentication agents; prompt and lock state must be tested. The pinned Soteria unit is wanted by `graphical-session.target`, so on the pilot it also starts under GNOME beside the built-in agent: scope it to the niri session and check for one agent in each session. On the GNOME-free install there is no GNOME session, so Soteria is the only agent. [ADR-0013](0013-desktop-shell-bar-notifications-trial.md), [pilot system](../../../nix/hosts/linux-desktop-pilot/system.nix). |
| **GNOME session autostart/service graph** | Native `niri-session` systemd user targets, XDG autostart, opt-in shell services; UWSM only for proven need | **niri-session** | Audit `xdg-desktop-autostart.target`, `graphical-session.target`, lingering, shell-specific process scope and dead locker recovery. [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md). |
| **GNOME screenshot and screen sharing UI** | Niri native screenshots; Flameshot existing annotation workflow; `grim+slurp+satty` alternative; GNOME+PipeWire ScreenCast portal for sharing | **—** capture; **GNOME+GTK portals for trial** | Separate capture annotations from ScreenCast portals; never treat a screenshot application as a replacement for the ScreenCast backend. [ADR-0036](0036-screenshots-media-images-and-pdf.md). |

### P1 — actual desktop features and applications

| Existing GNOME element / role | Non-GNOME options, why worth comparing | Target | Owner / test |
|---|---|---|---|
| **GNOME top bar, notifications and tray extension** | Dux / Noctalia / iNiR integrated bars (feature-rich, integrated process), Waybar + SwayNC (modular, higher glue cost) | **—**; Dux→Noctalia trials | P0 tray/history/DND, running-window buttons and single DBus notification owner. [ADR-0013](0013-desktop-shell-bar-notifications-trial.md), [ADR-0045](0045-niri-windows-like-desktop-shell-ux.md). |
| **GNOME lock screen / idle** | Shell-integrated locker (cohesive, shell crash dependence); swaylock+swayidle (independent and auditable); gtklock (GTK modular) | **—** | Verify **lock before suspend**, resume, failed shell, reconnect and emergency TTY. G03/G17/G21 in ADR-0046. |
| **Nautilus / GNOME Files** general manager | **Double Commander** (existing dual-pane power features); **Dux Files** (integrated tab/split and chooser, newer); **Dolphin** (rich, KDE framework); **Thunar** (lean); **Nemo** (traditional) | **—** preferred browser | Keep Nautilus **only if** file picker integration or functionality wins. `xdg-desktop-portal-gnome` defaults to Nautilus; set FileChooser to GTK portal before removing it. [ADR-0028](0028-files.md), [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md). |
| **GNOME portal file chooser** | GTK portal (small cross-app fallback); Dux Files portal (newer; standalone, needs no Dux Shell, though its closure includes Quickshell); KDE portal (larger dependency) | **GTK portal** on the GNOME-free install (`programs.niri.useNautilus = false`); **—** as a permanent choice | Test file upload/save-as, dialogs, sandboxing and picker focus with browsers, editor, messenger; do not guess that Double Commander replaces a portal. |
| **GNOME System Monitor / Baobab** | btop (existing TUI), QDirStat (existing disk usage), Mission Center (rich GPU graphs), bottom (TUI) | **btop/QDirStat inherited**; GUI **—** | Do not install a second GUI merely for parity; add only if a required diagnostic workflow is missing. [ADR-0037](0037-system-monitoring-diagnostics-device-software.md). |
| **GNOME Settings: displays/network/Bluetooth** | Native Niri output KDL/IPC (one owner), **Kanshi** (dynamic profiles), Noctalia/Dux controls (shell-bound), `nm-applet` and `blueman` (separate proven GUIs) | Native Niri + shell UI; automation **—** | GUI convenience should not override native display owner; mobile display profiles conditional on real usage. |
| **GNOME Settings: audio, brightness, power** | `wpctl`/WirePlumber, `pavucontrol` (fine routing), shell OSD, SwayOSD; `power-profiles-daemon` vs TLP vs TuneD (one policy) | Existing backend; graphical/power owner **—** | Test actual profiles, microphone device switching, brightness/keys, lid, suspend, battery; do not run multiple power controllers. |
| **GNOME Disks/automount/GVfs** | `udisks2+GVfs` (common file manager mounts); `udiskie` (automount/tray add-on); KDE KIO (different ecosystem) | **—** | Verify USB storage, safe eject, network mount and file chooser before installing any helper. |
| **GNOME keyboard and input** | XKB, Compose key, existing keyd; Fcitx5 for advanced IME; IBus if required | US/RU XKB baseline | Accessibility, Unicode and physical binds must work; additional input daemon conditional. |
| **GNOME default app launch and MIME integration** | The repo's existing mutable `mimeapps.list` (`nix/modules/home/default-apps.nix`, which deliberately avoids `xdg.mimeApps` so GNOME can still change defaults), `xdg-mime` for validation, desktop entries, `xdg-open` | **—** final owner | Test HTTPS, mailto, custom URIs, PDFs, folders, desktop apps across GNOME/Niri, including portal launch with correct env. |
| **GNOME Terminal / calculator / text editor / image/media tools** | Ghostty, Vicinae calculator, VS Code, Brave/Firefox and existing media apps; other alternatives only for a named missing function | **Existing apps inherited** | Prefer the established app with greater capabilities. Do not replace a GNOME-branded utility just for the brand if dependency costs are trivial and the workflow is better. |

### P2 — presentation and enhancements

| Role | Candidates and trade-off | Install decision |
|---|---|---|
| Wallpaper | Shell provider first (no extra daemon), swaybg (minimal), awww/swww (animation + service) | **—**; no animated wallpaper daemon by default |
| Night light | Shell integration, wlsunset, Gammastep | **—**; test gamma on target output |
| GTK/Qt appearance | Existing GTK defaults, nwg-look, qt6ct, Stylix, shell-managed themes | **—**; require a demonstrated inconsistency |
| Icons and cursors | Adwaita, Papirus, Bibata, Breeze | **—**; no GNOME-wide desktop requirement |
| Workspace/session restore | Niri native app state + XDG autostart, shell window rules, nirinit / niche session tools | **—**; post-trial only, avoid extra supervisor |

## New replacement candidates and safety corrections (2026-11-22)

The research shortlist now includes **[niri-screenshare](https://github.com/pantarune/niri-screenshare)**, **[xdg-desktop-portal-generic](https://github.com/lamco-admin/xdg-desktop-portal-generic)** and **[oo7](https://github.com/linux-credentials/oo7)**. Treat each as a **candidate**, not a chosen dependency or approved deletion. Niri's [current screencasting documentation](https://niri-wm.github.io/niri/Screencasting.html) still specifies the GNOME portal as its baseline, so upstream project existence alone is not proof of feature parity.

### ScreenCast portal (P0 functionality, P1 replacement experiment)

| Candidate | Verified advertised capability | Open risk / comparison requirement | Disposition |
|---|---|---|---|
| `xdg-desktop-portal-gnome` | Niri-documented window/monitor ScreenCast and **Dynamic Cast Target** | GNOME runtime closure; test existing source picker, browser/Electron/OBS, hotplug and exact pinned portal version; the GNOME portal depends on niri's own implementation of the Mutter.ScreenCast D-Bus API | **Keep for current PC 2 pilot; reference** |
| [`niri-screenshare`](https://github.com/pantarune/niri-screenshare) | Separate ScreenCast portal backend using **Niri's exposed Mutter.ScreenCast D-Bus API**, PipeWire and a GTK4 window/display picker; optional Niri dynamic-cast mode | **Runs a startup routine that edits portal preferences**; conflicts with declarative Nix/chezmoi unless explicitly suppressed/controlled; dynamic cast must be enabled and proven, and each app must be tested. GTK4/libadwaita is not GNOME Shell. Verify NixOS package/module provenance and no hidden auto-update | **First Niri-specific experiment once a reproducible package exists (it is absent from the pinned nixpkgs), NOT selected** |
| [`xdg-desktop-portal-generic`](https://github.com/lamco-admin/xdg-desktop-portal-generic) | Advertises ScreenCast v6 through `ext-image-copy-capture-v1` (fallback `wlr-screencopy`), plus RemoteDesktop/clipboard/input interfaces on supporting compositors | Newer/smaller ecosystem and protocol-dependent feature reach; **does not establish Niri's synthetic Dynamic Cast Target or matching window-picker UX**. Compare permission prompt, monitor/window capture, multiple PipeWire sessions and security, not just protocol list | **In the pinned nixpkgs, so the first alternative that can actually be run ([ADR-0049](0049-niri-safest-staged-installation-order.md) stage 15); NOT selected** |
| `xdg-desktop-portal-wlr` / KDE | Useful for particular protocol/compositor environments or other portal interfaces | Not inherently equivalent to Niri's current per-window/dynamic-cast UX; KDE increases closure | **Conditional only** |

**Critical portal distinction:** choose each portal **interface**, not one blanket default; `org.freedesktop.impl.portal.ScreenCast`, `FileChooser`, `Secret`, `GlobalShortcuts`, `Settings`, `RemoteDesktop` can have different owners. Validate the evaluated `niri-portals.conf`, actual DBus activation, and Niri-only scope after setting any preference. The portal front-end itself, `xdg-desktop-portal`, remains needed.

**Acceptance:** baseline and each candidate must be tested with Brave/Chromium, Firefox, Vesktop/Electron and OBS; monitor/window capture, cancel/deny, 2+ simultaneous streams, Niri Dynamic Cast Target, switching/blanking a stream, multi-output unplug/replug, privacy exclusions, source closing, and recovery after shell/portal restart. A missing feature does **not** mean replacing ScreenCast is P0: keeping the working GNOME portal is allowed without retaining GNOME Shell.

### Secret provider and keyring (P0 security, P1 replacement experiment)

| Candidate | Strength | Risks / checks |
|---|---|---|
| **gnome-keyring** (pilot) | Existing Secret Service, Secret portal/PAM integration | GNOME-named component, but *not* the GNOME desktop; baseline to beat |
| **`oo7-daemon` + `oo7-portal`** | Dedicated freedesktop Secret Service daemon and portal, PAM module, documented migration support | Separate Secret Service vs portal interfaces; test greetd **PAM auto-unlock** with exact Nix package paths, `HOME`/`XDG_RUNTIME_DIR`, session activation and encrypted keyring. [Reported greetd issue #516](https://github.com/linux-credentials/oo7/issues/516) is **closed**, not proof all versions/environments work. **Never allow it to silently migrate the real keyring on first test** |
| **KeePassXC Secret Service** | Can reuse existing password manager | Interactive database unlocking and credential exposure/lifecycle may differ; not an automatic Secret portal replacement |
| **KWallet** | Mature desktop keyring | KDE dependencies and PAM integration, no automatic migration compatibility |

**Do not activate two `org.freedesktop.secrets` providers.** Use disposable test data before migrating credentials. A separate test user is not isolation: the pinned `services.oo7` module starts `oo7-daemon` for every user and adds PAM to `login`, and it leaves gnome-keyring enabled and the Secret portal routed to it. Trial oo7 only on a machine or VM that holds no real keyring. Test locking, reboot/login, suspend, browser/native applications, Secret portal access and rollback. Keep KeePassXC as the separate personal password-manager selection (ADR-0023) regardless of which Secret Service wins. Do not mix the keyring migration and greetd cutover into one unreviewable change.

### Feature comparison evidence and provenance

For every GNOME replacement, record the pinned release/commit, the real module/package source, service owner, runtime dependency closure, persistence/mutation of config files, any PAM/group privilege change, current issue status, and reproducible success/failure traces. A **GNOME-free desktop UI** does not require a **GNOME-free dependency closure** when a standalone portal offers materially stronger support. Use [ADR-0046](0046-niri-desktop-installation-decision-register.md) G18/G22 and T-0032 for the tracked acceptance.

## GNOME-specific retirement gates (non-negotiable)

1. Inventory **actual dependency closure** and services of the selected Niri profile with `nix path-info -r`, `nix why-depends`, NixOS option evaluation and `systemctl --user`/journal. **No statement that GNOME is removed may be based only on a package-name grep**: GTK libs, GNOME portal and GNOME desktop are different.
2. Confirm `xdg-desktop-portal-gnome` ScreenCast, `xdg-desktop-portal-gtk` FileChooser/fallback, Secret provider, GlobalShortcuts portal, `xdg-open`, notifications and session environment **per interface and app**. Niri documentation currently calls for GNOME Portal and `gnome-control-center` for some capabilities.
3. Do not remove Nautilus while the GNOME portal still routes FileChooser to Nautilus; **either** retain Nautilus for its actual file-manager/chooser advantage **or** first prove GTK FileChooser routing and then remove it.
4. Set `XDG_CURRENT_DESKTOP=niri` through the proper session, not globally spoofed for unrelated apps. Do not globally set `GDK_BACKEND`, which Niri upstream warns can break ScreenCast.
5. Keep GDM/GNOME on the current live host until a separate approved cutover and recoverable login. A fresh niri install is not bound by this gate: it never had them. If GNOME session remains as fallback, some GNOME packages and its integration extension **necessarily remain on disk**; a "GNOME-minimal" Niri target does not require deleting the fallback prematurely.
6. Ensure VS Code, Brave/Firefox, Vesktop, KeePassXC and file dialogs, notifications, screenshot editing, multiple outputs, clipboard history and secure session recovery pass real hardware tests before disabling anything.
7. Compare substitutes on **feature coverage**, user workflow, Niri compatibility, rebuild/rollback, permissions and actual idle CPU/RSS; do not conflate package count with quality. Record which functionality is *better*, *equivalent*, *worse* or *untested* for each proposed deletion.

## Interaction with other ADRs and gaps

- [ADR-0046](0046-niri-desktop-installation-decision-register.md) remains the **installation manifest and empty-choice register**, including P0/P1/P2 new gaps G17–G28.
- [ADR-0041](0041-login-greeter-gdm-greetd-tuigreet-regreet.md) owns **login**; [ADR-0048](0048-niri-launcher-vscode-project-workflows.md) owns the **launcher**. This ADR does not change either option's implementation.
- [ADR-0013](0013-desktop-shell-bar-notifications-trial.md) and [ADR-0045](0045-niri-windows-like-desktop-shell-ux.md) own the **shell and taskbar**. GNOME-free target does not waive the trial order or handwave locker/clipboard ownership.
- [ADR-0033](0033-communication-sync-notes-and-backup.md): Kopia remains the recorded backup selection; restic/Borg are comparison candidates, **not selected replacements**. [ADR-0038](0038-disko-nixos-anywhere-fresh-hosts.md): destructive disk and encryption choices stay open.
- [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md) records **actual runtime evidence**, not hypothetical paper preferences. [T-0033](../../work/active/T-0033-refresh-stale-migration-docs/ticket.md) reconciles older GNOME/portal ownership claims.

**Outcome:** the niri install is built without the GNOME desktop; two GNOME-named services stay as proven compatibility pieces until better alternatives pass; the existing GNOME system is left as it is. **No package/service is removed or activated by this document.**
