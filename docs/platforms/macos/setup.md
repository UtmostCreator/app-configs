# macOS setup

macOS uses the `macos` host profile: nix-darwin (system, Homebrew casks) plus
Home Manager (user CLI layer) from `nix/flake.nix`, with chezmoi for dotfiles.
The expected machine is a recent macOS on an Apple Silicon laptop (M4 or
newer). It shares one `flake.lock` with Linux and WSL2.

**Status: nobody has run this on a real Mac yet.** Everything below comes from
static inspection of the repository at commit ed39171 and from evaluating the
darwin outputs on Linux. Steps marked *(unverified)* describe expected
behaviour that is not proven. The blockers and open work are tracked in
`docs/work/active/T-0046-macos-first-run-readiness/ticket.md` (T-0046). Do not
run steps 4, 9 and 10 until the fixes in that ticket have landed. Steps that
change the live Mac are marked **LIVE**.

## 1. Prerequisites

Install these by hand. The repo does not (yet) check for them.

```bash
xcode-select --install                 # provides git, needed to clone
# Homebrew: follow https://brew.sh (hard prerequisite, see below)
brew --prefix                          # expect /opt/homebrew
brew info --cask aerospace             # see "Known gaps": the token may be wrong
git clone https://github.com/UtmostCreator/app-configs.git ~/app-configs
cd ~/app-configs
/bin/bash --version                    # expect 3.2.x
```

- Log in as the `username` from `nix/vars/default.nix`. `ops/install.sh`
  stops early if the login user differs (`ops/lib/preflight.sh:76-91`).
- Homebrew is a hard prerequisite. nix-darwin's Homebrew module does not
  install brew. Without it activation prints "Homebrew is not installed,
  skipping..." and continues, no cask is installed, and the default-browser
  step then fails (see "Known gaps").
- The first install seeds `home/.chezmoidata/personal.yaml` with `gui: true`.
  Fill in your name and email there. Do not commit it.
- Rosetta, Full Disk Access and the App Store are not needed.

## 2. Procedure, in this order

Each step lists the expected output and the rollback. Stop at the first
surprise and record it in the ticket.

1. **Prerequisites** (above). Rollback: none needed.

2. **Dry run under bash 3.2, no TTY.**
   ```bash
   APP_CONFIGS_SELECTION_DIR=$(mktemp -d) /bin/bash ops/install.sh --dry-run --profile work </dev/null
   ```
   Expect: no `unbound variable`, `mapfile` or `bad substitution` errors, a
   `dry run: would write ...` line, and the run ends with "Dry run finished;
   nothing was changed." Rollback: none (writes nothing). Before step 4 this
   run is partial: Nix is not installed yet, so it warns "nix is not
   installed (dry-run)" and the selection preview prints "preview unavailable:
   nix not installed" (`ops/install.sh:254`, `ops/lib/selection-preview.sh:317`).
   It only proves the script parses and runs under bash 3.2. Repeat steps 2
   and 3 after step 4 to close T-0042 human check 2.

3. **Dry run on a TTY.** In a terminal, with `APP_CONFIGS_SELECTION_DIR` set to
   an empty scratch directory:
   ```bash
   /bin/bash ops/install.sh --dry-run
   ```
   Answer Enter five times (profile, go, macInput, media, security), then `a`.
   Expect a `dry run: would write ...` line and the final "Dry run finished;
   nothing was changed." Rollback: none. As in step 2 this is partial before
   Nix exists; repeat it after step 4 to close T-0042 human check 2. Check 3
   (brew preview) needs the casks installed first (step 6).

4. **Real install (LIVE).** Only after fixes 1 to 3 of the ticket have landed.
   ```bash
   bash ops/install.sh --profile work
   ```
   It runs, in order: preflight (`sudo -v` on a TTY), the Determinate Nix
   installer if Nix is missing, `nix profile install` of chezmoi, mise,
   home-manager and lefthook, `nix flake check`, the Selection step, chezmoi
   init/snapshot/apply, `sudo nix run ...#darwin-rebuild -- switch --flake
   ...#macos`, then mise, VS Code extensions, lefthook, ssh-agent setup and
   doctor. Expect it to finish with the doctor report. Then repeat steps 2
   and 3, now with Nix present.

   Rollback for a first install. `sudo darwin-rebuild --rollback` does not
   work here: there is only one generation, and darwin-rebuild's rollback runs
   `nix-env --rollback` on the system profile. Removing Nix first would leave
   the `/etc` symlinks into `/etc/static` dangling. Use this order *(all
   unverified)*:
   1. Restore the `$HOME` snapshot. `ops/snapshot-home.sh` copies the files
      chezmoi is about to overwrite to
      `~/.local/state/dotfiles-snapshots/<UTC timestamp>/` (override with
      `DOTFILES_SNAPSHOT_ROOT`), with a `MANIFEST.txt` there.
   2. Run nix-darwin's uninstaller at the locked revision, for example
      `sudo nix run github:nix-darwin/nix-darwin/<locked rev>#darwin-uninstaller`
      (the package is `pkgs/darwin-uninstaller`; read the rev from
      `nix/flake.lock`; the exact command form is unverified).
   3. Only then remove Nix with the Determinate uninstaller,
      `sudo /nix/nix-installer uninstall`.

   *(unverified: the Determinate install, `sudo nix run` on a user-owned repo,
   the closure build, and the /etc conflicts below.)* If the switch fails on
   git's `safe.directory` check for the user-owned repo (the root user does
   not trust it), one possible workaround is
   `sudo git config --global --add safe.directory ~/app-configs`; unverified.

5. **AC14: a switch with a selection override (LIVE).** Use the recipe in
   `docs/work/active/T-0042-install-selection/evidence/t6-t8-results.md`
   ("Human checks", item 1), but write `shasum -a 256 nix/flake.lock` where it
   says `sha256sum` (stock macOS has no `sha256sum`). The recipe is stale in
   two more places: use a clean checkout of main (the feat/install-selection
   branch no longer exists), and compare the lock hash before and after the
   switch instead of against the pinned 44847d... value, because main's lock
   has changed. Expect: the switch
   succeeds, `git status --short` is empty, the lock hash is unchanged, and
   karabiner-elements and linearmouse are still installed. Rollback: re-run
   the switch without `--override-input`, or `sudo darwin-rebuild --rollback`.
   Closes AC14.

6. **Brew preview.** With the casks installed, repeat step 3, answering
   macInput `n` as the T-0042 evidence describes. Closes T-0042 human check 3.

7. **Health checks.**
   ```bash
   bash ops/doctor.sh
   bash ops/readiness.sh
   ```
   Expect `[TODO]` lines for GUI apps without a CLI and no `[MISS]` lines.
   (The macOS GUI sample reports only `[TODO]`, never a failure
   (`ops/readiness.sh:32`).) Rollback: none.

8. **sys-update, report mode.** Run `/bin/bash ops/update-all.sh`; it changes
   nothing. Do not type `sys-update` for this: the wrapper always adds
   `--apply`. Use `/bin/bash` explicitly because after activation plain `bash`
   is likely bash 5.3 (`environment.systemPackages` has bash-interactive, and
   `/run/current-system/sw/bin` comes ahead of `/bin`; evaluated, unverified),
   which would hide a bash 3.2 failure. Under bash 3.2 it can fail on
   `mapfile` (see "Known gaps"); that is a finding until fix 4 of the ticket
   lands.

9. **`sys-update --apply` (LIVE).** Only after fix 1 of the ticket. Expect "no
   runtime verification gate for macos". Rollback: `sys-update rollback`
   (`do_rollback`, `ops/update-all.sh:473-545`) restores files and prints
   `sudo <previous system>/activate` to run by hand; or
   `sudo darwin-rebuild --rollback`, which works here because an older
   generation now exists. The script does not roll darwin back automatically
   (`ops/update-all.sh:539-545`).

10. **Rollback drill (LIVE).** `sudo darwin-rebuild --rollback`, then switch
    forward with
    `sudo darwin-rebuild switch --flake "$PWD/nix#macos"`, adding
    `--override-input selection path:<dir>` after the flake when a local
    selection exists (`ops/lib/selection.sh` prints the arguments), or
    `mise run sync:apply` once fix 1 has landed. Casks stay installed because Homebrew `cleanup` is `"none"`
    (`nix/modules/darwin/homebrew.nix:35`).

## 3. Manual approvals

Expect to click through these; none can be scripted. *(All unverified.)*

- Gatekeeper / quarantine prompts the first time each cask app launches.
- Karabiner-Elements: approve the driver extension and Input Monitoring
  (only when `macInput` is on).
- A probable confirmation dialog when `duti` changes the default browser
  (`nix/modules/home/scripts/set-default-browser-macos.sh`). That declining
  it fails the Home Manager activation is an inference *(unverified)*: the
  script exits 1 when `duti` fails or when public.html is not handled by Brave
  (lines 9-18), and the dialog most likely guards http and https.
- The 1Password desktop app, if you want biometric unlock. Only
  `1password-cli` is declared.
- Possibly "Unexpected files in /etc" on the first activation, if the stock
  `/etc/bashrc`, `/etc/zshrc`, `/etc/zshenv` or `/etc/zprofile` do not match
  the hashes nix-darwin knows. The fix is to rename each to
  `*.before-nix-darwin` and re-run.

## 4. What differs from Linux and WSL2

| Area | macOS | Linux / WSL2 |
| --- | --- | --- |
| Clipboard (tmux copy) | `pbcopy` | `clipcopy` (`home/dot_local/bin/executable_clipcopy`): `wl-copy`, `xclip` or `xsel` on Linux, `clip.exe` on WSL2 |
| SSH key passphrase | Keychain via `home/dot_config/app-configs/ssh-agent.sh` (`UseKeychain`) | `keychain` (Nix), once per boot |
| GUI apps | Homebrew casks from `nix/modules/darwin/homebrew.nix`, `cleanup = "none"` (removing a cask from the list never uninstalls it) | Nix packages (`gui.nix`) on linux-desktop; none on WSL2 |
| Login shell | zsh (macOS default). Fish is installed but never the login shell: there is no `chsh`, no `/etc/shells` entry and no `users.users.<name>.shell`, and zsh does not exec fish | fish on NixOS via `sys-setup`; bash `exec`s into fish |
| Docker daemon | Colima VM. `nix/modules/darwin/homebrew.nix:92-97` says `docker compose` needs a manual `~/.docker/config.json` `cliPluginsExtraDirs`; that is probably wrong or unnecessary *(unverified)*: the darwin Home Manager `docker` appears to wrap the CLI with `DOCKER_CLI_PLUGIN_DIRS` including docker-compose's cli-plugins (derivation read, not run), and brew installs no docker CLI. Check `docker compose version` | Docker Engine |
| Nix installer | Determinate; `nix.enable = false` in nix-darwin avoids the conflict | Determinate (non-NixOS) or the OS |
| Launch agents | `home/Library/LaunchAgents` plists, loaded at the next login only | systemd user timers |

`system.stateVersion = 5` (`nix/hosts/macos/darwin.nix:5`) is valid; the
current maximum is 7. Going from 5 to 7 changes tmux defaults and also crosses
the 6-or-later default for `environment.darwinConfig`, which is harmless here
with `nix.enable = false` and flakes. Keeping 5 is fine.
`docs/guides/shell-setup.md` describes the Linux behaviour (fish via bash
`exec`); it does not apply to macOS.

## 5. Known gaps

Fixes are specified in the ticket. Numbers match its fix tasks.

1. **BLOCKER, `sys-update --apply` fails at the switch.** Recent nix-darwin
   refuses `darwin-rebuild switch|check` unless run as root. `ops/update-all.sh:1218`
   and `mise.toml:115` and `mise.toml:186` run it without `sudo`. `install.sh`
   and `bootstrap.sh` use `sudo`. The failure comes after `chezmoi apply`, with
   no automatic darwin rollback.
2. **BLOCKER, Homebrew absent is not detected.** See Prerequisites. The
   default-browser script then exits 1 ("Brave Beta is missing").
3. **Blocker (inferred), the `aerospace` cask.** homebrew-cask has no
   aerospace (formulae.brew.sh API 404 on 2026-11-15, no rename or migration
   entry). The `nikitabobko/homebrew-tap` repository has `Casks/aerospace.rb`,
   so the qualified token is `nikitabobko/tap/aerospace`. The repo declares no
   taps. Activation runs under `set -e`, so a failing `brew bundle` probably
   aborts it (inferred). The other 23 cask
   tokens were current and none deprecated, disabled or Intel-only.
4. **`ops/update-all.sh` is not bash 3.2 safe.** `mapfile` at lines 720, 770,
   824, 1006, 1021, 1165 and 1167, with no version guard. The ones at about
   1165 and 1167 sit in the `!= macos` branch and are never reached on
   darwin. After activation plain `bash` is likely 5.3 (evaluated,
   unverified), so only `/bin/bash` shows the 3.2 behaviour.
5. **Default browser step is fatal on failure.** The script exits 1 on a
   `duti` failure or an unhandled public.html; that a declined dialog aborts
   the activation is an inference *(unverified)*.
6. **LaunchAgents.** The litellm plist runs
   `~/.config/litellm-copilot/scripts/start.sh`, which no repo source
   provides (with `KeepAlive`). The codebase-memory plist runs
   `~/.local/bin/codebase-memory-mcp`, which nothing places there (Home
   Manager installs it on darwin, `nix/modules/home/dev.nix:82`, so the plist
   can point at the Home Manager profile path). Nothing
   loads the agents before the next login, and their log directories are not
   created.
7. T-0038 (Colima darwin-only) can wait until after a first successful run.

Other gaps: the header of `nix/modules/home/gui.nix` says only linux-desktop
imports it, but macOS imports it too (a no-op through the `isLinux` guard).

## Not yet verified on a real Mac

Nothing has been run on a Mac. From a Linux host the darwin outputs evaluate
(`darwinConfigurations.macos.system.drvPath`, 24 cask tokens, the brews list,
taps empty, prefix `/opt/homebrew`) and `nix flake check
--all-systems --no-build` covers darwin. Not checkable without a Mac:
`brew bundle`, Gatekeeper, the /etc conflicts, `duti` dialogs, launchd loading,
the Determinate install, `sudo nix run` on a user-owned repo, `update-all.sh`
under bash 3.2, the real darwin closure build, and macOS 27 behaviour.

Open work and the verification checklist:
[T-0046](../../work/active/T-0046-macos-first-run-readiness/ticket.md).
