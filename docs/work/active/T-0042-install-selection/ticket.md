Source: local

# T-0042: Install selection: committed profiles, a local per-host selection, first-run choice (feature)

Status: open (design approved; T1 spike not started)
Wave: unassigned
Depends on: none to start (T1 is a gate). T4 touches ops/update-all.sh; land it
after T-0010 (now landed). Does not depend on T-0029..T-0033.

## Summary
Let a host pick what it installs without building a framework:
- committed profiles (`work`, `personal`, the existing `myConfig.profile` values),
  each a TOML table of group toggles;
- an optional local selection at `~/.config/app-configs/selection/selection.toml`
  that names a profile and overrides individual groups;
- a first-run question in `sys-install` on a TTY, with a preview of additions and removals;
- `sys-install --reconfigure` to ask again.
`sys-update` and hm-switch use the stored selection silently. With no local file,
every output is identical to today. Order: NixOS/linux-desktop (linux-cli free),
then macOS casks plus chezmoi gating, then a brief WSL2 check. Native Windows is out.

## Decision
Local selection enters Nix as a flake input:
`inputs.selection = { url = "path:./selection"; flake = false; }`, default the committed
empty nix/selection/selection.toml (new file). When
`${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/selection/selection.toml` exists, scripts add
`--override-input selection path:<dir>`. TOML read with `builtins.fromTOML` (chezmoi
can read it with `fromToml`). Pure evaluation, no `--impure`; on Nix 2.34.7
`--override-input` implies `--no-write-lock-file` (contract-proven), so flake.lock is
not dirtied by the override. home-manager and darwin-rebuild pass `--override-input`
through to `nix build` (code-inspected). Costs: one-time lock edit adding a
`selection` node (needs user approval; AGENTS.md has sys-update own the lock); relative
input behaviour must be proven in T1; every build/switch call site must pass the
override (guarded by a new single-owner rule).
Rejected: generated `homeConfigurations."<host>-<profile>"` outputs (2^n outputs,
kills custom setups); `--impure` + `getEnv` (same call-site cost, loses purity and
pinning); `personal.yaml` via chezmoi (purity split, mixes identity with choices); a
local file under `nix/` (invisible to git flake refs, visible to `path:` refs, and
update-all rejects untracked nix/ files).
Reuse: a committed profile is a value of the existing `myConfig.profile` option
(nix/modules/home/profile.nix:11-23); no parallel concept. Default output stays
identical: both profiles start all-true and packages are spliced in place with
`lib.optionals` (list order feeds the home-path drvPath).

## Owned files (write boundary)
- nix/flake.nix (inputs block only), nix/flake.lock (the new `selection` node only)
- nix/selection/selection.toml (new), nix/profiles/work.toml, nix/profiles/personal.toml (new)
- nix/modules/home/profile.nix
- nix/modules/home/cli.nix (media lines only), nix/modules/home/dev.nix (security and go lines only)
- nix/modules/darwin/homebrew.nix (phase 2; karabiner-elements and linearmouse lines only)
- ops/lib/selection.sh (new), ops/lib/hm-switch.sh
- ops/install.sh (args, the new selection step, darwin switch lines)
- ops/bootstrap.sh (switch lines), ops/update-all.sh (host build/switch lines), ops/audit.sh (eval line)
- home/.chezmoiignore (phase 2)
- tests/bash/selection.bats, tests/bash/install-selection.bats,
  tests/bash/chezmoiignore-selection.bats (new); tests/bash/fixtures/selection/** (new);
  tests/bash/single-owner.bats (one new rule)
- docs/getting-started/install.md, docs/architecture/tool-ownership.md,
  docs/platforms/wsl/setup.md (phase 3), docs/work/index.md (row)
Line numbers must be re-checked at implementation time (T-0010 changed update-all.sh).

## Findings (verified at main b3d303a unless marked)
- VERIFIED: `myConfig.profile` (work|personal, default work) set only in
  nix/hosts/linux-desktop/home.nix ("personal"); gates gui.nix personal apps and openclaw.nix.
- VERIFIED: `inputs` reaches HM modules via extraSpecialArgs (mkhome.nix and darwin
  home-manager.extraSpecialArgs); darwin specialArgs carry `vars`.
- VERIFIED: `nix build --help` (2.34.7): `--override-input` implies `--no-write-lock-file`.
- CODE-INSPECTED: home-manager passes `--override-input` to `nix build` in flake mode;
  darwin-rebuild does too (pinned revision UNVERIFIED).
- INFERRED, prove in T1: relative `path:./selection` input works under bare `git+file`
  and `path:` refs, and the lock gains only a `selection` node.
- VERIFIED: host build/switch call sites: ops/lib/hm-switch.sh (used by install,
  bootstrap, update-all, update-codebase-memory-mcp), ops/install.sh darwin switch,
  ops/bootstrap.sh switch, ops/update-all.sh host build/switch, ops/audit.sh eval.
  Validators and CI evaluate the committed default and should keep doing so.
- VERIFIED: install.sh says it is non-interactive by design; a TTY prompt changes that
  on a first run only (open question).
- VERIFIED: `~/.config/app-configs/` is a chezmoi target, not `exact_`, so chezmoi
  leaves a `selection/` subdirectory alone.
- VERIFIED: home/.chezmoiignore gates `.config/karabiner` by os and gui only;
  `.config/linearmouse` is ungated (deploys on Linux where the app does not exist).
- VERIFIED: homebrew.nix has `cleanup = "none"`: a deselected cask stays installed.
- VERIFIED: nothing in ops, tests, mise.toml or .lefthook.yml requires trivy,
  osv-scanner, ffmpeg, yt-dlp, imagemagick, viu or the Go toolchain; doctor checks
  repomix only as optional.

## Design
- Profiles: `nix/profiles/<name>.toml` with `[groups] <group> = true|false` listing every
  group; file name equals a `myConfig.profile` enum value; both start all-true.
- Groups: declared once in profile.nix as `options.myConfig.groups.<g>` (bool) with a
  description naming its packages; default from the profile TOML of the effective
  `myConfig.profile`. Phase 1: `media` (ffmpeg, yt-dlp, imagemagick, viu), `security`
  (trivy, osv-scanner), `go` (the Go block in dev.nix). Phase 2: `macInput` (casks
  karabiner-elements and linearmouse plus their chezmoi configs). Core tools are never
  in a group.
- Local selection: TOML with `profile` and optional `[groups]` deltas; enters Nix only
  via `inputs.selection` when a script passes `--override-input`. Unknown groups or
  profiles fail evaluation; an assertion requires `profile` whenever groups are set.
- Scripts: ops/lib/selection.sh (new file) is the single source of the override arguments
  (`SELECTION_DIR`, test override `APP_CONFIGS_SELECTION_DIR`; `selection_args`,
  `selection_preview`, `selection_write` via tmp + mv). hm-switch.sh sources it; other
  call sites append `"${SELECTION_ARGS[@]}"`. No prompt ever runs in sys-update,
  bootstrap or hm-switch.
- Precedence: `--profile` flag > TTY prompt > local file > committed profile default >
  host default (linux-desktop=personal, others=work). Flag and prompt only write the
  local file; Nix is the single place the selection is resolved.
- sys-install: gains `--profile NAME` and `--reconfigure`, and a "Selection" step after
  "Validate flake", before chezmoi or any switch.
  - `--reconfigure` without a TTY: exit 1, nothing written.
  - `--profile NAME`: write `profile = NAME`, drop group deltas, preview, continue.
  - Local file exists: use it, print one line (path and profile), never prompt.
  - No local file and a TTY: prompt profile (default = host's), then each group [Y/n]/[y/N]
    from profile defaults; preview; confirm; write only deltas.
  - No local file and no TTY: write nothing, use the committed default, never block.
  - `--reconfigure` on a TTY: prompt with current effective values pre-selected.
  - `--dry-run`: prompts and previews, writes and applies nothing.
- Preview: sorted diff of `home.packages` names, current vs proposed (proposed via a temp
  dir passed with `--override-input`). On macOS also diff `homebrew.casks`; every removed
  cask reads "stays installed (Homebrew cleanup = none); remove by hand: brew uninstall
  --cask <name>". On Nix, deselected packages leave PATH at the next switch; $HOME data stays.
- chezmoi (phase 2): `.chezmoiignore` resolves `macInput` from the local file, else the
  profile TOML read from the repo, else the host default profile; when off or not
  darwin, ignore `.config/karabiner` and `.config/linearmouse`. A bats parity test keeps
  the host-default mapping equal to `nix eval …config.myConfig.profile` for every host.

## Acceptance criteria
Phase 0 (gate, T1)
- AC0: baseline drvPaths recorded in evidence/ for the 4 activation packages and
  `darwinConfigurations.macos.system`; in a scratch copy the relative input evaluates
  under bare and `path:` refs; `--override-input` works with `nix build` and
  `home-manager build --flake`; `nix/flake.lock` is byte-identical after the override runs.
Phase 1 (NixOS / linux-desktop; linux-cli and wsl for free)
- AC1: no local file: each activation drvPath equals the T1 baseline; an all-on fixture
  also equals the baseline.
- AC2: a fixture with `media = false` and `go = false` evaluates; `home.packages` lacks
  ffmpeg and go and still has fish, ripgrep, fd, jq and git.
- AC3: an all-false fixture still provides every tool update-all, readiness and doctor
  require from Home Manager.
- AC4: an unknown group, unknown profile, or groups without `profile` fail evaluation
  with a message naming the key.
- AC5: the lock diff from this ticket adds only the `selection` node and its root
  input; running any script with a local selection leaves `nix/flake.lock` unchanged.
- AC6: `install.sh --reconfigure </dev/null` exits 1 before any mutation;
  `install.sh --dry-run </dev/null` with no local file prompts for nothing, writes
  nothing and uses the default; with a local file `SELECTION_ARGS` carries the override.
- AC7: `--profile` and TTY-prompt runs write only deltas; the preview lists additions and
  removals; a second run with the file present asks nothing.
- AC8: single-owner.bats fails if a host build/switch/eval call site in ops/ omits the
  selection arguments (seeded test, like existing rules).
- AC9: validate-config (text and --eval), nix-ownership.bats and `nix flake check ./nix`
  pass; the package matrix and static scanner still list every gated package by literal name.
- AC10: install.md documents the selection file, precedence, `--profile`,
  `--reconfigure` and removal behaviour; tool-ownership.md records the mechanism and why.
Phase 2 (macOS casks and chezmoi gating)
- AC11: `darwinConfigurations.macos.system.drvPath` equals the T1 baseline with no local
  file; with `macInput = false`, `homebrew.casks` lacks karabiner-elements and linearmouse.
- AC12: rendered `.chezmoiignore` ignores `.config/karabiner` and `.config/linearmouse` on
  darwin with `macInput = false` and always on non-darwin; on darwin with `macInput` on,
  neither is ignored; the host-default parity test passes.
- AC13: on macOS the preview marks removed casks as staying installed; the docs say so.
- AC14 (human): on a real Mac, `sudo darwin-rebuild switch --flake … --override-input
  selection path:…` works with the installed Determinate Nix and the lock is unchanged.
Phase 3 (WSL2 brief check)
- AC15: the wsl profile evaluates with a non-default fixture; `SELECTION_DIR` resolves
  under the Linux $HOME, not /mnt/c; wsl/setup.md has three or fewer lines pointing to install.md.
Negative (must not change)
- AC-N1: no prompt in update-all, bootstrap, hm-switch or CI paths.
- AC-N2: no new `--impure`, no file under `nix/` read from outside git.
- AC-N3: personal-app gates, `HOST_PROFILE` detection and the existing `.chezmoiignore`
  os, gui and hostProfile rules behave the same.
- AC-N4: no other flake.lock node changes; mise optional tools, the NixOS system layer
  and `ops/system-setup.sh` are untouched.
- Independent review PASS on each phase; one conventional commit per logical change;
  no AI attribution trailers.

## Plan
- [ ] T1: Baseline drvPaths and a mechanism spike in a scratch copy (evidence/ only). AC0. Review before T2.
- [ ] T2: Selection input, profiles and the groups option, no packages gated. AC1 (partial), AC4, AC5.
- [ ] T3: Gate media, security and go in place. AC1, AC2, AC3, AC9.
- [ ] T4: Pass the selection at every build/switch/eval call site; single-owner rule. AC5, AC8, AC-N1.
- [ ] T5: sys-install `--profile`, `--reconfigure`, prompt, preview and write. AC6, AC7.
- [ ] T6: Phase 1 docs and the index row. AC10.
- [ ] T7: Phase 2 macInput casks and chezmoi gating. AC11, AC12, AC13 (AC14 human).
- [ ] T8: Phase 3 WSL2 brief check. AC15.

## Verification
- `nix eval --raw "path:$PWD/nix#homeConfigurations.<p>.activationPackage.drvPath"` per
  profile, with no local file and with the all-on fixture, vs the T1 baseline; same for
  `darwinConfigurations.macos.system.drvPath`.
- `bats tests/bash/selection.bats tests/bash/install-selection.bats tests/bash/single-owner.bats tests/bash/chezmoiignore-selection.bats`
- `nix flake check ./nix`; `nix flake check ./nix --all-systems --no-build`
- `nix build --no-link "path:$PWD/nix#homeConfigurations.$(bash ops/detect-host.sh).activationPackage"`
- `bash ops/validate-config.sh --eval`; `bats tests/bash`; `chezmoi diff`; `bash ops/update-all.sh` (report mode)
- `git diff --stat nix/flake.lock` shows the `selection` node only.

## Open questions (answer before implementation)
1. Keep profile names `work | personal` (recommended) or rename to `work | home`?
2. What should each profile actually turn off? (Both start all-on, so nothing changes.)
3. Is a prompt acceptable in `sys-install` on a first run with a TTY and no stored
   selection, or only with `--reconfigure` (and `--profile` for unattended runs)?
4. Approve the one-time `flake.lock` edit adding the `selection` node?
5. Are `media`, `security` and `go` the right phase-1 groups? Add `aiContext` despite
   breaking drvPath identity once?
6. Phase 2: only `macInput` (karabiner-elements, linearmouse), or also aerospace,
   alt-tab, raycast, granola? OK that linearmouse config stops deploying on Linux?
7. First install without a TTY: write nothing (recommended) or write the host default?
8. `--profile NAME` with an existing local file: replace group deltas (recommended)?
   Is `--profile` an acceptable name next to `HOST_PROFILE`?
9. (Resolved) T4 lands after T-0010, which is now landed.

## Out of scope / notes
- Rollback: delete `~/.config/app-configs/selection/`; the next sys-update returns to
  the committed default. Revert commits; HM generations allow rollback.
- "Profile" has two meanings (host profile `HOST_PROFILE` vs selection profile
  `myConfig.profile`); docs must say which.
- Build-affecting: validate per AGENTS.md before any commit; the lock edit needs approval.
- Discarded or deferred:
  - Per-package toggles: groups are enough.
  - TUI, DSL or plugin system: ruled out; plain prompts only.
  - Auto-uninstalling casks (cleanup = "zap"): destructive.
  - Selections for the NixOS system layer and `ops/system-setup.sh`: T-0029 owns it.
  - Native Windows: out.
  - Group flags on the command line (`--with`/`--without`): edit the TOML or `--reconfigure`.
  - aiContext, dev-language and nix-maintenance groups: deferred (scattered packages
    or other checks depend on them).
  - Gating mise optional tools: already local and opt-in.
  - Desktop-environment pieces (vicinae, GNOME, niri): T-0031 and T-0032.
  - Removing the selection directory in uninstall.sh: manual step, documented.
  - Writing an effective-selection file from Home Manager: would change the default drvPath.

## Decisions (user, 2026-11-14)

- Keep `work` and `personal`.
- Both profiles start all-on, preserving the current effective configs.
- A first-run prompt is approved for a first install on a TTY only, with no unattended prompts.
- Approve the one-time `flake.lock` addition of the `selection` input only.
- Initial groups: `media`, `security` and `go`. `aiContext` is deferred until a dependency and regression analysis.
- macOS: `macInput` only (Karabiner-Elements, LinearMouse). Stop deploying the macOS-only LinearMouse config on Linux.
- Non-TTY install writes no selection file and uses the defaults.
- `--profile NAME` replaces group overrides, with a clear preview.
- Keep `--profile`, but document the selection profile vs `HOST_PROFILE` distinction.
- Extra acceptance constraints:
  - no local selection means an identical activation derivation;
  - invalid configurations fail before any system change;
  - every build/switch entry point receives the same selection;
  - no automatic macOS app uninstall or user-data deletion;
  - `--dry-run` never persists a selection;
  - any unexpected change to existing `flake.lock` inputs blocks the change.
- Phase 0 (T1) must pass before later phases are authorised.
- Priority P2, after the update/rollback baseline is stable.
