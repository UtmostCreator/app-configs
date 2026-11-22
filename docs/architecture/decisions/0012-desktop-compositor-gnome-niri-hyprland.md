---
adr: 12
title: "Desktop compositor: GNOME live, niri trial proposed, Hyprland parked"
status: partly-decided
date: 2026-11-15
platforms: [linux, nixos]
areas: [desktop, compositor]
permits: [gnome-default, niri-trial]
forbids: [unauthorised-niri-migration]
amends: []
supersedes: []
superseded_by: []
related: [46]
---
# ADR-0012: Desktop compositor: GNOME live, niri trial proposed, Hyprland parked
Status: GNOME decided (stay for now); niri proposed trial; Hyprland deferred · Date: 2026-11-15 (niri plan; the GNOME decision date is not recorded) · Sources: `docs/plans/future-upgrades.md` (section 12), `docs/plans/niri-migration.md`, `docs/research/niri-vs-hyprland.md`, `docs/research/desktop-migration-claim-audit.md`, `docs/plans/hyprland-migration.md`, `docs/work/active/T-0029-nixos-system-ownership/ticket.md`

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

## Decision
- GNOME + Vicinae is what runs today and stays the default session. GDM stays.
- niri through the nixpkgs `programs.niri` module is the working trial target. "No migration is authorised" (`docs/plans/niri-migration.md`, section 1).
- Hyprland is deferred, not rejected.
- GNOME 51 parity is not a gate for the niri migration (owner, 2026-11-20). If the daily session is niri, there is no need to first upgrade to GNOME 51 and prove the Vicinae GNOME extension and the GNOME keybindings there. The flake-owned system still installs GNOME 51 packages (GDM, the GNOME portal and keyring that niri uses, and the fallback session), so one check stays: GDM starts and the GNOME fallback session logs in. Full GNOME 51 parity is only needed if GNOME remains the daily session.
- Keybindings are checked by the owner by hand, under GNOME and under niri. They are not an agent task or an automated gate.

## Why
- GNOME is already declarative in Home Manager and trivially reversible: maintainability 80 vs 30 and rollback 90 vs 40 against Hyprland (`docs/plans/future-upgrades.md` section 12, an earlier table that the audit later corrected in parts).
- niri is the lower-risk default today: the audit keeps "niri via nixpkgs `programs.niri`" and keeps GNOME selectable (`docs/research/desktop-migration-claim-audit.md`, section 6). Its older comparison text on Hyprland's Lua transition is marked stale by the audit (R10).
- Hyprland 0.57.2 in the pinned nixpkgs removed `.conf` support, so the Hyprland plan's config assumptions are stale (audit, via `docs/plans/niri-migration.md` section 1).
- The audit's fifth-review scores (opinion only): niri 89, GNOME 84, KDE 78, Hyprland 72.

## Strong alternatives
| Option | Why it lost (for now) |
|--------|-----------------------|
| Hyprland + Vicinae | Scored higher on resize stability (90 vs 55), but that score rested on the GNOME extension cliff, which the audit superseded. It also needs system-level session config the repo does not own yet, and its plan is stale. Deferred, not rejected. |
| Staying on GNOME for good | Not rejected. The earlier stay-on-GNOME reasoning leaned on the Vicinae extension cliff (shell 46-50); the audit calls "46-50" stale and verified that extension 1.8.x supports 46-51, so the cliff is not a current migration trigger (audit R3 and section 5). The pinned gnome-shell is 51.0. |

## Discarded
KDE (score 78; no reason beyond the score recorded), COSMIC (no declarative NixOS options, partly verified), niri-flake (not needed), Ly and greetd/tuigreet (deferred).

## Consequences
- niri needs T-0029 first (flake-owned NixOS system; in progress since 2026-11-21: the PC 2 pilot host `linux-desktop-pilot` exists, PC 1 not started); the trial is T-0032.
- Stale docs: `docs/plans/migration/overview.md` still lists the compositor, greeter and notification daemon as open choices (line 53); T-0033 refreshes them.
- Revisit Hyprland only after its plan is rewritten against the current config format (the audit marks the plan's assumptions stale); the old trigger "HM Lua support stable" is not supported by the audit.
