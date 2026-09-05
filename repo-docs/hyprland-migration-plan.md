# Migration Plan — GNOME → Hyprland

> Home: `repo-docs/hyprland-migration-plan.md`
> Status: planning document. No code changes are authorized by this file alone.
> GNOME stays the default login until a single revertable cutover commit (Phase 6).
> Sibling docs: niri plan = `migration-plan.md` (repo root); decision doc =
> `repo-docs/niri-vs-hyprland-comparison.md`; originating deferral =
> `repo-docs/future-upgrade-plan.md` §12 ("Hyprland vs GNOME+Vicinae — deferred").

This plan mirrors the niri plan's structure and was built from direct repository
evidence (see "Verified Facts"). Claims grounded only in upstream guidance — the
**NixOS Wiki "Hyprland"** (last edited 2026-05-27) and the **Hyprland Wiki Nix
pages** — are labelled `BEST-PRACTICE`. Anything provable from neither the repo
nor that guidance is labelled `UNVERIFIED` and routed through GATE 0 rather than
asserted as fact.

> **TOP RISK (read first): Hyprland's config format is mid-transition.** Hyprland
> **v0.55 introduced and now recommends Lua** for configuration; plain-text
> `hyprland.conf`/hyprlang support is slated for removal in a future release, and
> **Home-Manager support for the Lua config is still "in progress"** (NixOS Wiki
> outdated-notice, May 2026 — `UNVERIFIED` exact timeline). This is the single
> biggest delta vs niri (whose typed KDL is stable + build-validated). See the
> dedicated callout in §10 and the matrix row in §11. Mitigation is baked in: pin
> a known-good nixpkgs Hyprland and prefer a config surface that survives the
> transition.

---

## 0. Relationship to existing repo decisions

- `repo-docs/future-upgrade-plan.md` **§12** already evaluated GNOME+Vicinae vs
  Hyprland+Vicinae and **deferred** Hyprland ("deferred, not rejected"), gated on
  **item #6 (mkSystem + `nixosConfigurations`)** landing first. **This plan is the
  execution path for that deferred decision.**
- `migration-plan.md` (repo root) is the **parallel** active compositor plan
  (GNOME → niri). These two plans are mutually exclusive end-states; pick one via
  `repo-docs/niri-vs-hyprland-comparison.md` before executing either past GATE 0.
- In-code comments at `nix/modules/home/gui.nix:87` and
  `nix/modules/home/gnome-extensions.nix:40` already name Hyprland as the
  alternative and point at `future-upgrade-plan.md item #12`; those pointers are
  reconciled in Phase 6 (same as the niri plan's Phase 6 comment reconciliation).

---

## 1. Goals

1. **Complete the architecture** — add an in-repo `nixosConfigurations` host so a
   system-level compositor (`programs.hyprland`) can be owned. The repo today
   exposes only `homeConfigurations` (+ `darwinConfigurations.macos`).
2. **Migrate GNOME → Hyprland** safely, additively, with GNOME selectable as a
   fallback at the greeter until a single revertable cutover commit (Phase 6).
3. **Adopt the first-party hypr\* ecosystem** (hyprlock, hypridle, hyprpaper,
   hyprpolkitagent, hyprsunset, hyprpicker) on a cohesive renderer, with Waybar +
   notifications + screenshot tooling on top.
4. **Hold the config surface stable through the Lua transition** — pin a
   known-good nixpkgs Hyprland and choose a config owner that survives the
   `hyprland.conf` → Lua change (see §10). `BEST-PRACTICE`.

Non-goals: deleting chezmoi, deleting generated adapter surfaces, owning the niri
stack in parallel, or any change to secrets/auth/billing.

---

## 2. Verified Facts (proven against this repo)

| Fact | Evidence |
|---|---|
| `nix/flake.nix` exposes only `homeConfigurations` + `darwinConfigurations.macos`; **no `nixosConfigurations`** | `nix/flake.nix:83-104`; `rg nixosConfigurations nix/` → none |
| Inputs: nixpkgs **unstable**, home-manager, nix-darwin, treefmt-nix, vicinae, vicinae-extensions | `nix/flake.nix:4-39` |
| Validator **rule 6** bans `programs.<x>.enable = true` across **all** of `nix/modules` (not home-only) | `ops/validate-config.sh` (rule 6 block) |
| Validator **rule 9** REQUIRES `repo-docs/migration-source-of-truth.md` and `repo-docs/migration-package-ownership.md` to exist | `ops/validate-config.sh:106` |
| Validator **rule 10** fails the build on any **untracked `*.nix`** under `nix/` | `ops/validate-config.sh:124` (`git ls-files --others`) |
| `nix/modules/nixos/` holds only browser-policies, default, dual-boot, substituters, timezone — **orphaned** (no nixos host imports them) | `ls nix/modules/nixos/`; no `nixosConfigurations` in flake |
| `nix/hosts/linux-desktop/home.nix:8-10` imports the three `gnome-*.nix` modules | `nix/hosts/linux-desktop/home.nix:8-10` |
| Current desktop = GNOME (`gnome-extensions/files/keybindings.nix` + GNOME bits in `gui.nix`) | `ls nix/modules/home/` |
| Vicinae is integrated (`services.vicinae`) and is **compositor-agnostic** (spawns `vicinae server` under Wayland) | `nix/flake.nix:22-30`; `nix/modules/home/vicinae.nix` |
| Repo philosophy: prefer the **nixpkgs (Hydra-cached) binary** over source compiles | `nix/flake.nix:22-29` (Vicinae note) |
| **No Hyprland config/dotfile exists today** — only doc/comment mentions; greenfield for ownership | `rg -i hypr` → only `future-upgrade-plan.md §12`, `gui.nix:87`, `gnome-extensions.nix:40`, `substituters.nix:16`, doc lists |
| `nix/modules/nixos/substituters.nix:16` already anticipates a hyprland cache | `nix/modules/nixos/substituters.nix:16` |
| `bash ops/validate-config.sh` and `nix flake check` currently PASS | confirmed baseline this session |

`BEST-PRACTICE` (NixOS Wiki "Hyprland" 2026-05-27 / Hyprland Wiki — not repo-proven):

- `programs.hyprland = { enable = true; withUWSM = true; xwayland.enable = true; };`
  auto-enables polkit, `xdg-desktop-portal-hyprland`, graphics drivers, fonts,
  dconf, Xwayland, and adds a Desktop Entry to the display manager.
- **UWSM** (Universal Wayland Session Manager) is the **recommended** launch
  method since NixOS 24.11; it integrates the session with systemd and cleanly
  solves the `WAYLAND_DISPLAY`/systemd-environment problem (the Hyprland analogue
  of the niri plan's "Ly env-gate").
- **nixpkgs `pkgs.hyprland` is Hydra-cached** (no recompile). The upstream flake
  `github:hyprwm/Hyprland` is bleeding-edge but recompiles Hyprland + deps unless
  `hyprland.cachix.org` is enabled, and risks a mesa-version mismatch on a stable
  channel. This repo tracks **nixpkgs-unstable** (`flake.nix:5`), which keeps the
  nixpkgs build fresh and *reduces* — not removes — the flake's mesa-mismatch
  motivation.

`UNVERIFIED` (route through GATE 0 / treat as a moving target):

- Exact release that removes `hyprland.conf`/hyprlang support, and the current
  state of Home-Manager Lua-config support (wiki says "in progress", May 2026).
- Whether Vicinae runs on Hyprland **without** `gnomeExtensions.vicinae` — it uses
  the wlr-layer-shell path, marked "unverified live" at `future-upgrade-plan.md:267`.

---

## 3. Architecture (target ownership model)

| Concern | Owner | Notes |
|---|---|---|
| Display manager, session registration, Hyprland package, portals, polkit, PipeWire, graphics, fonts, Xwayland | **NixOS** | system substrate; HM cannot own cleanly. `programs.hyprland` auto-wires most of it. |
| Input, networking, timezone, dual-boot, substituters, browser policies | **NixOS** | modules already exist under `nix/modules/nixos/` |
| `hypr/hyprland.conf` (or `settings`), Waybar, mako/swaync, hypridle/hyprlock, hyprpaper, hyprsunset/hyprpicker, user apps, shell, git, nvim | **Home Manager** | raw files via `xdg.configFile` **or** the `wayland.windowManager.hyprland` module — pick ONE |
| Cross-platform raw dotfiles, macOS Karabiner, Windows `*.ps1`, non-Nix fallback | **chezmoi** | demoted, not deleted |
| Bootstrap, validation, migration glue | **ops/** | not dotfile ownership |

**Hyprland enablement lives in `nix/modules/nixos/` (`programs.hyprland.enable`),
NOT in `nix/modules/home/`** — validator rule 6 bans `programs.<x>.enable` across
all of `nix/modules`, so the compositor's enable cannot live in `home/`. Its
config ships from Home Manager. Re-scope rule 6 to `nix/modules/home/` only in the
**same commit** as the new nixos module (Phase 1).

**All Hyprland/Linux Nix pieces must be `lib.optionals stdenv.hostPlatform.isLinux` no-ops** so
the Darwin (`darwinConfigurations.macos`) build still evaluates.

---

## 4. Invariants (do not violate)

1. **One file, one owner.** Never let chezmoi and Home Manager own the same file.
   Hyprland config is greenfield (no `hypr*` path exists today) — keep it HM-only.
2. **`programs.hyprland.enable` goes in `nix/modules/nixos/`**, never in
   `nix/modules/home/` (validator rule 6).
3. **Never delete** `repo-docs/migration-source-of-truth.md` or
   `repo-docs/migration-package-ownership.md` (validator rule 9 fails the build).
4. **`git add` every new `*.nix`** before validating (rule 10 — flakes ignore
   untracked files).
5. **GNOME is deleted last**, behind a single revertable commit (Phase 6).
6. **Exactly one launch path** per service — one polkit agent (hyprpolkitagent),
   one Waybar, one notification daemon, one idle daemon. `BEST-PRACTICE`.
7. **UWSM ⇒ disable the HM systemd integration:** if config comes from the
   `wayland.windowManager.hyprland` module, set
   `wayland.windowManager.hyprland.systemd.enable = false;` — it conflicts with
   UWSM. `BEST-PRACTICE`.
8. **Pin a known-good nixpkgs Hyprland** and treat the config format as a moving
   target (Lua transition, §10). `BEST-PRACTICE`.
9. Approval required before secrets, destructive changes, or the NixOS system
   layer apply (`nixos-rebuild switch`).

---

## 5. GATE 0 — Read-only discovery (mandatory, BLOCKING, zero deletions)

Prove ownership and references before touching anything. Nothing here mutates the repo.

Re-confirm the verified facts still hold:

- [ ] `rg -n 'programs\.\w+\.enable' ops/validate-config.sh` — rule 6 scope
- [ ] `rg -n 'git ls-files|--others|untracked' ops/validate-config.sh` — rule 10 gate
- [ ] `rg -n 'migration-source-of-truth|migration-package-ownership' ops/validate-config.sh` — rule 9
- [ ] `rg -n 'nixosConfigurations' nix/` — confirm none
- [ ] `rg -in 'hypr' .` — confirm only doc/comment mentions (greenfield)
- [ ] Read `repo-docs/future-upgrade-plan.md` §12 — confirm the item #6 dependency

Resolve before acting:

- [ ] **Decide niri vs Hyprland** via `repo-docs/niri-vs-hyprland-comparison.md`
      (the two plans are mutually exclusive end-states)
- [ ] Confirm Vicinae runs on Hyprland **without** `gnomeExtensions.vicinae`
      (`UNVERIFIED` — `future-upgrade-plan.md:267`)
- [ ] Lock the config surface: typed `settings` vs raw symlink (§10 hedge)

**Exit criterion:** compositor decision recorded, item #6 dependency acknowledged,
config-surface owner chosen. No decision → no Phase 1.

---

## 6. Track B — Hyprland migration (additive; GNOME safe until Phase 6)

### Default component choices (swap if preferred)

| Slot | Default | Alternative |
|---|---|---|
| Display manager | greetd + tuigreet (or SDDM) | GDM (**kept until cutover**); Ly (works, not recommended) |
| Session launch | **UWSM** (`programs.hyprland.withUWSM = true`) | bare `Hyprland` session |
| Compositor package | **nixpkgs `pkgs.hyprland`** (Hydra-cached) | upstream `github:hyprwm/Hyprland` + `hyprland.cachix.org` |
| Config surface | HM `wayland.windowManager.hyprland.settings` (generates `hyprland.conf`) | raw `xdg.configFile."hypr/hyprland.conf"` / `mkOutOfStoreSymlink` |
| Bar / tray | Waybar | — |
| Notifications | mako | swaync |
| Idle / lock | **hypridle + hyprlock** | swayidle + swaylock |
| Wallpaper | hyprpaper | swww |
| Polkit agent | **hyprpolkitagent** (ONE only) | polkit-kde / lxqt-policykit |
| Blue-light / picker | hyprsunset / hyprpicker | gammastep / — |
| Screenshots | **grim + slurp + satty** (Hyprland has no native screenshot) | grimblast |
| Portal file-picker | `xdg-desktop-portal-hyprland` (auto) + gtk | — |

### Phase 0 — Pre-flight

- [ ] `git checkout -b feat/hyprland-migration`; confirm GNOME login is the baseline
- [ ] Record decision: niri-vs-Hyprland resolved to **Hyprland** (GATE 0)
- [ ] Lock: DM = `__________`  |  package = `__________` (nixpkgs default)  |
      config surface = `__________` (typed vs raw symlink, §10)
- [ ] Inventory GNOME-locked surface removed in Phase 6:
      `gnome-keybindings.nix` (256L), `gnome-extensions.nix` (53L),
      `gnome-files.nix` (28L, 2 GTK keys to migrate), GNOME bits in `gui.nix` (369L),
      imports at `nix/hosts/linux-desktop/home.nix:8-10`
- [ ] Confirm kept: `nix/modules/home/default-apps.nix` (pure XDG)

### Phase 1 — NixOS system layer (additive; GNOME still default)

- [ ] Add `nix/hosts/linux-desktop/system.nix`; wire `nix/modules/nixos/default.nix`
- [ ] Add `nix/modules/nixos/desktop-hyprland.nix`:
      `programs.hyprland = { enable = true; withUWSM = true; xwayland.enable = true; };`
      `programs.hyprland.package = pkgs.hyprland;` (nixpkgs-first) `BEST-PRACTICE`
- [ ] Add `nix/modules/nixos/display-manager.nix` (greetd/SDDM; **do not** disable GDM yet)
- [ ] Add `environment.sessionVariables.NIXOS_OZONE_WL = "1";` (Electron/Chromium native Wayland)
- [ ] Add `security.pam.services.hyprlock = {};` (so hyprlock can unlock)
- [ ] Add `nixosConfigurations.linux-desktop` to `nix/flake.nix`
- [ ] **Re-scope validator rule 6** to `nix/modules/home/` only (same commit)
- [ ] **`git add` every new `*.nix`** (rule 10)
- [ ] Build only:
      `sudo nixos-rebuild build --flake .#linux-desktop`
      `nix build .#homeConfigurations.linux-desktop.activationPackage`
      `bash ops/validate-config.sh`

### Phase 2 — Activate + capture hardware

- [ ] `sudo nixos-rebuild test --flake .#linux-desktop`
- [ ] Confirm BOTH "GNOME" and "Hyprland" sessions appear at the greeter
- [ ] **UWSM env check:** in Hyprland, `systemctl --user show-environment | grep WAYLAND_DISPLAY`
      must be populated (UWSM should make this pass cleanly; if empty, confirm
      `withUWSM = true` took effect). Result: `__________`
- [ ] Capture real outputs: `hyprctl monitors` → `__________`
- [ ] `sudo nixos-rebuild switch --flake .#linux-desktop` once sessions select cleanly

### Phase 3 — Hyprland config via Home Manager

- [ ] Add `nix/modules/home/hypr/` owning the config (ONE surface):
      - typed: `wayland.windowManager.hyprland.settings = { … };`
        **with `wayland.windowManager.hyprland.systemd.enable = false;`** (UWSM conflict), or
      - raw: `xdg.configFile."hypr/hyprland.conf".source = ./hyprland.conf;`
        (or `mkOutOfStoreSymlink`) — the Lua-transition hedge (§10)
- [ ] `monitor = …` blocks parameterised from captured `hyprctl monitors`
- [ ] Keyboard: `input { kb_layout = us,ru; kb_options = grp:win_space_toggle; }`
- [ ] `exec-once = vicinae server` (compositor-agnostic launcher)
- [ ] hypridle + hyprlock config; hyprpaper wallpaper

### Phase 4 — Wayland service graph (BEFORE any GNOME deletion)

- [ ] Portals: `xdg-desktop-portal-hyprland` (auto via module) + gtk file-picker
- [ ] polkit + **exactly one** polkit agent (`hyprpolkitagent`)
- [ ] PipeWire, graphics, fonts (auto via `programs.hyprland`; verify) `BEST-PRACTICE`
- [ ] Waybar (HM) — **one launch path**; mako/swaync (HM) — **one launch path**
- [ ] Verify: file dialog, screen-share picker, polkit prompt, notification, lock

### Phase 5 — Launcher, screenshots, shortcut parity

- [ ] `vicinae.nix`: drop GNOME assumptions; deeplink binds; add VS Code extension
- [ ] Translate all `gnome-keybindings.nix` shortcuts into Hyprland `bind =` lines
- [ ] Screenshots: grim + slurp + satty (no Hyprland-native shot); hyprpicker; hyprsunset
- [ ] Native resize/move binds replace the GNOME Vicinae-extension resize script
      (`future-upgrade-plan.md §12`); drop `gnomeExtensions.vicinae`

### Phase 6 — GNOME cutover (SINGLE revertable commit — the real Nix thinning)

- [ ] Make Hyprland the default session; disable GDM
- [ ] Migrate the 2 GTK keys out of `gnome-files.nix`
- [ ] Delete `gnome-keybindings.nix`, `gnome-extensions.nix`, `gnome-files.nix`
- [ ] Strip GNOME from `gui.nix`; drop dead imports from `linux-desktop/home.nix:8-10`
- [ ] Reconcile the `future-upgrade-plan.md item #12` comment pointers at
      `gui.nix:87` and `gnome-extensions.nix:40` in the SAME commit
- [ ] Keep `default-apps.nix`
- [ ] `sudo nixos-rebuild switch --flake .#linux-desktop` +
      `nix build .#homeConfigurations.linux-desktop.activationPackage`

### Phase 7 — Validation & reconcile

- [ ] Validator: hypr config present, no orphaned `gnome*` refs
- [ ] All Hyprland/Linux pieces are `lib.optionals stdenv.hostPlatform.isLinux` no-ops on Darwin
- [ ] chezmoi reconciliation: confirm no file owned by both chezmoi and HM
- [ ] `bash ops/validate-config.sh && mise run repo:check && mise run test:bash`
- [ ] Update `repo-docs/migration-decisions.md` /
      `repo-docs/architecture/tool-ownership.md` with the final split; update
      `future-upgrade-plan.md §12` status from "deferred" to "adopted"
- [ ] (Optional) `tests/bash/hyprland-*.bats` smoke tests + CI gate

---

## 7. Execution Order

1. **GATE 0** — read-only; resolve niri-vs-Hyprland; acknowledge item #6 (BLOCKING)
2. **Phase 0** — branch, lock component + config-surface decisions
3. **Phases 1–5** — additive, GNOME safe at the greeter
4. **Phase 6** — cutover (single revertable commit; this is what thins the Nix layer)
5. **Phase 7** — validation + reconcile docs

---

## 8. Rollback Playbook

| Phase | Undo |
|---|---|
| GATE 0 / Phase 0 | Read-only / branch only; nothing to undo |
| Phase 1 | Build-only; nothing to undo |
| Phases 2–5 | Pick **GNOME** at the greeter; `sudo nixos-rebuild --rollback`; rebuild prior HM generation |
| Phase 6 | `git revert <cutover commit>` + rebuild, or boot the previous NixOS generation |
| Package/cache regret | Re-pin nixpkgs Hyprland; drop the upstream flake input + its cachix |
| Lua-format breakage | Roll back to the pinned nixpkgs Hyprland; keep a raw `hyprland.conf` symlink (§10) |

---

## 9. Success Signals (definition of done)

- Greeter shows Hyprland as default; Hyprland starts cleanly under UWSM
- `systemctl --user show-environment` shows `WAYLAND_DISPLAY` (UWSM env OK)
- Every translated bind fires; xkb layout toggle works from one bind
- Native window resize/move works without the GNOME extension/script
- Vicinae launcher + clipboard history work; VS Code extension present
- File dialog, screen-share picker, **one** polkit prompt, notifications, hyprlock all work
- Screenshots work (grim + slurp + satty)
- All external monitors + laptop panel detected at correct scale (`hyprctl monitors`)
- `bash ops/validate-config.sh && mise run repo:check && mise run test:bash` all green
- GNOME surface = 0 (no `gnome*` modules, no GNOME refs); chezmoi retained cross-platform
- `future-upgrade-plan.md §12` updated from "deferred" to "adopted"

---

## 10. Risk callout — Hyprland config-format transition (conf → Lua)

> **This is the single biggest delta vs niri and the highest-signal risk in this plan.**

- **What:** Hyprland **v0.55** introduced and now **recommends Lua** for config.
  Plain-text `hyprland.conf`/hyprlang is slated for removal in a future release.
  **Home-Manager Lua-config support is still "in progress"** (NixOS Wiki
  outdated-notice, May 2026). `UNVERIFIED` exact timeline. `BEST-PRACTICE` source.
- **Why it matters here:** the HM `wayland.windowManager.hyprland.settings`
  generator currently emits **`hyprland.conf` syntax**. When Lua becomes
  mandatory, the typed generator may need rework, and HM may lag upstream.
  niri's typed KDL (`programs.niri.settings`, validated by `niri validate` at
  build) has no equivalent in-flight transition — see the comparison doc.
- **Mitigations baked into this plan:**
  1. **Pin a known-good nixpkgs Hyprland** (do not float to upstream HEAD).
  2. **Prefer the raw config surface as a hedge:** `xdg.configFile."hypr/hyprland.conf"`
     / `mkOutOfStoreSymlink` ships *whatever syntax you author* (conf today, Lua
     later) **without** depending on the HM generator keeping pace. The typed
     `settings` path gives nicer validation today but more transition exposure.
     Decision: `__________`.
  3. **Watch the HM module + NixOS Wiki Hyprland page** for the Lua landing; treat
     a Hyprland bump as a config-format review, not a routine update.
  4. Keep the cutover (Phase 6) a single revertable commit so a format break is a
     `git revert` + nixpkgs re-pin, not a rebuild from scratch.

---

## 11. Tooling & edge-case matrix

| Edge case | Risk | Required handling |
|---|---|---|
| New `*.nix` left untracked | rule 10 FAILS build | `git add` every module before `validate-config.sh` |
| `programs.hyprland.enable` placed in `nix/modules/home/` | rule 6 FAILS | enable goes in `nix/modules/nixos/` only |
| Re-scope rule 6 too early/late | false-positive or missed ban | re-scope in Phase 1, same commit as the nixos module |
| HM `systemd.enable` left `true` under UWSM | session/env conflict (double session, broken `WAYLAND_DISPLAY`) | set `wayland.windowManager.hyprland.systemd.enable = false;` |
| **Lua config transition** | `hyprland.conf` deprecated; HM Lua support in progress | **TOP RISK** — §10: pin nixpkgs Hyprland; prefer raw-symlink hedge; watch HM module |
| Two polkit agents launched | double agent | exactly ONE (`hyprpolkitagent`) launch path |
| Two launch paths for Waybar | duplicate bar | exactly one launch path |
| hyprlock cannot unlock | locked out of session | `security.pam.services.hyprlock = {};` |
| `hyprpm` used to install plugins | unsupported on NixOS, breaks | HM `wayland.windowManager.hyprland.plugins = [ pkgs.hyprlandPlugins.<name> ];`; first-party plugins need the Hyprland flake with `hyprland-plugins.inputs.hyprland.follows = "hyprland"` |
| Upstream Hyprland flake without cache | long recompile + mesa mismatch on stable | prefer the nixpkgs binary; if flake, enable `hyprland.cachix.org`. Repo tracks **nixpkgs-unstable** (`flake.nix:5`), lowering — not removing — the mismatch motivation |
| Electron/Chromium runs XWayland (blurry) | apps not native Wayland | `environment.sessionVariables.NIXOS_OZONE_WL = "1";` |
| No Hyprland-native screenshot (unlike niri) | screenshot silently missing | ship grim + slurp + satty in Phase 5 |
| Darwin host evaluates Hyprland/Linux modules | macOS build breaks | wrap Linux pieces in `lib.optionals stdenv.hostPlatform.isLinux` |
| chezmoi + HM both own a hypr file | dual ownership | greenfield; keep hypr config HM-only (Phase 7 check) |
| `programs.hyprland` auto-enables differ from expectation | missing portal/polkit/driver | confirm what the module wired (`BEST-PRACTICE` list is wiki-sourced, not repo-proven) |

**Verification commands (repo-canonical):**

```
bash ops/validate-config.sh
mise run repo:check
mise run test:bash
```

---

## 12. chezmoi — standing rule

Keep chezmoi owning: `home/dot_config/karabiner/karabiner.json` (macOS),
cross-platform VS Code templates, Windows `*.ps1` scripts, and any future non-Nix
Linux fallback dotfiles. Long-term target: Nix/NixOS/nix-darwin ~75–85%, chezmoi
~15–25%, ops = bootstrap/validation only. The one invariant: **a given file has
exactly one owner.** Hyprland introduces no chezmoi overlap (greenfield — no
`hypr*` path exists today; keep `hyprland.conf` HM-only).

---

## 13. Implementer handoff

This plan is **read-only / planning**. Before writing code the implementer MUST:

- Resolve niri-vs-Hyprland (`repo-docs/niri-vs-hyprland-comparison.md`) and record it.
- Confirm **item #6 (`nixosConfigurations`)** is in scope — Hyprland depends on it
  (`future-upgrade-plan.md §12`), exactly as the niri plan's Phase 1 does.
- Fill the `__________` blanks: DM, package, config surface (typed vs raw), UWSM
  env result, `hyprctl monitors`.
- Author (Phase 1+): `nix/hosts/linux-desktop/system.nix`,
  `nix/modules/nixos/desktop-hyprland.nix`, `nix/modules/nixos/display-manager.nix`,
  portals/audio-graphics modules,
  `nix/modules/home/hypr/{default.nix,hyprland.conf|settings}`; add
  `nixosConfigurations.linux-desktop`; re-scope rule 6; `git add` all new `*.nix`.
- Record failed or blocked verification in `repo-docs/migration-followups.md`.
