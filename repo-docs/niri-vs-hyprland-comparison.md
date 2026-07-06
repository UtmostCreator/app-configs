# niri vs Hyprland — Compositor Decision for app-configs

> Home: `repo-docs/niri-vs-hyprland-comparison.md`
> Status: decision / comparison document. No code changes are authorized by this file alone.
> Plans compared: **niri** = `migration-plan.md` (repo root);
> **Hyprland** = `repo-docs/hyprland-migration-plan.md`.
> Originating deferral / prior scoring: `repo-docs/future-upgrade-plan.md` §12.

This is a **decision framework, not a forced verdict.** Both compositors are
viable for this repo and both have a write-ready migration plan. Claims grounded
only in upstream guidance (NixOS/Hyprland/niri wikis + the niri-flake README) are
labelled `BEST-PRACTICE`; anything not provable from the repo or that guidance is a
**judgement call**.

---

## Shared context for THIS repo (the ties)

Both options start from the same place, so several axes are a **tie**:

- **No `nixosConfigurations` yet** (`nix/flake.nix:83-104`). *Either* compositor
  requires adding an in-repo NixOS host first — this repo's `future-upgrade-plan.md`
  calls that **item #6 (mkSystem + nixosConfigurations)**, and §12 makes Hyprland
  explicitly depend on it. niri needs the same system layer. **Tie.**
- **GNOME is the default today** and stays default until a single revertable
  cutover commit in either plan. **Tie.**
- **Vicinae is already integrated** (`services.vicinae`, `nix/modules/home/vicinae.nix`)
  and is **compositor-agnostic** — it spawns `vicinae server` under Wayland and
  works on both. (Hyprland-on-Vicinae "live" is `UNVERIFIED` per
  `future-upgrade-plan.md:267`; niri drops the GNOME extension too.) **~Tie.**
- **Repo philosophy: prefer the nixpkgs (Hydra-cached) binary** over source
  compiles (`nix/flake.nix:22-29`). Applies equally; recommends the nixpkgs
  package for both. **Tie.**
- **Greenfield, no chezmoi overlap** for either (`rg -i niri` / `rg -i hypr` find
  only docs/comments, never a config/dotfile). **Tie.**

So the decision turns on the **non-tied** axes below.

---

## Axis-by-axis

| Axis | niri | Hyprland | Edge |
|---|---|---|---|
| **Layout paradigm** | Scrollable-tiling: columns + infinite horizontal scroll | Dynamic tiling + floating + workspaces + eye-candy | preference |
| **Nix config maturity** | KDL via niri-flake `programs.niri.settings` — **typed, build-validated (`niri validate`), STABLE** | `hyprland.conf` → **Lua transition IN FLUX**; HM Lua support "in progress" | **niri** |
| **Ecosystem cohesion** | smithay-based; reuses sway\* tools (swaylock/swayidle/mako/waybar/swaybg + xwayland-satellite) | Independent renderer + **first-party hypr\* suite** (hyprlock/hypridle/hyprpaper/hyprpolkitagent/hyprsunset/hyprpicker) | **Hyprland** |
| **Animations / eye-candy** | Minimal, functional | Blur, animations, shadows — rich | **Hyprland** |
| **Pace of change / breakage risk** | Leaner, calmer, slower-moving | Richer, faster-moving, more surface to break | **niri** |
| **Session / systemd integration** | `niri-session` (plan flags an env-gate to verify) | **UWSM** (`withUWSM`) integrates systemd cleanly | slight **Hyprland** |
| **Screenshots** | niri-native + satty | No native shot → grim + slurp + satty | slight **niri** |
| **Packaging / caching** | nixpkgs `pkgs.niri` (cached) + `niri.cachix.org`; `overlays.niri` keeps mesa in sync | nixpkgs `pkgs.hyprland` (cached) + `hyprland.cachix.org` | tie (nixpkgs for both) |
| **Plugins** | Less central to the WM | HM `plugins = [...]`; `hyprpm` unsupported on NixOS; flake-follows needed | Hyprland (with caveats) |
| **Migration blast radius (this repo)** | Compositor swap + new NixOS host | Compositor swap + new NixOS host | tie |
| **Existing plan detail** | Repo-root plan, detailed | New plan, parity-level detail | tie |

`future-upgrade-plan.md §12` independently scored a related GNOME-vs-Hyprland
matrix (resize 95, resize-stability 90, but "maintainability in THIS repo" 30 and
"migration/rollback" 40). Its concern was the **system-layer ownership cost** —
which the `nixosConfigurations` work (item #6) pays down for **either** compositor,
neutralising that particular objection once item #6 lands.

---

## The deciding axis: Nix config maturity

This is where the two genuinely diverge for a Nix-first repo:

- **niri** ships a **stable, typed, build-validated** config path. niri-flake's
  `programs.niri.settings` generates KDL and is checked by `niri validate` at
  build time; `overlays.niri` exposes `niri-stable`/`niri-unstable` and keeps
  **mesa in sync**; `niri.cachix.org` caches builds. The existing niri plan chose
  nixpkgs `pkgs.niri` + raw KDL via `xdg.configFile."niri/config.kdl".source` —
  NixOS-cached, one owner, best-practice-aligned. `BEST-PRACTICE`.
- **Hyprland** is **mid-transition**: v0.55 introduced and now recommends **Lua**;
  `hyprland.conf`/hyprlang is slated for removal; **HM Lua support is "in
  progress"** (NixOS Wiki, May 2026, `UNVERIFIED` timeline). The HM `settings`
  generator currently targets `hyprland.conf` syntax and may need rework when Lua
  lands. The Hyprland plan hedges with a pinned nixpkgs build + a raw-symlink
  config surface, but the format itself is a moving target. `BEST-PRACTICE`.

For a repo whose stated values are **smallest safe change**, **nixpkgs-binary
first**, and **stability/maintainability** (`future-upgrade-plan.md §12`), config
maturity weighs toward **niri** today.

---

## niri plan: best-practice deltas to fold in

The niri plan at `migration-plan.md` is **not edited here** — these are additions
to apply when that plan is executed, surfaced from current upstream guidance
(`BEST-PRACTICE`, niri wiki / niri-flake):

1. **greetd PATH gotcha:** set `systemd.user.services.niri.enableDefaultPath = false;`
   so niri inherits the full PATH from `niri-session` (else spawned tools lose PATH).
2. **IME on Electron:** pass `--wayland-text-input-version=3` — niri lacks
   text-input-v1, so IME in Electron apps needs the v3 flag.
3. **File-picker portal:** `xdg.portal.config.niri."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];`
   to use the GTK picker and avoid pulling in the Nautilus dependency.
4. **Upstream repo moved** to `niri-wm/niri` (update any pinned source URLs).

Cross-reference: the niri plan's own "Ly env-gate" (its Phase 2) and item 1 above
solve the **same class** of systemd-session-environment problem that **UWSM**
solves out of the box on the Hyprland side.

---

## Decision framework

**Choose niri if:**

- Config **stability + build-time validation** matters most (typed KDL, `niri validate`).
- You want the **lower-risk migration today** (mature, stable Nix integration; the
  niri-flake overlay keeps mesa in sync; the repo-root plan is already detailed).
- You prefer a **leaner, calmer** stack with less upgrade churn on the WM piece.
- **Scrollable / columns** tiling fits your workflow.

**Choose Hyprland if:**

- **Dynamic tiling + floating + animations / eye-candy** are primary value.
- You want a **cohesive first-party ecosystem** (hypr\* suite) on one renderer.
- You want **UWSM / systemd** session integration out of the box.
- You accept the **config-format flux** (conf → Lua, HM support in progress) and
  will **pin + watch** (Hyprland plan §10 hedge).
- **Fine-grained per-output config + window rules** matter day to day.

---

## Recommendation (judgement call — not a forced verdict)

Weighing this repo's **own stated priorities** — smallest safe change,
nixpkgs-binary-first, stability/maintainability (`future-upgrade-plan.md §12`) —
**niri is the lower-risk default today**, almost entirely because its Nix config
integration is **stable and build-validated** while Hyprland's is **mid-transition
to Lua with HM support still in progress**. Both plans are write-ready and both
depend on the same `nixosConfigurations` work, so the system-layer cost is a wash.

**Pick Hyprland instead** when eye-candy, dynamic tiling, and first-party
ecosystem cohesion are the *primary* goal and you accept owning the config-format
transition. This is a **judgement call**; re-evaluate once HM Lua support is
declared stable (which would neutralise niri's main edge).

---

## Cross-links

- niri migration plan: `migration-plan.md` (repo root)
- Hyprland migration plan: `repo-docs/hyprland-migration-plan.md`
- Prior deferral + scoring: `repo-docs/future-upgrade-plan.md` §12
- Ownership model + invariants: both plans' "Architecture" + "Invariants" sections
