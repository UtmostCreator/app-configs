---
adr: 17
title: "Interactive shell: fish as primary, on trial against zsh"
status: trial
date: 2026-11-16
platforms: [linux, nixos, macos, wsl]
areas: [shell]
amends: []
supersedes: []
superseded_by: []
related: [T-0036]
---
# ADR-0017: Interactive shell: fish as primary, on trial against zsh
Status: trial (owner decision 2026-11-16: fish was selected for testing purposes) · Date: 2026-11-16 · Sources: `docs/guides/shell-setup.md`, `home/dot_bashrc.tmpl`, `ops/system-setup.sh`, `ops/readiness.sh`, owner-supplied AI-assisted comparisons (estimates, not measurements)

## Decision
- fish is the primary interactive shell **for testing purposes**: an evaluation period, not a permanent selection.
- zsh stays supported as the alternative (`home/dot_zshrc.tmpl` keeps shipping). bash stays the fallback and the entry point that execs into fish.
- Trial ends, and this ADR is revisited, when any of these happens: a recurring fish/POSIX incompatibility costs real time (a tool or script that only supports bash/zsh init); the zsh twins in the tests keep drifting from fish; or the owner decides the trial is long enough. The outcome is then recorded as decided (fish or zsh) and this ADR is amended or superseded.

## Context (verified in the repository)
- `docs/guides/shell-setup.md` names fish the primary interactive shell; zsh and bash configs are still shipped.
- `home/dot_bashrc.tmpl` execs into fish for interactive terminals when fish is on PATH, unless `NO_FISH=1` is set; otherwise bash config is the fallback.
- On NixOS, `ops/system-setup.sh` writes `programs.fish.enable = true;` and `users.users."<user>".shell = pkgs.fish;` into the generated module (unless `/etc/nixos/configuration.nix` already assigns `programs.fish.enable`). On NixOS-WSL the login shell is `/nix/store/<hash>-wrapped-fish/wrapper` (handled by `detect_shell` in `ops/unix/ssh-agent-setup.sh`, tested in `tests/bash/ssh-agent-setup.bats`; readiness's `*fish*` match accepts it).
- Scope: NixOS gets a fish login shell; other Linux/WSL with a bash login: bash execs fish; macOS: the repo leaves the login shell unchanged (zsh).
- zsh config is `home/dot_zshrc.tmpl`. Oh My Zsh is optional: the repo does not install it and the template sources it only if present. zsh-autosuggestions and zsh-syntax-highlighting come from Nix (`nix/modules/home/shell-packages.nix`) and are sourced by the template (on macOS the template sources zsh-syntax-highlighting from Homebrew).
- Starship, zoxide, fzf and Atuin are initialised in both `home/dot_config/fish/config.fish.tmpl` and `home/dot_zshrc.tmpl`; the Starship config is shared.
- `ops/readiness.sh` (NixOS block) reports "login shell is fish" when the account's shell contains `fish`; otherwise it notes the shell and points to `sudo sys-setup --apply`.
- Tests that assume fish: `tests/bash/fish-completion.bats`, `fish-ctrl-c.bats`, `wsl-open.bats` (fish block), the fish cases in `shell-os-parity.bats`, `ws-shell-parity.bats` (skips if fish is absent), and fish/zsh cases in `ssh-agent-setup.bats` and `ssh-agent-loader.bats`. zsh is covered by the zsh cases in `shell-os-parity.bats` (skip if zsh is unavailable), `cli-abbr.bats` (fish/zsh abbreviations must match) and the zsh side of `ws-shell-parity.bats`.
- Known zsh gap: zsh does not set `BROWSER=wsl-open` or define `open` on WSL2; fish does. Tracked as open ticket `docs/work/active/T-0036-wsl-open-zsh-bash/ticket.md`.

## Options and comparison
Scores are estimates from an external AI-assisted review supplied by the owner. No benchmarks were run and they are not measurements.

| Lens (0-100, estimate) | zsh | fish |
|------------------------|-----|------|
| General developer use (POSIX-compatible scripting, ecosystem, portability) | about 72 | about 53 |
| Fit to this repository (fish already primary, built-in autosuggestions and highlighting, existing fish tests and config) | about 50 | about 82 |

The same review's 6-shell ranking put zsh 78, fish 67, bash 63, Nushell 46, Xonsh 39, Elvish 39 (estimates).

## Why
- It is already the primary shell, so the trial costs no migration and the repo's tests and docs already assume it.
- fish has autosuggestions and syntax highlighting built in; zsh gets them from two Nix-installed plugins (`nix/modules/home/shell-packages.nix`) sourced by `home/dot_zshrc.tmpl` (on macOS the template sources zsh-syntax-highlighting from Homebrew), with Oh My Zsh optional.
- Its weakness (non-POSIX syntax) is the thing the trial should measure. Scripts stay bash; only interactive use is fish.

## Strong alternatives
| Option | Why it is second |
|--------|------------------|
| zsh | Higher general-use estimate and POSIX-closer; fish is already primary and better fitted to this repo's existing config and tests. Stays supported and is the rollback target. |

## Discarded
bash as the primary interactive shell (kept as fallback only); Nushell, Xonsh and Elvish (not POSIX-compatible, no support in this repo, lowest estimates).

## Consequences
- Two interactive configs to keep in step; the parity tests are the guard, and T-0036 is the known open gap.
- Tools whose shell integration targets bash/zsh only need a fish equivalent or `NO_FISH=1 bash`.
- Nothing here removes zsh. No file, test or package changes with this ADR.

## Rollback
- Non-NixOS: `chsh -s <zsh>` (the path must be in /etc/shells).
- NixOS: not a config-only switch. It needs a change to `ops/system-setup.sh` (the fish lines it writes, and the `have_fish` check that skips regenerating its module on hosts that already ran sys-setup); the exact procedure is not verified yet.
- `home/dot_zshrc.tmpl` already exists. Mark this ADR superseded.

## Verification
- Existing shell suites stay green: `fish-completion`, `fish-ctrl-c`, `shell-os-parity`, `ws-shell-parity`, `wsl-open`, `cli-abbr`.
- On NixOS a fresh install has a fish login shell (`sys-readiness` reports it); on other Linux/WSL, bash execs fish; on macOS the login shell stays zsh. The Starship prompt and Atuin history work in fish. Not yet checked on a fresh machine: `unknown`.
