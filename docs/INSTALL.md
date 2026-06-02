# Install & maintenance guide

One place for: **install once unattended**, **keep it updated**, and **clean
up safely**. Targets macOS / Linux desktop / Linux CLI / WSL2, with explicit
NixOS handling.

- Stack & ownership: `docs/architecture/tool-ownership.md`
- App inventory (per OS): `docs/app-list.md`
- NixOS specifics & failure modes: `docs/install-nixos.md`
- Cold-start runbook (manual, step-by-step): `docs/bootstrap.md`

## 0. "Am I all set?" — check in one command

```bash
sys-readiness        # or: bash scripts/readiness.sh   or: mise run readiness
```

It verifies core tooling, all apps/CLI, dotfiles, git aliases, health checks,
and the NixOS system layer. The system-layer check reads the **live activated
system** (your actual login shell, `nix show-config` trusted-users, and the
`nix-gc`/`nix-optimise` systemd timers) — not a specific config file — so it is
accurate no matter whether settings live in `configuration.nix` or in the
`app-configs-extra.nix` module that `sys-setup` writes. Verdict + exit code:

- **`ALL SET`** (exit 0) — **you are fully set up; nothing else to run.**
- **`User environment READY, system rebuild pending`** (exit 2) — apps +
  dotfiles done; the NixOS system layer (fish login shell, trusted-users, GC
  timer) is not active yet. Run **`sudo sys-setup --apply`** (below).
- **`NOT READY`** (exit 1) — a required tool/file is missing; run `sys-install`.

You are **done** exactly when `sys-readiness` prints `ALL SET` and exits 0.

### Do I need `nixos-rebuild switch`?

Yes, **once**, only for the NixOS **system** layer (fish as login shell,
trusted-users, declarative GC) — Home Manager cannot set these. Everything else
(every app, CLI tool, dotfile) is already applied by `sys-install`/`sys-update`
without sudo. Automate the system step:

```bash
sudo sys-setup --apply      # or: sudo bash scripts/system-setup.sh --apply
```

This idempotently writes `/etc/nixos/app-configs-extra.nix` (backing up your
config first), imports it, and runs `nixos-rebuild switch --flake /etc/nixos#nixos`.
Preview first without sudo: `sys-setup` (report only). After it finishes, open a
**new terminal** (you'll land in fish); reboot only if a kernel/driver changed.
Details: `docs/nixos-rebuild.md`.

### The complete "I'm set" sequence on a fresh machine

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles
bash scripts/install.sh            # 1. apps + CLI + dotfiles (unattended, no sudo)
sudo bash scripts/system-setup.sh --apply   # 2. system layer + nixos-rebuild (once)
exec fish                          # 3. (or open a new terminal)
sys-readiness                      # 4. confirm: should print ALL SET
```

Notes:
- Every step is **idempotent** — safe to re-run; it only changes what's not
  already in the desired state.
- After step 2 succeeds you'll see `nix-gc.timer` / `nix-optimise.timer`
  started and the `auto-optimise-store` warnings disappear (trusted-users took
  effect). That is expected and means the system layer is active.
- When step 4 prints `ALL SET`, **nothing else is needed.** Day-to-day you only
  run `sys-update` (keep current) and `sys-cleanup` (reclaim disk).
- A reboot is **not** required for this stack; it only matters if a later
  change touches the kernel, drivers, or bootloader.

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

### What the next install looks like (timeline)

On a **fresh machine**, one command does it all and you can walk away:

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles && bash scripts/install.sh
```

Expected wall-clock time (most of it is unattended download from the binary
cache — the closure is ~7.7 GiB / ~300 binaries):

| Phase | What happens | Typical time |
| --- | --- | --- |
| Nix present (NixOS) or install (other) | skipped on NixOS; ~2–4 min via Determinate elsewhere | 0–4 min |
| Base tools (`nix profile install`) | chezmoi/mise/home-manager/lefthook | 1–3 min |
| `nix flake check` | evaluate the flake | 10–60 s |
| `chezmoi apply` | snapshot + write ~37 dotfiles | < 30 s |
| `home-manager switch` | **fetch ~7.7 GiB closure from cache.nixos.org** + activate | **10–30 min** (network-bound) |
| `mise install` | no-op on NixOS (runtimes from Nix) | < 10 s |
| `lefthook` + ssh-agent + `doctor` | hooks + health check | < 30 s |
| **Total (warm cache, good network)** | | **~15–35 min, unattended** |

A **re-run on the same machine** (warm `/nix/store`) is mostly cache hits and
finishes in **1–3 minutes**.

### Is it truly "one click, walk away"?

Yes for the **user environment** — `scripts/install.sh` needs no prompts and no
`sudo`. The **only** manual step that needs you is the optional **system**
rebuild (fish login shell, GC timer, trusted-users), because it requires `sudo`
and edits `/etc/nixos`. The installer **detects** whether that is needed and
prints the exact `sudo nixos-rebuild switch --flake /etc/nixos#nixos` command at
the end. See `docs/nixos-rebuild.md`.

### Complete-the-build steps (run after install on NixOS)

1. `bash scripts/install.sh` — finishes the user environment (no sudo). ✅ done.
2. **(recommended)** add the snippet from `docs/nixos-rebuild.md` to
   `/etc/nixos/configuration.nix`, then:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#nixos     # or: nh os switch /etc/nixos
   ```
3. **Reboot only if** a kernel/driver/bootloader changed; otherwise just open a
   new terminal (you'll land in fish).
4. **Confirm readiness:**
   ```bash
   nixos-rebuild list-generations | head     # new generation is Current
   systemctl --failed ; systemctl --user --failed
   bash scripts/doctor.sh ; chezmoi verify
   ```

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

## Short commands (installed to PATH + fish)

After install, these are on `PATH` (`~/.local/bin`) and as fish functions, so
you can run them from any directory / any shell. They manage **installed
applications + CLI tools + dotfiles**, not just dotfiles:

| Command (PATH) | fish function | Does |
| --- | --- | --- |
| `sys-update` | `sys-update` | Update all apps/CLI + config (brewup equivalent) + safe cleanup |
| `sys-cleanup` | `sys-cleanup` | De-dup Nix store + prune caches (keeps all rollbacks) |
| `sys-cleanup --gc` | `sys-cleanup-gc` | + remove aged generations (keeps recent) |
| `sys-install` | `sys-install` | Re-run the unattended full install |
| — | `sys-doctor` / `syscd` | Health check / cd into the repo |

## Quick reference

| Goal | Command |
| --- | --- |
| Install everything, unattended | `sys-install` · `mise run install` · `bash scripts/install.sh` |
| Preview install | `DRY_RUN=1 bash scripts/install.sh` |
| Update everything (brewup) | `sys-update` · `mise run update:apply` |
| Safe cleanup (keep rollbacks) | `sys-cleanup` · `mise run cleanup:apply` |
| Reclaim aged generations | `sys-cleanup --gc` · `mise run cleanup:gc` |
| Format / lint Nix | `mise run nix:fmt` · `mise run nix:lint` |
| Health check | `sys-doctor` · `mise run repo:check` |
| Make fish the login shell (NixOS) | see `docs/install-nixos.md` |
