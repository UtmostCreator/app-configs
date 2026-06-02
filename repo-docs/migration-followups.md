# Migration follow-ups

Live ledger of things that **failed**, were **deferred**, or remain **open**
after the Phase 0–10 dotfiles migration on `feat/dotfiles-migration`.

Also covers stacked work on `feat/project-orchestrator` (chezmoi-templated
tmux + health + GitHub orchestrator imported from
`C:\xampp\htdocs\project-scripts` and anonymised — see
`repo-docs/projects/README.md`).

Append-only. When an item is resolved, move it to the "Resolved" section
with the resolution commit hash.

The agent rule is in `AGENTS.md` ("Failure flagging is mandatory"): every
failed command/tool call/sub-agent must be flagged in the user-facing
summary and unresolved entries land here.

## Open — blocking next phase

(none)

## Open — non-blocking, before merge to `main`

(none — C3, C4, C5 all resolved; see Resolved section)

## Open — explicit deferrals (intentional, not bugs)

| Item | Why deferred | Unblock condition |
|------|--------------|-------------------|
| `nix flake check ./nix` | Determinate Systems installer needs interactive `sudo`, which this opencode session does not have. Attempted 2026-05-24 — `sudo: A terminal is required to authenticate`. | Run from your own shell: `sh /tmp/nix-installer.sh install --no-confirm` (still cached) or `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \| sh -s -- install --no-confirm`. Then `nix flake check ./nix`. |
| `home-manager switch --flake ./nix#wsl --dry-run` | Needs Nix and `home-manager` first (same blocker as above) | After Nix is installed, run `nix profile install nixpkgs#home-manager` then the dry-run command. |
| `darwin-rebuild check --flake ./nix#macos` | macOS host required | Validate on a Mac before any production macOS use. |
| `bash scripts/test-bootstrap-docker.sh` | docker not installed on this WSL host | Install Docker, then re-run before legacy-cleanup of `backup-sanitized/` is merged. |
| `home/dot_config/mise/config.toml.tmpl` does not pin PHP | Per Phase 0/5 decision: keep repo-level toml task-only | Decide C4 first. |
| `nix/modules/common/nix-settings.nix` `nix.package = pkgs.nix` (uncommitted) | Added so standalone Home Manager can manage `nix.*` on a **NixOS** host without conflicting with system Nix. Harmless on non-NixOS hosts but only strictly needed on NixOS, which is not a supported profile. | Decide whether to commit. If kept, gate it behind a NixOS condition or document it as NixOS-only in `repo-docs/install-nixos.md` (done). |
| `auto-optimise-store` warning on every nix command on NixOS | Standalone HM applies `nix.settings.auto-optimise-store = true` as a client setting; the user is not in the system `nix.settings.trusted-users`, so Nix ignores it and warns. Non-fatal. | Optional: add user to `trusted-users` in `/etc/nixos/configuration.nix` (system-side, out of repo scope). Documented in `repo-docs/install-nixos.md`. |
| `.opencode/agents/implementer.md` + `.opencode/opencode.json` widening uncommitted | Reviewer flagged the diff as overbroad (every `deny` flipped to `allow`/`ask`). User instruction: "do not commit this files for now." | Either revert with `git restore`, or land a surgical narrower patch on a `chore/opencode-policy-*` branch with explicit reviewer sign-off. |
| Docker-image policy comment removed from `tools:optional:install` | Aqua backend status (`experimental = true` floor on older mise versions) not documented in mise.toml | Add a `mise --version` floor note in `repo-docs/bootstrap.md` once the project decides a minimum. |
| `feat/project-orchestrator` history-rewrite of authoring identities | Reviewer flagged two personal author emails (a `@gmail.com` and a `@rabbies.com` work address — values redacted from this doc) in commit-author metadata on `main`. Per Q2 of the project-orchestrator brief, this slice **only** sanitises new content; existing-history rewrite is a separate later slice with explicit sign-off (because `git filter-repo` + force-push invalidates the open PR's commit shas). See `repo-docs/git-history-email-rewrite.md` for the exact, approval-gated procedure. | Land `feat/dotfiles-migration` and `feat/project-orchestrator` first; then file a `chore/rewrite-authors` PR per `repo-docs/git-history-email-rewrite.md` with the `git filter-repo --mailmap` invocation + coordination plan for the force-push. |
| `feat/project-orchestrator` `Herd` mention in `home/dot_gitconfig.tmpl` | The committed dotfiles `gitconfig` includes a `gitdir/i:{{ .chezmoi.homeDir }}/herd/` selector. `Herd` is a personal-machine convention (the Laravel Herd install path), not a project name — but it's a leak under a strict reading of the anonymisation contract. | Replace with a configurable selector via `personal.yaml` (e.g. `{{ .gitconfig.work_dir_pattern }}`) in a separate slice; not blocking. |

## Open — observations from dual-boot / NVMe slice (2026-06-02)

| Item | Why open | Unblock condition |
|------|----------|-------------------|
| `docs/ai/script-registry.json` references `scripts/ai/install-mandatory-tools.sh` which does not exist on disk | Generated mirror (per `docs/ai/script-registry.md`, source of truth is `tools/ai/install/script-registry.php`). Hand-editing a generated artifact is out of scope; the generator should be re-run. | Run the registry generator (`php tools/ai/...`) in a dedicated slice and commit the regenerated `script-registry.json`. |
| Dual-boot activation on the live host is NOT done | This slice only added the opt-in `nix/modules/nixos/dual-boot.nix` module + read-only `scripts/detect-os-disks.sh`. No `/etc/nixos` edit, no `nixos-rebuild`, no `efibootmgr` boot-order change (boot/auth-sensitive, needs approval). The full step-by-step is now documented in `repo-docs/nixos-rebuild.md` ("Dual-boot with Windows"). | Separate approved slice: import module in `/etc/nixos`, run `scripts/detect-os-disks.sh`, discover `windowsDeviceHandle` via EDK2 `map -c`, `nixos-rebuild switch`, then `efibootmgr -o` to make NixOS default. |

## Open — staleness sweep of oldest install/config files (2026-06-02)

Sweep of install/config files older than the repo median commit date (excluding
AI files). Verified with `lychee` (0 broken links) and reference-existence
checks. Most old files were confirmed current (linter configs are intentional
downstream "reference baseline" per README; zsh docs/`home/dot_zshrc.tmpl` are
still supported; Windows-native docs are out-of-scope-but-kept). Two genuine
items remain, recorded here (no edits made — both are approval-gated/judgment):

| Item | Why open | Unblock condition |
|------|----------|-------------------|
| `.husky/pre-commit` + `.husky/commit-msg` are dead config | Lefthook is the live hook engine (`.git/hooks/*` are lefthook-managed; `core.hooksPath` unset; husky never invoked). Already a documented deferred "separate hook cleanup" gate (`migration-implementation-plan.md` §1509) and `scripts/validate-config.sh` is built to flag `.husky/` rather than fail on it. | Approve the hook cleanup, then `git rm .husky/pre-commit .husky/commit-msg` and update the `.husky/` note in `scripts/validate-config.sh` + `repo-docs/architecture/tool-ownership.md`. |
| `repo-docs/install-dev-tools.sh` content drift | Legacy macOS Homebrew reference. Still REFERENCED (parsed by `scripts/generate-package-matrix.sh` for the package list; presence-checked by `scripts/doctor.sh`), so not an orphan. But it lists `direnv` (repo dropped direnv per Phase 3) and only wires zsh, while the repo is now fish-first. No current doc tells users to run it. | Judgment call in a dedicated slice: drop `direnv` from `FORMULAE`/wiring and add fish wiring (or annotate as macOS/zsh-legacy reference), then re-verify `scripts/doctor.sh` + `scripts/generate-package-matrix.sh` output still match. |

## Open — full repo file audit (scc-by-file.csv, 2026-06-02)

Per-file staleness/correctness audit tracked in `scc-by-file.csv` (Status +
Disposition columns). Plan: `repo-docs/file-audit-plan.md`. AI-kit files
(`docs/ai/**`, `.opencode/**`, `AGENTS.md`, `PLACEHOLDERS.md`,
`.ai-install-manifest.json`) are auto-shipped by another project and are OUT OF
SCOPE — left as `- [ ]`, not audited.

Dispositions recorded so far:

| Batch | Files | Disposition | Evidence |
|-------|-------|-------------|----------|
| B1 | 24 empty `reference/php/design-patterns/**/README.md` stubs | **Removed** — 0 bytes, created by `reference/php/create-design-patterns-structure.sh` (`touch`), referenced nowhere (`rg` = 0 hits), `reference/` is explicitly non-runtime per `reference/README.md`. | `find reference/php/design-patterns -name README.md -size 0 -delete` (24 deleted); `rg -l "design-patterns/.*/README"` = none |
| B2 | `.eslintrc.json`, `.prettierrc.json`, `.stylelintrc.json`, `.lefthook.yml`, `mise.toml` | **Kept** — all parse; linter configs are documented reference baseline (README §"Style configs"); lefthook scripts all exist; mise tasks resolve. | `php json_decode` OK x3; `yq .` OK; `mise tasks ls` OK |
| Scope | 288 AI-kit files marked `- [-]` out of scope | **Excluded** — `.ai-install-manifest.json` `files` map + kit roots (`docs/ai/`, `.opencode/`, `.schemas/`, `scripts/ai/`, `tools/ai/`, `.github/hooks/`, AI workflows). Auto-shipped by `ai-universal-rules`; not repo-bounded. Includes the would-be B3 `.schemas/**` and most of B7 `tools/ai/**`. | manifest parse: 159 entries; classification script -> 288 out-of-scope, 146 repo-bounded remain |
| B-ref | 11 `reference/**` files (8 PHP, 1 shell, 2 READMEs) | **Kept** — all `php -l` clean, `bash -n` clean, READMEs accurately describe present structure, generator script still referenced. | `php -l` x8 OK; `bash -n` OK; dir-existence checks OK |

| B-root | README, CONTRIBUTING, SECURITY (3) | **Kept** — all path refs resolve (README "MISS" hits were bare basenames that exist under `scripts/`). | `rg` path-existence + `fd` basename resolution |
| B-root | `file-assessment.md` | **Removed (already gone)** — stale CSV/scc entry; file not on disk. | `[ -e ]` = missing |
| B-root | `tests/php/SessionLogToolsTest.php` | **Out of scope** — tests AI-kit `tools/ai/session-log-lib.php`. | `rg` shows require of `tools/ai/` |
| B-scripts | 32 `scripts/**` (non-ai) | **Kept** — all `bash -n` + `shellcheck -S error/warning` clean; `checks.d/10-tmux.sh` reachable via `run.sh` glob (not orphan). | `bash -n` x32; `shellcheck` exit 0; glob-load confirmed |
| B-home | 32 `home/**` dotfiles/templates | **Kept** — JSONC valid x5 (karabiner, 2x keybindings, 2x settings bodies), TOML valid x2, fish/bash clean. **Duplicate pairs are intentional:** macOS `Library/...` twins of XDG `dot_config/...` share one chezmoi template body; `executable_git-branch-origin` is the source-of-truth mirror of `scripts/git-branch-origin.sh` (enforced by `check-source-of-truth.sh`). Lua/`.tmpl` got structural-only checks (no lua/chezmoi runtime). | robust JSONC state-machine parser; `yq -p toml`; `diff` (identical, intentional); `fish -n` |
| B-nix | 22 `nix/**` | **Kept** — all `nix-instantiate --parse` OK; flake host refs resolve. **Advisory DEFERRED:** 7 files flagged by the locally-available plain `nixfmt`, but the repo's canonical formatter is `nixfmt-rfc-style` (see Resolved 2026-06-01, "`nixfmt --check` passes on the existing config"). The drift is a formatter-variant mismatch, not real drift — **no action; not a bug.** | `nix-instantiate --parse` x22; `nixfmt --check` (plain variant) |
| B-docs | 41 `docs/**` repo-owned (31 md, 6 ps1, 2 sh, 2 json) | **Kept** — shell `bash -n` OK, workspace JSONC valid x2, markdown links clean via `lychee --offline` (3 "errors" were code-spans; 1 real link in dated `pr-body` is an intentional historical reference to a relocated file). **All 41 are `repo-docs/` move candidates — move stays PLAN-ONLY per direction.** Windows `.ps1` kept as-is per `repo-docs/README.md`. | `lychee --offline` (4 reported, 3 false-positive code-spans, 1 intentional archive link) |

### Gated candidates — RESOLVED (2026-06-02, approved)

| File | Finding | Action taken |
|------|---------|--------------|
| `SUPPORT.md` | 2 stale links: `docs/ai/install-order.md` + `packages/ai-universal-rules/QUICKSTART.md` did not exist. | **Edited** — removed both stale references (dropped the install-order bullet; kept the valid `ai-universal-rules/README.md` link). All remaining links verified to resolve. `- [x]`. |
| `.husky/pre-commit` + `.husky/commit-msg` | Dead config — lefthook is the live hook engine (`core.hooksPath` unset, `.git/hooks/*` are lefthook shims, no husky in package.json/mise/lefthook; husky driver in `tools/ai/.../install_extras.php` is opt-in `--driver husky`, not active here). | **Removed** via `git rm`. Updated repo-owned references: `scripts/validate-config.sh` (dropped `.husky/` flag-comment) and `repo-docs/architecture/tool-ownership.md` (note now says shims removed, Lefthook is sole engine). AI-kit refs (`AGENTS.md`, `docs/ai/*`, `tools/ai/*`) and historical migration docs left untouched. `bash -n` + lefthook-wiring re-verified. `- [x]`. |

### nixfmt advisory — DEFERRED (no action)

The 7-file `nixfmt` drift is a formatter-variant mismatch (repo uses
`nixfmt-rfc-style`; local check used plain `nixfmt`). Not a bug. No edit made.

### Post-move full re-audit + cleanup COMPLETE (2026-06-02)

After the `docs/` -> `repo-docs/` move, a fresh tree scan (`scc-by-file-new.csv`)
was fully audited: **all 440 file rows marked `- [x]`** (header fixed to
`Status,...,Disposition`; zero CSV-vs-disk drift). Breakdown: **287 AI-kit
auto-shipped** (out of scope) + **153 repo-bounded** (re-verified this session:
shell `bash -n`, php `-l`, nix `--parse`, JSON/TOML/YAML parse, markdown links
via `lychee --offline` — all clean).

Review cleanups applied (from the diff review F1–F3):

- **F1:** `.gitignore` now ignores root scratch scans `/scc-by-file.csv` +
  `/scc-by-file-new.csv` (canonical scc is the kit's
  `docs/ai/generated/repo-structure.*`).
- **F2/F3:** dropped redundant `repo-docs/docs-refmap.{py,json}` (superseded by
  `docs-move-manifest.*`); updated the helper reference.

### Repo-bounded audit COMPLETE (2026-06-02)

**174 repo-bounded files audited `- [x]`** (zero pending), 289 AI-kit `- [-]`
out of scope. Actions taken: B1 removed 24 empty stubs; `file-assessment.md`
already gone; `SUPPORT.md` edited; `.husky/` removed (2 files + 2 ref updates).

**UPDATE 2026-06-02: the `docs/` -> `repo-docs/` move is now EXECUTED and
COMPLETE** (M0–M5 all done) — see `repo-docs/file-audit-plan.md` §3 progress
tracker. Summary:

- **41 repo-owned docs moved** `docs/<x>` -> `repo-docs/<x>` via `git mv`
  (history preserved), mirroring sub-structure. `docs/` now holds only
  `docs/ai/` (the auto-shipped kit).
- **~184 path rewrites across 37 repo-owned files** (M2: 153 + 2 dir-refs + M3:
  31), incl. functional scripts `doctor.sh`, `validate-config.sh`,
  `check-source-of-truth.sh`, `generate-package-matrix.sh`, `install.sh`,
  `readiness.sh`; `README.md`; `mise.toml`; 3 nix modules; cross-link docs.
- **AI-kit untouched:** `git status docs/ai` empty. The kit's
  `repo-directory-map.json` / `repo-required-tools.md` / `AGENTS.md` still name
  old `docs/<x>` paths — left stale by design; the kit regenerates on next sync.
- **Verified:** 41 renames; zero stale moved-path refs (kit excluded);
  `validate-config.sh` + `generate-package-matrix.sh` exit 0; `bash -n` clean;
  `lychee --offline` shows only the same 4 pre-existing code-span false
  positives (no new broken links).
- `scc-by-file.csv` rows for the 41 files now point at `repo-docs/` with a
  MOVED disposition.

Original plan context below (kept for the audit trail):

**Ownership boundary confirmed against upstream** `UtmostCreator/awesome-ai-utmostcreator`
README: the kit installs exactly `docs/ai/**` (113 files); everything in
`docs/` outside `docs/ai/` (41 files) is repo-owned and is the move set.
`docs/` keeps existing (still holds `docs/ai/`); `repo-docs/` mirrors the
sub-structure of the moved files.

Move-readiness (exhaustive manifest `repo-docs/docs-move-manifest.json`):

- **Tier 1 (9):** zero inbound refs — move freely.
- **Tier 2 (27):** repo-only referrers — move + rewrite (all editable).
- **Tier 3 (5):** also referenced by auto-shipped AI-kit
  (`repo-directory-map.json`, `repo-required-tools.md`, `AGENTS.md`). **NOT
  blocking** — those are kit-generated reflections; they go stale until the kit
  regenerates. No app-configs tooling fails. We never edit kit files.

**Critical finding — functional script deps:** repo-owned scripts read/write
the moved docs and MUST be rewritten in the move slice: `scripts/doctor.sh`,
`scripts/validate-config.sh`, `scripts/check-source-of-truth.sh`,
`scripts/generate-package-matrix.sh`, `scripts/install.sh`,
`scripts/readiness.sh`. Full 36-file rewrite set is enumerated in plan §3.3.

Reusable helper (regenerate any time):
`repo-docs/docs-move-manifest.py` (+ `.json`) — per-file move manifest + tiers
(includes the inbound-reference map; the earlier standalone `docs-refmap.py`
was redundant and was dropped after the move completed).

The plan §3 now carries **per-item `- [ ]` checkboxes** (41 move targets + 36
referrer rewrites + M0–M5 phase boxes) and a progress tracker. Each box flips to
`- [x]` as the corresponding `git mv` / rewrite completes. Current tally:
**moves 0/41, rewrites 0/36, phases not started.**

## Resolved

| Date | Issue | Resolution commit |
|------|-------|-------------------|
| 2026-06-02 | **system-setup.sh failed to wire the module** — only matched single-line `imports = [`; the standard multi-line `configuration.nix` form left the module written but unwired and the rebuild un-run. | Rewrote wiring: prefer injecting into the system flake's `modules = [ ]`, fall back to a multi-line-safe awk `imports` injection; back up whichever file is edited. Verified on the real host — `sudo sys-setup --apply` then activated fish login shell, trusted-users, and nix-gc/optimise timers. |
| 2026-06-02 | **readiness.sh + install.sh reported FALSE system-layer TODOs** — they grepped `/etc/nixos/configuration.nix`, but `sys-setup` writes settings into the imported `app-configs-extra.nix`, so a fully-applied system still showed 3 TODO / exit 2. | Switched both to **live-state** checks: actual login shell (`getent passwd`), `nix show-config` trusted-users, and `systemctl is-active nix-gc.timer/nix-optimise.timer`. `sys-readiness` now correctly prints `ALL SET` (exit 0) once the system layer is active. |
| 2026-06-01 | **Install-completeness audit + system-rebuild docs + Nix-specifics** | Audited: all 54 binary packages from `nix/modules/home/{cli,dev,gui,shell-packages}.nix` on PATH, common module (curl/wget/git/unzip/xz) on PATH, both flake config sets evaluate, all 37 chezmoi dotfiles match (`chezmoi verify` exit 0), essential dotfiles non-empty. Added `repo-docs/nixos-rebuild.md` (official switch/boot/test/dry-activate semantics, when a system rebuild is REQUIRED vs `home-manager switch`, recommended `/etc/nixos/configuration.nix` snippet for fish login shell + trusted-users + GC, reboot/readiness checks). `scripts/install.sh` now ends with a NixOS advisory that detects missing system settings and prints the exact `sudo nixos-rebuild switch --flake /etc/nixos#nixos` command (never runs sudo unattended). Added `repo-docs/nix-specific-and-replacements.md` (honest Nix-mechanism vs portable-software split, attr-name map, cross-distro replacements, GUI channels). Added a fresh-install timeline to `repo-docs/INSTALL.md` (~15–35 min unattended cold, 1–3 min warm; ~7.7 GiB closure). README cross-links. |
| 2026-06-01 | **No unattended one-shot install / update / cleanup automation** — bootstrap defaulted to dry-run + prompts; no `brewup` equivalent; no on-demand cleanup. | Added `scripts/install.sh` (fully unattended, idempotent, NixOS-aware — skips Determinate installer, snapshots `$HOME`, `chezmoi apply --force`), `scripts/update-all.sh` (flake update + HM + chezmoi + nix profile upgrade + mise upgrade + safe cleanup; report-first), `scripts/cleanup.sh` (SAFE tier = store optimise + cache prune keeping all generations; opt-in `--gc` aged-generation removal keeping recent; never `nix-collect-garbage -d`). All shellcheck-clean; report/dry-run verified; safe cleanup freed 2.0 GiB (24G→21G) keeping all 5 generations. Wired mise tasks `install`, `update`/`update:apply`, `cleanup`/`cleanup:apply`/`cleanup:gc`. New `repo-docs/INSTALL.md`; README + install-nixos updated. |
| 2026-06-01 | **Nix-config maintainability tooling missing** (per Nix best-practice review). | Added `statix`, `deadnix`, `nixfmt-rfc-style`, `nix-index`, `nh` to `nix/modules/home/dev.nix`; mise tasks `nix:fmt` + `nix:lint`. `nixfmt --check` passes on the existing config; statix/deadnix report only advisory style nits in the original flake (left as-is to avoid churn on a working flake). |
| 2026-06-01 | **Full CLI parity from `software-and-cli-tools.md`** — Linux host missing docker-buildx + AI context packers + php. | Added `docker-buildx`, `repomix`, `files-to-prompt`, `code2prompt`, and `php` (8.4) to `nix/modules/home/dev.nix`; all verified on PATH after `home-manager switch`. `direnv` stays DROPPED; `duti` is macOS-only (skipped). |
| 2026-06-01 | **php now installed → doctor catalog validator ran and FAILED** — `packages/ai-universal-rules/catalog.json` + `docs/ai/catalog.md` were committed-but-stale (drift was invisible while php was absent and the validator skipped). | Regenerated via `php tools/ai/generate-ai-catalog.php`; only change was adding the `super-implementer` agent row. Tracked `.opencode/agents/super-implementer.md` so the catalog reference is valid on fresh clones. `doctor.sh` now exits 0 with php validators passing. This is the C4-era optional-php deferral finally closed. |
| 2026-06-01 | **Switch to fish without owning system config** — NixOS login shell is set in `/etc/nixos/configuration.nix`, not `chsh`. | `home/dot_bashrc` → `home/dot_bashrc.tmpl`: interactive bash `exec`s into fish (guards: interactive, fish present, not already in fish, `NO_FISH` escape hatch; non-interactive/script bash unaffected). Verified guards. Persistent login-shell snippet documented in `repo-docs/install-nixos.md` for the user to apply with `sudo nixos-rebuild switch`. |
| 2026-06-01 | **100% email removal incl. git history** — personal `@gmail.com` + `@rabbies.com` addresses in 205 commits. | `git filter-repo --mailmap` mapped both to `…@users.noreply.github.com` across all 206 commits (one new commit included). Verified zero personal emails in history and files. Backup bundle at `~/.local/state/app-configs-backups/app-configs-pre-email-rewrite.bundle` (preserves old SHAs). Origin re-added; **force-push left to the user** (`git push --force-with-lease --all origin`). filter-repo crashed first on a multi-line global git alias; worked around with `GIT_CONFIG_GLOBAL=<empty>`. Repo-local identity set to noreply to prevent recurrence. Example name `Roman`→`Alex` in a PHP reference file. |
| 2026-06-01 | **Complete app list + Linux-only-installable apps** — install ghostty/bruno/aerospace/flameshot/raycast etc. without attempting macOS-only apps on Linux. | Checked `meta.platforms`: `bruno`/`ghostty`/`flameshot` build on Linux → added to `nix/modules/home/gui.nix` (bruno new). `raycast`+`aerospace` are `darwin`-only → added/kept in `nix/modules/darwin/homebrew.nix`, excluded from Linux gui with a comment. Canonical list written to `repo-docs/app-list.md`. bruno verified on PATH after `home-manager switch`. |
| 2026-06-01 | **Shell migration to fish** — port zshrc to fish, prefer fish-native autosuggestions/highlighting (no extra packages). | Added `home/dot_config/fish/config.fish.tmpl` (starship/atuin/fzf/zoxide/yazi `yy`/mise; macOS-only Herd/op/mysql gated on `.chezmoi.os == darwin`). Added `fish` to `nix/modules/home/cli.nix` as a plain package (not `programs.fish.enable`, per validate-config invariant). chezmoi deploys it; `home-manager switch` installs fish 4.7.1; interactive init verified clean. Default-shell switch on NixOS documented as a system `configuration.nix` step in `repo-docs/install-nixos.md`. (uncommitted working tree) |
| 2026-06-01 | **mise-on-NixOS guidance missing** — unclear whether NixOS can use mise. | Documented in `repo-docs/install-nixos.md` ("Can NixOS use mise at all?"): yes for tasks/env/static binaries, but runtimes that compile from source (node) must come from Nix `dev.nix` + `home-manager switch`, not mise. mise template carries no runtime pins. |
| 2026-06-01 | **CLI/GUI parity from `software-and-cli-tools.md`** — Linux host missing several tools; doc was macOS-only. | Added Linux-installable CLI tools to Nix (`pnpm`, `stripe-cli`, `colima` in `dev.nix`) and GUI apps to `nix/modules/home/gui.nix` (firefox, ghostty, vscode, flameshot; isLinux-guarded). All 8 verified on PATH after `home-manager switch`. macOS-only casks stay in `nix/modules/darwin/homebrew.nix`. Added a cross-platform install matrix to `software-and-cli-tools.md`. jetbrains idea-community attr left as a TODO (channel attr name varies). |
| 2026-06-01 | **Personal emails in tracked files** — `repo-docs/migration-followups.md:39` named a `@gmail.com` and `@rabbies.com` address. | Redacted both from the file content (kept the row meaning). Git **history** still contains them; the destructive rewrite is documented as an approval-gated, run-it-yourself procedure in `repo-docs/git-history-email-rewrite.md` (not executed). |
| 2026-06-01 | **NixOS install — mise compiled node 22 from source ("infinite loop")** — `mise install` ran for 30–60 min emitting thousands of `cc … openssl` lines and left ~700 MB in `/tmp/mise/node-v22.22.3`. Cause: mise `core:node` backend downloads nodejs.org **prebuilt** binaries, but NixOS's `/lib64/ld-linux-x86-64.so.2` is a stub that rejects them, so mise fell back to a source build. | Node now provided by Nix: added `nodejs_22` to `nix/modules/home/dev.nix` (binary-cached `22.22.3`) and removed the `node = "22"` pin from `home/dot_config/mise/config.toml.tmpl`. After `home-manager switch`, `node --version` = v22.22.3, `npm` = 10.9.8, and `mise install` reports `all tools are installed` (exit 0, no compile). Cleaned the 686 MB `/tmp/mise` leftover. (uncommitted working tree) |
| 2026-06-01 | **NixOS install — `chezmoi apply` aborted with `could not open a new TTY`** — managed `~/.config/Code/User/settings.json` had a local edit (`untrustedFiles: open`) differing from repo source (`prompt`); chezmoi wanted interactive confirmation in a non-TTY session and exited 1. | Snapshot ran first (`scripts/snapshot-home.sh` → 19 files backed up). Resolved with `chezmoi apply --force` (repo wins; snapshot preserves the old value). Documented in `repo-docs/install-nixos.md`. |
| 2026-06-01 | **NixOS install — `bootstrap.sh` step 1 (Determinate Nix installer) unsafe on NixOS** — would install Nix over the OS-owned Nix. The pre-existing deferral row in this doc assumed the Determinate installer was the only path. | Skipped step 1; ran bootstrap steps 2–9 manually in NixOS-safe order. Full NixOS runbook + failure modes written to `repo-docs/install-nixos.md`. |
| 2026-06-01 | **NixOS install — `lefthook install` had never been run** — `.git/hooks/` held only `*.sample` files. | Ran `lefthook install`; `pre-commit`, `commit-msg`, `pre-push` now lefthook-managed. `doctor.sh` and `validate-config.sh` both pass (exit 0). |
| 2026-05-24 | `scripts/doctor.sh` not executable | `72fce1d` (Phase 7 — `chmod +x scripts/doctor.sh`) |
| 2026-05-24 | `scripts/doctor.sh` required deleted `configs/shell/.zshrc` | `0e614dc` (`fix(doctor,policy): align doctor checks ...`) |
| 2026-05-24 | `scripts/doctor.sh` carried `add_winget_paths()` Windows code | `0e614dc` (function removed) |
| 2026-05-24 | `scripts/unix/ssh-agent-setup.sh` `SNIPPET_DIR` pointed at deleted `configs/shell/ssh-agent/` (would break bootstrap step 8) | `a05eb30` (staleness sweep) |
| 2026-05-24 | `README.md`, `repo-docs/README.md`, `repo-docs/unix/QUICKSTART.md`, `repo-docs/unix/ssh-agent-setup.md`, `repo-docs/templates/vscode/workspace-template.json`, `home/.chezmoitemplates/vscode/settings.minimal.json` referenced deleted `configs/` paths | `a05eb30` (staleness sweep) |
| 2026-05-24 | `CONTRIBUTING.md` referenced non-existent `scripts/repo-health-check.sh` and `just *` targets | `a05eb30` (staleness sweep, partial — see C3 above for the corresponding hook bug) |
| 2026-05-24 | `repo-docs/vscode-extensions.md` install loop included Copilot duplicates and pointed at the wrong settings path | `a05eb30` (staleness sweep) |
| 2026-05-24 | `mise.toml` repo-level `[tools] php = "8.4"` triggered asdf-php build failure on every mise task | Removed pin in Phase-5/optional-tools commit chain — see "Tool versions" comment block in `mise.toml`. |
| 2026-05-24 | `mise.toml` task list had no convenience-tool installer | Added `tools:optional:install` + `tools:optional:list` (covers dive, fx, navi, glow, gum). |
| 2026-05-24 | **C3** — `scripts/hooks/pre-commit.sh` called non-existent `scripts/repo-health-check.sh` | Delegated the staged-files health check to `scripts/doctor.sh` + `scripts/validate-config.sh`; missing-script branch downgraded to a warning so a partial clone still commits. |
| 2026-05-24 | **C4** — `scripts/doctor.sh` listed `php` as required, but `mise.toml` no longer pins a runtime | `php` moved to optional binaries; AI workflow validators gated on `command -v php` and report a `[WARN]` block instead of failing when absent. Fresh Ubuntu hosts no longer abort at bootstrap step 9. |
| 2026-05-24 | **C5** — `mise.toml` `tools:optional:install` wrote to `~/.config/mise/config.toml`, which chezmoi also owns | Pins now land in `~/.config/mise/conf.d/optional-tools.toml`. mise auto-loads that file; the chezmoi-managed `config.toml` is untouched. Verified end-to-end: dive/fx/navi/glow/gum all resolve via the shim path. |
| 2026-05-24 | **Ghostty macOS path was wrong** — `home/dot_config/ghostty/config.tmpl` deployed to `~/.config/ghostty/config` on macOS, but Ghostty on macOS prefers `~/Library/Application Support/com.mitchellh.ghostty/config` (XDG works as fallback only) | Single source of truth body moved to `home/.chezmoitemplates/ghostty/config.body.tmpl`. Two thin wrappers point at it: `home/dot_config/ghostty/config.tmpl` (Linux/WSL desktop) and `home/Library/Application Support/com.mitchellh.ghostty/config.tmpl` (macOS). `.chezmoiignore` gates so each OS deploys to exactly one path. Validated via `chezmoi diff` for linux-desktop/linux-cli/wsl + macOS gate render. |
| 2026-05-24 | **chezmoi autoload failure** — `home/.chezmoidata/personal.yaml.example` was inside the `.chezmoidata/` autoload dir; chezmoi tried to parse `.example` as a data format and failed with `unknown format` on any first run | Example moved to `home/personal.yaml.example` (outside `.chezmoidata/`). `.chezmoiignore` excludes it from deployment. Doctor + validator + every doc updated; validator gained an explicit anti-regression rule that errors if `home/.chezmoidata/personal.yaml.example` reappears. |
| 2026-05-24 | **`.chezmoiignore` rule selector** — patterns used `dot_config/...` (source-tree path) instead of `.config/...` (target path). Result: `karabiner` and `Library/...` directory entries still appeared in `chezmoi diff` on Linux even though file children were excluded | Rewrote `home/.chezmoiignore` to use target paths (`.config/karabiner`, `Library/Application Support/...`). Added explicit dir entries alongside `/**` so chezmoi excludes the parent dir as well as children. Verified for all four host profiles. |
| 2026-05-24 | **`scripts/bootstrap.sh` `interactive_confirm` unbound `CI`** — with `set -u`, the log line `log "Non-interactive (CI=$CI or no tty); ..."` dereferenced `$CI` directly on the non-interactive auto-confirm path. In any non-TTY shell without `CI=` exported (cron, opencode, local automation) the bootstrap aborted with `unbound variable` instead of auto-confirming, breaking exactly the `--yes` path the function was meant to support. | Captured `${CI:-}` into a local `ci_flag` at the top of the function and log `CI=${ci_flag:-<unset>}` instead. Regression test: `env -i bash -c '...interactive_confirm "test"' ` now logs `CI=<unset> or no tty` and returns 0. |
| 2026-05-24 | **`.github/workflows/validate-ai-surface.yml` `test-php` job** — the job ran `composer install --no-interaction --prefer-dist` unconditionally; this repo (and any kit-only install) has no `composer.json`, so the step failed on every push and PR and kept the workflow permanently red on unrelated changes. | Added a `Detect PHP test project` step that checks for `composer.json` and gates the setup-php / composer-install / phpunit steps on `steps.detect.outputs.has_php == 'true'`. Emits a GitHub `::notice::` when skipped. Also added `--no-run-if-empty` to the `lint` job's shellcheck xargs invocation for the same parity reason. actionlint clean. |
| 2026-05-24 | **Personal project orchestrator imported from `C:\xampp\htdocs\project-scripts`** — original was 5 named projects (CMS / frontend / traverse / vue-components / stripe), hard-coded paths, 1058-line health monitor, 668-line PR watcher, project names in every script. | New `scripts/projects/` tree on `feat/project-orchestrator`. Generic over N projects via `home/.chezmoidata/projects.yaml` (gitignored). `tmux-master.sh` (~190 lines, generic), `tmux-logs.sh`, `tmux-ssh.sh`, `repo-checks.sh`, `health/run.sh` + `render.sh` + `checks.d/*`, `github/sync-main.sh`, slim `github/pr-watch.sh` (~110 lines). Zero project names in tracked code (leak grep passes). ~5k lines → ~640 lines. New mise tasks under `projects:*`. Docs: `repo-docs/projects/README.md`. |
| 2026-05-24 | **Codex P1 — `tmux-master.sh` dropped tertiary at N=3** — the outer `if [[ -n "$BOTTOM_L_ID" || -n "$BOTTOM_R_ID" ]]` only matched the 4+ project case. With exactly 3 projects, `TERTIARY_ID` was set but the `else` branch only opened primary + secondary, silently hiding the third project. | Rewrote the pane-assignment block around explicit N=1..5 cases keyed on whether `SECONDARY_ID` / `TERTIARY_ID` / `BOTTOM_L_ID` / `BOTTOM_R_ID` are set. N=3 now splits the right column once for tertiary. Regression test in `/tmp/tmux-master-p1-test.sh` confirms all five counts open the correct project set. |
| 2026-05-24 | **Codex P2a — `pr-watch.sh` rang `pr_review_requested` for every transition and never reached `ci_failed`** — any state change (mergeable, updatedAt, anything) fired the review-requested bell; the `ci_failed` event key in the config schema was unreachable. | Per-field transition detection: read `statusCheckRollup` from `gh pr list` and roll it up to `FAILURE`/`PENDING`/`SUCCESS`/`NONE`. Compare `reviewDecision` and the rolled-up CI state separately. `pr_review_requested` only fires when review becomes `REVIEW_REQUIRED`. `ci_failed` fires on `* → FAILURE`. Generic changes (mergeable, updatedAt only) log without ringing any bell. State file now persists `{review, ci, mergeable, updatedAt}`. |
| 2026-05-24 | **Codex P2b — `health/run.sh --quiet` exited 1 on warn-only runs** — `[[ "$(jq -r '.overall.status' <<<"$AGG")" == "ok" ]]` treated `warn` as failure, contradicting the documented "exit 0 if all ok, 1 if any fail" contract and breaking warn-only automation. | Replaced the `== "ok"` guard with `final_exit()` keyed on `overall.failed > 0`. Both `--quiet` and `pretty` modes now exit 0 for ok and warn-only, 1 only when at least one check has `status: fail`. Docstring updated to spell out the contract. Regression test for the four shapes (ok / warn-only / fail / warn+fail) confirms the mapping. |

## Process notes

When you, the reader, hit something that fails:

1. Note the literal command and the one-line failure reason.
2. Decide: **fix now** (smallest safe slice), **defer** (add row to "Open"), or **drop** (remove the broken caller).
3. If you defer, append a row under "Open" with `Symptom / Severity / Fix options / Owner`.
4. When the fix lands, move the row to "Resolved" with the commit hash.

Silent skips are not allowed. The agent rule in `AGENTS.md` ("Failure
flagging is mandatory") makes this the explicit completion criterion for
every slice.
