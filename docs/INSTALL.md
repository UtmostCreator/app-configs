# Install & maintenance guide

One place for: **install once unattended**, **keep it updated**, and **clean
up safely**. Targets macOS / Linux desktop / Linux CLI / WSL2, with explicit
NixOS handling.

- Stack & ownership: `docs/architecture/tool-ownership.md`
- App inventory (per OS): `docs/app-list.md`
- NixOS specifics & failure modes: `docs/install-nixos.md`
- Cold-start runbook (manual, step-by-step): `docs/bootstrap.md`

## 1. Install — one command, walk away

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles
bash scripts/install.sh
```

`scripts/install.sh` is **fully unattended and idempotent**:

- Detects the host; on **NixOS** it uses the system Nix and **skips** the
  Determinate Systems installer (which would conflict).
- Installs base tools (`chezmoi`, `mise`, `home-manager`, `lefthook`) only if
  missing.
- Validates the flake, **snapshots `$HOME`**, then `chezmoi apply --force`.
- Runs `home-manager switch` (or `darwin-rebuild switch` on macOS).
- Runs `mise install`, `lefthook install`, the ssh-agent helper, and
  `doctor.sh` (must pass).
- Seeds `home/.chezmoidata/personal.yaml` from the example if absent (edit it
  afterwards for real name/email/host profile).

Preview without mutating anything:

```bash
DRY_RUN=1 bash scripts/install.sh
HOST_PROFILE=linux-cli bash scripts/install.sh   # pin a profile
```

Equivalent mise task:

```bash
mise run install
```

> Difference vs `scripts/bootstrap.sh`: bootstrap defaults to a dry-run and
> prompts before applying. `install.sh` is the non-interactive, NixOS-aware
> "set and forget" path.

## 2. Keep it updated — the `brewup` equivalent

On macOS you ran a `brewup` function (update + upgrade + cleanup). The
cross-platform equivalent here:

```bash
mise run update            # report only: shows the full plan, mutates nothing
mise run update:apply      # apply unattended (brewup equivalent)
```

`scripts/update-all.sh` runs, in order:

1. `git pull --ff-only` (only if the worktree is clean)
2. `nix flake update ./nix` then `nix flake check ./nix`
3. `chezmoi apply --force` (snapshots `$HOME` first)
4. `home-manager switch` / `darwin-rebuild switch`
5. `nix profile upgrade --all` (base tools)
6. `mise upgrade`
7. `lefthook install`
8. safe cleanup (step 3 below) unless `NO_CLEANUP=1`

```bash
bash scripts/update-all.sh --apply          # one confirmation prompt
bash scripts/update-all.sh --apply --yes     # no prompt (cron/unattended)
NO_CLEANUP=1 bash scripts/update-all.sh --apply
```

## 3. Clean up safely (non-destructive by default)

`scripts/cleanup.sh` reclaims disk **without destroying rollbacks**.

```bash
mise run cleanup           # report only (shows store size + generation count)
mise run cleanup:apply     # SAFE tier: store optimise + cache prune; keeps ALL generations
mise run cleanup:gc        # SAFE + remove generations older than KEEP_DAYS (default 14d)
```

- **SAFE tier** (`--apply`): `nix store optimise` (hard-links identical files —
  never deletes references), `mise cache clear`, `npm cache verify`. Verified
  to free multiple GiB while keeping every Home Manager generation.
- **AGED tier** (`--apply --gc`): `home-manager expire-generations` +
  `nix-collect-garbage --delete-older-than ${KEEP_DAYS}d`. This removes only
  generations **older than** the window, so recent rollbacks survive.

```bash
KEEP_DAYS=30 bash scripts/cleanup.sh --apply --gc
```

This script **never** runs `nix-collect-garbage -d` (delete all old
generations) — that would wipe every rollback point. Run that yourself only if
you are certain.

### Declarative GC (already configured)

`nix/modules/common/nix-settings.nix` declares scheduled GC
(`nix.gc.automatic`, weekly, `--delete-older-than 7d`) and
`auto-optimise-store`. On a **standalone Home Manager install on NixOS**, the
system-wide GC timer is owned by the system config, not HM; `scripts/cleanup.sh`
gives you an explicit, on-demand path regardless. To run GC declaratively at
the system level on NixOS, add to `/etc/nixos/configuration.nix`:

```nix
nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
nix.optimise.automatic = true;
nix.settings.trusted-users = [ "root" "utmostcreator" ];  # silences the
                                                          # auto-optimise warning
```

then `sudo nixos-rebuild switch`.

## 4. Verify

```bash
mise run repo:check        # git diff --check + doctor + validate + flake check
bash scripts/doctor.sh
chezmoi verify             # all managed dotfiles match (exit 0)
```

## 5. Maintaining the Nix config (best practices)

This repo ships a small Nix maintenance toolchain (in
`nix/modules/home/dev.nix`):

```bash
mise run nix:fmt           # nixfmt (RFC 166 style) — format all .nix files
mise run nix:lint          # statix + deadnix + nixfmt --check (advisory)
nix-locate <file>          # which package provides a missing command/file
nh os switch ./nix         # friendlier home-manager/nixos-rebuild + GC wrapper
```

Discipline that keeps the config maintainable (per Nix community guidance):

- Keep `flake.lock` committed; update it deliberately via `mise run update`.
- Keep modules small and split by concern (`modules/home/{cli,dev,gui,shell}`,
  `modules/common`, `modules/darwin`); avoid one giant file.
- System packages → `configuration.nix` (system); user packages/dotfiles →
  Home Manager; project runtimes → flake dev shells / mise.
- Prefer the **stable** nixpkgs channel for the OS; pull specific newer
  packages via an overlay/input rather than moving everything to unstable.
- Learn rollback before you need it: `home-manager generations`,
  `sudo nixos-rebuild switch --rollback`.

## 6. Uninstall / handoff

```bash
bash scripts/uninstall.sh             # report only (safe any time)
bash scripts/uninstall.sh --apply     # actually run
```

Never removes Nix itself and never deletes snapshots under
`~/.local/state/dotfiles-snapshots/`.

## Quick reference

| Goal | Command |
| --- | --- |
| Install everything, unattended | `mise run install` (or `bash scripts/install.sh`) |
| Preview install | `DRY_RUN=1 bash scripts/install.sh` |
| Update everything (brewup) | `mise run update:apply` |
| Safe cleanup (keep rollbacks) | `mise run cleanup:apply` |
| Reclaim aged generations | `mise run cleanup:gc` |
| Format / lint Nix | `mise run nix:fmt` · `mise run nix:lint` |
| Health check | `mise run repo:check` |
| Make fish the login shell (NixOS) | see `docs/install-nixos.md` |
