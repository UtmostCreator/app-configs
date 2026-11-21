Source: local

# T-0033: Refresh stale migration docs (docs)

Status: not started (stale statements still present in owned docs)
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
| `docs/plans/migration/overview.md:46-53` | Greeter (Ly vs greetd) is a pre-implementation decision | Defer out of the trial; keep GDM |
| `docs/plans/hyprland-migration.md:71` | Validator line reference | Rule 9 is now about `ops/validate-config.sh:530-535` (re-check before editing) |
| `docs/plans/hyprland-migration.md:72` | Cites `validate-config.sh:124` for rule 10 | Rule 10 is now about `:557` (re-check before editing) |
| `docs/plans/future-upgrades.md` section 12 | Premise: GNOME extension cliff | Weakened; not a current trigger |

- Once T-0030 decides the owner, update `docs/plans/migration/overview.md`'s ownership table for portals.
- Record that niri v26.04 is the latest tag while relevant fixes (ee8a04b) exist only on main.

## Acceptance criteria
- Each listed statement is corrected with a source link.
- `git diff` shows documentation and one comment change only; no behaviour change.
