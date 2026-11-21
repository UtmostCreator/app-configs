Source: local

# T-0046: macOS first-run readiness: blockers, fixes and a real-Mac verification order (bug)

Status: in progress (fix 3 aerospace tap e9bc4fd landed; fixes 1, 2, 4, 5, 6 and AC-B/C open; no real-Mac run yet)
Wave: unassigned
Depends on: none
Related: T-0042 (on main; this ticket closes its human checks AC14, bash 3.2
and brew preview), T-0038 (Colima darwin-only; can wait until after a first
successful run)

## Summary
Nobody has activated this repo on a Mac (a read-only settings inventory was captured on 2026-11-20, see T-0048 macos.yaml; activation is still unverified). A static review at main ed39171 (nothing was
run on a Mac) found two certain blockers and one inferred blocker on the way
to a first install, plus smaller gaps. This ticket orders the fixes, with
acceptance criteria, and holds the step-by-step real-Mac verification order.
The user-facing procedure is the macOS setup doc, docs/platforms/macos/setup.md.
This ticket changes no code; the fixes below are separate work.

## Findings
Verified by reading the files unless marked.
- BLOCKER: newer nix-darwin refuses `darwin-rebuild switch|check` unless run as
  root ("system activation must now be run as root"; locked nix-darwin source,
  pkgs/nix-tools/darwin-rebuild.sh around lines 149-152; read by the
  researcher and re-read by the round-1 review). `ops/update-all.sh:1218` and `mise.toml:115`
  (check) and `mise.toml:186` (switch) run it without sudo. `ops/install.sh:424,426`
  and `ops/bootstrap.sh:248,250` use sudo, and bats pins that (`mise.toml:115`
  is the `sync:dry-run` preview, so adding sudo there makes a preview need
  root). So
  `sys-update --apply` on a Mac would fail at the switch after chezmoi apply
  has run, and there is no automatic darwin rollback (`ops/update-all.sh:539-545`).
- BLOCKER: nix-darwin's homebrew module does not install Homebrew. With brew
  absent it prints "Homebrew is not installed, skipping..." and continues, so no
  cask is installed. Then `nix/modules/home/default-browser-macos.nix` runs
  `nix/modules/home/scripts/set-default-browser-macos.sh`, which exits 1
  ("Brave Beta is missing", line 7). Nothing in `ops/install.sh` or
  `ops/bootstrap.sh` checks for brew (`ops/install.sh:201-207` checks sudo only).
  (Behaviour of nix-darwin: researcher, unverified on a Mac.)
- BLOCKER (inferred): the cask `aerospace` (`nix/modules/darwin/homebrew.nix:61`)
  is not in homebrew-cask (404 from the formulae.brew.sh API on 2026-11-15; no
  rename or migration entry). The `nikitabobko/homebrew-tap` repository has
  Casks/aerospace.rb, so the qualified token is `nikitabobko/tap/aerospace`. The
  module sets no `homebrew.taps` (it defaults to an empty list). Activation runs
  under `set -e`, so a failing `brew bundle` probably aborts it (inferred). The other 23 cask tokens were current, none deprecated or
  disabled, none Intel-only. Confirm with `brew info --cask nikitabobko/tap/aerospace` on the Mac.
- `ops/update-all.sh` is not bash 3.2 safe: `mapfile` at lines 720, 770, 824,
  1006, 1021, 1165 and 1167, with no version guard. The ones at about 1165 and
  1167 are in the `!= macos` branch and are never reached on darwin. sys-update
  runs `bash update-all.sh`; after activation plain `bash` is likely 5.3
  (environment.systemPackages has bash-interactive 5.3 and
  /run/current-system/sw/bin comes ahead of /bin; evaluated, unverified), so
  the 3.2 problem shows only when run as `/bin/bash`.
  `ops/install.sh` and the selection libs are already 3.2 safe;
  `ops/lib/hm-switch.sh` has `mapfile` but is not reached on darwin (researcher).
  `tests/bash/portable-bash.bats` does not cover update-all.sh (researcher).
- The default-browser script exits 1 when `duti` fails or when public.html is
  not handled by Brave (`set-default-browser-macos.sh:9-18`); the dialog
  probably guards http/https. That a declined dialog fails the Home Manager
  activation is an inference (unverified).
- LaunchAgents under home/Library/LaunchAgents: the litellm plist runs
  `~/.config/litellm-copilot/scripts/start.sh` (plist line 12), and no repo
  source provides that script (nothing under home/dot_config); it has
  `KeepAlive`. The codebase-memory plist runs `~/.local/bin/codebase-memory-mcp`
  (plist line 9), which nothing places there (Home Manager installs it on
  darwin, `nix/modules/home/dev.nix:82`). Nothing loads either agent before
  the next login, and the log directories (plist lines 17, 19, 22, 25) are not
  created.
- Manual needs, all undocumented before the setup doc: Xcode CLT (for git),
  Homebrew, Gatekeeper prompts, Karabiner driver and Input Monitoring approval,
  a probable default-browser dialog, the 1Password desktop app (only
  `1password-cli` is declared). Rosetta, Full Disk Access and the App Store are
  not needed.
- `system.stateVersion = 5` (`nix/hosts/macos/darwin.nix:5`), maximum 7; 7
  changes tmux defaults and also crosses the 6-or-later default for
  `environment.darwinConfig` (harmless here with `nix.enable = false` and
  flakes), so keeping 5 is valid. The homebrew options in use are
  valid for the locked nix-darwin. `nix.enable = false` avoids the Determinate
  conflict and `nix.settings` is correctly absent.
- First activation may abort with "Unexpected files in /etc" if stock
  /etc/bashrc, zshrc, zshenv or zprofile do not match known hashes; fix: rename
  them to `*.before-nix-darwin`. Unverified.
- Fish is never the macOS login shell: no `chsh`, no /etc/shells entry, no
  `users.users.<name>.shell`, and zsh does not exec fish.
  `docs/guides/shell-setup.md` (around line 13) describes the Linux behaviour.
- The comment at `nix/modules/darwin/homebrew.nix:92-97` says `docker compose`
  needs a manual `~/.docker/config.json` `cliPluginsExtraDirs`. Probably wrong
  or unnecessary (unverified): the darwin Home Manager `docker` wraps the CLI
  with DOCKER_CLI_PLUGIN_DIRS including docker-compose's cli-plugins (derivation
  read, not run), and brew installs no docker CLI. Follow-up: fix the comment;
  not edited here.
- The macOS GUI sample in `ops/readiness.sh` only reports `[TODO]`, never a
  failure (`note()` at line 32).
- Docs drift: the header of `nix/modules/home/gui.nix` (lines 3-4) says only
  linux-desktop imports it, but `nix/hosts/macos/home.nix:5` imports it too (a
  no-op through the `isLinux` guard). The T-0042 AC14 recipe
  (evidence/t6-t8-results.md, "Human checks" item 1) uses `sha256sum`, which
  stock macOS lacks; use `shasum -a 256`.
- From Linux, the darwin outputs evaluate (`darwinConfigurations.macos.system.drvPath`,
  `homebrew.casks` with 24 tokens, brews, taps empty, prefix /opt/homebrew) and
  `nix flake check --all-systems --no-build` covers darwin.
- Not checkable without a Mac: `brew bundle`, Gatekeeper, the /etc conflicts,
  `duti` dialogs, launchd loading, the Determinate install, `sudo nix run` on a
  user-owned repo (git `safe.directory`), update-all under bash 3.2, the real
  darwin closure build, and macOS 27 behaviour.

## Fix tasks
Do them in this order. Fixes 1 to 3 gate the real install (verification step 4).
Fix 1 gates `sys-update --apply` (step 9). Fix 4 gates a clean step 8.

1. sudo for the darwin switch and check (BLOCKER).
   - Add `sudo` at ops/update-all.sh line 1218, mise.toml lines 115 and 186,
     keeping the selection arguments in place.
   - AC: a stub-based bats test of the update-all darwin branch asserts that
     `darwin-rebuild` is invoked through `sudo`, with the selection arguments
     intact. Test written first and seen failing.
   - AC: the full `bats tests/bash` suite passes (required for any change to
     update-all.sh).
   - AC: a stubbed bats assertion: with no TTY and `sudo -n` failing, the
     update-all `--apply` run on macOS exits before `chezmoi apply` runs.
   - Note: `mise.toml:115` is `sync:dry-run`; sudo there makes a preview need
     root (see the open question).
2. Homebrew preflight (BLOCKER).
   - Add a macOS preflight to ops/install.sh and ops/bootstrap.sh that fails,
     before any mutation, when /opt/homebrew/bin/brew is missing, with a
     pointer to https://brew.sh and to the macOS setup doc.
   - AC: bats tests with a stubbed PATH: brew missing fails with that message;
     brew present passes; a dry run still never fails on it (decide and pin).
   - AC: install and bootstrap bats suites pass.
3. The `aerospace` cask (inferred blocker).
   - Use the qualified token `nikitabobko/tap/aerospace` (and `homebrew.taps`
     if the module needs the tap declared), or remove the cask. Needs the
     answer to the first open question. Confirm on the Mac with
     `brew info --cask nikitabobko/tap/aerospace`.
   - AC: `brew info --cask <token>` succeeds on the Mac; `nix eval` of
     `darwinConfigurations.macos.config.homebrew.casks` and `.taps` shows the
     change; `nix flake check ./nix` passes.
4. bash 3.2 safety of ops/update-all.sh.
   - Replace each `mapfile` (as was done for install.sh), or add a version guard
     that re-execs under a newer bash with a clear message. The two at about
     1165/1167 are not reached on darwin but a blanket test still flags them.
   - AC: tests/bash/portable-bash.bats covers update-all.sh (no `mapfile` or
     `readarray` on the paths darwin reaches, or the guard is exercised); the
     full `bats tests/bash` suite passes; verification step 8 passes on the Mac
     as `/bin/bash ops/update-all.sh`.
5. Default-browser failure mode.
   - Decide whether a declined or failed `duti` step stays fatal. If non-fatal,
     warn and exit 0 when the dialog is declined; otherwise keep it and keep
     the warning in the setup doc.
   - AC: the decision is recorded here; if changed, a test or a documented
     manual check covers the declined case; the setup doc matches.
6. LaunchAgents.
   - Litellm: keep (and provide the script), fix, or drop the plist. Codebase
     memory: have something place the binary at ~/.local/bin, or point the
     plist at the real location, or drop it. Decide how agents get loaded
     (`launchctl bootstrap`, or document that they start at the next login) and
     create the log directories.
   - AC: no managed plist refers to a path that nothing creates; `chezmoi diff`
     is clean; the load method is documented; verified on the Mac with
     `launchctl print gui/$(id -u)/<label>`.
7. T-0038 (Colima darwin-only) after the first successful run. See that ticket.

Evidence follow-up: the T-0042 AC14 recipe (evidence/t6-t8-results.md, around
lines 71 and 74) is stale in three places: `sha256sum` (use `shasum -a 256`), a
clean checkout of feat/install-selection (that branch is gone; use main), and a
pinned lock hash 44847d... (main's lock has changed; compare the hash before
and after the switch instead). That file is not edited here.

Smaller follow-ups, same ticket, any order: correct the gui.nix header; correct or caveat
docs/guides/shell-setup.md for macOS; make the readiness macOS GUI sample able
to report a failure (or document that it cannot); decide on the fish login shell.

## Verification
Run on a fresh Mac, in this order. Each step lists expected output and
rollback. This is also the setup doc's procedure.

Steps 4, 5, 9 and 10 change the live Mac (LIVE).

1. Prerequisites: `xcode-select --install`; Homebrew from brew.sh;
   `brew info --cask nikitabobko/tap/aerospace` (the plain `aerospace` is
   expected to fail; brew may auto-tap a qualified name, a small change to
   Homebrew, unverified); `brew --prefix` (expect /opt/homebrew); clone
   as the login user named in nix/vars/default.nix; `/bin/bash --version`
   shows 3.2. Rollback: none needed.
2. Dry run under bash 3.2, no TTY:
   `APP_CONFIGS_SELECTION_DIR=$(mktemp -d) /bin/bash ops/install.sh --dry-run --profile work </dev/null`.
   Expect no "unbound variable", mapfile or "bad substitution", a
   `dry run: would write ...` line, and the run ending with "Dry run finished;
   nothing was changed." Before step 4 this is partial: Nix is missing, so the
   run warns "nix is not installed (dry-run)" (ops/install.sh:254) and the
   selection preview prints "preview unavailable: nix not installed"
   (ops/lib/selection-preview.sh:317). Repeat steps 2 and 3 after step 4 to
   close T-0042 human check 2.
3. TTY dry run: `/bin/bash ops/install.sh --dry-run` with an empty
   APP_CONFIGS_SELECTION_DIR; Enter five times (profile, go, macInput, media,
   security), then `a`; expect a `dry run: would write ...` line and the final
   "Dry run finished; nothing was changed." Partial before Nix exists, as in
   step 2; repeat it after step 4 to close check 2. Check 3 needs the casks
   installed first.
4. Real install (LIVE): `bash ops/install.sh --profile work`, only after fixes
   1 to 3. Then repeat steps 2 and 3. Rollback for a first install (one
   generation only, so `darwin-rebuild --rollback` has nothing to go back to:
   it runs `nix-env --rollback`; removing Nix first would leave /etc symlinks
   into /etc/static dangling), in this order, all unverified: (a) restore the
   $HOME snapshot from ~/.local/state/dotfiles-snapshots/<UTC timestamp>/
   (ops/snapshot-home.sh; override with DOTFILES_SNAPSHOT_ROOT; Home Manager's
   symlinks in $HOME and ~/.nix-profile dangle once Nix is gone, so also list
   leftovers with `find ~ -maxdepth 3 -type l ! -exec test -e {} \; -print`);
   (b) nix-darwin's uninstaller at the locked rev, for example `sudo nix run
   github:LnL7/nix-darwin/<locked rev>#darwin-uninstaller` (LnL7 matches the
   flake.lock owner; do not rely on the rename redirect); (c) only then
   `sudo /nix/nix-installer uninstall`. Homebrew casks stay installed. If the
   switch fails on git `safe.directory`, one possible workaround is to re-run
   it with a `path:` flake ref, `sudo darwin-rebuild switch --flake
   "path:$PWD/nix#macos" ...` (or the `sudo nix run` form with `path:`);
   unverified. Do not use
   `git config --global` for this: macOS `sudo` keeps HOME, so root would write
   to the chezmoi-managed `~/.gitconfig`, and `sys-update` then refuses to run
   over a hand-edited managed file.
5. AC14 (LIVE): a switch with a selection override per the T-0042 evidence
   recipe, with `shasum -a 256`, from a clean checkout of main, comparing the
   lock hash before and after (not against the pinned value). Expect success, a clean git status, an unchanged lock,
   and both casks still installed. Rollback: re-run without the override, or
   `sudo darwin-rebuild --rollback` (an older generation exists by now). Closes
   AC14.
6. Brew preview: repeat step 3 with casks installed. Closes check 3.
7. `bash ops/doctor.sh` and `bash ops/readiness.sh`. Expect [TODO] for GUI apps
   with no CLI and no [MISS]. Rollback: none.
8. sys-update in report mode: `/bin/bash ops/update-all.sh`. Do not type
   `sys-update`; the wrapper always adds --apply. `/bin/bash` because plain
   `bash` is likely 5.3 after activation (evaluated, unverified). Under bash 3.2
   it may fail on mapfile; that is a finding until fix 4 lands. Rollback: none.
9. `sys-update --apply` (LIVE), only after fix 1. Expect "no runtime
   verification gate for macos". Rollback: `sys-update rollback` (do_rollback,
   ops/update-all.sh:473-545) restores files and prints `sudo <previous
   system>/activate` to run by hand; or `sudo darwin-rebuild --rollback`.
10. Rollback drill (LIVE): `sudo darwin-rebuild --rollback`, then switch
    forward with `sudo darwin-rebuild switch --flake "$PWD/nix#macos"` (add
    `--override-input selection path:$HOME/.config/app-configs/selection` when
    `selection.toml` exists there; or get the arguments with
    `bash -c '. ops/lib/selection.sh; selection_args; selection_args_text'`, or `mise run sync:apply` after fix 1. Casks stay installed (cleanup = none).

Checks to run for the fixes themselves: `bats tests/bash` in full for fixes 1
and 4 (they change ops/update-all.sh), the install and bootstrap suites for fix
2, `nix flake check ./nix` for fix 3, and `bash ops/validate-config.sh`.

## Dependencies
- Related: [T-0042](../T-0042-install-selection/ticket.md): its human checks
  (AC14, real bash 3.2 run, real brew preview) are closed by verification steps
  2, 3, 5, 6.
- Related: [T-0038](../T-0038-colima-darwin-only/ticket.md): fix task 7; can wait.

## Open questions
1. Is adding the aerospace tap (nikitabobko/tap) acceptable, or should the app go?
2. Should the default-browser step be fatal, or warn and continue?
3. Litellm LaunchAgent: keep (and provide its script), fix, or drop?
4. Should fish become the macOS login shell (chsh, /etc/shells, and
   `users.users.<name>.shell`), or stay zsh-only?
5. Is Determinate the intended Nix installer for macOS?
6. Drop the brew `docker-compose`? Check `docker compose version` on the Mac
   first (the Home Manager docker wrapper may already provide compose).
7. For `sync:dry-run` (mise.toml:115), use sudo for `darwin-rebuild check`, or
   `darwin-rebuild build` (needs no root; untested) for the preview?

## Additional acceptance criteria (review of 2026-11-20)
- AC-A, configuration ownership: classify each setting the repo would write as `managed` (an MDM or employer policy owns it), `owner-configurable`, `observe-only` or `unsupported`. A managed setting is never overridden. If management status is unknown, the setting is not modified.
- AC-B, privilege before change: `sys-update --apply` checks that the privileged switch can run (root, or cached sudo) before the first step that changes user configuration, so it cannot fail at the switch after chezmoi has applied.
- AC-C, read-only preview: `sync:dry-run` needs no sudo, runs no activation and installs nothing (see open question 7; `darwin-rebuild build` needs no root). The temporary selection directory it creates with `mktemp -d` is a test fixture and is cleaned up; setup documents it separately from changes to the real system.
- AC-D, post-activation smoke tests on the real Mac: SSH, Git, the local web stack, Docker through Colima, the default browser (including the http and https handlers) and the editor still work.
- AC-E, rollback scope: say which of these a rollback covers and which stay manual: Nix generations, dotfiles, Homebrew applications, LaunchAgents and macOS settings. A Nix rollback does not undo all of them.
- AC-F, LaunchAgents: before an agent is loaded, its executable exists and is executable, its working directory is valid, its environment is explicit (not an interactive shell), `KeepAlive` is set only for a real long-lived service, its log directories exist with bounded retention, its real service state is checked (not only the plist), and it can be unloaded and restored. An agent with an unresolved executable is not activated. A live read-only check on 2026-11-20 found six user agents: every one that declares a program exists, none has a missing working directory, one has `KeepAlive` on.
- The default-browser script now checks the http and https handlers and warns (not fails) when they are not Brave yet, because macOS may ask for confirmation; the HTML and PDF checks stay fatal. This answers open question 2 for the scheme check only.
