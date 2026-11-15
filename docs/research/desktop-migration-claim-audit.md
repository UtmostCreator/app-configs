# Desktop migration claim audit (niri / KDE / Hyprland / GNOME)

> Home: `docs/research/desktop-migration-claim-audit.md`
> Status: evidence record. No code changes and no desktop migration are authorised by this file (`docs/plans/migration/overview.md:3`).
> Audit date: 2026-11-14.
> Related: `docs/research/niri-vs-hyprland.md`, `docs/plans/migration/overview.md`, `docs/plans/hyprland-migration.md`, `docs/plans/future-upgrades.md`.
> Tickets: T-0029, T-0030, T-0031, T-0032, T-0033 (index at the end).

Verdict tags used throughout: **VERIFIED** (source named), **REFUTED** (source
named), **PARTLY**, **UNVERIFIED**, plus two descriptive tags: **MISLEADING**
(literally true in part but gives a wrong impression; treated as PARTLY) and
**SCHEDULED** (announced for a future date, not yet a fact; treated as
UNVERIFIED until it happens). Repo facts carry `file:line`.

## 1. Purpose and status

This note records an audit, dated 2026-11-14, of four external reports: a
Niri-vs-KDE application regression audit, a ranked desktop options report, an
audit of that report, and a reassessment.

- The rankings in those reports are subjective. One ranked COSMIC (33) above
  river (36) with undisclosed reweighting; niri 44 vs Hyprland 43 is within
  noise. Treat all scores as opinion.
- No live niri or KDE tests have been run.
- No desktop migration is authorised (`docs/plans/migration/overview.md:3`).

## 2. Consensus conclusion

All four reports agree, and the agreement is consistent with the evidence below:

- niri is the best fit for this repo, conditional on regression testing.
- KDE is the runner-up; it is blocked mainly by Vicinae's KDE integration being
  "very brittle".
- Staying on GNOME is a legitimate option.
- System ownership (`nixosConfigurations`) must come first.
- Add any new session alongside GNOME.
- Do not bundle Noctalia or DMS into the first migration.
- Do not change the greeter during the trial.
- Keep Vicinae's existing systemd startup as the single owner.
- X11 is a poor strategic choice.

## 3. Host and pin facts

All VERIFIED by local read-only inspection on 2026-11-14.

| Item | Fact |
| --- | --- |
| Live session | GNOME Shell 50.1 under GDM, Wayland |
| Running system source | `/etc/nixos`, not this flake |
| Pinned nixpkgs | nixpkgs-unstable rev 2074cc67 (2026-11-12, 26.11) |
| Pinned versions | gnome-shell 51.0, niri 26.04, vicinae 0.29.2, vesktop 1.6.9, flameshot 15.0.0, xwayland-satellite 0.8.3 |
| Pinned home-manager | rev 82ce401 (2026-11-10) |
| nixpkgs Noctalia | `noctalia-shell` removed in favour of `noctalia` (v5) |
| GPU | Hybrid: AMD iGPU (amdgpu) drives both connected outputs (eDP-2, DP-3); NVIDIA dGPU 10de:2860 present, on nouveau |
| niri | Not installed |

## 4. Repo facts

All VERIFIED.

| ID | Fact | Source |
| --- | --- | --- |
| R1 | Flake has `homeConfigurations` {linux-desktop, linux-cli, wsl, macos} and `darwinConfigurations.macos`; no `nixosConfigurations`. | `nix/flake.nix:170-178` |
| R2 | linux-desktop home imports gui, gnome-files, gnome-extensions, gnome-keybindings, vicinae. | `nix/hosts/linux-desktop/home.nix` |
| R3 | Vicinae `systemd.autoStart` is the single startup owner. The GNOME extension is described as "backbone" and "46-50"; both are stale, see section 5. | `nix/modules/home/vicinae.nix`; `nix/modules/home/gnome-extensions.nix:28-45`; `docs/plans/future-upgrades.md:269,278` |
| R4 | GNOME-coupled helpers are inline in `gui.nix`: flameshot-area (:89), vicinae-resize (:136), vicinae-toggle-app (:181), vicinae-focus-tracker (:201), vscode-recent-projects (:228). Logic lives in `nix/modules/home/scripts/{vicinae-resize,vicinae-toggle-app,vicinae-focus-tracker}.sh`. They call `org.gnome.Shell` `/org/gnome/Shell/Extensions/Windows` (List, Activate, Minimize, GetFocusedWindowSync, MoveResize) and `org.gnome.Mutter.DisplayConfig`. The focus tracker polls every 0.25 s (`nix/modules/home/scripts/vicinae-focus-tracker.sh:9,24`) as a user service (`gui.nix:452-465`). | `nix/modules/home/gui.nix` |
| R5 | Bindings (`gnome-keybindings.nix`): Ctrl+Space vicinae toggle; Alt+V clipboard; Alt+Shift+T Ghostty; F1 Brave; Alt+Shift+R Telegram; Alt+Shift+D Vesktop; Alt+Shift+E VS Code; Alt+Shift+O Obsidian; Alt+1 KeePassXC; Super+E Nautilus; Alt+E vscode-recent-projects; Alt+Shift+F vicinae-resize 75 100; F4 and XF86LaunchB flameshot-area; Alt+Shift+S flameshot last region; Alt+P flameshot pin; Super+D show desktop. Layout switch is xkb `grp:win_space_toggle` (us,ru), not a custom binding. Cyrillic twins are generated as `<key>-cyr` only for bindings that declare `cyrillic`; Super+E Nautilus (`gnome-keybindings.nix:107-113`) has no twin. | `nix/modules/home/gnome-keybindings.nix` |
| R6 | Flameshot runs as a resident service (`gui.nix:434-448`); the flameshot-area wrapper uses flock and a 0.25 s sleep (`gui.nix:89-117`). | `nix/modules/home/gui.nix` |
| R7 | Validator rule 6 (`ops/validate-config.sh:464-514`) bans non-allowlisted `programs.<x>.enable` in NixOS modules too (`tests/bash/validate-config.bats:226-232`), so `programs.niri.enable` in `nix/modules/nixos` fails. Rule 11 (`:577-608`) is an `xdg.configFile` allowlist, so `xdg.configFile."niri/config.kdl"` fails. HM `wayland.windowManager.niri` is not covered by rule 6, but it is not a way around rule 11 either: pinned HM (82ce401) `modules/services/window-managers/niri.nix:221` itself writes `xdg.configFile."niri/config.kdl"`, and rule 13 (`ops/validate-config.sh --eval`, about `:776-860`) checks evaluated xdg keys against the same `ALLOWED_XDG_KEYS` (`:582`). Either route needs `niri/config.kdl` allowlisted. | `ops/validate-config.sh` |
| R8 | `ops/system-setup.sh` edits `/etc/nixos/configuration.nix`, writes `app-configs-extra.nix`, and runs `nixos-rebuild switch` (:50, :191, :253-311, :319). `nix/modules/nixos/default.nix` is consumed by no flake output. | `ops/system-setup.sh` |
| R9 | Migration overview: niri KDL is HM-owned, chezmoi not involved (:33-44); greeter (Ly vs greetd) is a pre-implementation decision (:46-53); GNOME stays selectable until phase 6 cutover; rollback (:125-129). | `docs/plans/migration/overview.md` |
| R10 | Stale: `hyprland-migration.md:18-20,187,241-245,332-348` and `niri-vs-hyprland.md:46,75-78` assume `hyprland.conf` / `exec-once`, HM Lua "in progress", and niri-flake `programs.niri.settings`. | see paths |
| R11 | No niri or hypr path under `home/` or `~/.config`. | repo and host read |
| R14 | mise tasks `test:bash`, `repo:validate`, `repo:check` exist; host attribute is `linux-desktop`. | `mise.toml:31,48,52` |
| R15 | Every app named in the reports is declared in the repo (no invented apps). Telegram, Vesktop and Syncthing are gated on `profile == "personal"` (`gui.nix:349`). Kanto ORA4 is configured via wireplumber `51-kanto-ora4.conf` (`gui.nix:483+`). | `nix/modules/home/gui.nix` |
| R16 | Installer snapshots home, then runs `chezmoi apply --force`. | `ops/install.sh:286-298` |

(R12 and R13 are intentionally absent; identifiers follow the audit worksheet.)

## 5. Upstream claim verdicts

| Claim | Verdict | Note and source |
| --- | --- | --- |
| niri v26.04 is 25 Apr 2026, latest tag; repo moved to github.com/niri-wm/niri | VERIFIED | github.com/niri-wm/niri/tags |
| niri has "built-in Xwayland" | MISLEADING (treated as PARTLY) | niri spawns external xwayland-satellite (>= 0.7) on demand since 25.08 and exports `DISPLAY` |
| IPC focus timestamps and `WindowFocusTimestampChanged` | VERIFIED, but since v25.11, not 26.04 | The polling focus tracker can be replaced by the event stream on niri |
| Live reload, `niri validate`, `include` (since 25.11), config-compat policy | VERIFIED | niri wiki and github.com/niri-wm/niri releases |
| Multi-monitor portal screenshot fix: commit ee8a04b exists, closes #117 on 18 Sep 2026, not in v26.04 | VERIFIED | github.com/niri-wm/niri/issues/117, github.com/niri-wm/niri/tags (no tag after v26.04) |
| Flameshot fails on two outputs with pinned niri 26.04 | PARTLY (HIGH RISK, reproduce on host) | **HIGH RISK:** reproduce before declaring Flameshot unusable. Flameshot 15.0.0 captures through the xdg-desktop-portal Screenshot API. niri's portal had no multi-monitor screenshot support until commit ee8a04b (issue #117, 18 Sep 2026), which postdates v26.04 (the latest tag), so the portal path very likely errors on two outputs. A grim/wlr-screencopy path is an untested alternative: niri implements wlr-screencopy (niri #33, closed 2024), and the Flameshot grim adapter is documented only for Hyprland (flameshot.org/docs/guide/wayland-help/). Also: v26.04 is the latest tag while the relevant fix exists only on main |
| VS Code queries X for keymap | VERIFIED (niri wiki, Application-Issues) | Mitigated by niri exporting `DISPLAY` |
| Electron `--wayland-text-input-version=3` | PARTLY | NixOS wiki only; IME only |
| nixpkgs `programs.niri`: session registration, gnome-keyring `mkDefault`, portal default [gnome gtk], Secret to gnome-keyring, `useNautilus` (default true, file chooser only) | VERIFIED | nixpkgs `nixos/modules/programs/wayland/niri.nix` |
| `defaultSession = mkDefault "niri"` | VERIFIED on nixos-unstable only (absent on 26.05) | **HIGH RISK.** This repo pins unstable, so enabling niri WOULD make niri GDM's default unless overridden. Must override |
| "Removing Nautilus breaks screen sharing" | REFUTED | xdg-desktop-portal-gnome has no nautilus dependency; Nautilus is only the default file chooser |
| Home Manager `programs.niri` | REFUTED as named | HM master has `wayland.windowManager.niri` (settings, extraConfig, checkConfig, ...); 404 on release-26.05; pinned HM (master) has it. Changes the overview's "HM owns raw KDL" mechanics (module vs `xdg.configFile`) |
| HM hyprland `configType = "lua"` | VERIFIED (release-26.05) | `extraLuaFiles` master-only; HM issue #9341 shows `settings.exec-once` generating invalid Lua |
| Vicinae compositor table: niri and Hyprland native IPC; KDE Wayland via "internal D-Bus KRunner API, very brittle"; COSMIC unsupported (planned); other Wayland via wlr-foreign-toplevel; clipboard via ext-data-control-v1 | VERIFIED | docs.vicinae.com/window, docs.vicinae.com/clipboard |
| Vicinae GNOME extension v1.8.0 (22 Oct; year inferred, date taken from the extension release notes / EGO review page) adds GNOME 51; 1.8.x supports 46-51 | VERIFIED | extensions.gnome.org/extension/8594. The "GNOME extension cliff" is not a current migration trigger. The pinned build's metadata is UNVERIFIED |
| Vicinae Hyprland docs: `exec-once` default, systemd only for UWSM | PARTLY | Vicinae docs |
| Vicinae niri global shortcuts may need ext-hotkey-v1 (unmerged in niri) | UNVERIFIED | niri `bind ... spawn "vicinae" "toggle"` is the expected workaround; must test |
| Hyprland: Lua announced 26 Apr 2026; 0.55 on 9 May 2026; 0.57 on 28 Oct 2026 removed `.conf`; 0.57.1 (3 Nov) NVIDIA black-screen fix; 0.57.2 (9 Nov); workspace sharing in 0.57 (source hypr.land/news/update57/; the release page is silent on it); Omacom exclusive sponsor announced 21 Aug 2026 | VERIFIED | hypr.land/news/update57/, github.com/hyprwm/Hyprland/releases |
| Plasma 6.8.0 on 14 Oct 2026, X11 session retired | VERIFIED | kde.org/announcements/plasma/6/6.8.0/ |
| Plasma 6.7.7 on 19 Jan 2027 | SCHEDULED (not released) | community.kde.org/Schedules/Plasma_6 |
| plasma-manager `overrideConfig` deletes KDE config on activation | VERIFIED | plasma-manager docs |
| GNOME 49 X11 | PARTLY | GDM X11 re-enabled late; shell X11 off |
| GNOME 50 Wayland-only | VERIFIED | exact 18 Mar date not confirmed |
| PaperWM #1139 (GNOME 50) fixed 21 Apr 2026; PR #1193 (GNOME 51) closed unmerged 21 Sep 2026 in favour of #1189 | VERIFIED | GNOME 51 support in flux |
| Noctalia v5 is C++/OpenGL ES, no Qt | VERIFIED (secondary) | v5.3.0 15 Oct, latest v5.5.0 12 Nov 2026; v4 was Quickshell. Docs use `spawn-at-startup` and deprecate systemd startup, which conflicts with the repo's one-owner rule |
| DMS writes KDL fragments | UNVERIFIED | |
| Vesktop issue #1375 (opened 26 Oct, closed 2 Nov 2026) | VERIFIED as an issue (github.com/Vencord/Vesktop/issues/1375); not shown to be niri-specific | Picker bug (`callback({})` to `callback(null)`, commit ba4e367). The reporter ran niri 26.04 + NixOS + portal-gnome (this host's planned stack); the maintainer said "likely fixed" by ba4e367. Fix in pinned 1.6.9: UNVERIFIED |
| JetBrains 2026.1 native Wayland default (`awt.toolkit.name=auto`, XToolkit opt-out) | VERIFIED | JetBrains release notes |
| JetBrains "CPU rendering default" | UNVERIFIED | No source found |
| JetBrains "official Vulkan flags" | UNVERIFIED | No official source found; appears to be a user workaround only. Do not add flags without a reproduced issue |
| Stylix has no niri target (issue #2544 open, PR #2479 open) | VERIFIED | niri-flake `homeModules.stylix` exists |
| "niri wiki points to maintained niri-flake fork" | UNVERIFIED | Not found on the niri wiki Nix / Integrating pages as of 2026-11-14 |
| NVIDIA `GLVidHeapReuseRatio=0` VRAM fix | VERIFIED on niri wiki | Only relevant if niri renders on the NVIDIA proprietary driver; host currently uses nouveau with AMD primary |
| COSMIC has no declarative NixOS options | PARTLY | NixOS wiki, not the manual; Epoch 1.0 date unchecked |
| Paneru / OmniWM exist and are macOS only | VERIFIED | github.com/karinushka/paneru, github.com/BarutSRB/OmniWM; out of scope for this repo's Linux migration |
| KaOS 2026.02 ships Niri 25.11 + Noctalia 4.4; reason was leaving systemd | PARTLY | |

## 6. Recommendations kept and rejected

**Keep**

- niri via nixpkgs `programs.niri` (no niri-flake initially).
- niri config HM-owned (owner mechanism per T-0030; rejects the report's "move `config.kdl` to chezmoi").
- GDM stays during the trial (defer Ly/greetd).
- GNOME stays selectable.
- Vicinae via the existing systemd unit only.
- Defer Noctalia and DMS.
- `niri validate` as a check.
- Test JetBrains native defaults first.

**Reject**

- "Nautilus is required for screen sharing".
- A global Electron `--password-store` flag without a reproduced issue.
- JetBrains Vulkan flags by default.
- macOS Paneru parity in this migration (scope creep).
- An NVIDIA profile applied unconditionally.

## 7. Effort estimates from the reports (opinion)

| Work | Estimate |
| --- | --- |
| System ownership | 1-2 days |
| niri minimal, on top of that | 3-8 days |
| Noctalia bundled, extra | +2-4 days |
| KDE | 3-8 days |
| Hyprland | 5-11 days |

Fifth review (2026-11-14): a later review agrees with the existing direction (minimal niri trial, GNOME stays default, no Noctalia). Its scores are opinion: niri 89, GNOME 84, KDE 78, Hyprland 72. Opinion effort for a minimal niri session: 4-7 days. It corrected two claims: the Flameshot wording (now PARTLY, see the screenshot-fix row) and the niri "hide" requirement (now an open design decision, T-0031). It proposed softening T-0029 as a prerequisite of T-0032; that was not adopted (niri could technically be trialled through `/etc/nixos`, but that adds another hand-edited writer, which the repo's ownership rule rejects).

## 8. Open checks (UNVERIFIED, must be resolved on the host)

- niri on hybrid AMD + NVIDIA (nouveau): does it render on AMD, and does external DP-3 work?
- Does pinned Vesktop contain commit ba4e367?
- Does Vicinae Ctrl+Space work under niri?
- What `shell-version` does the pinned Vicinae GNOME extension declare? Evidence so far: pinned `gnomeExtensions.vicinae` is EGO version 14 (`vicinaedagimg-dot.v14.shell-extension.zip`), and EGO extension-info for pk 8594 maps GNOME 46-51 to version 14. The `metadata.json` in the store was not read, so this stays UNVERIFIED.
- Behaviour of the GNOME 50.1 to 51.0 jump when the flake takes over the system.

## 9. Ticket index

| Ticket | Title |
| --- | --- |
| T-0029 | NixOS system ownership (`docs/work/active/T-0029-nixos-system-ownership/ticket.md`) |
| T-0030 | Validator: NixOS `programs.*` and niri config (`docs/work/active/T-0030-validator-nixos-programs-and-niri/ticket.md`) |
| T-0031 | Compositor-neutral window actions (`docs/work/active/T-0031-compositor-neutral-window-actions/ticket.md`) |
| T-0032 | niri trial session alongside GNOME (`docs/work/active/T-0032-niri-trial-session/ticket.md`) |
| T-0033 | Refresh stale migration docs (`docs/work/active/T-0033-refresh-stale-migration-docs/ticket.md`) |
