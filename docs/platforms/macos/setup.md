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
run steps 4, 9 and 10 until the fixes in that ticket have landed.

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
   Expect: no `unbound variable`, `mapfile` or `bad substitution` errors, and
   a last line `dry run: would write ...`. Rollback: none (writes nothing).
   Closes the first half of T-0042 human check 2.

3. **Dry run on a TTY.** In a terminal, with `APP_CONFIGS_SELECTION_DIR` set to
   an empty scratch directory:
   ```bash
   /bin/bash ops/install.sh --dry-run
   ```
   Answer Enter five times (profile, go, macInput, media, security), then `a`.
   Expect `dry run: would write ...`. Rollback: none. Closes T-0042 human
   check 2. Check 3 (brew preview) needs the casks installed first (step 6).

4. **Real install.** Only after fixes 1 to 3 of the ticket have landed.
   ```bash
   bash ops/install.sh --profile work
   ```
   It runs, in order: preflight (`sudo -v` on a TTY), the Determinate Nix
   installer if Nix is missing, `nix profile install` of chezmoi, mise,
   home-manager and lefthook, `nix flake check`, the Selection step, chezmoi
   init/snapshot/apply, `sudo nix run ...#darwin-rebuild -- switch --flake
   ...#macos`, then mise, VS Code extensions, lefthook, ssh-agent setup and
   doctor. Expect it to finish with the doctor report. Rollback: restore the
   `$HOME` snapshot taken by `ops/snapshot-home.sh`; `sudo darwin-rebuild
   --rollback` for the system; the Determinate uninstaller for Nix itself.
   *(unverified: the Determinate install, `sudo nix run` on a user-owned repo
   (git `safe.directory`), the closure build, and the /etc conflicts below.)*

5. **AC14: a switch with a selection override.** This switches the live Mac.
   Use the recipe in
   `docs/work/active/T-0042-install-selection/evidence/t6-t8-results.md`
   ("Human checks", item 1), but write `shasum -a 256 nix/flake.lock` where it
   says `sha256sum` (stock macOS has no `sha256sum`). Expect: the switch
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

8. **sys-update, report mode.** `bash ops/update-all.sh` changes nothing. Under
   bash 3.2 it can fail on `mapfile` (see "Known gaps"); that is a finding
   until fix 4 of the ticket lands.

9. **`sys-update --apply`.** Only after fix 1 of the ticket. Expect "no runtime
   verification gate for macos". Rollback: `sudo <previous system>/activate`
   (the update prints the path), or `sudo darwin-rebuild --rollback`. The
   script does not roll darwin back automatically (`ops/update-all.sh:539-545`).

10. **Rollback drill.** `sudo darwin-rebuild --rollback`, then switch forward
    again. Casks stay installed because Homebrew `cleanup` is `"none"`
    (`nix/modules/darwin/homebrew.nix:35`).

## 3. Manual approvals

Expect to click through these; none can be scripted. *(All unverified.)*

- Gatekeeper / quarantine prompts the first time each cask app launches.
- Karabiner-Elements: approve the driver extension and Input Monitoring
  (only when `macInput` is on).
- A probable confirmation dialog when `duti` changes the default browser
  (`nix/modules/home/scripts/set-default-browser-macos.sh`). Declining it
  fails the Home Manager activation (lines 15-18 of that script).
- The 1Password desktop app, if you want biometric unlock. Only
  `1password-cli` is declared.
- Possibly "Unexpected files in /etc" on the first activation, if the stock
  `/etc/bashrc`, `/etc/zshrc`, `/etc/zshenv` or `/etc/zprofile` do not match
  the hashes nix-darwin knows. The fix is to rename each to
  `*.before-nix-darwin` and re-run.

## 4. What differs from Linux and WSL2

| Area | macOS | Linux / WSL2 |
| --- | --- | --- |
| Clipboard (tmux copy) | `pbcopy` | `clip.exe` via `clipcopy` on WSL2; the Linux desktop tool is not covered here |
| SSH key passphrase | Keychain via `home/dot_config/app-configs/ssh-agent.sh` (`UseKeychain`) | `keychain` (Nix), once per boot |
| GUI apps | Homebrew casks from `nix/modules/darwin/homebrew.nix`, `cleanup = "none"` (removing a cask from the list never uninstalls it) | Nix packages (`gui.nix`) on linux-desktop; none on WSL2 |
| Login shell | zsh (macOS default). Fish is installed but never the login shell: there is no `chsh`, no `/etc/shells` entry and no `users.users.<name>.shell`, and zsh does not exec fish | fish on NixOS via `sys-setup`; bash `exec`s into fish |
| Docker daemon | Colima VM; `docker compose` needs a manual `~/.docker/config.json` `cliPluginsExtraDirs` (deliberately unmanaged, `nix/modules/darwin/homebrew.nix:92-97`) | Docker Engine |
| Nix installer | Determinate; `nix.enable = false` in nix-darwin avoids the conflict | Determinate (non-NixOS) or the OS |
| Launch agents | `home/Library/LaunchAgents` plists, loaded at the next login only | systemd user timers |

`system.stateVersion = 5` (`nix/hosts/macos/darwin.nix:5`) is valid; the
current maximum is 7, which only changes tmux defaults.
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
3. **Probable blocker, the `aerospace` cask.** The formulae.brew.sh API
   returned 404 for it on 2026-11-15; upstream installs from the tap
   `nikitabobko/tap`, and the repo declares no taps. The other 23 cask
   tokens were current and none deprecated, disabled or Intel-only.
4. **`ops/update-all.sh` is not bash 3.2 safe.** `mapfile` at lines 720, 770,
   824, 1006, 1021, 1165 and 1167, with no version guard. Which bash comes
   first on `PATH` on a Mac is unknown.
5. **Default browser step is fatal.** A declined `duti` dialog aborts the
   activation.
6. **LaunchAgents.** The litellm plist runs
   `~/.config/litellm-copilot/scripts/start.sh`, which no repo source
   provides (with `KeepAlive`). The codebase-memory plist runs
   `~/.local/bin/codebase-memory-mcp`, which nothing places there. Nothing
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
