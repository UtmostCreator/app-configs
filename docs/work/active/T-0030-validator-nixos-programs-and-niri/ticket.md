Source: local

# T-0030: Validator allows NixOS programs.* and a niri config owner (feature)

Status: open, partly superseded (niri config owned by chezmoi 6fb82ee, rule 11 change unneeded; rule 6 scope change still needed)
Depends on: none
Blocks: T-0032
Evidence: `docs/research/desktop-migration-claim-audit.md`

## Summary
Scope validator rule 6 (programs allowlist) to Home Manager surfaces so
legitimate NixOS `programs.*` (for example `programs.niri`) pass. The niri
config owner is decided: chezmoi owns `home/dot_config/niri/config.kdl`
(6fb82ee, 2026-11-21), so no `xdg.configFile` allowlist change (rule 11) is
needed. Keep the chezmoi collision check (rule 12) so no Home Manager or NixOS
declaration writes the same target.

## Owned files
- ops/validate-config.sh
- tests/bash/validate-config.bats

## Findings
- VERIFIED: rule 6 (`ops/validate-config.sh:464-514`) bans non-allowlisted `programs.<x>.enable` in NixOS modules too, pinned by `tests/bash/validate-config.bats:226-232`. `programs.niri.enable` in `nix/modules/nixos` would fail.
- VERIFIED: rule 11 (`ops/validate-config.sh:577-608`) is an `xdg.configFile` allowlist; `xdg.configFile."niri/config.kdl"` would fail.
- VERIFIED: HM `wayland.windowManager.niri` is not covered by rule 6, but it does not avoid rule 11: pinned HM (82ce401) `modules/services/window-managers/niri.nix:221` itself writes `xdg.configFile."niri/config.kdl"`, and rule 13 (`bash ops/validate-config.sh --eval`, about `:776-860`) checks evaluated xdg keys against the same `ALLOWED_XDG_KEYS` (`:582`) as rule 11. Either route therefore needs `niri/config.kdl` allowlisted.
- VERIFIED (HM master; 404 on release-26.05; pinned HM is master): `wayland.windowManager.niri` exists with settings, extraConfig and checkConfig. The report's `programs.niri` for HM is REFUTED.
- Owner-decision inputs (side effects of the HM module, pinned HM 82ce401):
  - enables HM `xdg.portal` when `portalPackage` is non-null (default xdg-desktop-portal-gnome; `niri.nix:199-203`), which writes extra `xdg.configFile` portal entries only if `xdg.portal.config` is set (default `{}`; `modules/misc/xdg/portal.nix:75-77,182-189`), adds `configPackages` (niri) to `home.packages` (`portal.nix:172`, another duplicate), and sets `NIX_XDG_DESKTOP_PORTAL_DIR` in systemd user session variables (`portal.nix:173-180`), affecting the GNOME session too;
  - adds niri to `home.packages` and `systemd.user.packages` (`niri.nix:192-197`), duplicating NixOS `programs.niri`;
  - `systemd.enable` asserts a non-null package (`niri.nix:179-180`); `checkConfig` needs one too (`niri.nix:183`).
  - VERIFIED (pinned HM `niri.nix:56,192-201`): by default the HM module installs niri, xwayland-satellite (`xwaylandSatellitePackage`) and the gnome portal.
  - Mitigation options (listed, not decided): set `package`, `xwaylandSatellitePackage` and `portalPackage` to null; or use a plain allowlisted `xdg.configFile`.
  - This is a one-owner issue: portals, package and units must have a single owner (NixOS module vs HM module).
- The change in `validate-config.bats:226-232` is a deliberate policy change, not a weakening; record the reason in the commit and test comment.

## Acceptance criteria
- Bats for validate-config pass with new cases:
  - NixOS `programs.niri` allowed.
  - HM `programs.<x>` still denied.
  - an `xdg.configFile."niri/config.kdl"` (or the HM niri module writing it) is still rejected, because chezmoi owns that target.
- `bash ops/validate-config.sh --eval` passes with chezmoi as the config owner.
- Evaluating the system and home configs shows exactly one owner each for the niri package, the niri user systemd units, xwayland-satellite and the XDG portal config.
- Rule 12 collision check still active.
- `bash ops/validate-config.sh` passes on the repo.

## Open checks
- Owner of the niri package, the niri user units, xwayland-satellite and the portals: the pilot uses the NixOS `programs.niri` module (`nix/hosts/linux-desktop-pilot/system.nix`); confirm one owner each.

## Historical alternatives (not chosen)
- Home Manager `wayland.windowManager.niri` module, or a raw HM `xdg.configFile."niri/config.kdl"`: both would need rule 11 changes; replaced by the chezmoi owner.
- A system-wide `/etc/niri/config.kdl` (proposed in docs/plans/niri-two-pc-pilot.md): not chosen.

## Progress
- 2026-11-21 documentation audit (applied above): the body treated the niri config owner as undecided; it is decided by implementation: chezmoi owns `home/dot_config/niri/config.kdl` (6fb82ee). Record the Home Manager and `/etc/niri` options as historical alternatives; no Home Manager or NixOS declaration may write the same KDL target; validator tests must cover the chosen path.
