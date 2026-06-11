# Install & maintenance guide

One place for: **install once unattended**, **keep it updated**, and **clean
up safely**. Targets macOS / Linux desktop / Linux CLI / WSL2, with explicit
NixOS handling.

- Stack & ownership: `repo-docs/architecture/tool-ownership.md`
- App inventory (per OS): `repo-docs/app-list.md`
- NixOS specifics & failure modes: `repo-docs/install-nixos.md`
- Cold-start runbook (manual, step-by-step): `repo-docs/bootstrap.md`

## 0. "Am I all set?" — check in one command

```bash
sys-readiness        # or: bash ops/readiness.sh   or: mise run readiness
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
  timer, Europe/London time zone) is not active yet. Run
  **`sudo sys-setup --apply`** (below).
- **`NOT READY`** (exit 1) — a required tool/file is missing; run `sys-install`.

You are **done** exactly when `sys-readiness` prints `ALL SET` and exits 0.

### Do I need `nixos-rebuild switch`?

Yes, **once**, only for the NixOS **system** layer (fish as login shell,
trusted-users, declarative GC, Europe/London time zone) — Home Manager cannot set these. Everything else
(every app, CLI tool, dotfile) is already applied by `sys-install`/`sys-update`
without sudo. Automate the system step:

```bash
sudo sys-setup --apply      # or: sudo bash ops/system-setup.sh --apply
```

This idempotently writes `/etc/nixos/app-configs-extra.nix` (backing up your
config first), imports it, and runs `nixos-rebuild switch --flake /etc/nixos#nixos`.
It writes `time.timeZone = lib.mkForce "Europe/London";` so the shipped default
wins over the stock installer line in `/etc/nixos/configuration.nix` without
hand-editing that file.
Preview first without sudo: `sys-setup` (report only). After it finishes, open a
**new terminal** (you'll land in fish); reboot only if a kernel/driver changed.
Details: `repo-docs/nixos-rebuild.md`.

### The complete "I'm set" sequence on a fresh machine

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles
bash ops/install.sh            # 1. apps + CLI + dotfiles (unattended, no sudo)
sudo bash ops/system-setup.sh --apply   # 2. system layer + nixos-rebuild (once)
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
bash ops/install.sh
```

`ops/install.sh` is **fully unattended and idempotent**:

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
DRY_RUN=1 bash ops/install.sh
HOST_PROFILE=linux-cli bash ops/install.sh   # pin a profile
```

Equivalent mise task:

```bash
mise run install
```

> Difference vs `ops/bootstrap.sh`: bootstrap defaults to a dry-run and
> prompts before applying. `install.sh` is the non-interactive, NixOS-aware
> "set and forget" path.

### What the next install looks like (timeline)

On a **fresh machine**, one command does it all and you can walk away:

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles && bash ops/install.sh
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

Yes for the **user environment** — `ops/install.sh` needs no prompts and no
`sudo`. The **only** manual step that needs you is the optional **system**
rebuild (fish login shell, GC timer, trusted-users, Europe/London time zone), because it requires `sudo`
and edits `/etc/nixos`. The installer **detects** whether that is needed and
prints the exact `sudo nixos-rebuild switch --flake /etc/nixos#nixos` command at
the end. See `repo-docs/nixos-rebuild.md`.

### Complete-the-build steps (run after install on NixOS)

1. `bash ops/install.sh` — finishes the user environment (no sudo). ✅ done.
2. **(recommended)** add the snippet from `repo-docs/nixos-rebuild.md` to
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
   bash ops/doctor.sh ; chezmoi verify
   ```

## 2. Keep it updated — the `brewup` equivalent

On macOS you ran a `brewup` function (update + upgrade + cleanup). The
cross-platform equivalent here:

```bash
mise run update            # report only: shows the full plan, mutates nothing
mise run update:apply      # apply unattended (brewup equivalent)
```

`ops/update-all.sh` runs, in order:

1. `git pull --ff-only` (only if the worktree is clean)
2. `nix flake update ./nix` then `nix flake check ./nix`
3. `chezmoi apply --force` (snapshots `$HOME` first)
4. `home-manager switch` / `darwin-rebuild switch`
5. `nix profile upgrade --all` (base tools)
6. `mise upgrade`
7. `lefthook install`
8. safe cleanup (step 3 below) unless `NO_CLEANUP=1`

```bash
bash ops/update-all.sh --apply          # one confirmation prompt
bash ops/update-all.sh --apply --yes     # no prompt (cron/unattended)
NO_CLEANUP=1 bash ops/update-all.sh --apply
```

## 3. Clean up safely (non-destructive by default)

`ops/cleanup.sh` reclaims disk **without destroying rollbacks**.

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
KEEP_DAYS=30 bash ops/cleanup.sh --apply --gc
```

This script **never** runs `nix-collect-garbage -d` (delete all old
generations) — that would wipe every rollback point. Run that yourself only if
you are certain.

### Declarative GC (already configured)

`nix/modules/common/nix-settings.nix` declares scheduled GC
(`nix.gc.automatic`, weekly, `--delete-older-than 7d`) and
`auto-optimise-store`. On a **standalone Home Manager install on NixOS**, the
system-wide GC timer is owned by the system config, not HM; `ops/cleanup.sh`
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
bash ops/doctor.sh
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
bash ops/uninstall.sh             # report only (safe any time)
bash ops/uninstall.sh --apply     # actually run
```

Never removes Nix itself and never deletes snapshots under
`~/.local/state/dotfiles-snapshots/`.

## Short commands (installed to PATH + fish)

After install, these are on `PATH` (`~/.local/bin`) and as fish functions, so
you can run them from any directory / any shell. They manage **installed
applications + CLI tools + dotfiles**, not just dotfiles:

| Command (PATH) | fish function | Does |
| --- | --- | --- |
| `sys-install` | `sys-install` | Re-run the unattended full install (Nix base + all apps/CLI via home-manager + dotfiles + git hooks). Runs `home-manager switch`, so it APPLIES user-layer config like keybindings/layouts. |
| `sys-update` | `sys-update` | Update all apps/CLI + config (brewup equivalent) + safe cleanup. Also runs `home-manager switch`, so it APPLIES user-layer config changes. |
| `sys-cleanup` | `sys-cleanup` | De-dup Nix store + prune caches (keeps all rollbacks) |
| `sys-cleanup --gc` | `sys-cleanup-gc` | + remove aged generations (keeps recent) |
| `sudo sys-setup --apply` | — | Apply the NixOS SYSTEM layer Home Manager cannot: fish login shell, trusted-users, declarative GC, timezone, then `nixos-rebuild switch`. Run WITHOUT `--apply` (no sudo) for a report-only preview. Does NOT touch user-layer config. |
| — | `sys-doctor` / `syscd` | Health check / cd into the repo |
| — | `sys-readiness` | Report whether the system layer is active (login shell, trusted-users, GC timers) |

### Which command applies what (important)

- **User layer** (keybindings, keyboard layouts, GNOME extensions, app packages,
  dotfiles): owned by **Home Manager + chezmoi**. Applied by **`sys-install`** or
  **`sys-update`** (both run `home-manager switch` + `chezmoi apply`). A change to a
  `nix/modules/home/*.nix` file is NOT live until one of these runs.
- **System layer** (fish as login shell, `nix.settings.trusted-users`, GC timers,
  timezone): owned by **`sudo sys-setup --apply`** (`nixos-rebuild`). This is a
  separate, root-only layer and does NOT apply user-layer keybinding/layout changes.

### Preferred order

First-time or after pulling repo changes:

```
sys-install                 # or: sys-update   (applies user layer: apps, dotfiles, keybindings, layout)
sudo sys-setup --apply      # only if the system layer changed (login shell / trusted-users / GC / timezone)
sys-cleanup                 # optional: reclaim disk, keeps all rollbacks
```

Routine maintenance (the usual loop):

```
sys-update                  # update + apply everything in the user layer, then safe cleanup
sys-cleanup --gc            # occasional deeper reclaim (removes aged generations, keeps recent)
```

Notes:

- `sys-setup` is only needed when the **system layer** changed. Day-to-day app/dotfile/keybinding
  work needs only `sys-install` / `sys-update`.
- `sys-update` already runs a safe cleanup at the end, so a separate `sys-cleanup` is only for
  extra disk reclaim.
- After a change that adds/enables a **GNOME extension** or changes the **keyboard layout**, log
  out and back in (GNOME Shell on Wayland cannot hot-reload extensions or fully reset input-source
  runtime state).

## Quick reference

| Goal | Command |
| --- | --- |
| Install everything, unattended | `sys-install` · `mise run install` · `bash ops/install.sh` |
| Preview install | `DRY_RUN=1 bash ops/install.sh` |
| Update everything (brewup) | `sys-update` · `mise run update:apply` |
| Safe cleanup (keep rollbacks) | `sys-cleanup` · `mise run cleanup:apply` |
| Reclaim aged generations | `sys-cleanup --gc` · `mise run cleanup:gc` |
| Format / lint Nix | `mise run nix:fmt` · `mise run nix:lint` |
| Health check | `sys-doctor` · `mise run repo:check` |
| Make fish the login shell (NixOS) | see `repo-docs/install-nixos.md` |
