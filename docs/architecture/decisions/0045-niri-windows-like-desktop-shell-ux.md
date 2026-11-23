---
adr: 45
title: "Niri desktop shell: taskbar, dock, window controls, features and ecosystem"
status: proposed
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, shell, taskbar, window-management, user-experience]
permits: [inir-waffle-research, feature-first-shell-comparison, workflow-evaluation]
forbids: [unapproved-live-shell-change, duplicate-desktop-service-owners, unreviewed-shell-autostart]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 27, 28, 46, 47, 48, 49, T-0031, T-0032]
---
# ADR-0045: Niri desktop shell: taskbar, dock, window controls, features and ecosystem
Status: proposed (comparison and acceptance criteria only; no permanent shell selected or live activation authorised) · Date: 2026-11-22 · Sources: ADR-0012, ADR-0013, T-0031/T-0032 and upstream links in References.

**Laptop delivery · 23 November 2026 · 25% (1/4) · P1 · high complexity.** Workflow criteria defined. Exercise window and task switching, then measure hotplug, lock and resume, then record a shell decision from the results. Actual interactions and mandatory privacy checks govern selection. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

## Problem and goals

The objective is a **more capable desktop than stock GNOME or the default macOS desktop**, not a Windows 11 visual clone. The user likes macOS-style hide/show and a persistent set of frequently used apps, but also wants **direct, visible control over running windows**. The default GNOME experience does not provide the desired bottom task manager and easy mouse-driven closure of individual running windows.

Order of preference:
1. A **reliable, usable taskbar or dock**, preferably along the bottom: pinned favourites alongside running applications, clear focused/running state, click-to-focus and fast switching. A dock on another edge, a split bar/dock or an Island is acceptable **if it is demonstrably more useful**, not merely prettier.
2. **Close, hide/show, restore and multi-window management** must be distinct, discoverable actions. One click must not silently open a duplicate app instead of focusing it. Close an individual running window from the taskbar/dock (e.g., middle-click or context menu) without killing the process or closing unrelated windows. Support explicit **close all windows for an app** if the shell offers it; never conflate it with closing one.
3. Handle multiple VS Code windows, browsers, terminals, chat applications, Niri scrolling workspaces and multiple outputs correctly. A panel's visibility alone is not window management.
4. Offer substantial additional capability—good settings, notifications/DND, quick controls, widgets, IPC, automation or plugins—**without losing reliability, rollback or declarative ownership**.
5. Prefer a sustainable upstream community, current documentation, compatible releases and low-maintenance NixOS integration. Appearance and resemblance to a particular operating system are secondary.

### Important compositor limitation

**Niri has no traditional native hide/minimise operation.** Dux documents a scratchpad workspace that parks windows; iNiR documents an `inir minimize` service that moves them to a hidden workspace. **These are workarounds, not equivalent to native minimisation.** For Dux, Niri's own overview, Alt+Tab and direct workspace navigation can still reach parked windows. Verify restoration, taskbar indicators, focus order, workspace placement and state after shell restart. Noctalia's documented minimisation on *other* compositors is **not evidence** that it works under Niri. Closing a window, minimising/parking it, hiding the dock itself and switching workspaces are four different actions.

## Existing decisions and scope
- [ADR-0012](0012-desktop-compositor-gnome-niri-hyprland.md): GNOME and GDM stay on the existing system; the niri install carries no GNOME desktop (owner direction 2026-11-22). This ADR cannot authorise cutover.
- [ADR-0013](0013-desktop-shell-bar-notifications-trial.md): Dux first, Noctalia second in a real Niri session; Waybar stack fallback; no selected shell. This is **not superseded**.
- [T-0031](../../work/active/T-0031-compositor-neutral-window-actions/ticket.md): compositor-neutral app/window actions and focus semantics.
- [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md): pre-migration backup, Nix build, pilot and live regression gates. These are mandatory before any additional shell trial.
- Vicinae remains the keyboard launcher/clipboard-history baseline; exactly one notification, polkit, idle/lock and clipboard-history owner per session. Shell launchers and graphical app menus can be compared, but their conflicting keyboard bindings must stay disabled unless ADR-0013 is explicitly changed.
- The repo's `home/dot_config/niri/config.kdl` is **chezmoi-owned**; NixOS owns the compositor session and portals. No shell installer may overwrite that contract.

## Proposed decision

Compare **four approaches** on actual Niri behaviour and their useful extra features, not OS likeness:

1. **Dux Modular Shell**: first in the already-approved *trial order* (not yet a selected solution). Evaluate its multi-edge OmegaDock/taskbar, window search, Niri scratchpads and CLI/IPC. Its ability to park and restore windows is a particularly strong fit for the hide/show requirement.
2. **Noctalia v5**: second in the existing order. Evaluate its configurable taskbar and optional auto-hiding dock, pinned apps, per-monitor profiles, native Wayland runtime, and exact Niri focus/close/instance cycling. Determine separately whether an acceptable hide/show workflow is possible on Niri.
3. **iNiR**: add as a **proposed additional trial**, requiring an owner decision before activation. Compare all relevant panel families, not only **Waffle** (bottom taskbar/Start/Action Center); **Material** supports different bar positions, and **iRiS** offers an Island on any edge plus a dock. iNiR documents Niri-aware window previews, app cycling, `minimize`/restore IPC and a Hub, all worth testing. Its Waffle look is a benefit, **not a selection criterion**.
4. **Waybar + SwayNC + swaylock + swayidle**, with Vicinae and **[niri_window_buttons](https://github.com/adelmonte/niri_window_buttons)** or another Niri-specific taskbar module when needed: compare as a credible **composable baseline**, not a feature-complete shell out of the box. Its taskbar module may supply better explicit per-window actions than a more attractive shell; its integration/maintenance costs must also count.

**Do not change ADR-0013's Dux → Noctalia order**, begin a new shell trial, or migrate from GNOME based on this proposal. The first pilot should test window controls and the bottom-dock/taskbar workflow before deep theming.

## Candidate trade-offs: pros, cons and best reasons to choose

### Dux Modular Shell
[GitHub](https://github.com/duxlabs-dev/dux-shell) · [Niri scratchpad/IPC](https://duxlabs.dev/docs/2.2/dms/keybinds-ipc) · [OmegaDock](https://duxlabs.dev/blog/v2-0-release)

**Pros**
- Multi-instance **OmegaDock** can appear on any edge as an icon dock or full-width taskbar; can host tray, workspace, media and plugin widgets beside pinned/running apps. Better flexibility than copying either Windows or macOS.
- **Niri-specific scratchpads** provide a documented hide/show approach, and clicking a parked window in the dock, taskbar or launcher brings it back to the current workspace.
- Strong developer-oriented feature reach: searchable running windows/files/commands; configurable window rules, IPC/CLI, plugins, control centre, notifications, lock/idle and widgets. A plugin lockfile can improve repeatability when verified.
- Supports several compositors: switching from Niri later may preserve more of the shell configuration. Dux Labs also maintains companion projects such as Dux Files and an official/community plugin registry.
- Particularly promising for a **power-user environment** with scripts and integrations instead of a basic fixed dock.

**Cons / risks**
- Integrated Quickshell/QML + Go stack and plugins enlarge the runtime and update surface. Rich features can introduce overlapping launcher, clipboard, lock and notification services.
- Scratchpad hiding is **not native minimisation**: Niri overview/Alt+Tab may still expose parked windows, so test whether it feels natural and whether it violates window isolation expectations.
- The shell may lose a shown window's scratchpad origin across shell restart; check recovery. The existing T-0032 trial also tracks a potentially serious monitor-reconnect lock-screen memory issue; its **current** state/version must be rechecked, not assumed open or fixed.
- The repo's pinned integration/ownership split (NixOS module available versus desired Home Manager ownership) needs resolution before a permanent declarative installation.
- More features and cross-compositor breadth may add regression surface; verify **the pinned version**, not just new upstream documentation.

**Prefer if** hide/show, window rules, multiple configurable docks, scripting, plugins and a broad developer workflow outperform the alternatives in the real session.

### Noctalia v5
[GitHub](https://github.com/noctalia-dev/noctalia) · [Taskbar](https://docs.noctalia.dev/noctalia/v5.6.0/bar/widgets/taskbar/) · [Dock](https://docs.noctalia.dev/noctalia/v5.6.0/dock/)

**Pros**
- **Both a taskbar and an optional dock**, with pinned favourites, running-window tracking, active indicators, grouping and per-monitor settings. The dock supports auto-hide; the bar can auto-hide independently.
- Current v5 taskbar docs explicitly support **left-click focus/cycle** and **middle-click close one window**; pinned-app controls are built in. Exact window identity handling for Niri has received upstream work.
- More integrated daily desktop controls than the fallback: notifications/DND, network/Bluetooth, sound, brightness, wallpaper, session actions, tray and plugins. A coherent UI avoids maintaining many separate look-and-feel layers.
- Native C++/Wayland/OpenGL ES runtime (not the older Quickshell-based Noctalia v4); TOML settings, IPC and hot reload can be evaluated for fast everyday use.
- Multi-compositor compatibility, public documentation and an active community make Noctalia attractive beyond one specific Niri installation.

**Cons / risks**
- **Do not infer native Niri minimisation**: its docs describe minimise/restore on supporting compositors; Niri must be tested separately for an equivalent hide/show result.
- Taskbar **pins are ignored when grouping by workspace** in the documented v5 taskbar configuration. This can conflict with a design combining persistent favourites and workspace-grouped running windows; the dock may be the better pinned surface.
- GUI-managed runtime TOML/override state can drift from Nix/Home Manager configuration; define the authoritative owner and state export strategy.
- The v5 runtime is a distinct architecture from v4; fresh regressions, plugin compatibility and migration reliability need live verification. Existing T-0032 flags locked-resume/hotplug and hybrid-GPU risk; verify against the exact installed version.
- A good-looking dock does not guarantee that **close, hide, restore, per-window menu and multiple instance focus** all work as expected.

**Prefer if** an integrated, polished and configurable Niri desktop with excellent **focus/close** taskbar actions is more useful than scratchpad minimisation or a very large plugin ecosystem.

### iNiR: Waffle, Material and iRiS
[GitHub](https://github.com/snowarch/iNiR) · [Families](https://inir.space/docs/panel-families/) · [Window IPC](https://inir.space/docs/ipc/) · [Hub](https://inir.space/hub/)

**Pros**
- Three distinct UI paradigms in one ecosystem: **Waffle** (bottom taskbar, Start, Action/Notification Centers and Task View), **Material** (flexible bar/sidebars/overview), **iRiS** (Island on any edge, expandable panels and dock). Strongest layout experimentation rather than merely a Windows skin.
- Documents pinned/running windows, per-window cycling, previews, Niri overview integration, alternate Alt+Tab and **`inir minimize`/`restore`** commands that park/restore windows on a dedicated workspace.
- Broad optional feature reach: theme/style families, desktop widgets, calendar, controls, system monitoring, Hub components and IPC. May offer a genuinely richer desktop than GNOME with fewer hand-assembled visual components.
- Niri-focused development can mean more attention to its particular scrolling-tiling interaction model.
- Waffle is a useful low-learning-curve **fallback layout** even if Material or iRiS wins on productivity.

**Cons / risks**
- Families, themes, widgets and runtimes distributed through the Hub **may update outside `flake.lock`**. Offline first boot, pinned versions, downgrade and reproducibility require an explicit strategy.
- A relatively specialised ecosystem may have a smaller pool of independent maintainers and package guidance than broader Wayland tools; **measure** contributors and issue response rather than inferring quality from novelty.
- Switching UI families may change window menus, shortcuts, panels and available affordances; test daily actions in **each family** rather than generalising from Waffle.
- iNiR NixOS integration is described upstream as experimental; modules can own desktop services, seed Niri config and grant extra hardware/input groups. These actions conflict with this repo unless explicitly suppressed and audited.
- Its own launcher/clipboard/settings and extensive features can duplicate Vicinae or require additional state management. Moving windows to a hidden workspace is again **not native minimisation**.

**Prefer if** multiple layout families, Waffle's complete taskbar, a flexible Island/dock and custom widgets **together with** usable window parking justify extra integration and update controls.

### Waybar + SwayNC + swaylock + swayidle (+ targeted Niri modules)
[Waybar](https://github.com/Alexays/Waybar) · [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) · [Niri window buttons](https://github.com/adelmonte/niri_window_buttons)

**Pros**
- Precise separation of bar, notifications, lock and idle, with straightforward replaceability. Good fit for versioned Home Manager/chezmoi configs and one-owner rules.
- **niri_window_buttons** documents actual per-window buttons, titles, configurable clicks, context-menu commands, close actions, multi-selection, multi-monitor display and drag-to-reorder. This is directly relevant to the complaint that GNOME hides running-window controls.
- Can make a conventional bottom task manager or a minimal app dock without installing an entire integrated shell, and can use Vicinae as-is.
- Broad Wayland component reuse reduces dependency on a single shell's entire UI/plugin stack; individual failures are potentially easier to isolate.

**Cons / risks**
- It is **not** a complete desktop shell. Settings, wallpaper, quick controls, media, coherent styling, a launcher and some power/session UI must be supplied separately.
- Multiple configuration formats, service units and Niri IPC adapters create more glue, updates and test ownership. A taskbar module built as a Waybar CFFI shared library adds its own native build/ABI compatibility burden.
- Polished application grouping, thumbnails, favourites, restore/parking, workspace awareness and notification badges may require custom code; no package should be assumed to cover them all.
- Independent parts can look inconsistent and may not recover together after output hotplug or session restart.

**Prefer if** explicit per-window buttons and maintainable component replacement matter more than an integrated dashboard. It may be the **best functional taskbar**, even if it loses on full-shell feature breadth.

## Cross-candidate feature comparison: documented, not tested

| Feature or design | Dux | Noctalia v5 | iNiR | Waybar stack |
|---|---|---|---|---|
| Persistent favourite apps + running windows | Dock/taskbar documented | Dock and flat taskbar documented | Waffle and family docks documented | Needs taskbar/pinning modules |
| Bottom taskbar | OmegaDock taskbar mode | Configurable bar/taskbar | Waffle | Configurable Waybar |
| Alternative dock position or layout | Multiple docks, any edge | Dock with monitor overrides | Material bar; iRiS Island/dock | Full manual positioning |
| Click-to-focus, multi-instance switching | Documented; verify per-app cases | Explicit focus/cycle docs | Documented app cycling/task view | Niri module-dependent |
| Close from taskbar | Verify configured actions | Middle-click documented | Verify actual window action | `niri_window_buttons` configurable |
| Hide/restore **window** under Niri | Scratchpad workaround documented | **Unverified / no native minimise assumption** | Hidden-workspace workaround documented | Custom scratchpad logic needed |
| Auto-hide **panel/dock** | Documented | Documented | Waffle bar toggle; verify auto-hide | Waybar config/scripts |
| Native Niri/workspace integration | Yes; scratchpad IPC | Yes; dedicated backend | Niri-focused | Waybar Niri modules |
| Built-in control centre / notifications | Yes | Yes | Yes | SwayNC + other tools |
| Plugins/widgets/automation | Plugin registry, lockfile, IPC | Plugins, scripts, IPC | Hub, families, widgets, IPC | Community modules and scripts |
| Deterministic Nix state by default | **Partial**; plugin state needs review | **Partial**; GUI overrides need policy, and the pinned package installs plugins by cloning repositories at run time | **Partial**; Hub assets need pinning | Best component-level control; more glue |
| Mature feature behaviour on **this PC** | Not tested | Not tested | Not tested | Not tested |

The word *documented* means described by upstream, **not verified to work on the pinned nixpkgs, Niri version or AMD/NVIDIA machine**.

## Ecosystem, community and sustainability

Compare community **health**, not GitHub stars alone. Record a dated snapshot for each **core repository and the specific subcomponent relied upon**:
- Releases and compatibility: latest stable tag, last meaningful release, current pinned nixpkgs/Home Manager version, upgrade and rollback documentation.
- Maintenance: substantive commits in the last 90 days, number of independent contributors, maintainer concentration, responsiveness to reproduced defects, whether critical regressions remain open in the *candidate version*.
- Ecosystem: docs/examples, discoverable plugins and third-party integrations, community configuration recipes, native NixOS packages/modules, issue quality, test coverage and migration discipline.
- Sustainability: plugin API stability, lockfiles, dependency provenance/signatures/checksums where provided, upstream release cadence, ability to maintain a working fork or replace one failed component.
- Security and operational risk: privileges, shell-script installers, auto-updaters, mutable configuration, network requirements, crash isolation and unneeded background processes.

### Public GitHub community snapshot (2026-11-22)

GitHub repository pages showed the following **rounded counts** when checked. These are indicators of reach and available peer support, **not scores for stability, maintenance or fit**. Issue counts reflect each project's own reporting practices and are not comparable defect rates. Re-check before any selection.

| Upstream project | Stars (approx.) | Forks (approx.) | Open issues shown | Reading for this repo |
|---|---:|---:|---:|---|
| [Dux Shell](https://github.com/duxlabs-dev/dux-shell) | 9.2k | 610 | 375 | Established public interest, companion Dux Labs projects and a plugin registry; verify Niri-specific scratchpad bugs |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | 12.2k | 1.0k | 428 | Broad Wayland audience and documentation; evaluate current **v5** regressions separately from legacy v4 |
| [iNiR](https://github.com/snowarch/iNiR) | 2.0k | 118 | 4 | More specialised Niri-focused audience; a low issue count does **not** mean fewer defects; review the Hub repositories as well |
| [Waybar](https://github.com/Alexays/Waybar) | 12.2k | 1.2k | 688 | Widely reused bar with substantial community reach, but task management depends on chosen Niri modules |
| [niri_window_buttons](https://github.com/adelmonte/niri_window_buttons) | 58 | 6 | Not sampled | Narrower third-party module with a much smaller support base than Waybar itself; treat packaging and ABI as separate risks |

**Qualitative hypotheses to validate (not rankings):**

| Candidate | Potential community/architecture advantage | What could undermine it |
|---|---|---|
| Dux | Dux Labs project family, plugin registry, shell CLI and cross-compositor users | Complex core/plugin coupling, critical regressions, Nix integration gaps |
| Noctalia | Dedicated documentation, integrated native stack, multiple compositor users, per-monitor configuration | v5 migration/regression and runtime config ownership |
| iNiR | Active Niri-specific feature development, Hub and three UI families; rich experiments | Specialised ecosystem, independently updated Hub packages, experimental Nix path |
| Waybar stack | Widely reused individual Wayland tools, many examples, independent upgrades | The **specific** Niri taskbar extension may have a much smaller community and require manual packaging |

Do not hardcode speculative stars, issue counts, RAM benchmarks or popularity scores. Collect reproducible numbers at trial time. Larger communities are useful for troubleshooting but **do not guarantee the desired Niri taskbar actions**.

## Evaluation categories and weights (100 points)

The earlier "Windows-like" criterion is deliberately renamed to **window/taskbar workflow**. All twelve user-provided weights are retained; visual fidelity to Windows, macOS or GNOME is **not scored**.

| # | Criterion | Weight | What counts |
|---|---|---:|---|
| 1 | **Taskbar/dock and window usability** | 16 | Pins, running state, focus, close one, multi-window cycling, hide/restore, positioning, autohide |
| 2 | Niri integration | 12 | IPC, overview, scrolling workspace semantics, window IDs, focus and restore |
| 3 | Feature completeness | 12 | Notifications, controls, launcher coexistence, widgets, clipboard, settings |
| 4 | Reliability and stability | 12 | Crash recovery, restore state, lock, resume, regression rate |
| 5 | Multi-monitor | 8 | Per-output docks, scaling, mixed DPI, unplug/replug, window placement |
| 6 | Customisation and extensibility | 8 | Dock location, grouping, shortcuts, plugins, scripts, IPC, themes |
| 7 | Performance and efficiency | 7 | Measured CPU, RSS, startup and window-focus latency on the same hardware |
| 8 | Updates and maintainability | 7 | Pinned upgrades, migration, rollbacks, issue handling |
| 9 | Configuration and reproducibility | 6 | Nix/chezmoi ownership, offline bootstrap, file drift, backups |
| 10 | Modularity and replaceability | 5 | Single-component swaps, failure isolation, vendor lock-in |
| 11 | Security and session management | 4 | Secure lock/idle/suspend, polkit, privileges, update provenance |
| 12 | Documentation and community | 3 | Supported examples, contributors, support responsiveness, Nix-specific guidance |
| | **Total** | **100** | |

Use `overall = sum(weight[i] * verified_score[i] / 100)`. Each category is scored **0–100 after evidence**: 90–100 excellent, 75–89 strong, 60–74 acceptable, 40–59 weak, below 40 inadequate. Record source URL, exact version, test result, date and issue link beside each score. Unknown is **unscored**, not zero. Show a provisional *coverage* percentage separately; do not extrapolate from only tested categories to declare a winner. A score of **80/100** is a proposed comparison threshold (not a measured result); passing **every P0 gate is mandatory regardless of aggregate score**. Scores within 5 points are treated as a tie and resolved by actual taskbar/hide/restore outcomes, ownership and maintenance.

## Functional acceptance matrix: P0 / P1 / P2

**P0 — mandatory for this user's desktop**
- [ ] Persistent, visible **running-application/task manager** and favourite pins; bottom placement works. A stronger alternative placement can be chosen only on actual testing.
- [ ] Left-click a running icon **focuses the existing instance**; a non-running favourite launches once; grouped icons cycle or expose all windows. Test three VS Code windows, two browser windows, terminal, Telegram/Vesktop and a second output.
- [ ] User can **close the selected window** from the taskbar/dock with a discoverable mouse action; unsaved-changes prompts work; multi-window app is not killed accidentally. Independently test **close all app windows**, if offered.
- [ ] Hide/restore path: where offered, park the correct window, show its hidden status, restore it to the intended current/original workspace and handle multiple windows. If not supported, record this as a failed requirement **rather than implying Niri supports native minimisation**; an explicitly agreed alternate workflow may be evaluated before cutover.
- [ ] No click-to-focus loops, dead taskbar clicks, duplicate launches, wrong-window focus or stale entries after app exit, shell restart, workspace switch or external-monitor hotplug.
- [ ] Niri multi-workspace switching, native Alt+Tab, Vicinae launcher/clipboard and US/Russian keybindings do not conflict. Keep the existing manual shortcut review in ADR-0012.
- [ ] Notifications and tray icons work (including Telegram/Vesktop); exactly one notification provider. Secure lock, idle, unlock and suspend/resume work; exactly one lock/idle owner and one polkit agent.
- [ ] Shell starts **only in the Niri session** and never on the existing GNOME system through the shared Home Manager profile; no user-data or config overwrite. Rollback restores previous shell and app/window behaviour.

**P1 — important for adoption**
- [ ] Dock placement: bottom default, optional side/top, reserved space vs overlay, intelligent auto-hide, multiple docks, per-display settings. A bar may substitute for a dock if it is functionally better.
- [ ] Per-window menu: app title, focus, close, workspace move, optional restore, close-all and drag reordering where supported.
- [ ] Window thumbnails, counts, badges, running-vs-pinned indicators, Task View/search and reliable multi-instance Electron/desktop-entry mapping.
- [ ] Network, Bluetooth, audio, brightness, battery, media, Do Not Disturb, calendar and quick settings work without competing services.
- [ ] Multi-monitor DPI/fractional scaling, output disconnect/reconnect, monitor-specific dock placement and focus; no stranded hidden windows.
- [ ] Flake-lock/closure integrity, shell/plugin versions, offline startup, no unmanaged UI overwrites and reproducible Home Manager/chezmoi state.
- [ ] CPU/RSS/startup/input latency collected identically, including 10 monitor reconnects and one prolonged normal-work session; reject persistent unbounded growth.
- [ ] Community activity/critical bug checks and clean upgrade/downgrade procedure recorded.

**P2 — differentiators, not reasons to waive P0**
- [ ] Layout families, themes, blur, animations, Island panels, desktop widgets, weather, live metrics, command palettes and interactive plugins.
- [ ] Scriptable IPC, per-app customisation, window rules, custom taskbar menus, AI/dev widgets and optional plugin store integrations.
- [ ] Unified settings and a coherent UI after disabling features already owned by Vicinae.

### Reproducible task scenarios
1. **Pinned + running:** pin VS Code, Brave, terminal and Telegram. Open three VS Code windows on two workspaces, close only one from the taskbar, focus the others and cycle them without duplicating apps.
2. **Hide + show:** park one browser window and later restore it from another workspace, after a shell restart, and after switching monitors; verify it cannot be lost even if Niri Alt+Tab still sees it.
3. **Close semantics:** test a document with unsaved edits; one-window close, close-all (if implemented), application exit and the absence of zombie task entries.
4. **Layout change:** try bottom taskbar, compact dock, side dock/Island (where available); compare required clicks and keyboard actions, not looks. Test auto-hide and windows covering the edge.
5. **Recovery:** crash/restart only the shell, log out/in, lock/suspend/hotplug, then verify notification history, running-app list, pinned apps, lock, polkit and taskbar input still work.
6. **Developer workday:** switch between VS Code windows, a terminal, browser documentation, chat and file manager; record task-completion time and number of context switches for 10 repetitions.
7. **Nix reproducibility:** rebuild PC 2 from the pinned flake, disconnect network and start the Niri shell; compare managed files and plugin/family versions before and after GUI settings changes.

## NixOS and repo-specific integration policy

**Common rules**
- Keep the greeter (greetd on the GNOME-free niri install, GDM on the existing system) and the Niri session wiring with the NixOS owner; no general upstream shell installer is permitted to change them.
- `home/dot_config/niri/config.kdl` stays chezmoi-owned and must pass `niri validate`. Shells may offer bindings but the repo chooses and deploys them; no `spawn-at-startup` duplicate of a session-scoped systemd service.
- Prefer pinned packages and session-scoped services. Keep **Vicinae** as the incumbent keyboard launcher and clipboard-history baseline for the pilot. The final clipboard owner is open (ADR-0013, ADR-0046 G06) and the launcher is compared in ADR-0048. A *clickable* Start menu/dock launcher may coexist without taking global keyboard shortcuts.
- Test systray/AppIndicator, notification DBus owner, portal/screenshot/screencast, file dialogs, polkit and lock independently. Do not mask service problems by enabling lingering.
- Never grant new groups, automatic updates, broad file permissions or runtime execution of community plugins without review. Record exact package source, closure and permissions.

**Dux:** Resolve current pinned nixpkgs NixOS-module vs Home Manager ownership before permanent install; compare upstream module options with the lockfile/plugin strategy and Niri-only service startup. Verify that a restart does not strand scratchpad windows. The Dux documentation cited here is for 2.2, while the pin is dux-shell 2.1.2: confirm the scratchpad and IPC commands exist in 2.1.2. The pinned `programs.dux-shell` module also turns on `hardware.i2c` and `services.accounts-daemon` by default; review or override both under the rule above.

**Noctalia:** Pin the *native v5* version intended for the test; distinguish its live GUI overrides from declarative TOML. Check which features and commands exist in **that pinned version**, rather than relying on newer v5.6 documentation. Check how taskbar pins interact with workspace grouping and whether the dock avoids the conflict.

**iNiR:** [NixOS guidance](https://inir.space/docs/nixos/) is experimental. Keep `programs.inir.desktop.enable = false` in the trial to avoid taking over desktop services/display manager; disable `programs.inir.niriConfig.seed` to protect chezmoi. Inspect NixOS module-added groups (`video`, `input`, `i2c`, `ydotool`), service scope, mutable `~/.config/quickshell/inir` state and Hub-delivered families. Pin/vendor the actual Waffle/Material/iRiS and Hub assets or explicitly document an offline/reproducibility exception **before** cutover. Do not invoke the generic upstream `./setup install` over the managed system.

**Waybar fallback:** Prefer Home Manager modules and repo-owned CSS/config; use a prebuilt compatible Niri taskbar extension where possible. For `niri_window_buttons`, verify source, CFFI ABI compatibility, Waybar version and reproducible native build instead of fetching an unmanaged shared library. A tiny alternative with only reliable task buttons can beat a large shell **if** P0 and service ownership pass.

## Community and feature-reach review procedure

Collect, per candidate and its taskbar/dock component, a dated evidence table before selection: pinned version, upstream version, release age, relevant issues closed/open and severity, independent contributors in last 90 days, docs freshness, number of maintained *relevant* plugins, known Niri regressions and reproducible installation path. **Do not turn raw stars, plugin counts or commit counts into a quality score without relevance and maintenance checks.** Compare issues against the exact version to be installed.

## Consequences and open decisions
- This feature-first version replaces the earlier "Windows-like" framing of this ADR; it is not a decision to emulate Windows or macOS. The filename is retained to avoid breaking existing references.
- **Dux** appears especially relevant to hide/show and configurable multi-edge docks; **Noctalia** to a polished taskbar with documented mouse close/focus; **iNiR** to multiple layout paradigms plus a hidden-workspace restore service; **Waybar + niri_window_buttons** to explicit traditional per-window controls. These are **test priorities, not scored winners**.
- The existing **Dux → Noctalia** trial order is unchanged. The niri install has no GNOME session, so there is no GNOME default to preserve on it (ADR-0012, 2026-11-22). No permanent shell is selected. iNiR remains an additional proposed trial; any owner-approved addition must amend ADR-0013 and T-0032 trial scope before activation.
- Decide after real tests whether hide/show via a parking workspace is adequate, which exact shell owns notifications/lock/polkit, whether GUI settings can persist, whether Hub-managed runtime components are acceptable, and whether another edge or Island beats a bottom taskbar in the daily workflow.

## References
- [Dux shell and Niri scratchpad IPC](https://duxlabs.dev/docs/2.2/dms/keybinds-ipc)
- [Dux v2 dock and extensibility](https://duxlabs.dev/blog/v2-0-release)
- [Noctalia native v5 overview](https://github.com/noctalia-dev/noctalia)
- [Noctalia v5.6 taskbar](https://docs.noctalia.dev/noctalia/v5.6.0/bar/widgets/taskbar/) and [dock](https://docs.noctalia.dev/noctalia/v5.6.0/dock/)
- [iNiR panel families](https://inir.space/docs/panel-families/), [Niri minimisation IPC](https://inir.space/docs/ipc/) and [NixOS](https://inir.space/docs/nixos/)
- [Waybar Niri window buttons](https://github.com/adelmonte/niri_window_buttons)
- [Existing shell issue research](../../research/niri-shell-dux-vs-noctalia.md) (2026-11-15; reports are unverified until refreshed)


## Feature-first integration amendment (2026-11-22)

- **GNOME desktop is not a candidate to retain by default.** GNOME Shell/top bar, extensions and settings must be evaluated against the complete Niri shell and native utilities; a GNOME-named **portal/keyring** may remain as a compatibility service without the GNOME desktop. See [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md).
- **Vicinae is an incumbent for the current pilot, not a permanent shell dependency.** [ADR-0048](0048-niri-launcher-vscode-project-workflows.md) compares Walker, Albert, Ulauncher, Rofi and shell launchers. The winning frontend must preserve exact VS Code recent-project opening, Niri window focus and desired command/clipboard features.
- Re-evaluate every shell's own integrated UI before adding a separate daemon: app/taskbar, DND history, tray, launcher, OSD, network/Bluetooth, lock/idle, wallpaper, screenshot and power controls.
- **Feature completeness must not disguise functional omissions.** A shell with widgets and multiple layouts loses the critical taskbar workflow if it cannot close the correct window, restore parked windows, keep pins or recover safely from a crash.
- After the shell comparison, score the **incremental** value of every standalone add-on: `niri_window_buttons` or `niri-taskbar` for richer window controls; SwayNC for history; swaylock/swayidle for independent secure recovery; Kanshi for physical monitor profiles; Satty only for annotation; SwayOSD only when shell OSD fails.
- For the final Niri environment, use one compositor, one running desktop shell, one notification bus owner, one polkit agent, one clipboard-history owner and one lock/idle policy. Rofi/Fuzzel may be an **on-demand rescue frontend**, not a competing autostart service.
- The installation decision register and new GNOME/launcher gaps are [ADR-0046](0046-niri-desktop-installation-decision-register.md). **No paper evidence automatically selects or installs a tool.**
