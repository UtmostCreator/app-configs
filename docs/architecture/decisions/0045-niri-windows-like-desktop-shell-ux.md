---
adr: 45
title: "Niri desktop UX: evaluate Windows-like iNiR Waffle alongside the existing shell trial"
status: proposed
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, shell, taskbar, window-management, user-experience]
permits: [inir-waffle-research, windows-like-ux-comparison]
forbids: [unapproved-live-shell-change, duplicate-desktop-service-owners, unreviewed-shell-autostart]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 27, 28, T-0032]
---
# ADR-0045: Niri desktop UX: evaluate Windows-like iNiR Waffle alongside the existing shell trial
Status: proposed (evaluation scope only; no package or session change authorised) · Date: 2026-11-22 · Sources: ADR-0012, ADR-0013, T-0032; upstream iNiR, Dux and Noctalia documentation linked below.

## Context
The desired Niri desktop should feel as immediately usable as Windows 11, especially for a bottom taskbar, pinned and running applications, window switching, tray, notifications, multi-monitor use and quick settings. Advanced workflow matters more than copying Windows decoration.

Niri is the scrolling-tiling **compositor/window manager**; a desktop shell supplies the taskbar, Start-like menu, notifications and settings. Replacing the shell does not replace Niri.

Existing decisions remain authoritative:
- [ADR-0012](0012-desktop-compositor-gnome-niri-hyprland.md): GNOME and GDM remain the live default; Niri is an optional pilot session, not an approved migration.
- [ADR-0013](0013-desktop-shell-bar-notifications-trial.md): trial Dux first, Noctalia second; no shell selected; Vicinae owns keyboard launcher and clipboard; one owner per desktop service.
- [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md): pilot, backup, session and regression gates apply before any real shell trial.

## Decision (proposed)
1. **Add iNiR with its Waffle panel family to the research shortlist** as the closest Windows 11-style candidate. Waffle documents a bottom taskbar, pinned/open apps, a Start menu, Action Center, Notification Center and Task View.
2. **Do not change the existing Dux → Noctalia trial order** on the strength of screenshots or documentation. An iNiR/Waffle trial is an *additional, separately approved* pilot comparison, only if the Windows-style UX requirement remains insufficiently satisfied. No permanent shell is selected here.
3. Evaluate actual **behaviour**, not visual resemblance: selecting a running window rather than launching duplicates, multiple windows of one application, window focus across Niri workspaces, taskbar grouping/pinning, external monitors, keyboard switching and restoration after suspend.
4. Keep **Vicinae** as the primary keyboard launcher and clipboard history. A clickable Waffle Start menu can be evaluated as a Windows-style surface, but enabling its keyboard launcher or clipboard shortcuts would conflict with ADR-0013 and requires an explicit amendment before adoption. Keep Niri's native recent-window switcher as the baseline.
5. Exactly **one running shell**, one notification provider, one lock/idle owner, one polkit agent and one clipboard-history owner per session. Do not allow a shell's systemd units or helpers to run in GNOME.
6. NixOS integration must be **declarative and reversible**. Do not run the upstream generic `./setup install` or let it replace the greeter, compositor configuration or system services. Keep `home/dot_config/niri/config.kdl` owned by chezmoi. Do not let an installer, `inir bind --add` or a module silently take over this file.

## Candidates

| Candidate | Main advantage | Main concern | Standing |
|---|---|---|---|
| [iNiR / Waffle](https://github.com/snowarch/iNiR) | Explicit Windows 11-style taskbar, Start, Action Center and Task View | NixOS support is marked experimental; runtime Hub-managed families/themes/widgets complicate reproducibility; default launcher overlaps Vicinae | Additional proposed candidate |
| [Dux Modular Shell](https://github.com/duxlabs-dev/dux-shell) | Broad Niri integration, plugin ecosystem and shell utilities | Existing ADR-0013 notes module/ownership and IPC risks to validate | First existing trial |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | Integrated, configurable Wayland shell with Niri support | Existing ADR-0013 records config ownership and lock/polkit risks to validate | Second existing trial |
| Waybar + SwayNC + swaylock + swayidle | Small, independently owned components; flexible bar | More configuration and upkeep; Windows-like UI must be assembled | Existing fallback |

Do not treat features listed in upstream documentation as having passed on this machine. Do not infer measured performance, maintainability or reliability rankings from screenshots.

## NixOS-specific safety review
Upstream [iNiR NixOS guidance](https://inir.space/docs/nixos/) documents a flake, NixOS module and Home Manager module. It also states:
- `programs.inir.desktop.enable` configures desktop services and a display manager. **Keep it false** on the pilot; Niri, GNOME and GDM already have owners.
- `programs.inir.niriConfig.seed` may create Niri configuration if absent. **Disable seeding** to protect the existing chezmoi-owned configuration.
- The NixOS module can enrol users in `video`, `input`, `i2c` and `ydotool` groups. Review actual necessity and permissions before choosing module ownership. Prefer the least-privileged integration.
- The base runtime follows the pinned Nix flake input, but Waffle and other families, themes and widgets are fetched via the Hub at first start and updated separately. Determine how to pin or vendor required Hub items, or record an explicitly accepted reproducibility exception. An offline baseline that cannot load is not acceptable for cutover.
- A user service and mutable `~/.config/quickshell/inir` runtime are involved. Audit actual unit conditions, generated files, autostart hooks and update behaviour; prohibit unreviewed writes to managed configuration.

Prefer an opt-in NixOS/Home Manager integration on **PC 2 only**, after verifying ownership and version/flake-lock compatibility. Preserve the GNOME login path and rollback. Nothing here authorises activation.

## Evaluation rubric (100 points; score only from a real pilot)

| Criterion | Weight | Evidence required |
|---|---:|---|
| Windows-like workflow | 25 | Taskbar click-to-focus, pin/unpin, running indicators, multi-window groups, task view and tray |
| Reliability | 25 | Login, lock/suspend/resume, hotplug, notifications, clipboard, polkit and no duplicate services |
| Niri and application integration | 20 | Multi-workspace and multi-monitor focus; Vicinae; VS Code; browser, Telegram/Vesktop and file dialogs |
| Declarativity and security | 20 | Nix pinning, no unexpected file edits, Hub handling, minimal permissions, rollback |
| Responsiveness and overhead | 10 | Measured cold/warm startup, shell RSS, CPU at idle and while switching windows; same host and workload |

Benchmark: `80/100` is a **proposed acceptance threshold**, not an existing measurement. **Any T-0032 P0 failure disqualifies the candidate regardless of its score.** Compare results on the same Niri build, hardware and session profile; record commands, versions and failure reproductions. A candidate must deliver a meaningful UX improvement, not merely a higher subjective appearance rating.

## Acceptance criteria for an *approved* iNiR trial
- [ ] Record an owner decision to extend ADR-0013's comparison; do not silently replace its two-candidate order.
- [ ] Satisfy T-0032's backup and pilot activation gates before touching a live session.
- [ ] Pin the iNiR flake/ref and identify all runtime Hub dependencies, mutable state and group additions; confirm a reversible installation plan.
- [ ] `nix flake check ./nix`, relevant NixOS/Home Manager builds, config validator and ADR contract tests pass before activation.
- [ ] GNOME/GDM still work unchanged; shell services only run in Niri; exactly one owner of notifications, lock/idle, clipboard history and polkit.
- [ ] Verify Waffle's taskbar pinning, running app focus, multiple windows, Task View, tray, Start-menu click and Action Center on one and two monitors.
- [ ] Verify Alt+Tab, Vicinae Ctrl+Space/Alt+V, and existing US/Russian bindings with no shortcut collision.
- [ ] Run T-0032's screenshots, portal, file chooser, screen sharing, suspend, hotplug, app and rollback checks, including relevant shell-specific gates.
- [ ] Measure startup, CPU and RSS with reproducible steps; record failures and score all candidates against the same rubric.
- [ ] If selected later, amend ADR-0013, decide precisely which Waffle launcher features may coexist with Vicinae, and create a separate implementation ticket.

## Consequences and unresolved decisions
- Documentation-only decision proposal. No package, Nix option, keybinding, user service, default session or taskbar is changed.
- iNiR/Waffle is the **best match to the Windows-like visual/layout requirement on documented features**, not yet a verified overall winner.
- Dux and Noctalia remain the committed first and second pilot trials until the owner explicitly revises ADR-0013.
- Open: approve the additional iNiR trial; accept or prohibit runtime Hub-managed files; define whether Waffle's clickable Start menu may coexist with Vicinae without duplicating launcher ownership.
