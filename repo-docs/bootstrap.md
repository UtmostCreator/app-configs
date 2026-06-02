# Bootstrap

Cold-start procedure for the chezmoi + mise + Nix/Home Manager + nix-darwin
+ Lefthook stack.

> **Prefer the automated path.** `bash scripts/install.sh` (alias `sys-install`)
> is the fully-unattended, NixOS-aware installer; `repo-docs/INSTALL.md` is the
> canonical install + maintenance guide (with the `sys-readiness` /
> `sys-update` / `sys-cleanup` / `sys-setup` commands). This file documents the
> lower-level `bootstrap.sh` flow it builds on. On NixOS also read
> `repo-docs/install-nixos.md` and `repo-docs/nixos-rebuild.md`.

See `repo-docs/architecture/tool-ownership.md` for why each tool owns what.

## Supported targets

- macOS (Apple Silicon by default; Intel via `nix/vars/default.nix`)
- Linux desktop
- Linux CLI / headless
- WSL2 (best-effort, Linux-flavoured CLI/dev only)

Windows native is explicitly not supported.

## Cold start (any target)

```bash
git clone <your-fork-of-this-repo> ~/dotfiles && cd ~/dotfiles

# 1. Create your private identity file (gitignored)
cp home/personal.yaml.example home/.chezmoidata/personal.yaml
$EDITOR home/.chezmoidata/personal.yaml   # name, email, signingKey, hostProfile, gui

# 2. Preview what bootstrap would do (no mutations)
bash scripts/bootstrap.sh                 # equivalent to: --dry-run

# 3. Actually apply, after reviewing the preview
bash scripts/bootstrap.sh --yes
```

`--yes` is required to mutate. `CI=true` allows non-interactive apply on
runners.

## Per-host override

`scripts/detect-host.sh` returns one of `macos`, `linux-desktop`,
`linux-cli`, `wsl`. Override the linux fallback or pin a host:

```bash
HOST_PROFILE=linux-cli bash scripts/bootstrap.sh
HOST_PROFILE_DEFAULT=linux-cli bash scripts/bootstrap.sh
HOST_PROFILE=wsl bash scripts/bootstrap.sh
```

## After bootstrap (day-to-day)

```bash
# Preview pending changes
mise run sync               # alias for sync:dry-run

# Apply (interactive confirm; snapshots $HOME first)
mise run sync:apply

# Apply chezmoi-only (no Nix/mise/lefthook side effects)
mise run apply
```

Snapshots live under `~/.local/state/dotfiles-snapshots/<UTC-timestamp>/`.
Restore from one with `cp -a <snapshot>/. ~/`.

## WSL2 caveats

- **Windows VS Code (Remote-WSL)** reads settings from the Windows side.
  This repo does not manage Windows-side VS Code settings.
- **Windows SSH agent bridge**: set up `wsl2-ssh-agent` manually if you
  want Windows-side keys. Out of scope.
- **Windows Terminal config**: out of scope. Manage on the Windows side
  if you use it.
- **Windows package managers**: out of scope. Do not run them from inside
  WSL.
- **Clipboard**: use `clip.exe` from the shell or rely on terminal
  integration. No automation here.
- **Filesystem performance**: keep repos under `~/`, not `/mnt/c/`.
- **WSL detection**: `scripts/detect-host.sh` checks `/proc/version` for
  `microsoft|wsl`. Override with `HOST_PROFILE=wsl` if detection fails.

## Linux-cli / headless notes

- `hostProfile: linux-cli` in `personal.yaml` plus `gui: false` excludes
  ghostty, karabiner, and Linux-desktop GUI bits.
- Phase 6 `nix/hosts/linux-cli/home.nix` skips the GUI module.

## macOS notes

- Edit `nix/vars/default.nix` if your Mac is Intel (`x86_64-darwin`).
- nix-darwin owns system defaults (`darwin-rebuild switch --flake ./nix#macos`).
- macOS GUI apps come from `nix/modules/darwin/homebrew.nix` via the
  Homebrew cask bridge — never `home.packages`.

## Secrets handling

`home/.chezmoidata/personal.yaml` is gitignored and must never be
committed. Lefthook `pre-commit` blocks accidental commits of it. The
example file `home/personal.yaml.example` documents the required keys
with fake values. The example lives **outside** `home/.chezmoidata/`
on purpose — chezmoi autoloads every `*.yaml|*.toml|*.json` inside the
data dir and would fail to parse the `.example` suffix.

For real per-host secrets (SSH keys, API tokens), pick one of chezmoi's
secret backends (age, 1Password, Bitwarden) and add it as a separate
reviewed slice. Until then, do not bolt on a secrets layer.

## Dependency updates

```bash
# Refresh Nix inputs (typically quarterly)
nix flake update ./nix
nix flake check ./nix

# Preview
mise run sync

# Apply
mise run sync:apply
```

`mise outdated` lists tool-version drift; bump with `mise upgrade <tool>`.

## Uninstall / handoff

```bash
bash scripts/uninstall.sh             # report only
bash scripts/uninstall.sh --apply     # actually run
```

The report mode is safe to run any time and shows what would happen.
Nix itself is not removed; use the official Nix uninstaller for that.

## Verification

After bootstrap completes:

```bash
bash scripts/doctor.sh
bash scripts/validate-config.sh
mise run repo:check
```

If anything is missing or red, re-read `scripts/bootstrap.sh` output for
the failed step, fix the host issue, and re-run.
