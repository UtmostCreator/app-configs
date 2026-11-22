Source: local

# T-0042: Install selection: committed profiles, a local per-host selection, first-run choice (feature)

Status: done, pending human (T1-T8 on main; real-Mac checks via T-0046; extension questions Q1-Q11 await owner, Q6 answered by T-0044)
Niri desktop installation and component decision register: [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md). The Niri migration registry uses existing Linux desktop GUI selections as inherited baseline; this ticket does not select a Niri shell or change its session/installation ownership.
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
then macOS casks plus chezmoi gating, then a brief WSL2 check. Native Windows future planning is described in the 2026-11-14 extension below; it remains unimplemented.

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
- [x] T1: Baseline drvPaths and a mechanism spike in a scratch copy (evidence/ only). AC0. Review before T2.
- [x] T2: Selection input, profiles and the groups option, no packages gated. AC1 (partial), AC4, AC5.
- [x] T3: Gate media, security and go in place. AC1, AC2, AC3, AC9.
- [x] T4: Pass the selection at every build/switch/eval call site; single-owner rule. AC5, AC8, AC-N1.
- [x] T5: sys-install `--profile`, `--reconfigure`, prompt, preview and write. AC6, AC7.
- [x] T6: Phase 1 docs and the index row. AC10.
- [x] T7: Phase 2 macInput casks and chezmoi gating. AC11, AC12, AC13 (AC14 human).
- [x] T8: Phase 3 WSL2 brief check. AC15.

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
2. What should each profile actually turn off? (Both start all-on, so nothing changes.) ADR-0021 P5a (decided gate): nothing now; see P5b.
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
  - Native Windows automated application management: out; T-0041's documentation-only policy governs Windows. The 2026-11-14 extension, section 3, records a future WinGet installer that needs separate approval.
  - Group flags on the command line (`--with`/`--without`): edit the TOML or `--reconfigure`.
  - aiContext, dev-language and nix-maintenance groups: deferred (scattered packages
    or other checks depend on them).
  - Gating mise optional tools: already local and opt-in.
  - Desktop-environment pieces (vicinae, GNOME, niri): T-0031 and T-0032. Open since 2026-11-22: the niri install carries no GNOME desktop (ADR-0012), but the `linux-desktop` Home Manager output still imports the GNOME modules and two GNOME Shell extensions, and the installer knows no `linux-niri` host or profile (ADR-0046 G28).
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

---

## Extension (2026-11-14): cross-platform selectable CLI, GUI and Windows/WSL2

Status: proposed. Nothing in this section is approved until the user answers
Q1–Q11 (§7). It merges the pushed extension (a23ad46, 4022763) with the
reviewed draft "Revision 2026-11-14b" into one design.

**Request:** extend the install-selection plan beyond the initial `media`, `security`, `go` and `macInput` groups. Let users choose additional CLI tools, GUI apps and manageable supporting components on Linux, macOS and Windows 11 + WSL2, using the appropriate installer for the detected platform. Support the `personal` and `work` selection profiles: e.g. Telegram/Vesktop for personal, Teams for work. This is a **ticket/design amendment only**, not authorisation to install software or change the currently deployed system.

**Authority / compatibility:** preserve the approved T1–T8 gates and all no-selection baseline invariants above. This extension would supersede the earlier **design-scope** statements "Native Windows: out" and "Per-package toggles: groups are enough" **for subsequent planning only**, if Q2/Q3 are approved. It does **not** silently repeal T-0041's explicit *docs-only / no automated winget* implementation decision, or `docs/plans/migration/implementation.md` Appendix A: reconcile that policy explicitly before implementing a Windows writer. Until then Windows is **documented manual commands only** (T-0041): no repo script, preview or prototype runs on Windows. Do not blend native Windows work into the already approved Nix T1–T8 patch set.

Approved statements this extension would change. Each is tied to a question;
until it is answered, the approved text governs.
- "Native Windows: out": narrowed to the T-0041 manual list, a Group column in
  apps.md and a WSL pointer line (Q3, Q8). A repo-run Windows installer stays out (§3).
- "Per-package toggles: groups are enough": allowlisted `[apps]` overrides or
  single-app groups (Q2). Arbitrary per-package switches stay rejected.
- "Both profiles start all-on": every group defaults to today's effective state (Q10).
- T2 also creates the group registry (Q1).
- The nix-maintenance deferral is reopened by the `nixTools` candidate (Q7).
- AC-N3 is reworded (§5).
- `go` group: would also gate the gremlins xdg.configFile (dev.nix:182), which sits outside the approved "Go block"; applies in T3 only if approved, otherwise T3 gates packages only.
- AC1's all-on fixture holds in Phase 1, when only media, security and go exist.
  Once Phase 5/6 add groups that are off in a profile, T12/T13 replace it with a
  "committed defaults" fixture. The assertion (fixture output equals default
  output) stays as strong. AC3 is unchanged; AC17 adds the readiness sample.

### 1. Installation boundaries and automatic target detection

| Detected target | Installation owner | What is selectable | What must not happen |
| --- | --- | --- | --- |
| NixOS / Linux desktop | Nix/Home Manager, existing system owner; chezmoi for user configs | Existing and newly audited optional CLI groups, Linux GUI apps, opt-in HM services with their app | No separate apt/Flatpak ownership of a Nix-owned package, no removal of user data |
| Other Linux CLI/headless | Nix/Home Manager | CLI/dev groups only; no desktop-specific app or system setting | Never offer unsupported GUI choices |
| macOS | Home Manager for cross-platform CLI, nix-darwin/Homebrew for casks, chezmoi for configs | CLI groups and audited GUI casks (including optional personal/work apps) | No parallel `brew install` outside the existing nix-darwin owner; `cleanup = "none"` stays |
| WSL2 Ubuntu | Linux Home Manager, `nix/hosts/wsl/home.nix` | Same Linux CLI/dev options; WSL-only integration and daemon/client choices when verified | Do **not** install Windows desktop apps inside WSL; do not run macOS apps, Linux desktop apps or Colima VM in WSL |
| Windows 11 host | The user, by hand: PowerShell + **WinGet** per the planned docs/platforms/windows/apps.md (not yet created; T-0041, documentation only). A repo-run WinGet installer is a future proposal (§3) | Native terminal/editor, fonts, desktop apps and selected work/personal apps from the T-0041 list; Windows-only utilities only if Q8 amends T-0041 | Do not let WSL `sys-install` or `sys-update` silently invoke `winget.exe`, mutate Windows, change UAC/registry/Defender, or remove native apps |

- Detect OS/host once, using existing `ops/detect-host.sh` (macos, linux-desktop, linux-cli, wsl). linux-desktop vs linux-cli is **not** detected: it comes from `HOST_PROFILE` / `HOST_PROFILE_DEFAULT` (default linux-desktop). sys-update re-detects on every run (update-all.sh:412), so a headless host must export `HOST_PROFILE`; persisting it is Q6. The selection step prints "Host: <p> (headless? HOST_PROFILE=linux-cli)". A future Windows entry point (§3) would use PowerShell `$IsWindows` when available or a safe Windows-version probe. Profile (`work|personal`) is a **user choice**, not an OS detector; `HOST_PROFILE` is still an OS/host override and must not be conflated with `--profile`. WSL helpers (wsl-open, clip.exe/interop, wsl-check) are host-fixed on wsl, never a choice.
- A single physical Windows PC has **two independent installation targets**: the Windows host for GUI software and the WSL Linux distribution for dev CLI. Windows-side documentation may give the `wsl --install` / Ubuntu step, but WSL provisioning, export backups, `/etc/wsl.conf`, kernel update, admin prompts and distro migration stay separate from app selection and retain T-0034–T-0040 safety checks.
- WSL must work even if native Windows selections were never applied. Conversely, the Windows app list must work with no WSL distribution present. No automatic traversal into the other OS and no assumption that `winget.exe` works from WSL.
- Prefer one installer per app **per target**. Having a Linux `git` in WSL and Windows `Git.Git` for explicitly Windows-native tooling is legitimate; installing Windows Node/PHP/Composer/pnpm/gh merely to mirror the WSL CLI is not. Record explicit exceptions and test PATH precedence (`command -v node npm npx pnpm php composer git code` in WSL).
- Current repo finding: `dev.nix` includes `colima` in the shared package list (dev.nix:83) although `docs/platforms/wsl/setup.md` says not to run it inside WSL. Audit and plan a platform gate separately; do **not** mix that baseline-changing cleanup into T1's identity test.

### 2. Selectable groups, packages, services and configuration

**Keep the simple, approved prompt and TOML mechanism.** Core/bootstrap dependencies are always-on: packages used by `ops/install.sh`, `ops/update-all.sh`, `ops/doctor.sh`, `ops/validate-config.sh`, selection/preview/rollback, shell boot and credentials. Build a machine-checked dependency graph from actual call sites before promoting any additional package to optional.

Candidate groups (contents final after the T9 audit; do not gate unexamined packages).
Default rule: a package installed today defaults on in both profiles, except the
existing personal gates, which stay personal-only. A package not installed today
defaults off in both (AC-N6, Q10).

| Group | Hosts / owner | Candidate contents | Default work/personal |
| --- | --- | --- | --- |
| `media`, `security`, `go`, `macInput` | Approved T-0042 groups | Approved membership and macOS config gating. `go` also gates `xdg.configFile."gremlins/gremlins/.gremlins.yaml"` (dev.nix:182) (proposed, see the list above) | Unchanged from approved design |
| `cliConvenience` | Nix, every Unix target | btop, ripgrep-all, tlrc, tree, yazi, entr, dust, navi, sd, glow. chezmoi ignores `.config/btop` when off. `viu` stays in `media`; `parallel` is core (run-bats.sh:58) | on/on |
| `nixTools` (Q7; reopens a deferral) | Nix, every Unix target | deadnix, statix, nh, nix-index, nix-output-monitor, nvd. mise `lint` only reports statix/deadnix as advisory "missing:" (mise.toml:278-281); nixfmt stays core | on/on |
| `devExtras` (Q7) | Nix, every Unix target | act, ast-grep, tree-sitter, difftastic, onefetch, xh, hyperfine, watchexec, lizard, just | on/on |
| `aiExtras` | Nix all Unix targets | Deferred. The aiContext packages (code2prompt, files-to-prompt, repomix, opencode, codebaseMemoryMcp + units, used by .vscode/mcp.json and the timer path) stay ungated until the old deferral's regression audit passes. promptfoo is repo tooling (core) | existing: ungated; new candidates off/off |
| `containerTools` | Nix CLI; native daemon selected separately | Extras such as docker-buildx/compose and the daemon choice (macOS Colima vs Desktop; Linux Engine; Windows Docker Desktop integration vs WSL Engine). The `docker` CLI is core (readiness sample). No two active daemon owners; warn about licence and admin requirements | today's state |
| `dbTools` | Nix CLI; future native tools only if needed | MySQL/MariaDB client and future Redis/DB clients, with macOS Homebrew `mysql-client` exception; check PHP dev dependencies (php is core) before making optional | today's state |
| `desktopUtilities` (Q9) | linux-desktop Nix; macOS casks only if Q9 | Obsidian, KeePassXC, QDirStat, Double Commander, LocalSend, Czkawka (desktop table below) | on/on |
| `mobileDev` (Q9) | linux-desktop Nix (linux-desktop only for now: the macOS and Windows mappings are unverified) | Android Studio; SDK licences, emulator acceleration and large downloads are post-install checks; WSL gets CLI-only if specifically supported | on/on |
| `personalChat` | linux-desktop Nix; macOS casks | Telegram, Vesktop (separately selectable per Q2) | off/on |
| `personalSync` | linux-desktop Nix | Syncthing + helpers + the existing `services.syncthing` | off/on |
| `workComms` (Q2) | macOS casks; linux-desktop Nix for Slack/Zoom; Linux Teams per Q5 | Teams, Slack, Zoom | off/off (Q4) |
| cloud CLIs (Q2: one group or aws/azure/gcp) | HM, every Nix host incl. wsl | awscli2, azure-cli, google-cloud-sdk | off/off |
| `windowsUtilities` (Q8) | Native Windows only, manual list | PowerToys / PowerShell 7 / 7-Zip / Git for Windows: not adopted under T-0041's parity rule | n/a |

- Never grouped (F6, code-inspected):
  - Required by checks: nix, git, chezmoi, home-manager / darwin-rebuild, curl, jq (update-all.sh:735-737); mise, fish, rg, fd (its verify step); lefthook, yq and gitleaks (readiness core and pre-commit); bash (doctor).
  - Readiness sample (readiness.sh:53-59): fzf, bat, eza, zoxide, starship, atuin, tmux, nvim, lazygit, delta, gh, node, npm, php, docker, stripe; GUI firefox, code, ghostty, bruno, flameshot.
  - Repo tooling: lsof (update-all.sh:161), parallel (run-bats.sh:58), nixfmt, bats, shellcheck, shfmt, actionlint, promptfoo, composer, composer-require-checker.
  - Likely core, AC16 decides: lnav (ops/ci-packages.txt:26), scc (doctor.sh:81).
  - Deferred: aiExtras (above); langExtras (bun, uv, pnpm).
- Group registry (Q1): the planned registry file nix/profiles/groups.toml (not yet created) holds metadata only: description, hosts, windowsHost, phase (and, if Q2 = a, the allowlisted app IDs per group). profile.nix reads it to declare `myConfig.groups.<g>`; selection.sh reads it with `yq -p toml` (yq is core) for prompt text and host filtering. Package lists stay literal in the modules, because the scanner needs literal names. Parity test: registry keys = work.toml keys = personal.toml keys = declared options.
- A logical app ID maps to 0 or 1 **installer owner per host** (e.g. `telegram`: Nix `telegram-desktop` on Linux desktop, Homebrew `telegram-desktop` on macOS, WinGet `Telegram.TelegramDesktop` on Windows by hand; unsupported in WSL). Availability is the intersection of catalog support, actual host architecture, installer capability and policy, not simply a checkbox.
- Proposed (Q2 option a): support an **advanced, allowlisted app/tool override** alongside group switches, to satisfy individual CLI choices without a generic dependency/package-manager DSL. A group is a convenient bulk default; an explicit per-app override wins. Candidate TOML extension (introduced only after T1–T8 and migration tests): `[apps]` with keys such as `telegram`, `vesktop`, `"yt-dlp"`. Keys are stable logical IDs, not executable commands, Nix attributes or arbitrary WinGet package IDs. Unknown IDs and unsupported **explicit** targets fail early with a useful reason; unavailable defaults are shown as N/A and excluded. A selected package that a required script depends on cannot be disabled. Q2 option b instead uses single-app groups and no `[apps]` table. Either way, a valid group key with no mapping on this host is a no-op, and the preview marks it N/A.
- Any optional daemon, systemd unit/timer, `xdg.configFile`, chezmoi target, GNOME hook, macOS service or login item is selectable **only as a dependency of the owning app/group** (examples: go gates the gremlins config; cliConvenience gates `.config/btop`; personalSync wraps `services.syncthing`). Disabling it must disable its managed integration without deleting files, app data, credentials or user-defined service state. Never expose raw system/registry/security settings as arbitrary toggles.
- Keep existing profiles `work` and `personal`. Recommended UX: first choose profile, then show the groups that have an effect on this host (plus Windows-host groups on wsl, marked "Windows, by hand") with current defaults, then `Customize individual apps and optional CLI tools?` (default No; only if Q2 = a), then platform-specific preview and confirmation. Work preset: no personal chat by default; Teams is offered **opt-in** (never installed without an explicit choice). Personal preset: Telegram/Vesktop options; no Teams by default. An explicit override can cross presets after the preview makes the exception visible.
- The *existing Linux personal* Telegram/Vesktop/Syncthing configuration and existing all-on Nix groups must remain unchanged with **no local selection**. Never change `myConfig.profile` or make work/personal toggles implicitly enable new Mac/Windows installs on `sys-update`. Baselines protect existing hosts; new optional apps require deliberate selection and explicit apply.

**Desktop apps by host.** gui.nix is imported by linux-desktop and macos; its
package lists are Linux-guarded, so macOS uses casks. Every cask token not marked
"today" and every winget id is UNVERIFIED (check with `brew info --cask` and
`winget show --id <id> --exact --source winget`). Nix attrs were verified against
the pinned nixpkgs on 2026-11-14.

| Group | App | linux-desktop (Nix) | macOS (cask) | linux-cli | wsl | Windows host (by hand, id UNVERIFIED) | Default work/personal |
|---|---|---|---|---|---|---|---|
| core GUI (never grouped) | Firefox | firefox (gui.nix:18) | firefox (today) | none | Windows host | Mozilla.Firefox | always |
| core GUI (never grouped) | Brave (default browser) | brave (gui.nix:19) | brave-browser@beta (today) | none | Windows host | Brave.Brave or Brave.Brave.Beta (choose channel explicitly) | always |
| core GUI (never grouped) | Ghostty | ghostty (gui.nix:26) | ghostty (today) | none | none (Windows Terminal) | n/a (no Windows build) | always |
| core GUI (never grouped) | VS Code | vscode (gui.nix:27) | visual-studio-code (today) | none | Windows host + Remote-WSL; `code .` shim | Microsoft.VisualStudioCode | always |
| core GUI (never grouped) | Flameshot | flameshot (gui.nix:29) | none | none | Windows host | Flameshot.Flameshot | always |
| core GUI (never grouped) | Bruno | bruno (gui.nix:32) | bruno (today) | none | Windows host | Bruno.Bruno | always |
| desktopUtilities | Obsidian | obsidian (gui.nix:33) | obsidian (today; grouped only if Q9) | none | Windows host | Obsidian.Obsidian | on/on |
| desktopUtilities | KeePassXC | keepassxc (gui.nix:34) | none today (adding one is a new app) | none | Windows host | KeePassXCTeam.KeePassXC | on/on |
| desktopUtilities | QDirStat, Double Commander, LocalSend, Czkawka | qdirstat, doublecmd, localsend, czkawka (gui.nix:41-45) | localsend, grandperspective, nimble-commander (today; grouped only if Q9) | none | Windows host (Double Commander, LocalSend) | alexx2000.DoubleCommander, LocalSend.LocalSend; QDirStat/Czkawka not listed | on/on |
| mobileDev | Android Studio | android-studio (gui.nix:28) | none | none | none | not listed in T-0041 | on/on |
| personalChat | Telegram | telegram-desktop (today, personal gate) | telegram-desktop (new) | none | Windows host | Telegram.TelegramDesktop | off/on |
| personalChat | Vesktop (unofficial Discord client, ToS risk) | vesktop (today, gui.nix:349) | vesktop (new) | none | Windows host | Vencord.Vesktop | off/on |
| personalSync | Syncthing + helpers + `services.syncthing` | today (gui.nix:476) | deferred (unknown) | none | none | deferred (T-0041) | off/on |
| workComms | Teams | none: web/PWA (Q5; alt teams-for-linux 2.29.0, unofficial) | microsoft-teams (new) | none | Windows host | Microsoft.Teams (often preinstalled/MDM) | off/off (Q4) |
| workComms | Slack | slack | slack (new) | none | Windows host | SlackTechnologies.Slack | off/off |
| workComms | Zoom | zoom-us | zoom (new) | none | Windows host | Zoom.Zoom | off/off |
| (T-0041 list, always) | Windows Terminal, JetBrainsMono Nerd Font | as declared | font-jetbrains-mono-nerd-font (today) | n/a | Windows host | Microsoft.WindowsTerminal, DEVCOM.JetBrainsMonoNerdFont | always (manual) |
| windowsUtilities (Q8) | PowerToys, PowerShell 7, 7-Zip, Git for Windows | n/a | n/a | n/a | n/a | Microsoft.PowerToys, Microsoft.PowerShell, Git.Git; 7-Zip id to verify | not adopted |
| (T-0041 deferred) | Docker Desktop vs Docker Engine | n/a | applicable cask after audit | n/a | WSL Engine **or** Desktop integration, never both | id to verify | deferred |
| (ungrouped, macOS-only casks) | sequel-ace, granola, raycast, aerospace, alt-tab, betterdisplay, ice, notunes, stats, fonts, 1password-cli, copilot-cli | n/a | today | n/a | n/a | n/a | always (macOS cask groups limited to macInput by the 2026-11-14 decision) |
| (not grouped) | GNOME/Vicinae helpers, wl-clipboard, audio/usb utils | today | n/a | n/a | n/a | n/a | T-0031/T-0032 own them |
| (no group) | Outlook, OneDrive, Office, VPN, MDM agents | web | employer-managed | none | none | employer-managed | docs only |

- Bruno and Flameshot are core GUI because readiness checks them (readiness.sh:53-59). The readiness GUI sample (firefox, code, ghostty, bruno, flameshot) and the default browser are core.
- Only the gui.nix personal gates (gui.nix:349, 363, 476) migrate to personalChat/personalSync; openclaw.nix:82 stays on `myConfig.profile`. Keep the `stdenv.hostPlatform.isLinux` guard in gui.nix; macOS gets personalChat through casks in homebrew.nix only. Under Q10 option A the drvPaths stay identical: only linux-desktop is personal today, and the work hosts lack these apps today.
- KeePassXC's Alt+1 raise-or-launch binding lives in gnome-keybindings.nix:99-104 (outside this ticket). With KeePassXC off it launches nothing; AC16 records the verdict.

Selection file (approved shape; the `[apps]` block only if Q2 = a):

~~~toml
# ~/.config/app-configs/selection/selection.toml (per machine, never synced)
profile = "work"            # required when [groups] is present
[groups]                    # deltas only; an unknown key is an evaluation error
media = false
workComms = true            # macOS: casks; wsl: Windows pointer; linux-cli: no-op (N/A)
# [apps]                    # only if Q2 = a; allowlisted logical IDs
# zoom = false
~~~

- A per-platform section is rejected: the file lives on one machine, and unavailable groups are no-ops.
- chezmoi: `.chezmoiignore` resolves only the groups that own dotfiles (macInput, cliConvenience). The order is the local delta, else `profiles/<profile>.toml`, else the host-default profile. It reads the local file with `stat` + `include` of an absolute path (inferred; prove in T7). A parity bats test checks this resolution against `nix eval` for each fixture.
- Readiness, doctor and verify are unchanged: nothing their required checks or the readiness sample name is grouped (AC3, AC17).
- validate-config: rule 6 (programs/services allowlist) still holds, because there are no new `programs.*.enable` or services. personalSync wraps the existing, allowed `services.syncthing`. The gremlins key stays in ALLOWED_XDG_KEYS (validate-config.sh:588); T3 confirms the text scanner still matches the gated form. Rules 7/8 cover only the bootstrap tools and are unaffected. Profile and registry files are tracked TOML, not `.nix`, so rule 10 does not apply. `--eval` and CI stay on the committed default.

### 3. Windows: current policy, options, app review and a future installer proposal

**Current policy (authoritative): T-0041.** Windows apps are a documentation-only, copy-only list in the planned docs/platforms/windows/apps.md (not yet created, not yet landed). The user installs them by hand in PowerShell, one `winget install --id <id> --exact` at a time. The list is limited to apps used on macOS or Linux. No repo script runs winget, wsl.exe or PowerShell. No DSC, registry or `windows/` layer. This extension does not change that policy; Q3 and Q8 propose bounded additions that go through T-0041.

Options (Q3):
- (a) Docs only, plus a Group column in apps.md and one WSL pointer line after the switch: "Windows apps for groups X, Y: docs/platforms/windows/apps.md (install by hand in PowerShell)". RECOMMENDED. It runs nothing on Windows and adds only the pointer and the new rows (via T-0041).
- (b1) sys-install on wsl prints the winget lines for the selected groups from the registry, and runs nothing. A proposed revision of T-0041 that needs a user decision.
- (b2) Generate a winget import JSON or a configure YAML. Rejected: configure is DSC, which T-0041 excludes; import adds schema upkeep, runs serially and has no per-package scope.
- (c) A WSL interop helper that calls powershell.exe/winget. Rejected: it needs UAC, interop may be disabled on work machines, winget's App Execution Alias is flaky from WSL, the output is CRLF/UTF-16, and it violates T-0041.
- (d) The native PowerShell/WinGet installer below. Not decidable in this ticket: it needs separate approval.

Windows app review (proposed changes to the T-0041 list, decided in Q8; the parity rule is met once a group declares the app on macOS or Linux):
- Add: Teams, Slack and Zoom (workComms), and Vesktop (personalChat).
- Keep deferred, in T-0041's wording: Syncthing on Windows (a tray app such as SyncTrayzor or syncthingtray is part of that later decision), PowerToys, 1Password desktop, "Docker Desktop vs Docker Engine".
- Proposed new rejections for apps.md "Discarded": Discord (Vesktop chosen); Everything (Windows-only; ShareX is already discarded); 7-Zip (Windows 11 extracts 7z natively [memory/unverified]; p7zip lives in WSL); Git for Windows (git and SSH live in WSL); Chocolatey and Scoop (no gain over winget for these apps). The pushed extension instead proposes `windowsUtilities` (PowerToys, PowerShell 7, 7-Zip, `Git.Git`) for concrete Windows needs; Q8 decides.
- WSL2 tooling: no new packages. wslu was removed from nixpkgs (proven with `nix eval`) and wsl-open replaces it; clip.exe stays (interop); the SSH-agent bridge and .wslconfig stay discarded/deferred per T-0041; WSLg Linux GUI apps are not offered.
- Native Windows Teams is the default choice for Windows work communications; Mac can use the cask; Linux work uses the official browser/PWA route. The Windows work set may be empty on a personal PC until explicitly chosen. Do not conflate Teams app installation with subscription entitlement.

**Future proposal: native WinGet installer (option d). Not part of this plan; needs separate approval after reconciling T-0041 and Appendix A, and a real Windows test host.** T-0041 currently discards "a `windows/` layer (`setup.ps1`, `doctor.ps1`, DSC)", so this proposal also needs that discard amended. The text below is kept from the pushed extension.

**Why WinGet:** Windows 11 provides a capable command-line package manager through App Installer. It can `search`, `show`, `list`, `install`, `upgrade`, `export/import` and `configure`; it supports installation by exact ID and source. The limiting cases are missing/unverified manifests, UAC, machine-vs-user scope, package-specific installers and managed-device policy, **not** a general inability to install apps from a terminal. Do not introduce Scoop/Chocolatey or `winget configure`/DSC merely for this use case.

**Proposed files (future write boundary; not added by this ticket update):** `windows/catalog.json` with canonical logical IDs, verified WinGet IDs/source, platform/scope, profile/group defaults, install owner and notes; planned ops/windows/install-apps.ps1 (not yet created) as a **separate** Windows-native preview/apply entry point; targeted Pester/mock tests (or a hermetic PowerShell smoke suite), planned docs/platforms/windows/apps.md (not yet created) and a one-sentence update to the ownership/Appendix A policy after reconciliation with T-0041. Use JSON for the native Windows catalog and the **local** native Windows selection because Windows PowerShell can read it without a TOML parser/dependency; Linux/macOS/WSL continue using approved `selection.toml`. The two host-specific selections share logical profile/group/app IDs (the §2 registry) but are **not silently synchronised** across the Windows/WSL boundary; a parity test checks shared logical IDs. Avoid requiring PowerShell 7 before the bootstrap, or generating and executing arbitrary PowerShell from WSL.

**CLI contract (names illustrative until the implementation review):**

~~~powershell
# Run in Windows PowerShell, not WSL. These are proposed future commands.
.\ops\windows\install-apps.ps1 -Profile personal -Preview
.\ops\windows\install-apps.ps1 -Profile personal -Reconfigure
.\ops\windows\install-apps.ps1 -Apply          # explicit Windows mutation
.\ops\windows\install-apps.ps1 -Check          # installed/selected/missing summary
~~~

- Discovery/preview is read-only. `-Apply` requires an explicit user action (and confirmation if interactive); no surprise admin elevation, reboot, pre-accepted licence, default-app reassignment or automatic user/machine scope switch. In noninteractive use require an additional explicit opt-in flag for any previously approved agreements; otherwise stop with manual steps. Refuse policies that block an install; do not bypass them.
- Verify package ID and architecture with `winget show --id <ID> --exact --source winget`; inspect installed state with `winget list --id <ID> --exact` and distinguish not-installed from query/source/exit failures. Use `winget install --id <ID> --exact --source winget` for a confirmed manifest; avoid fuzzy searches, unverified IDs, `--force`, `--ignore-security-hash`, blanket `--silent`, `--scope machine` or blindly accepting every agreement. Source agreements and package agreements are distinct; log both.
- Output an ordered, per-app plan: detected/unsupported/selected/already installed/install required/manual/UAC needed/failed/restart needed; include package ID, owner, version when reliable, action and exit code. A retry is idempotent and resumes failed items; an unlisted existing app is **never uninstalled**. `-Check` and preview must not access secrets. `-Upgrade` (if added later) updates only opted-in WinGet-owned IDs with a preview, never `winget upgrade --all`.
- Distinguish **application install** from **Windows account/work isolation**: `work` and `personal` presets choose apps but do **not** create separate Windows users, separate Teams data, separate browser profiles, or enforce security boundaries. On a shared Windows account, switching profiles does not remove earlier apps. Enterprise-managed device policy, licence, login, MFA and tenant restrictions remain operator/IT-owned; no secrets or account IDs in a committed or local selection.
- If a WinGet manifest is absent or unreliable, mark `manual` with official installer URL; never fetch-and-execute an arbitrary PowerShell script. If WinGet is unavailable at first login, report App Installer registration/repair guidance (it becomes available after first user login); do not silently install another package manager. Windows Terminal can already be present.
- Do not auto-install Windows-native Node, PHP, Composer, pnpm, Python, Go, Nix, `gh`, Docker CLI or SSH tools solely for parity with WSL. Optional native Git/PowerShell 7/Android Studio have valid Windows-specific reasons; only install when selected. VS Code Windows + Remote WSL is the GUI/editor owner; the WSL `code .` shim is integration, not a second Linux VS Code GUI install.
- Future steps if approved: W1, policy reconciliation and a read-only prototype (no `-Apply`, registry/DSC changes or WSL calls; manifest ID verification; mocked tests). W2, guarded `-Apply` for selected IDs on a real Windows host (idempotence, per-user vs machine installers, UAC/agreements, failed downloads, installed-app detection, no auto-uninstall, no auto-restart, no work-policy bypass; independent of `sys-update` and WSL). Acceptance would include W-AC1–W-AC3 (§5).

### 4. User flows and lifecycle

All Unix hosts, `sys-install`:
1. Preflight: detect the host.
2. Nix, base tools, validate flake.
3. **Selection** (the approved step): resolve flag > TTY prompt > local file > committed default.
4. Write the deltas, except in dry-run.
5. Preview.
6. chezmoi apply (`.chezmoiignore` reads the same TOML).
7. Switch with `"${SELECTION_ARGS[@]}"`.
8. mise.

sys-update, bootstrap, hm-switch, hms and the codebase-memory timer reuse the stored file silently.

**Windows 11 + WSL2 personal machine**
1. Windows PowerShell, by hand per apps.md (T-0041): check `winget --version`, then install only the wanted apps one at a time: Windows Terminal, font, browsers, native VS Code, optionally Telegram + Vesktop. Run without elevation for user-scope installers; expect UAC for machine-scope ones. No Windows changes are driven by the WSL script.
2. Separately enable/check WSL2, systemd and Ubuntu per `docs/platforms/wsl/setup.md` and the T-0034/T-0040 backup/real-host checks. Run `bash ops/detect-host.sh`, then `DRY_RUN=1 bash ops/install.sh`; on a TTY select `personal` and optional Linux CLI groups; install with `sys-install`. `selection.toml` stays under the WSL Linux home. Windows-host groups are stored in the same file, have no Nix effect, and produce only the pointer line (Q3).
3. Check `sys-readiness`, `code .`, `gh`, `ssh`, Node/PHP PATH, clipboard, `docker compose version` and the selected optional CLI tools. Do not start Windows GUI installers in WSL.

**Windows 11 + WSL2 work machine**: same installation targets; choose `work` separately on both. On Windows, the apps.md work rows offer Teams (+ optional Slack/Zoom, if IT allows), VS Code and browsers; omit Telegram and Vesktop by default. Store-only apps (new Outlook, some Teams builds) and employer-managed apps are documented but not listed. WSL gets selected dev tooling, not Teams or personal GUI apps. Managed machines stop at the docs if policies forbid installing.

**macOS / Linux**: `sys-install` selects a profile and supported optional groups; advanced selection displays actual app/tool choices available on that OS only. Mac uses the existing nix-darwin Homebrew bridge for approved casks; Linux desktop uses GUI Nix packages; Linux CLI and WSL omit GUI choices. A disabled Mac cask is **not removed** (`cleanup = "none"`), and the preview says so. Enabling a cask for an app already installed by hand (Teams today) may make brew refuse; that is unknown and checked in human AC14/AC24. Removing an HM package removes only its managed profile link on next activation, not user data.

**Subsequent `sys-update`:** read saved choices silently, with no new prompt and no implicit enabling of newly catalogued optional apps. On Unix only the existing owner updates its installed set; on Windows, updates stay manual (T-0041). `sys-install --reconfigure` remains the Unix way to edit choices. An opt-in from one OS does not automatically change the other OS.

### 5. Acceptance criteria and plan

**Do not begin these until approved T1 spike and baseline identity proof pass; preserve all current acceptance criteria.**

"Default output unchanged" in phases 4–7 (Q11) means: with no local file, each
activation drvPath and `darwinConfigurations.macos.system.drvPath` at the task
commit equal those at its parent commit, on the same flake.lock. The T1 baseline
applies only to phases 1–2, because T-0038 and sys-update lock bumps land before
P2 work resumes.

Phase 4, CLI groups and audit:
- [ ] **AC16:** `evidence/group-audit.md` covers every candidate in §2 (cliConvenience, nixTools, devExtras, containerTools, dbTools, aiExtras, cloud CLIs) and the desktop table groups (desktopUtilities, mobileDev).
  - It lists every reference in ops/, home/, nix/, mise.toml, .lefthook.yml, tests/, .vscode/mcp.json and ops/ci-packages.txt, with a verdict: core, keep as is, guard with `command -v`, or chezmoi-ignore.
  - It covers at least the hard references lnav (ci-packages.txt:26) and scc (doctor.sh:81).
  - It covers at least the soft references: `yy` → yazi (config.fish.tmpl:108, dot_zshrc.tmpl:99), `patw` → watchexec (conf.d/cli.fish:64), onefetch alias (dot_gitconfig.tmpl:247), glow fallback (projects/health/render.sh:59), statix/deadnix advisory (mise.toml:278-281), KeePassXC Alt+1 binding (gnome-keybindings.nix:99-104).
  - Each candidate maps to exactly one owner per supported host, or to unsupported / manual (Windows, T-0041). It flags colima on WSL (dev.nix:83) and duplicate runtimes, and names the separate ticket for colima.
  - Hard dependencies stay core.
- [ ] **AC17:** the default output is unchanged. The all-false fixture still provides every tool AC3 requires, plus the readiness sample (core list; GUI list on linux-desktop). With cliConvenience off, `.config/btop` is ignored. AC0–AC15 tests pass for both profiles.

Phase 4b, GUI groups (only those Q9 adopts):
- [ ] **AC18:** the default output is unchanged. On linux-desktop, a fixture with the adopted groups off lacks their packages (for example obsidian, keepassxc, qdirstat, doublecmd, localsend, czkawka, android-studio) and still has firefox, brave, ghostty, vscode, flameshot and bruno. linux-cli and wsl are unaffected.
- [ ] **AC19** (only if Q9 adds macOS casks): a macOS fixture removes the mapped casks from `homebrew.casks`, and the preview marks them "stays installed".

Phase 5, personal apps:
- [ ] **AC20:** the gui.nix personal gates become personalChat/personalSync, and openclaw.nix stays on `myConfig.profile`. The default output is unchanged for all 4 hosts and darwin. linux-desktop with `profile = "work"` lacks vesktop, telegram-desktop and the syncthing unit (today's work behaviour).
- [ ] **AC21:** a macOS fixture with personalChat on adds tokens verified with `brew info --cask` evidence; the default casks are unchanged.

Phase 6, work apps and the host-filtered prompt:
- [ ] **AC22:** workComms and the cloud CLIs are off in both profile files, and the default output is unchanged.
- [ ] **AC23:** enabling each in fixtures adds slack/zoom-us on linux-desktop (Teams per Q5, none by default), casks on macOS, and only the cloud CLIs on linux-cli and wsl.
- [ ] **AC24:** the prompt (bats, HOST_PROFILE fixtures) offers only groups whose `hosts` include the host, plus windowsHost groups on wsl marked "Windows, by hand". The preview distinguishes selected, disabled, N/A on this host, and stays installed. Always-on packages have no group key. Human check on macOS: enable Teams with Teams already installed and record brew's behaviour.
- [ ] **AC25** (only if Q2 = a): an `[apps]` key overrides its group only for allowlisted IDs. An unknown ID, or an explicit app unsupported on this host, fails evaluation with a message naming the key. Coupled config/services follow the app without deleting data. Profile defaults introduce no unapproved new application.

Phase 7, Windows tier (docs; after T-0041 lands apps.md):
- [ ] **AC26:** apps.md has a Group column, and every row maps to a group or "always". New rows are added only for apps that a group declares on macOS or Linux, unless Q8 amends T-0041; the new rejections are in "Discarded". Every winget id is either verified with saved `winget show --id <id> --exact --source winget` output or marked UNVERIFIED/MANUAL. Brave channels and Telegram variants are not silently substituted. UAC, Store-only and policy limits are documented.
- [ ] **AC27:** on wsl, install prints the pointer line naming the selected windowsHost groups; other hosts print nothing. With b1 only, the winget lines come from the registry.
- [ ] **AC28:** no task adds Windows-native Node, PHP, Composer, pnpm, Python, Go, Nix, gh, Docker CLI or SSH tools for WSL parity. Linux gets no Teams desktop package by default (Q5). WSL selection works with no Windows apps installed, and apps.md requires no WSL.

Negative:
- [ ] **AC-N3 (reworded):** personal-app gates, HOST_PROFILE detection and the existing .chezmoiignore os, gui and hostProfile rules behave the same under the default selection (no local file). With a selection, the gates follow the groups by design.
- [ ] **AC-N5:** a static grep test over ops/, home/ and nix/ finds no invocation of winget, powershell.exe, pwsh, cmd.exe or wsl.exe; allowlisted by path: nix/modules/home/scripts/ai-auth-status.sh and nix/modules/home/scripts/repo-audit.sh (existing toasts). No WSL-to-Windows writes. Printing the pointer line (or b1 command text) is not an invocation.
- [ ] **AC-N6:** no group or `[apps]` default is true for a package not installed today (checked in T10–T13). AC-N1 and the approved `--dry-run` rule extend to every new group and to `[apps]`.

Future installer only (not in this plan; applies only if §3 option d is separately approved):
- W-AC1: Windows `-Preview`/`-Check` are provably read-only (mock `winget`/filesystem), and `-Apply` is unreachable from WSL `sys-install`, `sys-update` and `home-manager switch`. Native Windows install requires explicit acceptance after the T-0041 policy update.
- W-AC2: Windows selection installs no personal chat from a default work preset and no Teams from a default personal preset; switching presets does not remove previously installed apps. Existing apps are skipped and install failures are individually reported.
- W-AC3: no `winget upgrade --all`, silent machine-wide install, package agreement auto-acceptance by default, automatic app uninstallation, credential sync, Windows registry/Defender/PowerShell policy modifications or Windows OS account creation.

Plan (T1 and T3–T8 as written; T2 revised only if Q1 is approved). These IDs
replace those in both earlier drafts.
- [ ] **T2 (revised, Q1):** also add the planned registry file nix/profiles/groups.toml (not yet created) and the registry/profile/option parity test. Files: groups.toml, profile.nix, tests/bash/selection.bats. ACs unchanged (AC1 partial, AC4, AC5). Risk low.
- [ ] **T9 — Inventory and dependency audit (evidence only).** Files: evidence/group-audit.md. Depends on T1. AC16. Risk low. **Review before T10 and T11.** Done when every candidate has a verdict and an owner per host.
- [ ] **T10 — Gate the CLI groups approved in Q7, plus the btop chezmoi rule.** Files: nix/modules/home/cli.nix, nix/modules/home/dev.nix, nix/profiles/*.toml, home/.chezmoiignore, tests/bash/selection.bats, tests/bash/chezmoiignore-selection.bats, fixtures. Depends on T3, T7, T9. AC17, AC-N6. Risk medium. Verify: parent vs task `nix eval --raw …drvPath` per host and darwin; the two bats files; `bash ops/validate-config.sh --eval`.
- [ ] **T11 — Gate the GUI groups Q9 adopts (macOS casks only if Q9 says so).** Files: nix/modules/home/gui.nix (group lines), homebrew.nix (only if Q9), profiles, fixtures. Depends on T9, T10. AC18, AC19, AC-N6. Risk medium.
- [ ] **T12 — Migrate the gui.nix personal gates to personalChat/personalSync; macOS personal casks.** Files: gui.nix (gates at 349, 363, 476), homebrew.nix (personal casks), profiles, fixtures. Depends on T7 and T11 (if Q9 adopts any group; otherwise T10). AC20, AC21, AC-N3, AC-N6. Risk medium.
- [ ] **T13 — workComms and cloud CLIs, the host-filtered prompt and preview (and `[apps]` if Q2 = a).** Files: dev.nix (cloud lines), gui.nix (slack/zoom lines), homebrew.nix (work casks), ops/lib/selection.sh, profiles, groups.toml, tests/bash/install-selection.bats. Depends on T5, T12. AC22–AC25, AC-N6. Risk medium.
- [ ] **T14 — WSL pointer line (b1 only if approved).** Files: ops/install.sh, tests/bash/install-selection.bats, a static-grep bats test. Depends on T8, T13 and T-0041 landing. AC27, AC-N5. Risk low.
- [ ] **T15 — Docs and real-host evidence.** Files: docs/reference/app-options.yaml (`windows:` key), docs/reference/profiles.md, docs/reference/app-catalog.md, docs/architecture/tool-ownership.md, repo-docs/migration-package-ownership.md, docs/getting-started/install.md. apps.md rows, the Group column and the rejections go through T-0041 (coordinate, don't edit in parallel). Evidence: Linux, macOS and WSL personal/work runs (`sys-readiness`, `brew info --cask`), and Windows `winget show`/`winget list` per id, by hand; redact usernames, private paths and tokens. Depends on T13 and T-0041 landing. AC26, AC28. Risk low.

Open item: the "command failures" test case from the pushed T13 matrix is not covered by any AC yet; decide whether to add an AC or drop the case.

T14 and T15 can run in parallel; their files do not overlap. Everything else runs
in order, because the tasks share profile TOMLs, gui.nix, dev.nix and selection.sh.
dev.nix overlaps T-0038 (land T-0038 first); of the approved tasks only T8 edits docs/platforms/wsl/setup.md.

### 6. Research and implementation references (reviewed 2026-11-14)

Tags: [doc] = vendor documentation; [search] = found by web search, not checked
against a primary source; [memory/unverified] = recalled, not checked.

- WinGet install, exact IDs and installer options; unattended form `winget install --id X -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity`; `--scope user|machine` only applies if the manifest offers it, and accepting agreements does not cover bundled offers. [doc] https://learn.microsoft.com/en-us/windows/package-manager/winget/install (2026-07)
- WinGet capabilities and first-login App Installer registration. [doc] https://learn.microsoft.com/en-us/windows/package-manager/winget/
- WinGet installer scope/UAC caveats. [doc] https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting
- `winget import -i file.json`: Packages[].PackageIdentifier, `--ignore-unavailable`, installs serially, no per-package scope. [doc] https://learn.microsoft.com/en-us/windows/package-manager/winget/import
- `winget configure -f x.dsc.yaml` needs Windows 10 1809+ and winget 1.6.2631+, pulls DSC modules from the PowerShell Gallery, some need admin. [doc + memory] https://learn.microsoft.com/en-us/windows/package-manager/winget/configure
- Not unattended: UAC for machine-scope installers; Store-only apps; enabling the WSL feature plus a reboot; Docker Desktop (admin, reboot, licence); corporate policy blocking winget, the Store or interop. Spotify's winget installer refuses an elevated shell. [memory/unverified]
- Scoop is per user with no admin but weak on proprietary apps; Chocolatey needs admin and offers little over winget. [memory/unverified]
- WSL interop: Windows executables run from WSL as the Windows user, non-elevated. [doc] https://learn.microsoft.com/en-us/windows/wsl/filesystems and https://learn.microsoft.com/en-us/windows/wsl/interop
- winget.exe as an App Execution Alias is flaky from WSL, interop can be disabled in wsl.conf, and the output is CRLF/UTF-16. [memory/unverified]
- WSLg is fine for light GUI apps and poor for calls, screen sharing, tray and HiDPI, so chat, calls, browsers and the password manager go on Windows. [memory/unverified]
- wsl.conf `[boot] systemd=true`, `[interop] appendWindowsPath`; .wslconfig memory, `networkingMode=mirrored` (Windows 11 22H2+). [memory/unverified]
- Official Microsoft Teams clients; no official native Linux client (web/PWA). [doc] https://learn.microsoft.com/en-us/microsoftteams/teams-client-desktop-admin and https://learn.microsoft.com/en-us/microsoftteams/teams-client-system-requirements . teams-for-linux is an unofficial Electron wrapper. [search] https://github.com/IsmaelMartinez/teams-for-linux
- Nix attrs on the pinned nixpkgs, 2026-11-14 [verified by the architect with `nix eval`; not re-run in this merge]: telegram-desktop, vesktop, slack, zoom-us, teams-for-linux (2.29.0), discord, azure-cli, awscli2, google-cloud-sdk, syncthingtray, bitwarden-desktop, _1password-gui, podman-desktop, signal-desktop. wslu was removed from nixpkgs.
- macOS cask pages exist for vesktop, telegram-desktop and microsoft-teams; tokens stay UNVERIFIED until `brew info --cask` on the Mac. [doc] https://formulae.brew.sh/cask/vesktop , https://formulae.brew.sh/cask/telegram-desktop , https://formulae.brew.sh/cask/microsoft-teams
- chezmoi `promptMultichoice`/`promptMultichoiceOnce` exist since v2.60.0 [search] https://www.chezmoi.io/reference/templates/init-functions/promptMultichoiceOnce/ ; `chezmoi init --promptDefaults` supports CI [doc] https://www.chezmoi.io/reference/commands/init/ . Alternatives to the approved flake-input mechanism; not adopted.
- Home Manager specialisations suit a few discrete variants, not combinatorial group subsets. [memory/unverified]
- Windows 10 reached end of support in October 2025; target Windows 11. [memory/unverified]
- Existing repo tickets: T-0041 (Windows manual copy-only list), T-0034–T-0040 (WSL safety / actual host verification), T-0009 (install preflight), T-0010 (update/rollback baseline). Any conflict is resolved via separately reviewed policy/doc amendments, not by an installer side effect.

### 7. Open questions (user decisions)

1. **Registry:** add the planned registry file nix/profiles/groups.toml (not yet created; revises T2), or keep metadata in profile.nix descriptions with host filters hard-coded in bash? Recommend: the registry.
2. **Individual choices:** (a) allowlisted `[apps]` overrides on top of groups (pushed extension; workComms = Teams/Slack/Zoom, one cloud group = aws/azure/gcp), or (b) single-app groups (teams, slack, zoom, aws, azure, gcp) and no `[apps]` table (reviewed draft)? Both soften "Per-package toggles: groups are enough". (b) has no precedence rule or second key space; (a) scales to individual CLI tools. Architect lean: (b) for the first slice, since every planned AC except AC25 works without `[apps]`, and `[apps]` can be added later.
3. **Windows mechanism:** (a) docs + Group column + WSL pointer, (b1) print the commands, (b2) import/configure file (rejected), (c) interop helper (rejected), or (d) the native WinGet installer (separate approval)? Recommend: (a) now; revisit (b1) after the T-0040 real-host pass; (d) only as a separate ticket after T-0041 is reconciled.
4. **Teams in work by default?** It would change the default macOS drvPath and may collide with the hand-installed Teams. Recommend: off; pick it in the prompt.
5. **Teams on Linux:** web/PWA (no package), or teams-for-linux (unofficial)? Recommend: PWA.
6. **Persisting linux-cli vs linux-desktop:** keep the env var, do it in T-0042, or open a new ticket (detect-host reads `~/.config/app-configs/host` for the Linux fallback; install asks once on a TTY with a graphical-session heuristic as the default)? Recommend: a new ticket.
7. **CLI groups:** approve cliConvenience and devExtras (lists final after T9)? Approve nixTools (reopens the nix-maintenance deferral)? Keep aiExtras/aiContext and langExtras deferred? Keep containerTools and dbTools as candidates until T9 shows no readiness or PHP dependency? Recommend: yes to all.
8. **Windows list (via T-0041):** add Teams, Slack, Zoom and Vesktop? Add the five rejections (Discord, Everything, 7-Zip, Git for Windows, Chocolatey/Scoop)? Keep the deferred items in T-0041's wording? Or amend T-0041's parity rule to allow `windowsUtilities` (PowerToys, PowerShell 7, 7-Zip, Git for Windows) as the pushed extension proposes? Recommend: the first three; keep the parity rule.
9. **GUI groups:** adopt desktopUtilities and mobileDev, in Phase 4b on linux-desktop only? One `desktopUtilities` group (pushed) or notes/passwords/fileTools (draft)? Do macOS casks (obsidian, localsend, grandperspective, nimble-commander) join? That goes beyond the earlier answer limiting macOS cask groups to macInput. The core GUI set is never grouped. Recommend: Phase 4b, linux-desktop only; one group if Q2 = a, the split if Q2 = b; macOS casks stay ungrouped.
10. **Defaults:** (A) every group defaults to today's effective state (existing packages on in both profiles, personal apps personal-only, new apps off), or (B) a literal all-on for both profiles (work hosts would get Telegram, Vesktop and Syncthing, and new apps would change the default drvPaths)? (B) contradicts profile.nix ("work ships nothing personal") and the drvPath rule. Recommend: (A), as a refinement of "both profiles start all-on, preserving the current effective configs".
11. **"Default output unchanged" for phases 4–7:** parent-commit comparison on the same lock (draft), or the T1 baseline (pushed)? Recommend: parent-commit, because lock bumps after T1 make the T1 baseline stale.

### 8. Risks and rollback

- Cask tokens and winget ids are unverified; a wrong cask token fails darwin-rebuild. Verify in T11–T13 (`brew info --cask`) and T15 (`winget show`).
- The unofficial clients (Vesktop, teams-for-linux) carry ToS and employer-policy risk.
- Turning off `go` breaks the ya-under-control hooks on that host; turning off KeePassXC leaves a dead Alt+1 binding (outside this ticket).
- The chezmoi resolution duplicates the Nix resolution; the parity test guards it.
- Scheduling: dev.nix overlaps T-0038 (land it first); T14/T15 wait for T-0041. The future installer conflicts with T-0041's discard of a `windows/` layer, so it stays outside this plan.
- Rollback: delete the selection dir, revert the commits, and use HM generations. Casks stay installed by design.

## Progress
- 2026-11-21 audit, APP-01: docs/reference/app-options.yaml:14 defines `installed` as declared in the repo, not observed on a host; consider separate declared / installed_observed / verified_at fields.
