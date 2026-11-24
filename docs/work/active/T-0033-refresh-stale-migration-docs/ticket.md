Source: local

# T-0033: Refresh stale migration docs (docs)

Status: in progress (fresh Niri setup documented; historical research and comparison claims remain to audit)

**Niri delivery · 23 November 2026 · 38% (3/8) · P1 maintenance · medium complexity.** Identify the historical in-place route. Link the dedicated runbook. Correct the account guidance. Reconcile GNOME retirement wording, then audit launcher assumptions, then audit greeter comparisons, then audit portal and chooser claims, then mark historical install instructions. Use the eight explicit documentation checks in this ticket. [T-0032](../T-0032-niri-trial-session/ticket.md) · [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md) · [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md) · [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md) · [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md) · [ADR-0048](../../../architecture/decisions/0048-niri-launcher-vscode-project-workflows.md) · [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md)
Niri desktop installation and component decision register: [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md). Related register gap: G16. The register's explicit contradiction list identifies old migration-plan wording; it does not mark this ticket complete.
Depends on: none
Evidence: `docs/research/desktop-migration-claim-audit.md`

## Summary
Correct statements in the migration docs that the 2026-11-14 audit found stale.
No behaviour change.

## Owned files
- docs/plans/future-upgrades.md
- docs/plans/hyprland-migration.md
- docs/plans/migration/overview.md
- docs/research/niri-vs-hyprland.md
- nix/modules/home/gnome-extensions.nix (comment only)

## Stale statements and corrections
| Location | Stale | Correct |
| --- | --- | --- |
| `nix/modules/home/gnome-extensions.nix:28-45`; `docs/plans/future-upgrades.md:269,278` | Vicinae GNOME extension "46-50" and "backbone" | 1.8.x supports 46-51 (v1.8.0, 22 Oct, year inferred; extensions.gnome.org/extension/8594). Pinned build's metadata UNVERIFIED |
| `docs/plans/hyprland-migration.md:18-20,187,241-245,332-348`; `niri-vs-hyprland.md:75-78` | Assumes `hyprland.conf` / `exec-once`, HM Lua "in progress" | Hyprland 0.57 (28 Oct 2026) removed `.conf`; HM `configType = "lua"` exists (release-26.05); `extraLuaFiles` master-only; HM issue #9341 shows `settings.exec-once` generating invalid Lua |
| `niri-vs-hyprland.md:46,69-70`; `hyprland-migration.md:339` | niri-flake `programs.niri.settings` | nixpkgs `programs.niri` plus HM `wayland.windowManager.niri` |
| `docs/plans/migration/overview.md` | Omits validator rule 11 and the `mkDefault "niri"` default-session trap; HM "raw KDL" mechanics | Add both; HM module vs `xdg.configFile` per T-0030 |
| Fresh laptop greeter | Earlier comparisons left Ly vs greetd open | Use greetd + tuigreet from first login. GDM belongs to the existing system. |
| `docs/plans/hyprland-migration.md:71` | Validator line reference | Rule 9 is now about `ops/validate-config.sh:530-535` (re-check before editing) |
| `docs/plans/hyprland-migration.md:72` | Cites `validate-config.sh:124` for rule 10 | Rule 10 is now about `:557` (re-check before editing) |
| `docs/plans/future-upgrades.md` section 12 | Premise: GNOME extension cliff | Weakened; not a current trigger |

- NixOS owns the portal configuration; T-0030 covers the dedicated Home Manager KDL writer.
- Record that niri v26.04 is the latest tag while relevant fixes (ee8a04b) exist only on main.

## Acceptance criteria
- Each listed statement is corrected with a source link.
- `git diff` shows documentation and one comment change only; no behaviour change.

## Follow-up for updated target policy (2026-11-22)

- [ ] Reconcile historical "GNOME for good" and "GNOME extension cliff" language with the **GNOME-minimal future target**, without changing the existing GNOME system; since the owner direction of 2026-11-22 the new niri install carries no GNOME desktop at all (ADR-0012); see [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md).
- [ ] Correct old assumptions that **Vicinae is permanently selected** for Niri; it remains the currently installed pilot launcher pending the [ADR-0048](../../../architecture/decisions/0048-niri-launcher-vscode-project-workflows.md) feature comparison. Windows Raycast choices remain separate.
- [ ] Correct old greeter alternatives to show **tuigreet preferred for research, gtkgreet graphical competitor and ReGreet optional**, with GDM retained on the existing GNOME system only; the GNOME-free niri install uses greetd with tuigreet from its first boot. [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md).
- [ ] Distinguish GNOME **Shell** from the still-needed GNOME **ScreenCast portal**, optional `gnome-control-center` for GlobalShortcuts, GNOME keyring/Secret, and Nautilus/GTK FileChooser routing. "GNOME-free" means no GNOME desktop, with `xdg-desktop-portal-gnome` and `gnome-keyring` kept; prove it from the evaluated package list and the closure (ADR-0047).
- [ ] Ensure any historical plan sending live installers or greeter edits is marked **non-authoritative** relative to [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md), and no physical NixOS deployment occurs without backup/rollback evidence.
- [x] Mark the GNOME-first sequencing in `docs/plans/niri-migration.md` and `docs/plans/niri-two-pc-pilot.md` (GNOME and GDM installed on the new machine, niri added as a second session) as the in-place alternative only; the fresh laptop and two-PC plans now use the separate target.
- [x] Direct fresh Niri installs to the dedicated runbook from the README and NixOS platform entry point. Keep the standalone procedure scoped to its original hosts.
- [x] Replace the obsolete identity-placeholder instruction with a check of the declared account.

## Progress
- 2026-11-21 documentation audit adds to the scope: `docs/plans/migration/overview.md` goals still prescribe a Home Manager-owned KDL and describe `nixosConfigurations` as future although the PC 2 pilot host exists; the pilot (done) must be told apart from the PC 1 takeover (not started). Already fixed on 2026-11-21: `docs/plans/future-upgrades.md` and `docs/plans/niri-two-pc-pilot.md` now say the pilot host exists.
