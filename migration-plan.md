# Migration Plan — Safe Thinning + niri Migration

> Home: `migration-plan.md` (repo root)
> Status: planning document. No code changes are authorized by this file alone.
> Two tracks, never conflated. **GATE 0 is read-only and BLOCKING — it must pass
> before any deletion.** GNOME stays the default login until Track B Phase 6.

This plan was built from direct repository evidence (see "Verified Facts"). Claims
that could not be proven from the repo are labelled `UNVERIFIED` and routed through
GATE 0 rather than asserted as fact.

---

## 1. Goals

1. **Thin the repo** — remove stale, hand-owned planning docs and old data so the
   tree is easier to parse, without deleting any generated output.
2. **Complete the architecture** — add an in-repo `nixosConfigurations` host so the
   existing orphaned `nix/modules/nixos/*` modules are actually owned.
3. **Migrate GNOME → niri** safely, additively, with GNOME selectable as a fallback
   until the final revertable cutover commit.

Non-goals: deleting chezmoi, deleting generated adapter surfaces, bulk comment
stripping, or any change to secrets/auth/billing.

---

## 2. Verified Facts (proven against this repo)

| Fact | Evidence |
|---|---|
| `nix/flake.nix` exposes only `homeConfigurations` + `darwinConfigurations`; **no `nixosConfigurations`** | `flake.nix:76-105`; `rg nixosConfigurations nix/flake.nix` → none |
| Validator **rule 6** bans `programs.<x>.enable` across **all** of `nix/modules` (not home-only) | `ops/validate-config.sh:69-79` (`rg ... nix/modules`) |
| Validator **rule 10** fails the build on any **untracked `*.nix`** under `nix/` | `ops/validate-config.sh:116-131` (`git ls-files --others`) |
| Validator **rule 9** REQUIRES `repo-docs/migration-source-of-truth.md` and `repo-docs/migration-package-ownership.md` to exist | `ops/validate-config.sh:106-114` |
| `.github/**`, `.opencode/**`, and `docs/ai/package/**` are **generated adapter output** | 92 `GENERATED — DO NOT EDIT` markers across agents, skills, commands |
| `docs/ai/package/CAPABILITY-MODEL.md` (164L) and `docs/ai/package/foundations/CAPABILITY-MODEL.md` (118L) are **different content, not copies** | Read both; distinct opening prose |
| `repo-docs/archive/*` carries **no** generated markers → genuinely hand-owned | Grep found markers only under `package/` and adapter trees |
| niri introduces **no chezmoi overlap** — no `niri` path exists anywhere today | scc dump shows no niri path |

Resolved during read-only investigation (this session):

- `repo-docs/migration-implementation-plan.md` (1,729L) **IS actively referenced** by
  `repo-docs/README.md:33`, `repo-docs/architecture/tool-ownership.md:4`, and
  `repo-docs/migration-followups.md` → **NOT safe to delete**; compress in place only.
- `repo-docs/archive/*` carries **zero** generated markers (Grep) → genuinely hand-owned.
- `nix/hosts/linux-desktop/home.nix:8-10` imports the three `gnome-*.nix` modules
  (confirms Phase 6 must drop these imports).
- `.husky/` does **not** exist (the `migration-followups.md:64` husky cleanup entry is itself stale).

`UNVERIFIED` (still route through GATE 0 before acting):

- Whether `docs/ai/MCP-BOUNDARIES.md` and `docs/ai/package/operations/MCP-BOUNDARIES.md`
  are byte-identical (top-level has no generated marker; package copy is under generated tree).

---

## 3. Architecture (target ownership model)

| Concern | Owner | Notes |
|---|---|---|
| Display manager, session registration, niri package, portals, polkit, PipeWire, Xwayland | **NixOS** | system substrate; HM cannot own cleanly |
| Fonts, input, graphics, networking, timezone, dual-boot, substituters, browser policies | **NixOS** | modules already exist under `nix/modules/nixos/` |
| `niri/config.kdl`, Waybar, mako, swayidle/lock config, user apps, shell, git, nvim | **Home Manager** | raw files via `xdg.configFile` |
| Cross-platform raw dotfiles, macOS Karabiner, Windows scripts, non-Nix fallback | **chezmoi** | demoted, not deleted |
| Bootstrap, validation, migration glue | **ops/** | not dotfile ownership |

**niri enablement lives in `nix/modules/nixos/` (`programs.niri.enable`), NOT in
`nix/modules/home/`.** Its config ships as raw KDL through Home Manager
(`xdg.configFile."niri/config.kdl".source`), which keeps the Home Manager
`programs.<x>.enable` ban intact.

---

## 4. Invariants (do not violate)

1. **One file, one owner.** Never let chezmoi and Home Manager own the same file.
2. **HARD DELETE GATE.** Never delete a file whose first 8 lines contain
   `GENERATED — DO NOT EDIT`, or that any template under
   `packages/ai-universal-rules/templates` or `tools/ai/install` emits. Thin
   generated surfaces at the generator/source, never with `rm`.
3. **Never delete** `repo-docs/migration-source-of-truth.md` or
   `repo-docs/migration-package-ownership.md` (validator rule 9 will fail the build).
4. **`git add` every new `*.nix`** before validating (rule 10).
5. **GNOME is deleted last**, behind a single revertable commit.
6. Approval required before secrets, destructive changes, or the NixOS system layer
   apply (`nixos-rebuild switch`).

---

## 5. GATE 0 — Read-only discovery (mandatory, BLOCKING, zero deletions)

Prove ownership and references before touching anything. Nothing here mutates the repo.

Confirm the verified facts still hold (already confirmed at plan time; re-check if drift suspected):

- [ ] `rg -n 'programs\.\w+\.enable' ops/validate-config.sh` — rule 6 scope
- [ ] `rg -n 'git ls-files|--others|untracked' ops/validate-config.sh` — rule 10 gate
- [ ] `rg -n 'nixosConfigurations' nix/flake.nix` — confirm none
- [ ] `rg -n 'TBD|migration-source-of-truth|migration-package-ownership' ops/validate-config.sh` — rule 9

Resolve the two `UNVERIFIED` items:

- [ ] MCP-BOUNDARIES dupe: compare `docs/ai/MCP-BOUNDARIES.md` vs
      `docs/ai/package/operations/MCP-BOUNDARIES.md` (top-level is canonical; package
      copy is under generated tree → fix at source, do not hand-delete)
- [ ] `repo-docs/migration-implementation-plan.md`: `ai-search.sh text "migration-implementation-plan" . --fixed`

### Per-file delete gate (run for EACH Track A candidate — ALL must pass)

- [ ] First 8 lines contain NO `GENERATED — DO NOT EDIT`
      (`bash ops/ai/preview-file.sh <path> --range 1:8`)
- [ ] Path is NOT under `.github/`, `.opencode/`, or `docs/ai/package/`
- [ ] No template emits it
      (`bash ops/ai/ai-search.sh text "<basename>" packages/ai-universal-rules/templates tools/ai/install`)
- [ ] No live reference (`bash ops/ai/ai-search.sh text "<path>" . --fixed`)
- [ ] Not `migration-source-of-truth.md` or `migration-package-ownership.md` (rule 9)

**Any check fails ⇒ DO NOT DELETE. Route to generator/source instead.**

**Exit criterion:** every Track A target has a proven label
(`HAND-OWNED` / `GENERATED` / `ADAPTER OUTPUT`). No label → no action.

---

## 6. Track A — Thin now (proven hand-owned only, low risk)

Only delete things that passed every GATE 0 check.

- [ ] Reference-check the candidate set:
      `bash ops/ai/ai-search.sh text "repo-docs/archive" . --fixed`
- [ ] Extract any still-live decisions into `repo-docs/migration-decisions.md` /
      `repo-docs/architecture/tool-ownership.md` first
- [ ] Delete confirmed-stale, marker-free archive docs (candidates):
  - `repo-docs/archive/*draft*`
  - `repo-docs/archive/pr-body-2026-05-24.md`
  - `repo-docs/archive/migration-audit-2026-05-24.md`
  - `repo-docs/archive/file-audit-plan.md`
  - `repo-docs/archive/docs-move-manifest.{json,py}`
- [ ] Only after a reference-check proves it stale: compress/archive
      `repo-docs/migration-implementation-plan.md` (1,729 lines)
- [ ] Verify after each deletion:
      `bash ops/validate-config.sh && mise run repo:check`
- [ ] **DO NOT** delete `docs/ai/package/**` pairs or `.github`/`.opencode` twins here

## 7. Track A-deferred — Generated dedup (source-level, NO deletions)

- [ ] If GATE 0 proved skills/agents/docs are generated: dedup at the
      generator/source so both adapters still render
- [ ] MCP-BOUNDARIES.md: top-level is canonical (no marker); collapse the
      `package/operations` copy at the generator, never by hand
- [ ] `CAPABILITY-MODEL` / `COMPATIBILITY` / `CONTROL-MODEL` / `DESIGN-PRINCIPLES` /
      `PRECEDENCE`: package vs foundations are **different content (verified)** — leave
      as deliberate two-tier docs unless you change source templates
- [ ] Optionally exclude generated twins from AI-context bundles (context-economy win,
      no install-surface change)
- [ ] Trim **stale** comments only in heavy Nix files; keep rationale comments (e.g. the
      Vicinae rationale in `flake.nix:22-29`). `gui.nix` / `gnome-*.nix` are skipped here
      — they vanish in Track B Phase 6.

---

## 8. Track B — niri migration (additive; GNOME safe until Phase 6)

### Default component choices (swap if preferred)

| Slot | Default | Alternative |
|---|---|---|
| Display manager | Ly | greetd + tuigreet |
| Bar / tray | Waybar | — |
| Notifications | mako | swaync |
| Idle / lock | swayidle + swaylock | hypridle / hyprlock |
| Screenshots | niri-native + satty | grim + slurp + satty |
| Portal file-picker | nautilus (`programs.niri.useNautilus`) | xdg-desktop-portal-gtk + gtk |

### Phase 0 — Pre-flight

- [ ] `git checkout -b feat/niri-migration`; confirm GNOME login is the baseline
- [ ] Lock DM choice: `__________`  |  file-picker backend: `__________`
- [ ] Inventory GNOME-locked surface to be removed in Phase 6:
      `gnome-keybindings.nix` (256L), `gnome-extensions.nix` (53L),
      `gnome-files.nix` (28L, 2 GTK keys to migrate), GNOME bits in `gui.nix` (369L),
      imports in `nix/hosts/linux-desktop/home.nix`
- [ ] Confirm kept: `nix/modules/home/default-apps.nix` (pure XDG)

### Phase 1 — NixOS system layer (additive; GNOME still default)

- [ ] Add `nix/hosts/linux-desktop/system.nix`; wire `nix/modules/nixos/default.nix`
- [ ] Add `nix/modules/nixos/desktop-niri.nix`:
      `programs.niri.enable = true; programs.niri.package = pkgs.niri;` (nixpkgs first)
- [ ] Add `nix/modules/nixos/display-manager.nix` (Ly/greetd; **do not** disable GDM yet)
- [ ] Add `nixosConfigurations.linux-desktop` to `nix/flake.nix`
- [ ] **Re-scope validator rule 6** to `nix/modules/home/` only (correct regardless of
      regex; niri's enable lives in `nix/modules/nixos/`)
- [ ] **`git add` every new `*.nix`** (rule 10 — flake ignores untracked files)
- [ ] Build only:
      `sudo nixos-rebuild build --flake .#linux-desktop`
      `nix build .#homeConfigurations.linux-desktop.activationPackage`
      `bash ops/validate-config.sh`

### Phase 2 — Activate + capture hardware

- [ ] `sudo nixos-rebuild test --flake .#linux-desktop`
- [ ] Confirm BOTH "GNOME" and "niri" sessions appear at the greeter
- [ ] **Ly env gate (MANDATORY):** in niri, run
      `systemctl --user show-environment | grep WAYLAND_DISPLAY`. Empty ⇒ switch launch
      to `niri-session`/uwsm or move to greetd before continuing. Result: `__________`
- [ ] Capture real outputs: `niri msg outputs` → `__________`
- [ ] `sudo nixos-rebuild switch --flake .#linux-desktop` once sessions select cleanly

### Phase 3 — niri config via Home Manager (raw KDL)

- [ ] `nix/modules/home/niri/`: `xdg.configFile."niri/config.kdl".source = ./config.kdl;`
- [ ] KDL: parameterise `output` blocks from captured `niri msg outputs`
- [ ] `input.keyboard.xkb { layout "us,ru"; options "grp:win_space_toggle"; }`
- [ ] `spawn-at-startup "vicinae" "server"`; `debug { honor-xdg-activation-with-invalid-serial; }`
- [ ] `niri validate ~/.config/niri/config.kdl` passes

### Phase 4 — Wayland service graph (BEFORE any GNOME deletion)

- [ ] `nix/modules/nixos/portals.nix` (+ file-picker backend per Phase 0)
- [ ] polkit + a polkit agent — **one launch path only**
- [ ] `nix/modules/nixos/audio-graphics.nix`: PipeWire, graphics, fonts
- [ ] `xwayland-satellite`, spawned from niri config
- [ ] mako (HM); Waybar (HM) — **one launch path only** (avoid duplicate bar)
- [ ] swayidle + swaylock (HM)
- [ ] Verify: file dialog, screen-share picker, polkit prompt, notification, lock

### Phase 5 — Launcher, screenshots, shortcut parity

- [ ] `vicinae.nix`: drop GNOME assumptions; deeplink binds; add VS Code extension
- [ ] Translate all `gnome-keybindings.nix` shortcuts into KDL binds
- [ ] Screenshots: niri-native + satty; drop Flameshot resident hack unless cold-test
      proves it. Decision: `__________`

### Phase 6 — GNOME cutover (SINGLE revertable commit — the real Nix thinning)

- [ ] Make niri the default session; disable GDM
- [ ] Migrate the 2 GTK keys out of `gnome-files.nix`
- [ ] Delete `gnome-keybindings.nix`, `gnome-extensions.nix`, `gnome-files.nix`
- [ ] Strip GNOME from `gui.nix`; drop dead imports from `linux-desktop/home.nix`
- [ ] Keep `default-apps.nix`
- [ ] `sudo nixos-rebuild switch --flake .#linux-desktop` +
      `nix build .#homeConfigurations.linux-desktop.activationPackage`

### Phase 7 — Validation & reconcile

- [ ] Validator: KDL present, no orphaned `gnome*` refs, `niri validate` passes
- [ ] All niri/Linux pieces are `lib.optionals stdenv.isLinux` no-ops on Darwin
- [ ] chezmoi reconciliation: confirm no file owned by both chezmoi and HM
- [ ] `bash ops/validate-config.sh && mise run repo:check && mise run test:bash`
- [ ] Update `repo-docs/migration-decisions.md` /
      `repo-docs/architecture/tool-ownership.md` with the final split
- [ ] (Optional) `tests/bash/niri-*.bats` smoke tests + CI gate

---

## 9. Execution Order

1. **GATE 0** — read-only, prove every label (BLOCKING)
2. **Track A** — proven hand-owned stale deletes only
3. **Track A-deferred** — generator-level dedup (optional, source edits)
4. **Track B Phases 1–5** — additive, GNOME safe
5. **Track B Phase 6** — cutover (this is what thins the Nix layer)

---

## 10. Rollback Playbook

| Phase / Track | Undo |
|---|---|
| GATE 0, Track A-deferred | Read-only / source edits; `git revert` |
| Track A deletes | `git revert` the deletion commit |
| Track B Phase 1 | Build-only; nothing to undo |
| Track B Phases 2–5 | Pick GNOME at greeter; `sudo nixos-rebuild --rollback`; rebuild prior HM generation |
| Track B Phase 6 | `git revert <cutover commit>` + rebuild, or boot previous NixOS generation |

---

## 11. Success Signals (definition of done)

- Greeter shows niri as default; niri starts cleanly
- Every translated bind fires; xkb layout toggle works from one bind
- Vicinae launcher + clipboard history work; VS Code extension present
- File dialog, screen-share picker, polkit prompt, notifications, lock all work
- Screenshots work (niri-native + satty)
- All external monitors + laptop panel detected at correct scale
- `bash ops/validate-config.sh && mise run repo:check && mise run test:bash` all green
- GNOME surface = 0 (no `gnome*` modules, no GNOME refs); chezmoi retained for cross-platform
- No generated file deleted; thinning achieved via `repo-docs/archive/*` removal +
  generator-level dedup + Phase 6 GNOME module deletion

---

## 11A. Stale / outdated file inventory (read-only verified)

All `repo-docs/archive/*` paths below were confirmed **marker-free (hand-owned)** by Grep
and are the only immediate-safe deletes. Line counts from the scc dump.

| Path | Lines | Status | Evidence | Action |
|---|---:|---|---|---|
| `repo-docs/archive/migration-source-of-truth.draft.md` | 89 | HAND-OWNED stale draft | superseded by non-draft in `repo-docs/` | Track A delete |
| `repo-docs/archive/migration-package-ownership.draft.md` | 101 | HAND-OWNED stale draft | superseded by non-draft in `repo-docs/` | Track A delete |
| `repo-docs/archive/pr-body-2026-05-24.md` | 254 | HAND-OWNED dated | only self/archive refs | Track A delete |
| `repo-docs/archive/migration-audit-2026-05-24.md` | 124 | HAND-OWNED dated | only self/archive refs | Track A delete |
| `repo-docs/archive/file-audit-plan.md` | 367 | HAND-OWNED completed | move plan done (all `[x]`) | Track A delete |
| `repo-docs/archive/docs-move-manifest.json` | 359 | HAND-OWNED one-off | snapshot of completed move | Track A delete |
| `repo-docs/archive/docs-move-manifest.py` | 69 | HAND-OWNED one-off | generated the manifest above | Track A delete |
| `repo-docs/archive/ai-tests/SessionLogToolsTest.php` | 210 | ARCHIVED AI-kit test (references live `tools/ai/session-log-lib.php` via `require_once`; classified "out of scope" at `migration-followups.md:86`) | safe to delete (archived copy; the live AI-kit owns the real test), but NOT a plain hand-owned doc | Track A delete LAST + update `archive/ai-tests/README.md` |
| `repo-docs/archive/README.md` + `archive/ai-tests/README.md` | 27 | index for the above | becomes empty after deletes | Update or delete LAST, after the files it indexes |

**Must NOT delete (build-breaking or live):**

| Path | Why kept |
|---|---|
| `repo-docs/migration-source-of-truth.md` | validator rule 9 requires it |
| `repo-docs/migration-package-ownership.md` | validator rule 9 requires it |
| `repo-docs/migration-implementation-plan.md` (1,729L) | **actively referenced** (README:33, tool-ownership:4, followups); compress only |
| `repo-docs/migration-decisions.md`, `migration-followups.md` | live decision/followup log |
| `repo-docs/future-upgrade-plan.md` (350L) | referenced by live Nix comments (`gui.nix:88,235`, `gnome-extensions.nix:41`) |
| `repo-docs/install-dev-tools.sh` (562L) | KEEP but STALE-CONTENT: still parsed by `ops/generate-package-matrix.sh` + presence-checked by `ops/doctor.sh` (not an orphan), yet lists dropped `direnv` and only wires zsh. Per `migration-followups.md:65`, fix in a dedicated slice — do NOT delete. |

**Cross-reference cleanup required after Track A deletes (or the docs go stale):**

- `repo-docs/README.md:33` — references `migration-implementation-plan.md` (kept; OK).
- `repo-docs/migration-followups.md:70,119,128,156,172` — reference the soon-deleted
  archive files (`file-audit-plan.md`, `docs-move-manifest.*`). Update these lines.
- `repo-docs/migration-followups.md:64` is a SEPARATE stale item: a `.husky/` hook-cleanup
  row, but `git ls-files '.husky*'` returns nothing → `.husky/` does not exist. The row is
  obsolete; mark it resolved/remove it (do not treat as an archive reference).
- `repo-docs/archive/README.md` indexes every deleted file — update/remove last.

## 11B. Comments & outdated-doc reconciliation

The "remove comments" goal is **scoped, not bulk**. Keep rationale comments; remove only
stale/dead ones. Verified comment-heavy files and their disposition:

| File | Lines / comments | Disposition |
|---|---|---|
| `nix/modules/home/gnome-keybindings.nix` | 256 / 122 | **Deleted in Phase 6** — no comment work now |
| `nix/modules/home/gui.nix` | 369 / 189 (51%) | GNOME bits stripped in Phase 6; review remaining comments then |
| `nix/modules/home/gnome-extensions.nix` | 53 / 42 | **Deleted in Phase 6** |
| `nix/modules/nixos/dual-boot.nix` | 181 / 30 | keep — rationale-heavy, system-critical |
| `nix/flake.nix` (Vicinae note `:22-29`) | — | **KEEP** — load-bearing rationale |

**Stale in-code doc pointers to reconcile (do NOT silently break):**

- `nix/modules/home/gui.nix:88` and `:235` — comments point to
  `repo-docs/future-upgrade-plan.md item #12`. If `gui.nix` GNOME blocks are removed in
  Phase 6, re-point or delete these comments in the SAME commit.
- `nix/modules/home/gnome-extensions.nix:41` — same `future-upgrade-plan.md item #12`
  pointer; the whole file is deleted in Phase 6 (pointer goes with it).
- `nix/modules/home/default-apps.nix:68` — TODO pointing to `repo-docs/default-apps.md`
  (file KEPT; leave TODO unless the TODO is resolved).

Rule: every comment that names a doc path must still resolve after the change, or be
removed in the same commit.

## 11C. Tooling & edge-case matrix

Edge cases the implementer must handle; each has a defined response.

| Edge case | Risk | Required handling |
|---|---|---|
| New `*.nix` left untracked | validator rule 10 FAILS build | `git add` every new module before `validate-config.sh` |
| `programs.niri.enable` placed in `nix/modules/home/` | validator rule 6 FAILS | niri enable goes in `nix/modules/nixos/` only |
| Re-scope rule 6 to `home/` too early/late | false-positive or missed ban | re-scope in Phase 1, same commit as the niri nixos module |
| Deleting a generated file by mistake | breaks a runtime / regenerated on install | HARD DELETE GATE: check first 8 lines for `GENERATED — DO NOT EDIT` |
| Deleting rule-9 audit docs | validator FAILS | never delete `migration-source-of-truth.md` / `migration-package-ownership.md` |
| `markdownlint-cli2` not installed locally | doc lint cannot run locally | rely on `ops/validate-config.sh` locally; markdown lint runs in CI |
| `bash ops/ai/*` AI scripts blocked by policy | discovery commands denied | use `scripts/ai/*` paths, or `rg`/`fd`/`git ls-files`/Read |
| Ly does not export `WAYLAND_DISPLAY` to systemd user env | swayidle/waybar/mako silently break | Phase 2 MANDATORY env gate; fallback `niri-session`/uwsm or greetd |
| Two launch paths for Waybar / polkit agent | duplicate bar / double agent | exactly ONE launch path each (Phase 4) |
| Darwin host evaluates niri/Linux modules | macOS build breaks | wrap Linux pieces in `lib.optionals stdenv.isLinux` |
| chezmoi + HM both own a niri file | dual ownership | niri is greenfield; keep config.kdl HM-only (Phase 7 check) |
| Flameshot assumed to work under Wayland | screenshot silently fails | use niri-native + satty; cold-test before keeping Flameshot |

**Verification commands (repo-canonical):**

```
bash ops/validate-config.sh
mise run repo:check
mise run test:bash
```

## 11D. Implementer handoff — required changes to document/apply

This plan is currently **read-only / planning**. The implementer picking this up MUST,
before writing code, fill in the `__________` decision blanks and document each change
back into this file. Concrete change set, grouped by track:

**GATE 0 (read-only, implementer confirms then records results inline):**
- Run the 4 verified-fact re-checks and the MCP-BOUNDARIES content compare; record PASS/FAIL.
- Produce the proven delete list and STOP for approval before any `git rm`.

**Track A (deletions — needs approval; destructive):**
- Delete the 8 marker-free archive files in §11A (one commit).
- Update cross-references in §11A "cleanup required" list in the SAME commit.
- Compress (do not delete) `migration-implementation-plan.md`; keep all inbound links valid.
- After: `bash ops/validate-config.sh && mise run repo:check` must stay green.

**Track B Phase 1 (additive Nix — new files to author):**
- `nix/hosts/linux-desktop/system.nix`
- `nix/modules/nixos/desktop-niri.nix` (`programs.niri.enable`, `package = pkgs.niri`)
- `nix/modules/nixos/display-manager.nix`
- `nix/modules/nixos/portals.nix`, `nix/modules/nixos/audio-graphics.nix` (Phase 4)
- `nix/modules/home/niri/{default.nix,config.kdl}` (Phase 3)
- Add `nixosConfigurations.linux-desktop` to `nix/flake.nix`.
- Re-scope `ops/validate-config.sh` rule 6 to `nix/modules/home/`.
- `git add` all new `*.nix` (rule 10).

**Track B Phase 6 (cutover — single revertable commit):**
- `git rm` `gnome-keybindings.nix`, `gnome-extensions.nix`, `gnome-files.nix`.
- Drop their imports from `nix/hosts/linux-desktop/home.nix:8-10`.
- Strip GNOME blocks from `gui.nix`; reconcile the `future-upgrade-plan.md` comment
  pointers at `gui.nix:88,235` in the same commit.
- Migrate 2 GTK keys out of `gnome-files.nix` before deleting it.

**Documentation duties (every change):**
- Record each applied change + verification evidence in this file or
  `repo-docs/migration-decisions.md`.
- Flag every failed/blocked command per AGENTS.md mandatory failure-flagging, appending
  unresolved items to `repo-docs/migration-followups.md`.
- Fill the decision blanks: DM choice, file-picker backend, Ly env-gate result,
  `niri msg outputs`, Flameshot keep/drop.

---

## 12. chezmoi — standing rule

Keep chezmoi owning: `home/dot_config/karabiner/karabiner.json` (macOS, 2,475 lines),
cross-platform VS Code templates, Windows `*.ps1` scripts, and any future non-Nix Linux
fallback dotfiles. Long-term target: Nix/NixOS/nix-darwin ~75–85%, chezmoi ~15–25%,
ops = bootstrap/validation only. The one invariant: **a given file has exactly one owner.**
niri introduces no chezmoi overlap.

---

## 13. Plan change log (verification corrections)

Read-only re-verification of every cited path/line. Corrections applied so no dead/stale
lines mislead the implementer:

- Fixed `migration-followups.md` archive-reference line list to `70,119,128,156,172`
  (was `64,70,128,156,172`; line 64 is a separate `.husky/` item).
- Confirmed `.husky/` is absent (`git ls-files '.husky*'` → empty); followups:64 row is obsolete.
- Re-labelled `SessionLogToolsTest.php`: it `require_once`s live `tools/ai/session-log-lib.php`;
  archived copy is delete-safe but is AI-kit material, not a plain doc.
- Added `repo-docs/install-dev-tools.sh` to "Must NOT delete" (stale `direnv`/zsh content,
  but still parsed by `ops/generate-package-matrix.sh` + `ops/doctor.sh`).

Verified CORRECT (no change): `nix/hosts/linux-desktop/home.nix:8-10` (gnome imports),
`repo-docs/README.md:33`, `repo-docs/architecture/tool-ownership.md:4`, `nix/modules/home/gui.nix:88`,
`nix/modules/home/default-apps.nix:68`, validator rules 6/9/10.
