Source: local

# T-0032: niri trial session, without the GNOME desktop (feature; originally "alongside GNOME")

Status: in progress (pilot session config and VM test on main 450e78e, 4c57049, 6fb82ee, 57b66fe; all real-session checks remain, PC 2 install needs owner)
Niri desktop installation and component decision register: [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md). Related register gaps: G02–G05, G10–G11 and G14. This ticket's pre-activation backup and real-session gates remain mandatory; the matrix is not authorisation. Proposed stage order, with a pass check and fallback per stage: [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md).
Depends on: T-0029, T-0030
The shell comparison trial also requires P4a (activation gate, its own user approval; plan `docs/plans/niri-migration.md` section 6)
Parity sign-off also needs: T-0031 niri backend (not a prerequisite for creating the session)
Evidence: `docs/research/desktop-migration-claim-audit.md`; shell trial gates: `docs/research/niri-shell-dux-vs-noctalia.md` (user-supplied, unverified)

## Installation progress and next steps

**23 November 2026 · 40% (4 of 10 delivery milestones) · high complexity.** Each row below counts once when its stated result has evidence. This measures delivery coverage. The remaining rows vary greatly in effort. The decision register has the [individual ADR scores](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision) and [ranked software list](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md#software-installation-order). [First-boot handoff](../../../platforms/nixos/niri-first-boot-handoff.md)

| State or next priority | Milestone | Evidence or completion condition | Decisions |
| --- | --- | --- | --- |
| Complete | Build the locked host and ISO | Target and integrated home built; installer checksum verified. | [ADR-0006](../../../architecture/decisions/0006-ai-clis-claude-code-and-codex.md), [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md) |
| Complete | Install and log in on a blank VM disk | UEFI/LUKS boot, installed CLI startup, TTY and Niri login exercised. | [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| Complete | Recover a virtual installation | Rollback and offline rescue passed. Latest seven-subtest run took 403.97 s. | [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| Complete | Rehearse the first-boot handoff | Offline checkout, private log with failure status, and repeated directory creation passed fixture checks. | [ADR-0009](../../../architecture/decisions/0009-two-machines-one-history.md), [ADR-0040](../../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md), [ADR-0050](../../../architecture/decisions/0050-nixos-niri-home-layout.md) |
| 1 · P0 | Discover the destination hardware | Boot the verified USB without formatting. Record 64-bit UEFI, storage, video, keyboard and usable networking. | [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md) |
| 2 · P0 | Freeze the destination kit | Review hardware, select a clean revision and match lock, system, ISO and target-specific preparation bundle. | [ADR-0009](../../../architecture/decisions/0009-two-machines-one-history.md), [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| 3 · P0 | Install and cold-boot the Kingston | Use the isolated route, enrol the user, verify both CLIs, the checkout, folders and saved log on the installed disk. | [ADR-0006](../../../architecture/decisions/0006-ai-clis-claude-code-and-codex.md), [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md), [ADR-0050](../../../architecture/decisions/0050-nixos-niri-home-layout.md) |
| 4 · P0 | Recover on the laptop | Retain a known-good generation. Demonstrate TTY rollback, offline rescue and a subsequent disk-only boot. | [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| 5 · P1 | Accept a normal work session | Test ordinary-user Wi-Fi/DNS, lock/resume, portals and capture privacy, actual launcher search, clipboard and exact Code project. Measure bare Niri, trial the shell and run one PHP/JS project. | [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0013](../../../architecture/decisions/0013-desktop-shell-bar-notifications-trial.md), [ADR-0021](../../../architecture/decisions/0021-cross-platform-parity-and-profiles.md), [ADR-0022](../../../architecture/decisions/0022-browsers.md), [ADR-0025](../../../architecture/decisions/0025-terminal-environment.md), [ADR-0026](../../../architecture/decisions/0026-editors-and-ides.md), [ADR-0027](../../../architecture/decisions/0027-launcher-clipboard-windows-input-macos-ux.md), [ADR-0028](../../../architecture/decisions/0028-files.md), [ADR-0036](../../../architecture/decisions/0036-screenshots-media-images-and-pdf.md), [ADR-0045](../../../architecture/decisions/0045-niri-windows-like-desktop-shell-ux.md), [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md), [ADR-0048](../../../architecture/decisions/0048-niri-launcher-vscode-project-workflows.md) |
| 6 · P0 before personal data | Accept existing-home migration | Fix MIME preservation and test two activations. Restore representative project, state and vault from the intended Kopia repository to independent storage. Start the MIME fix in parallel with hardware discovery. | [ADR-0022](../../../architecture/decisions/0022-browsers.md), [ADR-0023](../../../architecture/decisions/0023-password-managers-and-secrets-cli.md), [ADR-0033](../../../architecture/decisions/0033-communication-sync-notes-and-backup.md), [ADR-0040](../../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md), [ADR-0050](../../../architecture/decisions/0050-nixos-niri-home-layout.md) |

The physical disk is the first major dependency. Use the live installer with the Kingston as the sole writable target. The daily-PC route still needs tested source-disk, mount, swap and holder guards. The next major effort is hardware-specific desktop behavior: passing a VM window-title check or connecting virtual Ethernet as root leaves launcher selection and ordinary-user Wi-Fi open. Recovery of personal data has its own gate because the successful Kopia fixture used one temporary filesystem. [External Kingston walkthrough](../../../platforms/nixos/kingston-install-walkthrough.md)

### Related ticket delivery

Each percentage covers the listed checkpoints for the named scope. Complexity reflects integration and recovery effort. T-0029's existing-PC work runs independently of the laptop.

| Ticket and scope | Priority | Complexity | Complete | Completed checkpoints | Next checks |
| --- | --- | --- | --- | --- | --- |
| [T-0029](../T-0029-nixos-system-ownership/ticket.md) System ownership | P0 laptop / independent PC work | High | 50% (2/4) | GNOME pilot built · Dedicated laptop output built | Review the destination module · Resolve the existing PC takeover separately |
| [T-0030](../T-0030-validator-nixos-programs-and-niri/ticket.md) Configuration ownership | P0 build | Medium | 100% (3/3) | Positive and negative fixture suites passed · Six evaluated user profiles passed · Disposable chezmoi render checked the KDL exclusion | Repeat these checks if the deployment revision changes the relevant modules. |
| [T-0031](../T-0031-compositor-neutral-window-actions/ticket.md) Window actions | P1 daily use | High | 50% (2/4) | Backend contract recorded · GNOME backend landed | Implement the Niri backend · Verify focus and keyboard parity on hardware |
| [T-0033](../T-0033-refresh-stale-migration-docs/ticket.md) Migration documentation | P1 maintenance | Medium | 38% (3/8) | Identify the historical in-place route · Link the dedicated runbook · Correct the account guidance | Reconcile GNOME retirement wording · Audit launcher assumptions · Audit greeter comparisons · Audit portal and chooser claims · Mark historical install instructions |
| [T-0042](../T-0042-install-selection/ticket.md) Installer selection | P0 Niri selector | Medium | 100% (3/3) | Explicit locked build tested · Conflicting selection rejected · Installed-host legacy bootstrap guard tested | The original selection ticket retains its separate real-Mac checks and extension decisions. |

Latest VM result: `a464c0dxyllg2nbhbvsqamlynpic7i5k-vm-test-run-linux-niri-install-recovery`. The installer ISO digest matched the retained development verification record. The Kingston has no physical result yet.

## Scope change (2026-11-22): the niri install has no GNOME desktop

Owner direction, recorded in ADR-0012 and ordered in [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md): install NixOS with niri and without GNOME, where that is safe. This ticket was written for niri as a second session beside GNOME and GDM. Read it as follows.

- **Still valid:** everything about the niri session itself: the KDL, portals, screen sharing, lock, shell trial gates, applications, units and the backup gate.
- **Superseded for the new install:** "Keep GDM and GNOME; no greeter change", the `defaultSession = gnome` override, the GNOME-default acceptance items, and `useNautilus` left at its default. On the new install the greeter is greetd with tuigreet, `niri` is the only session, and `programs.niri.useNautilus = false` routes the file chooser to the GTK portal.
- **Still applies to the committed pilot host** (`linux-desktop-pilot`), which enables GNOME and GDM and is to be replaced by a niri-only host: the superseded items above.
- **Fallback:** the existing GNOME system, untouched, plus the text console, the boot menu and the installer USB. There is no GNOME session to log into on the new install.
- **Where:** the laptop, which has no operating system, installed from the NixOS installer USB; commands in the [runbook](../../../platforms/nixos/niri-install.md). Installing onto a disk attached to the running PC, and adding niri to the existing GNOME system first, were compared and not chosen (ADR-0049).

New acceptance criteria for the GNOME-free install:

- [ ] The niri-only NixOS host, `linux-niri`, exists and builds; evaluated options show the GNOME desktop off, GDM off, greetd on, and `niri` as the only session.
- [ ] Its GNOME-named system packages are exactly `xdg-desktop-portal-gnome` and `gnome-keyring`; no GNOME Shell, Mutter, GDM or Nautilus is in the system closure. Check the evaluated package list and the closure, not a text search for "gnome".
- [ ] A VM test boots that host to tuigreet and into niri, as the existing test does for the GNOME pilot.
- [ ] The host declares what the GNOME module used to switch on and this install needs: Bluetooth, udisks2 with GVfs, UPower, rtkit, and power-profiles-daemon on a laptop.
- [ ] Login at tuigreet starts `niri-session`; quitting or crashing niri ends at the login prompt; a second text console still logs in.
- [ ] The keyring unlocks at the greetd login: a test secret is stored and read with no second password prompt.
- [ ] File dialogs work through the GTK portal in Brave and VS Code.
- [ ] The runbook was rehearsed once in a UEFI VM with an empty disk, through the encrypted reboot, before the laptop was touched.
- [ ] The existing GNOME system on the PC was not modified.


## Summary
Originally: add niri as a selectable session next to GNOME, with GNOME the default. Since 2026-11-22 the target is a niri install without the GNOME desktop (see "Scope change" above); the bullets below describe the committed GNOME pilot unless they concern niri itself.

- `programs.niri` via nixpkgs in `nix/modules/nixos` (no niri-flake initially).
- Committed GNOME pilot only: keep GDM and GNOME; no greeter change. (GNOME-free install: greetd with tuigreet, no GNOME; see "Scope change".)
- Explicitly set `services.displayManager.defaultSession` to GNOME's session, to beat the nixpkgs `mkDefault "niri"` (VERIFIED on nixos-unstable, which this repo pins). Check the evaluated session name before activation instead of assuming it: NixOS asserts `defaultSession` is in `sessionData.sessionNames` (pinned nixpkgs `nixos/modules/services/display-managers/default.nix:196`), so a wrong name fails evaluation.
- xwayland-satellite present (niri spawns it on demand and exports `DISPLAY`).
- Decide `useNautilus` (default true, file chooser only). Nautilus is not needed for screencast (REFUTED claim otherwise). `programs.niri.useNautilus = false` routes FileChooser to gtk (pinned nixpkgs `nixos/modules/programs/wayland/niri.nix:72`). niri #3765 is cited only for the symptom: without Nautilus, portal-gnome's file chooser fails silently.
- Keep xdg-desktop-portal-gnome.
- niri config is chezmoi-owned (`home/dot_config/niri/config.kdl`) and validated with `niri validate` (tests/bash/niri-config.bats or a pre-commit check).
- Vicinae starts via the existing systemd unit only; no `spawn-at-startup`.
- With `defaultSession` set, the GDM preStart runs set-session and ignores session history (pinned nixpkgs `nixos/modules/services/display-managers/gdm.nix:249-251`). Choosing niri at the greeter will therefore not persist across GDM restarts; this is expected during the trial.
- In this ticket (plan decision 4, user confirmed 2026-11-15): the shell comparison trial within the niri trial, Dux first, then Noctalia, gated by "Shell trial gates" below.
- Not in this ticket: the permanent shell implementation (a separate implementation ticket only after selection), the waybar fallback, greeter change.
- Essential bindings first.
- Shell comparison trial (Dux first, then Noctalia) inside this niri trial, using the "Shell trial gates" below; see plan decision 4.

## Owned files
- nix/modules/nixos/** (niri), nix/hosts/linux-desktop/system.nix
- niri config: chezmoi owns `home/dot_config/niri/config.kdl` (6fb82ee; see T-0030). The session, package and portals come from the NixOS `programs.niri` module on the pilot host. Historical alternatives (HM module, HM `xdg.configFile`, `/etc/niri/config.kdl`) were not chosen.
- Trial shell config: the Dux NixOS module settings and the Noctalia HM config (exact paths not decided; the module-versus-HM split is open plan decision 8)

## Known blockers and risks
- HIGH: pinned niri 26.04 lacks the multi-monitor portal screenshot fix (commit ee8a04b, niri issue #117, 18 Sep 2026; no later tag). PARTLY: reproduce before declaring Flameshot unusable. Flameshot 15.0.0 captures through the xdg-desktop-portal Screenshot API. niri's portal had no multi-monitor screenshot support until commit ee8a04b (issue #117, 18 Sep 2026), which postdates v26.04 (the latest tag), so the portal path very likely errors on two outputs. A grim/wlr-screencopy path is an untested alternative: niri implements wlr-screencopy (niri #33, closed 2024), and the Flameshot grim adapter is documented only for Hyprland (flameshot.org/docs/guide/wayland-help/).
- HIGH: default-session trap above.
- UNVERIFIED: niri on hybrid AMD + NVIDIA (nouveau); external DP-3.
- UNVERIFIED in a real session: the Vicinae launcher key under niri. The KDL binds Alt+Space to `spawn "vicinae" "toggle"` (ext-hotkey-v1 is unmerged in niri, so Vicinae cannot register the key itself). Alt+Space is also the GNOME binding; the earlier "Ctrl+Space" here was stale. The KDL has no bind yet for clipboard history (Alt+V under GNOME).
- UNVERIFIED: whether pinned Vesktop 1.6.9 contains the picker fix ba4e367.

## Gate priority
- P0 (release-blocking): the existing GNOME system untouched and bootable (on the committed pilot: GNOME + GDM preserved and default); user data and credentials preserved; all application packages present in both sessions; window helpers (launch/focus MRU); all shortcuts under us and ru; clipboard, screenshots, screen sharing; login, lock, suspend.
- P1 (needed for completion): audio and external displays; background services (no missing or duplicate units); MIME defaults and file dialogs; Nix/HM builds; rollback.
- A P0 failure blocks any cutover decision.

## Runtime smoke checks (in the niri session)
```bash
echo "$XDG_CURRENT_DESKTOP" "$XDG_SESSION_TYPE"
systemctl --user show-environment | grep -E 'WAYLAND_DISPLAY|DISPLAY|XDG_CURRENT_DESKTOP'   # DISPLAY matters for VS Code keymaps
systemctl --user list-units --all | grep -Ei 'vicinae|flameshot|syncthing|openclaw|codebase-memory'
wpctl status
```
These do not replace the GUI tests below.

System gate (build only): `sudo nixos-rebuild build --flake ./nix#linux-desktop`, equivalent to the NixOS toplevel build listed in the checklist.

## Acceptance criteria (regression checklist; run on the target session and mark only what ran)
- [ ] Pre-migration backup gate met (section "Mandatory backup before any live change" in docs/plans/niri-migration.md), evidence recorded. Nothing live starts, and none of the shell trial gates run, before this
- [ ] Vicinae launcher on Alt+Space and clipboard history on Alt+V, under both layouts (niri needs a clipboard bind in the KDL first)
- [ ] All application toggles launch or focus the most-recent window. Hide and restore are required only for backends that explicitly implement those capabilities. GNOME must retain its existing behaviour. (niri part requires T-0031 niri backend)
- [ ] Two VS Code windows keep MRU (requires T-0031 niri backend)
- [ ] Bilingual gate: every global accelerator in R5 of the audit works under both the us and ru layouts, tested by physical key
- [ ] Capture with the selected tool: area, last region, clipboard, pin (tested separately from screencast). Flameshot is the tool today; if it is replaced, the same capabilities are tested on the replacement (ADR-0036). The host-side reproduction of Flameshot on two outputs is mandatory before it is declared unusable
- [ ] Portal matrix, per interface, on niri and re-checked on GNOME: FileChooser, ScreenCast, Screenshot, Secret, Notification, OpenURI
- [ ] Screen sharing: monitor share, single-window share, share again after cancel, after monitor hotplug, after suspend/resume, and with mixed-scale outputs
- [ ] Committed GNOME pilot only: evaluated config has `defaultSession` equal to GNOME's session name and lists niri in `sessionNames`. GNOME-free install: `sessionNames` is exactly `niri`
- [ ] Screenshots on every monitor and scale
- [ ] Vesktop and browser window/monitor screen share
- [ ] ORA4 audio, mic, volume
- [ ] External monitor, suspend/resume, lock
- [ ] VS Code; Android Studio and emulator
- [ ] Brave, Firefox, Obsidian, KeePassXC data and credentials (keyring); KeePassXC unlock, browser integration and autofill
- [ ] Telegram and Vesktop notifications, tray, calls
- [ ] Nautilus and Double Commander file chooser, drag-and-drop and hidden files
- [ ] Bruno saved environments/secrets load; QDirStat and Czkawka file access, dialogs, scaling
- [ ] LocalSend and Syncthing
- [ ] Session-scoped units (vicinae, flameshot, vicinae-focus-tracker or its replacement) start on login and stop at logout
- [ ] Units meant to persist (syncthing, openclaw, codebase-memory, if lingering is enabled) are named as such and behave accordingly; failures are not masked with `loginctl enable-linger`. VERIFIED: niri-session runs `dbus-update-activation-environment --systemd --all` (github.com/niri-wm/niri `resources/niri-session`)
- [ ] `systemctl --user --failed` is empty
- [ ] xdg-mime defaults for https and text/x-php
- [ ] Nix and repo checks pass: `nix flake check ./nix`; activationPackage build for `homeConfigurations.linux-desktop`; `bats tests/bash`; `chezmoi diff`; `bash ops/validate-config.sh` and `--eval`; NixOS toplevel build
- [ ] Committed GNOME pilot only: GNOME still selectable and default. GNOME-free install: `niri` is the only session and the existing system still boots
- [ ] Rollback and a separate data backup verified

## Shell trial gates (run on whichever shell is under trial: Dux first, Noctalia second)
These G1 to G11 are local to this ticket. ADR-0046's gaps are written with two digits (G01 to G28) and are a different list.
Depends on the pre-migration backup gate in the acceptance list above. Source: `docs/research/niri-shell-dux-vs-noctalia.md` (user-supplied audit, upstream issue states unverified). These apply during the shell comparison trial (in scope per plan decision 4, user confirmed 2026-11-15), not to creating the niri session itself. The existing "External monitor, suspend/resume, lock" and "Flameshot" items above are extended by these, not replaced. Use the repo's KDL binds only, with exactly one owner each for notifications, clipboard, lock/idle and polkit.
- [ ] G1: Lock, then disconnect and reconnect an external monitor N = 10 times while locked; record shell RSS before and after; fail if RSS grows more than 200 MiB in total or keeps growing (Dux #4259)
- [ ] G2: Lock, suspend, unplug an output, resume: the session unlocks without re-login (Noctalia #5349)
- [ ] G3: Notification flood while locked, then unlock: no crash (Noctalia #2836 regression)
- [ ] G4: Polkit: exactly one agent is running and an auth prompt appears (Noctalia `polkit_agent` defaults to false; #4565)
- [ ] G5: The shell UI renders on this GPU setup (Noctalia #4714); N/A if not hybrid NVIDIA with the proprietary driver (host currently AMD iGPU + NVIDIA dGPU on nouveau)
- [ ] G6: capture and pin with the selected capture tool both work under the shell (reported against Flameshot, Noctalia #1325)
- [ ] G7: The shell's IPC works on NixOS/niri (Dux #1153): the shell's documented IPC command responds (for example `dms ipc ...` or `noctalia msg ...`; exact command not confirmed here)
- [ ] G8: U2F unlock works, only if a security key is used (Dux #2789)
- [ ] G9: Notifications have one owner: exactly one `org.freedesktop.Notifications` owner (for example `busctl --user status org.freedesktop.Notifications`)
- [ ] G10: Clipboard history has one owner: the shell's clipboard history is disabled and Vicinae's is active
- [ ] G11: Lock/idle has one owner: exactly one idle controller and exactly one locker run. swayidle with swaylock is one such pair; the shell's own idle or lock service must not run beside it

NixOS generations are not data backups; back up mutable `$HOME` data and secrets separately.

## Additional migration comparison / recovery acceptance (2026-11-22)

The [master register ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md) now tracks gaps G17–G26. [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md) audits GNOME-specific dependencies, [ADR-0048](../../../architecture/decisions/0048-niri-launcher-vscode-project-workflows.md) compares Vicinae and alternatives, and [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md) compares future tuigreet and gtkgreet. **These do not authorise any greeter switch, shell installation or GNOME removal.**

- [ ] **G17 P0 — Emergency rescue:** demonstrate TTY login with failed shell, dead locker, broken output and keyboard shortcut inhibition; recover without an unrecoverable screen lock, lost project or reinstall. Confirm no one assumes a shell UI remains available after it crashes.
- [ ] **G02/G18 P0 conditional — Session/provider routing:** inspect `xdg-desktop-autostart.target`, `graphical-session.target`, session-scoped app services and DBus owners. Verify GlobalShortcuts portal request/consent and Secret unlock/Keyring as separate interfaces; test the `gnome-control-center` dependency when relevant. Exactly one active owner for polkit, notification, clipboard-history and locker/idle.
- [ ] **G19 P1 — App activation:** URLs, mailto, VS Code custom URI, `xdg-open` to folder/PDF, desktop entries, save/upload dialogs; a browser/file-manager icon should focus its existing window instead of starting duplicates.
- [ ] **G20 P1 — Input:** US/Russian physical shortcuts, Compose/Unicode where needed, keyboard-only shell accessibility, text field input and Ctrl/Alt+Tab switching; advanced IME only if required.
- [ ] **G21 P0 on portable host — Suspend:** lock-before-suspend ordering, lid-close behaviour, resume prompts with external monitor unplugged, no unlocked desktop flash, no competing power policy managers.
- [ ] **G22 P0 for GNOME retirement — Dependency audit:** separately record GNOME Shell, GDM/fallback, GNOME portal (ScreenCast), GTK portal (FileChooser), `gnome-control-center` (GlobalShortcuts), gnome-keyring/oo7 (Secret), Nautilus and GNOME-only user services. Remove none without feature-equivalent tests.
- [ ] **G23 P1/P0 when required — Launcher:** compare Vicinae with Walker, Albert, Ulauncher, Rofi and shell launcher, preserve exact VS Code recent folders/`.code-workspace` and focus the correct existing Code window. No dual launcher keyboard binding.
- [ ] **G24 P1 — Core service and removable devices:** PipeWire/WirePlumber microphone/audio device routing, BlueZ/Bluetooth, NetworkManager/VPN, UPower, USB mount/unmount and GVfs file operations; add no duplicate services.
- [ ] **G25 P1 — Nix recovery:** record selected `flake.lock`, previous-generation boot, retention/GC policy, backup restore and optional `nh`/nvd evaluation without another system configuration writer.
- [ ] **G26 P1/P0 if sensitive sharing — Capture privacy:** Niri native capture vs Flameshot/Satty, per-window ScreenCast, KeePassXC/sensitive window exclusion, two monitors and post-hotplug share; observe capture output on a receiving client.

Do not make a new tool mandatory merely because it is listed as a candidate. These scenarios **extend**, not replace, existing G1–G11 shell gates and the mandatory backup/user-approval requirements.

## Portal and secret-provider alternative trials (2026-11-22)

New upstream candidates are **documentation-only until separately approved in PC 2**. See [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md), [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md), [ADR-0023](../../../architecture/decisions/0023-password-managers-and-secrets-cli.md). Required functions are P0; **removing their working GNOME implementation is P1** unless the replacement itself becomes necessary to meet a documented P0 requirement.

- [ ] **ScreenCast baseline**: record pinned `xdg-desktop-portal-gnome` + `xdg-desktop-portal-gtk` + PipeWire versions and `niri-portals.conf`/Nix module ownership; test Brave, Firefox, Vesktop and OBS window/monitor picker, denial, multi-stream, reconnect and **Dynamic Cast Target**. Record actual live capture, not just a functioning picker.
- [ ] **niri-screenshare trial**: verify NixOS package/module or pinned source build, GTK picker, Niri-specific Mutter.ScreenCast IPC, PipeWire nodes and explicit dynamic-cast option. **Test its documented first-start portal preference write in a disposable user HOME**; refuse if it mutates `portals.conf` controlled by Home Manager/chezmoi without an approved override. Compare each capture scenario against baseline.
- [ ] **xdg-desktop-portal-generic trial**: verify `ext-image-copy-capture` / `wlr-screencopy` protocol compatibility with pinned Niri, consent UI, window/monitor sources and Niri dynamic target (not assumed supported); test `RemoteDesktop`/clipboard interfaces separately if needed, do not blanket-switch the portal default.
- [ ] **oo7 Secret trial**: use a machine or VM with no real keyring and a fake one (a test user is not isolation: the pinned `services.oo7` module applies to every user and to PAM `login`, and leaves gnome-keyring on), then test `oo7-daemon` and `oo7-portal` interfaces separately, greetd PAM unlock after reboot, `HOME`/`XDG_RUNTIME_DIR`, authentication and SecretService DBus owners. Upstream greetd issue #516 is **closed** but still requires pinned-version reproduction; do **not** import the real GNOME Keyring or KeePassXC secrets during comparison.
- [ ] **FileChooser alternative**: compare GTK FileChooser and **standalone Dux Files** FileChooser after testing file-manager functions. Test Niri focus, keyboard navigation, window parenting, modal state, upload/save-as and cold-start. **Dux Files documents that its chooser currently does not attach to the calling application and ignores modal**. Do not invoke commands that rewrite the active portal preference from an unmanaged installer.
- [ ] **Launcher**: compare **Vicinae** versus **Walker + Elephant**, then Ulauncher/Albert/Rofi. Test exact VS Code `.code-workspace` and directory history, Niri existing-window focus, clipboard images/history, provider restarts and total resident processes; do not activate two global hotkeys simultaneously.
- [ ] **Future login (separate gate)**: after safe cutover planning, test `tuigreet` and ReGreet/gtkgreet using the actual TTY/GPU/PAM/lock scenarios in ADR-0041. This does **not** belong in the current shell activation and does not authorise replacing GDM.

## Installation-order checks from ADR-0049 (2026-11-22)

These are the pass checks of [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) (proposed) that this list did not have. They add to the criteria above and authorise nothing.

- [ ] **Install preflight (stage 2):** the generated `hardware-configuration.nix` is a module of the pilot host beside `system.nix` (not imported by it, so the VM test keeps booting), committed, with the placeholder `fileSystems` entries gone; the checkout lives on the installed disk; `pilot-vm-test` and `tests/bash/nixos-pilot.bats` pass with that change; that configuration builds before `nixos-install`; the user's password is set before the first reboot.
- [ ] **Two generations (stage 3):** `nixos-rebuild list-generations` shows two entries on PC 2 and each has been booted once. Rebuilding an unchanged configuration creates no generation.
- [ ] **User environment (stage 3b):** Home Manager and chezmoi are activated on PC 2, not only built: `command -v ghostty vicinae niri` resolve, the niri config is deployed and `niri validate` passes.
- [ ] **Rescue (stage 4):** the installer USB sequence (unlock, mount root and ESP, `nixos-enter`, restore the boot default) has been run once in full; key-only SSH works and password and root logins are refused.
- [ ] **Bound commands (stage 5):** every command a KDL bind calls resolves on the session `PATH` (`brightnessctl` and `playerctl` are bound but not declared today).
- [ ] **Lock lifecycle (stage 6):** the bind, the idle timeout, `loginctl lock-session`, `systemctl suspend` and the lid each lock; a killed locker leaves the session locked and a new locker restores the prompt.
- [ ] **Locked quit (stages 5 and 6):** quitting niri, locked or not, ends at an authenticated greeter, never at a logged-in console. Repeat if the greeter changes.
- [ ] **One polkit agent per session:** on the GNOME-free install Soteria is the only agent. Committed GNOME pilot only: under GNOME, `pkexec true` raises one prompt. The pinned Soteria unit starts on `graphical-session.target` and so also under GNOME, beside GNOME Shell's own agent, until it is bound to the niri session.
- [ ] **Pilot profile (stage 3b):** PC 2's first activation uses `bash ops/install.sh --profile work`; `syncthing.service` and `openclaw-gateway.service` do not exist there. The personal profile is a later, separate step.
- [ ] **Launcher binds (stage 9):** the niri KDL has binds for clipboard history and the recent-projects picker (GNOME has Alt+V and Alt+E; the KDL has only Alt+Space today).
- [ ] **Capture privacy (G26):** the KDL's KeePassXC `block-out-from "screen-capture"` rule is enabled (it is switched off with `/-` today) and checked on a receiving client.
- [ ] **Unit audit (stage 10):** user units and XDG autostart entries started in the niri session are listed and marked GNOME-only, niri-only or both, before a shell is activated.

## Out of scope
Cutover to niri as default: a separate later decision, only after 2-4 weeks of daily use with no blockers.

Exit path: if niri fails on GPU/display or screen sharing, keep working on the existing GNOME system. KDE Plasma 6.8 (Vicinae's KDE integration is "very brittle") is evaluated only if there is a separate reason to leave GNOME. That is a later user decision, not part of this ticket.

## Progress
- 2026-11-21 documentation audit (applied above): this ticket said the niri config is Home Manager-owned, `docs/plans/niri-migration.md` recommends Home Manager `xdg.configFile` and `docs/plans/niri-two-pc-pilot.md` proposes `/etc/niri/config.kdl`, while the implementation is chezmoi (6fb82ee). Record chezmoi as current, keep the others as historical alternatives, and decide package, session, portal and user-service ownership separately.
