---
adr: 12
title: "Desktop compositor: GNOME on the existing system, niri without the GNOME desktop on the new install, Hyprland parked"
status: partly-decided
date: 2026-11-15
platforms: [linux, nixos]
areas: [desktop, compositor]
permits: [gnome-default, niri-trial, gnome-free-niri-install]
forbids: [unauthorised-niri-migration]
amends: []
supersedes: []
superseded_by: []
related: [41, 46, 47, 48, 49]
---
# ADR-0012: Desktop compositor: GNOME on the existing system, niri without the GNOME desktop on the new install, Hyprland parked
Status: GNOME decided for the existing system (stay for now); a niri install without the GNOME desktop is built and tested in a VM, with the older-laptop trial pending; Hyprland deferred · Date: 2026-11-15 (niri plan; the GNOME decision date is not recorded) · Sources: `docs/plans/future-upgrades.md` (section 12), `docs/plans/niri-migration.md`, `docs/research/niri-vs-hyprland.md`, `docs/research/desktop-migration-claim-audit.md`, `docs/plans/hyprland-migration.md`, `docs/work/active/T-0029-nixos-system-ownership/ticket.md`

**Laptop delivery · 23 November 2026 · 50% (2/4) · P0 · high complexity.** Dedicated Niri system built. Authenticated guest session exercised. Verify laptop display and input, then verify suspend and output hotplug. The virtual GPU did not prove visible rendering on the destination. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

The owner will confirm when the installed Niri laptop works for daily use. Keep the GNOME setup available until then. After confirmation, tag the last verified GNOME-capable revision before removing the GNOME desktop from future releases. [Release transition](../../plans/niri-migration.md#release-transition)

## Decision
- GNOME + Vicinae is what runs today on the existing system and stays its default session. GDM stays there.
- The separate `linux-niri` host uses the native nixpkgs `programs.niri` module. The migrated desktop and integrated user configuration build independently of the GNOME profiles.
- Hyprland is deferred, not rejected.
- GNOME parity belongs only to a future change to the existing GNOME system. The fresh Niri laptop has its own login, boot and recovery checks.
- Keybindings are checked by the owner by hand, under GNOME and under niri. They are not an agent task or an automated gate.

## Why
- GNOME is already declarative in Home Manager and trivially reversible: maintainability 80 vs 30 and rollback 90 vs 40 against Hyprland (`docs/plans/future-upgrades.md` section 12, an earlier table that the audit later corrected in parts).
- niri is the lower-risk default today: the audit keeps "niri via nixpkgs `programs.niri`" and keeps GNOME selectable (`docs/research/desktop-migration-claim-audit.md`, section 6). Its older comparison text on Hyprland's Lua transition is marked stale by the audit (R10).
- Hyprland 0.57.2 in the pinned nixpkgs removed `.conf` support, so the Hyprland plan's config assumptions are stale as recorded in the [Hyprland plan](../../plans/hyprland-migration.md).
- The audit's fifth-review scores (opinion only): niri 89, GNOME 84, KDE 78, Hyprland 72.

## Strong alternatives
| Option | Why it lost (for now) |
|--------|-----------------------|
| Hyprland + Vicinae | Scored higher on resize stability (90 vs 55), but that score rested on the GNOME extension cliff, which the audit superseded. It also needs system-level session config the repo does not own yet, and its plan is stale. Deferred, not rejected. |
| Staying on GNOME for good | Not rejected. The earlier stay-on-GNOME reasoning leaned on the Vicinae extension cliff (shell 46-50); the audit calls "46-50" stale and verified that extension 1.8.x supports 46-51, so the cliff is not a current migration trigger (audit R3 and section 5). The pinned gnome-shell is 51.1 (the audit recorded 51.0 on 2026-11-14). |

## Discarded
KDE (score 78; no reason beyond the score recorded), COSMIC (recorded on 2026-11-15 as "no declarative NixOS options, partly verified"; the pinned nixpkgs now has `services.desktopManager.cosmic`, so that reason no longer holds as written and COSMIC would need a fresh look), niri-flake (not needed), Ly (deferred). greetd with tuigreet was listed here as deferred; since 2026-11-22 it is the preferred future greeter under ADR-0041 (see the refinement below).

## Owner direction (2026-11-22): the niri install has no GNOME desktop

The owner wants NixOS with niri and without GNOME, where that is safe, so that no desktop is carried only as a spare. This replaces the earlier plan of adding niri as a second session beside GNOME and GDM on the new install.

- **Scope.** Install on the laptop from USB or prepare its dedicated SSD on a guarded workstation. Cold boot on the destination in either case.
- Keep the GNOME ScreenCast portal and GNOME Keyring for their required interfaces. Verify the actual target closure, enabled sessions and runtime service owners. [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md)
- **What follows:** greetd with tuigreet replaces GDM (ADR-0041); the GTK portal replaces the Nautilus file chooser; the services the GNOME module switched on by default have to be declared (ADR-0047).
- **Why it is safe:** the install is on its own disk, the login is text, the recovery routes are rehearsed with the declared lock and idle services, and the existing system stays bootable. The conditions are in [ADR-0049](0049-niri-safest-staged-installation-order.md).
- **Not covered:** removing GNOME from the existing system in place. There GNOME stays until niri has passed on that hardware.
- `linux-niri` is the deployment target. The older `linux-desktop-pilot` fixture enables GNOME and GDM. [Build and deployment gates](../../platforms/nixos/niri-install.md)

## Direction refinement (2026-11-22)

**GNOME is the incumbent fallback, not the desired permanent desktop.** The owner now prefers a more functional Niri desktop without GNOME Shell unless GNOME can demonstrate a superior required feature. On the existing system GNOME+GDM stay the live/default session; the new niri install carries neither (see "Owner direction" above).

- Compare every GNOME application/extension to a feature-equivalent alternative in [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md); GNOME **portals and Secret services** may still be necessary for Niri even when GNOME Shell is removed.
- Future login research prefers **greetd + tuigreet**, with **ReGreet** (feature-rich) and **gtkgreet** (lean) as the graphical comparators, neither ranked, under [ADR-0041](0041-login-greeter-gdm-greetd-tuigreet-regreet.md). This is not a change to the running GDM.
- Vicinae is **retained during trial only**; the final launcher is decided by VS Code project-opening and feature comparisons in [ADR-0048](0048-niri-launcher-vscode-project-workflows.md). The compositor and launcher are distinct decisions.
- [ADR-0046](0046-niri-desktop-installation-decision-register.md) is the central gate/component matrix, not a cutover approval. [ADR-0049](0049-niri-safest-staged-installation-order.md) proposes the order of the stages.

## Consequences
- A niri-only host is needed for the new install; the committed pilot enables GNOME. The in-place route needs T-0029 first (flake-owned NixOS system; in progress since 2026-11-21: the PC 2 pilot host `linux-desktop-pilot` exists, PC 1 not started); the trial is T-0032.
- Follow the [migration overview](../../plans/migration/overview.md) for the fresh laptop.
- Revisit Hyprland only after its plan is rewritten against the current config format (the audit marks the plan's assumptions stale); the old trigger "HM Lua support stable" is not supported by the audit.
