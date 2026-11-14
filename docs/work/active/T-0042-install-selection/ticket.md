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
  - Native Windows automated application management: not in original T1–T8; see separately gated T11–T12 extension.
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

---

## Extension (2026-11-14): cross-platform selectable CLI, GUI and Windows/WSL2

**Request:** extend the install-selection plan beyond the initial `media`, `security`, `go` and `macInput` groups. Let users choose additional CLI tools, GUI apps and manageable supporting components on Linux, macOS and Windows 11 + WSL2, using the appropriate installer for the detected platform. Support the `personal` and `work` selection profiles: e.g. Telegram/Vesktop for personal, Teams for work. This is a **ticket/design amendment only**, not authorisation to install software or change the currently deployed system.

**Authority / compatibility:** preserve the approved T1–T8 gates and all no-selection baseline invariants above. This extension supersedes the earlier **design-scope** statements "Native Windows: out" and "Per-package toggles: groups are enough" **for subsequent planning only**. It does **not** silently repeal T-0041's explicit *docs-only / no automated winget* implementation decision, or `docs/plans/migration/implementation.md` Appendix A: reconcile that policy explicitly before implementing a Windows writer. Until then Windows is **preview / documented commands only**. Do not blend native Windows work into the already approved Nix T1–T8 patch set.

### 1. Installation boundaries and automatic target detection

| Detected target | Installation owner | What is selectable | What must not happen |
| --- | --- | --- | --- |
| NixOS / Linux desktop | Nix/Home Manager, existing system owner; chezmoi for user configs | Existing and newly audited optional CLI groups, Linux GUI apps, opt-in HM services with their app | No separate apt/Flatpak ownership of a Nix-owned package, no removal of user data |
| Other Linux CLI/headless | Nix/Home Manager | CLI/dev groups only; no desktop-specific app or system setting | Never offer unsupported GUI choices |
| macOS | Home Manager for cross-platform CLI, nix-darwin/Homebrew for casks, chezmoi for configs | CLI groups and audited GUI casks (including optional personal/work apps) | No parallel `brew install` outside the existing nix-darwin owner; `cleanup = "none"` stays |
| WSL2 Ubuntu | Linux Home Manager, `nix/hosts/wsl/home.nix` | Same Linux CLI/dev options; WSL-only integration and daemon/client choices when verified | Do **not** install Windows desktop apps inside WSL; do not run macOS apps, Linux desktop apps or Colima VM in WSL |
| Windows 11 host | Windows PowerShell + **WinGet** as proposed native package owner | Native terminal/editor, fonts, desktop apps, Windows-only utilities, selected work/personal apps | Do not let WSL `sys-install` or `sys-update` silently invoke `winget.exe`, mutate Windows, change UAC/registry/Defender, or remove native apps |

- Detect OS/host once, using existing `ops/detect-host.sh` (macos, linux-desktop, linux-cli, wsl); Windows entry point uses PowerShell `$IsWindows` when available or a safe Windows-version probe. Profile (`work|personal`) is a **user choice**, not an OS detector; `HOST_PROFILE` is still an OS/host override and must not be conflated with `--profile`.
- A single physical Windows PC has **two independent installation targets**: the Windows host for GUI software and the WSL Linux distribution for dev CLI. A Windows-side bootstrap may offer the **documented** `wsl --install` / Ubuntu step, but WSL provisioning, export backups, `/etc/wsl.conf`, kernel update, admin prompts and distro migration stay separate from app selection and retain T-0034–T-0040 safety checks.
- WSL must work even if native Windows selections were never applied. Conversely, the Windows app selector must work with no WSL distribution present. No automatic traversal into the other OS and no assumption that `winget.exe` works from WSL.
- Prefer one installer per app **per target**. Having a Linux `git` in WSL and Windows `Git.Git` for explicitly Windows-native tooling is legitimate; installing Windows Node/PHP/Composer/pnpm/gh merely to mirror the WSL CLI is not. Record explicit exceptions and test PATH precedence (`command -v node npm npx pnpm php composer git code` in WSL).
- Current repo finding: `dev.nix` includes `colima` in the shared package list although `docs/platforms/wsl/setup.md` says not to run it inside WSL. Audit and plan a platform gate separately; do **not** mix that baseline-changing cleanup into T1's identity test.

### 2. Selectable groups, packages, services and configuration

**Keep the simple, approved prompt and TOML mechanism.** Core/bootstrap dependencies are always-on: packages used by `ops/install.sh`, `ops/update-all.sh`, `ops/doctor.sh`, `ops/validate-config.sh`, selection/preview/rollback, shell boot and credentials. Build a machine-checked dependency graph from actual call sites before promoting any additional package to optional.

Suggested logical groups (exact contents to be inventoried in T9; do not gate unexamined packages):

| Group | Cross-platform / ownership | Initial scope / dependency rule | Default / baseline |
| --- | --- | --- | --- |
| `media`, `security`, `go`, `macInput` | Existing approved T-0042 groups | Preserve precise T1–T8 package membership and macOS config gating | Unchanged from approved design |
| `cliConvenience` | Nix all Unix targets | Optional-only tools after auditing `navi`, `glow`, `dust`, `sd`, `parallel`, `viu`, etc.; reject if shell scripts/config need one | **Off unless chosen** for newly gated entries; no change to no-file baseline |
| `aiExtras` | Nix all Unix targets, optional native Windows candidates | Separate AI context/evaluation/agent tools from core; inspect `repomix`, `code2prompt`, `files-to-prompt`, `promptfoo`, `opencode`, codebase-memory-MCP and their timers/callers. Do not gate `aiContext` until the old deferral's regression audit passes | Off-by-default *new* candidates; preserve existing packages without a local selection |
| `containerTools` | Nix CLI; native Docker daemon selected separately | Docker CLI/buildx/compose choices must match daemon (macOS Colima vs Desktop; Linux Engine; Windows Docker Desktop integration vs WSL Engine). No two active daemon owners; warn about licence and admin requirements | No change without explicit selection |
| `dbTools` | Nix CLI; future native tools only if needed | MySQL/MariaDB client and future Redis/DB clients, with macOS Homebrew `mysql-client` exception; check PHP dev dependencies before making optional | Preserve installed baseline |
| `mobileDev` | Linux desktop GUI, macOS cask, Windows WinGet | Android Studio/SDK/ADB/emulator if selected; platform-specific emulator acceleration, SDK licences and large downloads are post-install checks; WSL gets CLI-only if specifically supported | Opt-in; preserve Linux's currently installed Android Studio by default |
| `personalChat` | Linux GUI Nix, macOS casks, Windows WinGet | Telegram + Vesktop (separately selectable); never install GUI apps in WSL. Linux already gates them on `myConfig.profile == "personal"` | Preserve that Linux personal gate; no new macOS/Windows install without explicit apply |
| `workComms` | Windows WinGet, macOS casks; Linux browser/PWA | Teams; optional Zoom/Slack if selected. Official Teams desktop is **not supported on Linux**; use Teams Web/PWA, never an unofficial Linux wrapper by default | Not currently installed by repo; opt-in |
| `desktopUtilities` | Platform-appropriate Linux GUI, macOS cask, Windows WinGet | Bruno, Obsidian, LocalSend, KeePassXC, Flameshot, file/disk tools, etc.; preserve platform differences (QDirStat vs GrandPerspective, etc.) | Preserve current package/app baseline |
| `windowsUtilities` | Native Windows only, WinGet | Optional PowerToys / PowerShell 7 / 7-Zip; avoid redundant launchers or duplicate Git/Node stacks | Opt-in; not a WSL group |

- A logical app ID maps to 0 or 1 **installer owner per host** (e.g. `telegram`: Nix `telegram-desktop` on Linux desktop, Homebrew `telegram-desktop` on macOS, WinGet `Telegram.TelegramDesktop` on Windows; unsupported in WSL). Availability is the intersection of catalog support, actual host architecture, installer capability and policy, not simply a checkbox.
- Support an **advanced, allowlisted app/tool override** alongside group switches, to satisfy individual CLI choices without a generic dependency/package-manager DSL. A group is a convenient bulk default; an explicit per-app override wins. Candidate TOML extension (introduced only after T1–T8 and migration tests): `[apps] telegram = true; vesktop = true; "yt-dlp" = false` on separate TOML lines. Keys are stable logical IDs, not executable commands, Nix attributes or arbitrary WinGet package IDs. Unknown IDs and unsupported **explicit** targets fail early with a useful reason; unavailable defaults are shown as N/A and excluded. A selected package that a required script depends on cannot be disabled.
- Any optional daemon, systemd unit/timer, `xdg.configFile`, chezmoi target, GNOME hook, macOS service or login item is selectable **only as a dependency of the owning app/group**. Disabling it must disable its managed integration without deleting files, app data, credentials or user-defined service state. Never expose raw system/registry/security settings as arbitrary toggles.
- Keep existing profiles `work` and `personal`. Recommended UX: first choose profile, then show groups with current defaults, then `Customize individual apps and optional CLI tools?` (default No), then platform-specific preview and confirmation. Work preset: no personal chat by default; Teams is offered **opt-in** (never installed without an explicit choice). Personal preset: Telegram/Vesktop options; no Teams by default. An explicit override can cross presets after the preview makes the exception visible.
- The *existing Linux personal* Telegram/Vesktop/Syncthing configuration and existing all-on Nix groups must remain unchanged with **no local selection**. Never change `myConfig.profile` or make work/personal toggles implicitly enable new Mac/Windows installs on `sys-update`. Baselines protect existing hosts; new optional apps require deliberate selection and explicit apply.

### 3. Windows-specific implementation proposal (separate, gated phase)

**Why WinGet:** Windows 11 provides a capable command-line package manager through App Installer. It can `search`, `show`, `list`, `install`, `upgrade`, `export/import` and `configure`; it supports installation by exact ID and source. The limiting cases are missing/unverified manifests, UAC, machine-vs-user scope, package-specific installers and managed-device policy, **not** a general inability to install apps from a terminal. Do not introduce Scoop/Chocolatey or `winget configure`/DSC merely for this use case.

**Proposed files (future write boundary; not added by this ticket update):** `windows/catalog.json` with canonical logical IDs, verified WinGet IDs/source, platform/scope, profile/group defaults, install owner and notes; `ops/windows/install-apps.ps1` as a **separate** Windows-native preview/apply entry point; targeted Pester/mock tests (or a hermetic PowerShell smoke suite), `docs/platforms/windows/apps.md` and a one-sentence update to the ownership/Appendix A policy after reconciliation with T-0041. Use JSON for the native Windows catalog and the **local** native Windows selection because Windows PowerShell can read it without a TOML parser/dependency; Linux/macOS/WSL continue using approved `selection.toml`. The two host-specific selections share logical profile/group/app IDs but are **not silently synchronised** across the Windows/WSL boundary; a parity test checks shared logical IDs. Avoid requiring PowerShell 7 before the bootstrap, or generating and executing arbitrary PowerShell from WSL.

**CLI contract (names illustrative until the implementation review):**
```powershell
# Run in Windows PowerShell, not WSL. These are proposed future commands.
.\ops\windows\install-apps.ps1 -Profile personal -Preview
.\ops\windows\install-apps.ps1 -Profile personal -Reconfigure
.\ops\windows\install-apps.ps1 -Apply          # explicit Windows mutation
.\ops\windows\install-apps.ps1 -Check          # installed/selected/missing summary
```
- Discovery/preview is read-only. `-Apply` requires an explicit user action (and confirmation if interactive); no surprise admin elevation, reboot, pre-accepted licence, default-app reassignment or automatic user/machine scope switch. In noninteractive use require an additional explicit opt-in flag for any previously approved agreements; otherwise stop with manual steps. Refuse policies that block an install; do not bypass them.
- Verify package ID and architecture with `winget show --id <ID> --exact --source winget`; inspect installed state with `winget list --id <ID> --exact` and distinguish not-installed from query/source/exit failures. Use `winget install --id <ID> --exact --source winget` for a confirmed manifest; avoid fuzzy searches, unverified IDs, `--force`, `--ignore-security-hash`, blanket `--silent`, `--scope machine` or blindly accepting every agreement. Source agreements and package agreements are distinct; log both.
- Output an ordered, per-app plan: detected/unsupported/selected/already installed/install required/manual/UAC needed/failed/restart needed; include package ID, owner, version when reliable, action and exit code. A retry is idempotent and resumes failed items; an unlisted existing app is **never uninstalled**. `-Check` and preview must not access secrets. `-Upgrade` (if added later) updates only opted-in WinGet-owned IDs with a preview, never `winget upgrade --all`.
- Distinguish **application install** from **Windows account/work isolation**: `work` and `personal` presets choose apps but do **not** create separate Windows users, separate Teams data, separate browser profiles, or enforce security boundaries. On a shared Windows account, switching profiles does not remove earlier apps. Enterprise-managed device policy, licence, login, MFA and tenant restrictions remain operator/IT-owned; no secrets or account IDs in a committed or local selection.
- If a WinGet manifest is absent or unreliable, mark `manual` with official installer URL; never fetch-and-execute an arbitrary PowerShell script. If WinGet is unavailable at first login, report App Installer registration/repair guidance (it becomes available after first user login); do not silently install another package manager. Windows Terminal can already be present.
- Do not auto-install Windows-native Node, PHP, Composer, pnpm, Python, Go, Nix, `gh`, Docker CLI or SSH tools solely for parity with WSL. Optional native Git/PowerShell 7/Android Studio have valid Windows-specific reasons; only install when selected. VS Code Windows + Remote WSL is the GUI/editor owner; the WSL `code .` shim is integration, not a second Linux VS Code GUI install.

**Candidate Windows/macOS app matrix (WinGet IDs are research candidates, not locally confirmed on the user's Windows installation):**

| Logical option | Windows proposed WinGet ID | macOS proposed Homebrew cask | Linux desktop / WSL |
| --- | --- | --- | --- |
| VS Code | `Microsoft.VisualStudioCode` | `visual-studio-code` (existing) | Linux `vscode`; WSL uses Windows VS Code + Remote WSL |
| Windows Terminal, Nerd Font | `Microsoft.WindowsTerminal`, `DEVCOM.JetBrainsMonoNerdFont` (verify font ID) | `font-jetbrains-mono-nerd-font` (existing) | Linux terminal/font as already declared; WSL Windows-side |
| Firefox / Brave | `Mozilla.Firefox`, `Brave.Brave` or `Brave.Brave.Beta` (choose channel explicitly) | `firefox`, `brave-browser@beta` (existing) | Linux Firefox/Brave; do not install WSL browsers |
| Telegram | `Telegram.TelegramDesktop` | `telegram-desktop` (new optional cask) | Linux `telegram-desktop` for personal; WSL N/A |
| Vesktop | `Vencord.Vesktop` (verify) | `vesktop` (new optional cask) | Linux `vesktop` for personal; WSL N/A |
| Microsoft Teams (work) | `Microsoft.Teams` (verify; may be provisioned by IT) | `microsoft-teams` (new optional cask) | Official Linux desktop unsupported: web/PWA only; WSL N/A |
| Slack / Zoom (work optional) | `SlackTechnologies.Slack`, `Zoom.Zoom` (verify) | verify `slack`, `zoom` casks if needed | browser/PWA or supported native Linux build; not automatic |
| Obsidian / Bruno / LocalSend | `Obsidian.Obsidian`, `Bruno.Bruno`, `LocalSend.LocalSend` | existing casks (audit) | existing Linux GUI apps or review each omission |
| KeePassXC / Double Commander / Flameshot | `KeePassXCTeam.KeePassXC`, `alexx2000.DoubleCommander`, `Flameshot.Flameshot` | audit availability/functional alternatives | existing Linux apps; Windows hotkeys not Linux GNOME equivalents |
| PowerToys (Windows-only optional) | `Microsoft.PowerToys` | N/A | N/A |
| Git for Windows / PowerShell 7 | `Git.Git`, `Microsoft.PowerShell` | N/A (Nix Git / OS shell) | WSL Git/shell from Nix; native options only if a Windows-specific task needs them |
| Android Studio / Docker Desktop | verify exact native WinGet IDs and installer conditions | existing/applicable casks after audit | Linux Android Studio already declared; WSL Docker Engine **or** Docker Desktop integration, never both as daemon |

- The list in T-0041 remains the reference for previously reviewed **Windows parity candidates**, but this extension additionally permits Windows-only apps when a concrete Windows need exists (e.g. PowerToys) and work-only apps (Teams). Do not silently install anything from the matrix. For Windows verification, capture `winget --version`, `winget source list`, `winget show` / `winget list` output and a post-apply inventory on the real host; do not mark candidate IDs verified until tested.
- Native Windows Teams is the default choice for Windows work communications; Mac can use the cask; Linux work uses the official browser/PWA route. The Windows work set may be empty on a personal PC until explicitly chosen. Do not conflate Teams app installation with subscription entitlement.

### 4. User flows and lifecycle

**Windows 11 + WSL2 personal machine**
1. Windows PowerShell: inspect WinGet and existing Windows apps; preview personal Windows selections (Windows Terminal, font, browsers, native VS Code, optionally Telegram + Vesktop), and explicitly apply only wanted Windows apps under the *future* Windows phase. No Windows changes are driven by the WSL script.
2. Separately enable/check WSL2, systemd and Ubuntu per `docs/platforms/wsl/setup.md` and the T-0034/T-0040 backup/real-host checks. Run `bash ops/detect-host.sh`, then `DRY_RUN=1 bash ops/install.sh`; on a TTY select `personal` and optional Linux CLI groups; install with `sys-install`. `selection.toml` stays under the WSL Linux home.
3. Check `sys-readiness`, `code .`, `gh`, `ssh`, Node/PHP PATH, clipboard, `docker compose version` and the selected optional CLI tools. Do not start Windows GUI installers in WSL.

**Windows 11 + WSL2 work machine**: same installation targets; choose `work` separately on both. Native Windows offers Teams (+ optional Slack/Zoom, if IT allows), VS Code and browsers; it omits Telegram and Vesktop by default. WSL gets selected dev tooling, not Teams or personal GUI apps. Managed machines must stop at preview if policies forbid installing.

**macOS / Linux**: `sys-install` selects a profile and supported optional groups; advanced selection displays actual app/tool choices available on that OS only. Mac uses the existing nix-darwin Homebrew bridge for approved casks; Linux desktop uses GUI Nix packages; Linux CLI and WSL omit GUI choices. A disabled Mac cask is **not removed** (`cleanup = "none"`); removing an HM package removes only its managed profile link on next activation, not user data.

**Subsequent `sys-update`:** read saved choices silently, with no new prompt and no implicit enabling of newly catalogued optional apps. On Unix only the existing owner updates its installed set; on Windows app upgrades are a separately invoked native action. `sys-install --reconfigure` remains the Unix way to edit choices; native Windows uses `-Reconfigure`. An opt-in from one OS does not automatically change the other OS.

### 5. Phase additions and implementation gates

**Do not begin these until approved T1 spike and baseline identity proof pass; preserve all current acceptance criteria.**

- [ ] **T9 — Inventory / package support and dependency audit (design gate).** Generate a matrix from current `cli.nix`, `dev.nix`, `gui.nix`, Homebrew, chezmoi ignore, mise optional tasks, actual `ops/` call sites, Linux systemd services and docs. Classify every candidate as required, optional-safe, coupled-service, unsupported or manual; flag WSL Colima, duplicate runtimes and macOS Linux-only support. Confirm default config equality and decide whether new groups/advanced app toggles can be introduced without destabilising the original T1–T8. Review before any code.
- [ ] **T10 — Unix advanced selection (after original phases).** Extend catalog and allowlisted `[apps]` overrides; preserve no-file drvPaths; gate app-specific HM packages/services/configs and audited macOS casks; test Linux GUI, macOS, linux-cli, WSL + both profiles. Explicitly show disabled vs unsupported vs never-installed; never auto-uninstall.
- [ ] **T11 — Windows policy reconciliation + read-only prototype.** Resolve T-0041's earlier docs-only decision and Appendix A in a separately reviewed documentation step. Prototype native PowerShell WinGet discovery/preview/selection parsing in isolation, without `-Apply`, registry/DSC changes or WSL calls; require manifest ID verification and mocked tests.
- [ ] **T12 — Optional Windows apply (requires T11 approval and a real Windows test host).** Only after explicit policy approval, add guarded `-Apply` for selected IDs. Verify idempotence, per-user vs machine installers, UAC/agreements, failed downloads, installed-app detection, no auto-uninstall, no auto-restart, and no work-policy bypass. Keep Windows-side installer independent of `sys-update` and WSL.
- [ ] **T13 — Documentation and real-host tests.** Update catalog, app docs, ownership, profile examples, README/install entry points and tests. Test: Linux personal/work, macOS personal/work, WSL personal/work, Windows personal/work, non-TTY/default/invalid/unsupported/opt-out cases, switch of profile after prior install, and command failures. Include Windows-side `winget list` before/after and WSL `sys-readiness` evidence; redact usernames/private paths/tokens.
- [ ] **AC16:** every optional candidate is explicitly mapped to exactly one owner per supported host; selection offers only supported packages; unsupported explicit items fail early with a reason; always-on dependencies cannot be disabled.
- [ ] **AC17:** per-app override takes precedence over its group only for allowlisted IDs; coupled config/services follow the app without deleting data; profile defaults preserve existing installs and introduce no unapproved new application.
- [ ] **AC18:** Linux/WSL no-file activation drvPaths and macOS system drvPath still match T1 baseline until an independently approved intentional migration; both profile types and all original tests pass.
- [ ] **AC19:** Windows `-Preview`/`-Check` are provably read-only (mock `winget`/filesystem), and `-Apply` is unreachable from WSL `sys-install`, `sys-update` and `home-manager switch`. Native Windows install requires explicit acceptance after the T-0041 policy update.
- [ ] **AC20:** Windows selection installs no personal chat from a default work preset, no Teams from a default personal preset; switching presets does not remove previously installed apps. Existing apps are skipped and install failures are individually reported.
- [ ] **AC21:** Windows/WSL never duplicate Windows developer runtimes by default, never run Colima in WSL, and never deploy unsupported Linux Teams desktop; Windows GUI apps and WSL CLI can be installed independently.
- [ ] **AC22:** every proposed WinGet ID is either verified against the real Windows host with evidence or marked UNVERIFIED/MANUAL; different Brave channels and Telegram variants are not silently substituted; Windows Installer/UAC/policy limitations are documented.
- [ ] **AC-N5:** no `winget upgrade --all`, silent machine-wide install, package agreement auto-acceptance by default, automatic app uninstallation, credential sync, Windows registry/Defender/PowerShell policy modifications, Windows OS account creation or WSL-to-Windows implicit writes.
- [ ] **AC-N6:** no newly introduced profile prompt in scheduled updates, bootstrap, HM switch or CI; preview/dry-run never persists choices; target detection, lock purity and all original safety guarantees remain intact.

### 6. Research and implementation references (reviewed 2026-11-14)

- Microsoft WinGet installation, exact IDs and installer options: https://learn.microsoft.com/en-us/windows/package-manager/winget/install
- WinGet capabilities and first-login App Installer registration: https://learn.microsoft.com/en-us/windows/package-manager/winget/
- WinGet installer scope/UAC caveats: https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting
- WinGet import/export and configuration: https://learn.microsoft.com/en-us/windows/package-manager/winget/import and https://learn.microsoft.com/en-us/windows/package-manager/winget/configure
- Windows/WSL executable interop and boundary: https://learn.microsoft.com/en-us/windows/wsl/interop
- Official Microsoft Teams clients: https://learn.microsoft.com/en-us/microsoftteams/teams-client-desktop-admin and https://learn.microsoft.com/en-us/microsoftteams/teams-client-system-requirements
- Verified *macOS cask existence* for proposed personal/work apps (not yet verified with local `brew info`): https://formulae.brew.sh/cask/vesktop , https://formulae.brew.sh/cask/telegram-desktop , https://formulae.brew.sh/cask/microsoft-teams
- Existing repo tickets: T-0041 (Windows manual copy-only list), T-0034–T-0040 (WSL safety / actual host verification), T-0009 (install preflight), T-0010 (update/rollback baseline). Any conflict is resolved via separately reviewed policy/doc amendments, not by an installer side effect.

