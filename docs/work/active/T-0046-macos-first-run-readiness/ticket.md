Source: local

# T-0046: macOS first-run readiness: blockers, fixes and a real-Mac verification order (bug)

Status: open
Wave: unassigned
Depends on: T-0042 (landed on main; its human checks AC14, bash 3.2 and brew
preview close here), T-0038 (Colima darwin-only; may wait until after a first
successful run)

## Summary
Nobody has run this repo on a Mac. A static review at main ed39171 (nothing was
run on a Mac) found two certain blockers and one probable blocker on the way
to a first install, plus smaller gaps. This ticket orders the fixes, with
acceptance criteria, and holds the step-by-step real-Mac verification order.
The user-facing procedure is the macOS setup doc, docs/platforms/macos/setup.md.
This ticket changes no code; the fixes below are separate work.

## Findings
Verified by reading the files unless marked.
- BLOCKER: newer nix-darwin refuses `darwin-rebuild switch|check` unless run as
  root ("system activation must now be run as root"; locked nix-darwin source,
  pkgs/nix-tools/darwin-rebuild.sh around lines 149-152, read by the
  researcher, not re-read here). `ops/update-all.sh:1218` and `mise.toml:115`
  (check) and `mise.toml:186` (switch) run it without sudo. `ops/install.sh:424,426`
  and `ops/bootstrap.sh:248,250` use sudo, and bats pins that. So
  `sys-update --apply` on a Mac would fail at the switch after chezmoi apply
  has run, and there is no automatic darwin rollback (`ops/update-all.sh:539-545`).
- BLOCKER: nix-darwin's homebrew module does not install Homebrew. With brew
  absent it prints "Homebrew is not installed, skipping..." and continues, so no
  cask is installed. Then `nix/modules/home/default-browser-macos.nix` runs
  `nix/modules/home/scripts/set-default-browser-macos.sh`, which exits 1
  ("Brave Beta is missing", line 7). Nothing in `ops/install.sh` or
  `ops/bootstrap.sh` checks for brew (`ops/install.sh:201-207` checks sudo only).
  (Behaviour of nix-darwin: researcher, unverified on a Mac.)
- PROBABLE BLOCKER: the cask `aerospace` (`nix/modules/darwin/homebrew.nix:61`)
  returned 404 from the formulae.brew.sh API on 2026-11-15; upstream installs
  from the tap nikitabobko/tap. The module sets no `homebrew.taps` (it defaults
  to an empty list). The other 23 cask tokens were current, none deprecated or
  disabled, none Intel-only. Confirm with `brew info --cask aerospace` on the Mac.
- `ops/update-all.sh` is not bash 3.2 safe: `mapfile` at lines 720, 770, 824,
  1006, 1021, 1165 and 1167, with no version guard. sys-update runs
  `bash update-all.sh`; which bash is first on PATH on macOS is unknown.
  `ops/install.sh` and the selection libs are already 3.2 safe;
  `ops/lib/hm-switch.sh` has `mapfile` but is not reached on darwin (researcher).
  `tests/bash/portable-bash.bats` does not cover update-all.sh (researcher).
- The default-browser script fails the whole Home Manager activation if the
  `duti` confirmation dialog is declined (`set-default-browser-macos.sh:15-18`).
- LaunchAgents under home/Library/LaunchAgents: the litellm plist runs
  `~/.config/litellm-copilot/scripts/start.sh` (plist line 12), and no repo
  source provides that script (nothing under home/dot_config); it has
  `KeepAlive`. The codebase-memory plist runs `~/.local/bin/codebase-memory-mcp`
  (plist line 9), which nothing places there. Nothing loads either agent before
  the next login, and the log directories (plist lines 17, 19, 22, 25) are not
  created.
- Manual needs, all undocumented before the setup doc: Xcode CLT (for git),
  Homebrew, Gatekeeper prompts, Karabiner driver and Input Monitoring approval,
  a probable default-browser dialog, the 1Password desktop app (only
  `1password-cli` is declared). Rosetta, Full Disk Access and the App Store are
  not needed.
- `system.stateVersion = 5` (`nix/hosts/macos/darwin.nix:5`), maximum 7; 7 only
  changes tmux defaults, so keeping 5 is valid. The homebrew options in use are
  valid for the locked nix-darwin. `nix.enable = false` avoids the Determinate
  conflict and `nix.settings` is correctly absent.
- First activation may abort with "Unexpected files in /etc" if stock
  /etc/bashrc, zshrc, zshenv or zprofile do not match known hashes; fix: rename
  them to `*.before-nix-darwin`. Unverified.
- Fish is never the macOS login shell: no `chsh`, no /etc/shells entry, no
  `users.users.<name>.shell`, and zsh does not exec fish.
  `docs/guides/shell-setup.md` (around line 13) describes the Linux behaviour.
- `docker compose` needs a manual `~/.docker/config.json` `cliPluginsExtraDirs`,
  deliberately unmanaged (`nix/modules/darwin/homebrew.nix:92-97`).
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
   - AC: the `sys-update --apply` path does not reach `chezmoi apply` on macOS
     without confirming sudo is available (or the failure is reported before
     any mutation). Decide in review; record the choice.
2. Homebrew preflight (BLOCKER).
   - Add a macOS preflight to ops/install.sh and ops/bootstrap.sh that fails,
     before any mutation, when /opt/homebrew/bin/brew is missing, with a
     pointer to https://brew.sh and to the macOS setup doc.
   - AC: bats tests with a stubbed PATH: brew missing fails with that message;
     brew present passes; a dry run still never fails on it (decide and pin).
   - AC: install and bootstrap bats suites pass.
3. The `aerospace` cask (PROBABLE BLOCKER).
   - On the Mac run `brew info --cask aerospace`. If it fails, add the tap
     (nikitabobko/tap, via `homebrew.taps`) with the cask token the tap uses,
     or remove the cask. Needs the answer to the first open question.
   - AC: `brew info --cask <token>` succeeds on the Mac; `nix eval` of
     `darwinConfigurations.macos.config.homebrew.casks` and `.taps` shows the
     change; `nix flake check ./nix` passes.
4. bash 3.2 safety of ops/update-all.sh.
   - Replace each `mapfile` (as was done for install.sh), or add a version guard
     that re-execs under a newer bash with a clear message.
   - AC: tests/bash/portable-bash.bats covers update-all.sh (no `mapfile` or
     `readarray`, or the guard is exercised); the full `bats tests/bash` suite
     passes; verification step 8 passes on the Mac under /bin/bash.
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

Smaller follow-ups, same ticket, any order: correct the gui.nix header; use
`shasum -a 256` in the T-0042 evidence recipe; correct or caveat
docs/guides/shell-setup.md for macOS; make the readiness macOS GUI sample able
to report a failure (or document that it cannot); decide on the fish login shell.

## Verification
Run on a fresh Mac, in this order. Each step lists expected output and
rollback. This is also the setup doc's procedure.

1. Prerequisites: `xcode-select --install`; Homebrew from brew.sh;
   `brew info --cask aerospace`; `brew --prefix` (expect /opt/homebrew); clone
   as the login user named in nix/vars/default.nix; `/bin/bash --version`
   shows 3.2. Rollback: none needed.
2. Dry run under bash 3.2, no TTY:
   `APP_CONFIGS_SELECTION_DIR=$(mktemp -d) /bin/bash ops/install.sh --dry-run --profile work </dev/null`.
   Expect no "unbound variable", mapfile or "bad substitution", ending with
   "dry run: would write ...". Closes T-0042 human check 2, first half.
3. TTY dry run: `/bin/bash ops/install.sh --dry-run` with an empty
   APP_CONFIGS_SELECTION_DIR; Enter five times (profile, go, macInput, media,
   security), then `a`; expect "dry run: would write". Closes check 2. Check 3
   needs the casks installed first.
4. Real install: `bash ops/install.sh --profile work`, only after fixes 1 to 3.
   Rollback: the snapshot from ops/snapshot-home.sh, `sudo darwin-rebuild
   --rollback`, and the Determinate uninstaller for Nix.
5. AC14: a switch with a selection override per the T-0042 evidence recipe,
   with `shasum -a 256`. Expect success, a clean git status, an unchanged lock,
   and both casks still installed. Rollback: re-run without the override, or
   `sudo darwin-rebuild --rollback`. Closes AC14.
6. Brew preview: repeat step 3 with casks installed. Closes check 3.
7. `bash ops/doctor.sh` and `bash ops/readiness.sh`. Expect [TODO] for GUI apps
   with no CLI and no [MISS]. Rollback: none.
8. sys-update in report mode (`bash ops/update-all.sh`). Under bash 3.2 it may
   fail on mapfile; that is a finding until fix 4 lands. Rollback: none.
9. `sys-update --apply`, only after fix 1. Expect "no runtime verification gate
   for macos". Rollback: `sudo <previous system>/activate`, or `sudo
   darwin-rebuild --rollback`.
10. Rollback drill: `sudo darwin-rebuild --rollback`, then switch forward
    again. Casks stay installed (cleanup = none).

Checks to run for the fixes themselves: `bats tests/bash` in full for fixes 1
and 4 (they change ops/update-all.sh), the install and bootstrap suites for fix
2, `nix flake check ./nix` for fix 3, and `bash ops/validate-config.sh`.

## Dependencies
- [T-0042](../T-0042-install-selection/ticket.md): its human checks (AC14, real
  bash 3.2 run, real brew preview) are closed by verification steps 2, 3, 5, 6.
- [T-0038](../T-0038-colima-darwin-only/ticket.md): fix task 7.

## Open questions
1. Is adding the aerospace tap (nikitabobko/tap) acceptable, or should the app go?
2. Should the default-browser step be fatal, or warn and continue?
3. Litellm LaunchAgent: keep (and provide its script), fix, or drop?
4. Should fish become the macOS login shell (chsh, /etc/shells, and
   `users.users.<name>.shell`), or stay zsh-only?
5. Is Determinate the intended Nix installer for macOS?
