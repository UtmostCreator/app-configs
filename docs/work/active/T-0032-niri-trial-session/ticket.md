Source: local

# T-0032: niri trial session alongside GNOME (feature)

Status: in progress (pilot session config and VM test on main 450e78e, 4c57049, 6fb82ee, 57b66fe; all real-session checks remain, PC 2 install needs owner)
Depends on: T-0029, T-0030
The shell comparison trial also requires P4a (activation gate, its own user approval; plan `docs/plans/niri-migration.md` section 6)
Parity sign-off also needs: T-0031 niri backend (not a prerequisite for creating the session)
Evidence: `docs/research/desktop-migration-claim-audit.md`; shell trial gates: `docs/research/niri-shell-dux-vs-noctalia.md` (user-supplied, unverified)

## Summary
Add niri as a selectable session next to GNOME. GNOME stays the default.

- `programs.niri` via nixpkgs in `nix/modules/nixos` (no niri-flake initially).
- Keep GDM and GNOME; no greeter change.
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
- UNVERIFIED: Vicinae Ctrl+Space under niri (may need `bind ... spawn "vicinae" "toggle"`; ext-hotkey-v1 is unmerged in niri).
- UNVERIFIED: whether pinned Vesktop 1.6.9 contains the picker fix ba4e367.

## Gate priority
- P0 (release-blocking): GNOME + GDM preserved and default; user data and credentials preserved; all application packages present in both sessions; window helpers (launch/focus MRU); all shortcuts under us and ru; clipboard, screenshots, screen sharing; login, lock, suspend.
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
- [ ] Vicinae Ctrl+Space and Alt+V
- [ ] All application toggles launch or focus the most-recent window. Hide and restore are required only for backends that explicitly implement those capabilities. GNOME must retain its existing behaviour. (niri part requires T-0031 niri backend)
- [ ] Two VS Code windows keep MRU (requires T-0031 niri backend)
- [ ] Bilingual gate: every global accelerator in R5 of the audit works under both the us and ru layouts, tested by physical key
- [ ] Flameshot area, last region, clipboard, pin (tested separately from screencast); the host-side reproduction on two outputs is mandatory
- [ ] Portal matrix, per interface, on niri and re-checked on GNOME: FileChooser, ScreenCast, Screenshot, Secret, Notification, OpenURI
- [ ] Screen sharing: monitor share, single-window share, share again after cancel, after monitor hotplug, after suspend/resume, and with mixed-scale outputs
- [ ] Evaluated config has `defaultSession` equal to GNOME's session name and lists niri in `sessionNames`
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
- [ ] GNOME still selectable and default
- [ ] Rollback and a separate data backup verified

## Shell trial gates (run on whichever shell is under trial: Dux first, Noctalia second)
Depends on the pre-migration backup gate in the acceptance list above. Source: `docs/research/niri-shell-dux-vs-noctalia.md` (user-supplied audit, upstream issue states unverified). These apply during the shell comparison trial (in scope per plan decision 4, user confirmed 2026-11-15), not to creating the niri session itself. The existing "External monitor, suspend/resume, lock" and "Flameshot" items above are extended by these, not replaced. Use the repo's KDL binds only, with exactly one owner each for notifications, clipboard, lock/idle and polkit.
- [ ] G1: Lock, then disconnect and reconnect an external monitor N = 10 times while locked; record shell RSS before and after; fail if RSS grows more than 200 MiB in total or keeps growing (Dux #4259)
- [ ] G2: Lock, suspend, unplug an output, resume: the session unlocks without re-login (Noctalia #5349)
- [ ] G3: Notification flood while locked, then unlock: no crash (Noctalia #2836 regression)
- [ ] G4: Polkit: exactly one agent is running and an auth prompt appears (Noctalia `polkit_agent` defaults to false; #4565)
- [ ] G5: The shell UI renders on this GPU setup (Noctalia #4714); N/A if not hybrid NVIDIA with the proprietary driver (host currently AMD iGPU + NVIDIA dGPU on nouveau)
- [ ] G6: Flameshot capture and pin both work under the shell (Noctalia #1325)
- [ ] G7: The shell's IPC works on NixOS/niri (Dux #1153): the shell's documented IPC command responds (for example `dms ipc ...` or `noctalia msg ...`; exact command not confirmed here)
- [ ] G8: U2F unlock works, only if a security key is used (Dux #2789)
- [ ] G9: Notifications have one owner: exactly one `org.freedesktop.Notifications` owner (for example `busctl --user status org.freedesktop.Notifications`)
- [ ] G10: Clipboard history has one owner: the shell's clipboard history is disabled and Vicinae's is active
- [ ] G11: Lock/idle has one owner: exactly one idle or lock daemon runs (swayidle, swaylock and the shell's own must not overlap)

NixOS generations are not data backups; back up mutable `$HOME` data and secrets separately.

## Out of scope
Cutover to niri as default: a separate later decision, only after 2-4 weeks of daily use with no blockers.

Exit path: if niri fails on GPU/display or screen sharing, stay on GNOME first. KDE Plasma 6.8 (Vicinae's KDE integration is "very brittle") is evaluated only if there is a separate reason to leave GNOME. That is a later user decision, not part of this ticket.

## Progress
- 2026-11-21 documentation audit (applied above): this ticket said the niri config is Home Manager-owned, `docs/plans/niri-migration.md` recommends Home Manager `xdg.configFile` and `docs/plans/niri-two-pc-pilot.md` proposes `/etc/niri/config.kdl`, while the implementation is chezmoi (6fb82ee). Record chezmoi as current, keep the others as historical alternatives, and decide package, session, portal and user-service ownership separately.
