---
adr: 13
title: "Desktop shell, bar and notifications: trial order, not yet selected"
status: trial
date: 2026-11-15
platforms: [linux, nixos]
areas: [desktop, shell]
permits: [dux-trial, noctalia-trial]
forbids: [shell-selection-before-trial]
amends: []
supersedes: []
superseded_by: []
related: [45, 46, 47, 48, 49]
---
# ADR-0013: Desktop shell, bar and notifications: trial order, not yet selected
Status: trial (user decision 2026-11-15 on the order only) · Date: 2026-11-15 · Sources: `docs/plans/niri-migration.md` (shell, ownership and decisions sections), `docs/research/desktop-migration-claim-audit.md`, `docs/research/nix-config-borrow-analysis.md`

**Laptop delivery · 23 November 2026 · 25% (1/4) · P1 · high complexity.** Trial order recorded. Run the ticket’s shell acceptance gates, then verify shell-stop recovery, then select a passing shell. Capture bare Niri measurements first. Trial Dux first and proceed to Noctalia if needed. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

## Decision
- After installation and recovery, trial Dux first and Noctalia second if needed. Select the first candidate that passes workflow, service ownership, pinned configuration and crash-recovery checks. [Trial criteria](../../work/active/T-0032-niri-trial-session/ticket.md)
- Fallback: Waybar + SwayNC + swaylock + swayidle.
- **During the existing Dux → Noctalia pilot**, Vicinae stays the incumbent launcher and its VS Code project workflow stays available; shell launcher/clipboard keyboard binds remain disabled to avoid duplication. **Permanent launcher selection is reopened for a feature-first comparison** in ADR-0048 (Walker, Albert, Ulauncher, Rofi and the chosen shell), rather than assuming Vicinae is strongest.
- Exactly one owner each for notifications, clipboard history, lock/idle and polkit. The selected shell will own notifications, the bar, tray and OSD.

> The user recalls having selected Noctalia (and a "niri shell") for the status bar and notifications. The repository does not record that selection; if it was decided in a session outside the repo, update this ADR. Awaiting confirmation from the NixOS desktop session.

## Why
- Dux is already pinned in nixpkgs (dux-shell 2.1.2, formerly DankMaterialShell) with a closure-friendly plugin option.
- Noctalia is young (v5 stable about 10 weeks old) and its GUI can rewrite its own config.toml at runtime, an ownership issue.
- Open conflict: Dux has only a NixOS module in the pinned nixpkgs, not Home Manager, against the user's guidance that Home Manager owns the shell.

## Strong alternatives
| Option | Why it is second or fallback |
|--------|------------------------------|
| Noctalia | Collapses about 7-8 pieces into 1-2 (estimate); young; runtime config rewrite. The borrow analysis declined a noctalia flake input earlier (NixOS-only, "personal taste"). Since then both the pinned nixpkgs and the pinned Home Manager ship `programs.noctalia`, so unlike Dux it can be Home Manager-owned. |
| Waybar + SwayNC + swaylock + swayidle | Modular, all Home Manager modules; more pieces to own. mako vs SwayNC was never decided. |
| quickshell | A base for shells, not a candidate. |

## Discarded
Shell-bundled launcher and clipboard keyboard binds, for the pilot (Vicinae is the incumbent launcher). Superseded in part on 2026-11-22: a shell's launcher is now a candidate in ADR-0048; its binds still stay off during the trial.

## Consequences
- Open items: screenshots (Flameshot live; niri action or grim + slurp + satty as alternatives).
- Keep shell configuration on the dedicated Niri host and bind its units to the graphical session. During the trial Vicinae owns clipboard history and swayidle/swaylock and Soteria operate independently of the shell.
- Revisit after the real trial; nothing here is a selection.
- The audit's fifth review (2026-11-14) says "no Noctalia"; the newer niri plan (2026-11-15) makes it the second trial candidate.

## Evidence update 2026-11-15

Two user-supplied assessments (Dux vs Noctalia: feature comparison and an upstream issue audit) are recorded in
[docs/research/niri-shell-dux-vs-noctalia.md](../../research/niri-shell-dux-vs-noctalia.md). The issue states are
unverified. The decision is unchanged: Dux first, Noctalia second, no permanent shell selected, Vicinae stays
the launcher, one owner each for notifications, clipboard, lock/idle and polkit. The open upstream risks (Dux #4259;
Noctalia #5349, #4714, #4565) become trial gates in T-0032. A mandatory pre-migration backup gate applies before any
live change (docs/plans/niri-migration.md, "Mandatory backup before any live change").

## Decision refinement 2026-11-22: GNOME-minimal desktop and feature comparisons

- This ADR still selects **the trial order only: Dux first, Noctalia second**, with iNiR research and the Waybar stack as alternative baselines in [ADR-0045](0045-niri-windows-like-desktop-shell-ux.md). No shell is selected.
- GNOME Shell/top bar is **not** the desired long-term interface. The component-by-component exit criteria and exceptions (portals/Secret/GlobalShortcuts, not full GNOME) are in [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md). The niri install carries no GNOME desktop (ADR-0012, owner direction 2026-11-22); the existing GNOME system is the fallback and is not changed.
- **Do not automatically retain Vicinae** beyond the trial: [ADR-0048](0048-niri-launcher-vscode-project-workflows.md) compares app/window search, clipboard, command plugins and **exact VS Code recent project opening/focus**. Replacing Vicinae requires equal or stronger real-world workflow, but no single plugin is mandatory if a shared project reader and another frontend solve it.
- Notifications, lock/idle, tray, OSD, clipboard and polkit are **single-owner slots**. Compare shell-provided functions to SwayNC, mako, swaylock+swayidle and the pilot's Soteria; enable standalone fallbacks **only for missing/failed shell capabilities**.
- The live migration inventory, exact installed/declared split and gaps are in [ADR-0046](0046-niri-desktop-installation-decision-register.md). Its G17–G22 checks (G17 is P0; G18, G21 and G22 are P0 only under their stated conditions; G19 and G20 are P1) add recovery, portal routing for GlobalShortcuts and Secret, MIME activation, input, power and GNOME-dependency validation.
- The pinned Soteria unit starts on `graphical-session.target`, so on the pilot it also starts in the GNOME session beside GNOME Shell's own polkit agent. That concerned the committed GNOME pilot; on the GNOME-free niri install there is no GNOME session and Soteria is the only agent.
- Selection gate: window close/focus/pin/hide/restore, secure suspend/recovery, notifications, portals and the recovery routes must all be tested on real Niri hardware. The decision must compare *actual functionality and process ownership*, not use visually familiar defaults.
