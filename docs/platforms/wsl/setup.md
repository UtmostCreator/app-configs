# WSL2 setup

NixOS-WSL is the default distro (ADR-0001, ADR-0015), installed by the Windows bootstrap (see [`../windows/setup.md`](../windows/setup.md), T-0047). Ubuntu is the supported alternative (section "Alternative: Ubuntu").

Runbook for the path verified on a real PC (2026-11-16): NixOS-WSL on Windows 11, set up by `ops/windows/bootstrap.ps1`.

- Distro choice: [ADR-0015](../../architecture/decisions/0015-wsl-distro-selection-nixos-or-ubuntu.md) (NixOS-WSL by default, Ubuntu supported; one `wsl` profile).
- Run output and success criteria: [`expected-results.md`](expected-results.md).
- Edition, where to run Claude, Docker, reboots, restore points: [`windows-and-wsl.md`](windows-and-wsl.md).
- Evidence: [`final-run-2026-11-16.md`](../../work/active/T-0047-nixos-wsl/evidence/final-run-2026-11-16.md).
- Issues met during the setup, with status and owner: [`findings.md`](../../work/active/T-0047-nixos-wsl/findings.md).

Profile `wsl`: the shared CLI and dev modules (`nix/modules/common`, `nix/modules/home`); no GUI module, no Windows-side management. macOS and WSL share one `flake.lock` (same tool versions once both pull the same commit). Home Manager output: `wsl-nixos` on NixOS-WSL (`ops/detect-host.sh --hm-attr`), `wsl` on Ubuntu.

## Before you start

- Windows 11, Git for Windows and winget. winget stays manual; the bootstrap installs chezmoi, gitleaks, and lefthook (user scope).
- Keep the repo and projects on the Linux filesystem (`~/...`), not under `/mnt/c`. Git, Nix and package managers are many times slower across the Windows drive bridge.
- An SSH key on GitHub. The managed gitconfig sends `https://github.com/` Git URLs over SSH.

## 1. Windows prerequisites

1. Elevated PowerShell, once: `Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent`. The only other elevated step is the first bootstrap run on a fresh machine (step 3).
2. Normal PowerShell, interactive: `ssh-add $HOME\.ssh\id_ed25519`. Then `ssh -T git@github.com` should greet you by your GitHub user name without a prompt.
3. WSL itself (WSL 3.0.5 plus VirtualMachinePlatform) is installed by the first, elevated bootstrap run, which ends with a reboot. See runs 1 and 2 in [`expected-results.md`](expected-results.md).

## 2. Bootstrap (normal PowerShell, NOT elevated)

```powershell
git pull --ff-only    # in the Windows clone of app-configs
powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1
```

- Dry run first; it should exit 0.
- The real run imports NixOS-WSL (the distro named `NixOS`; NixOS-WSL 2605.7.2 on the verified PC), re-clones the repo inside WSL at step 6, runs system setup (`ops/system-setup.sh --apply`) and the install, then prints "Install complete (host=wsl, mode=apply)" and exits 0.
- Snapshots: inside WSL under /var/lib/app-configs/host-snapshots/, on Windows under `%LOCALAPPDATA%\app-configs\host-snapshots\`.
- Step C installs the git hooks on Windows (into .git/app-configs-hooks, `core.hooksPath`) and runs `install-git-hooks.sh --check`, which needs 8f6b4eb or later (before it: "_lefthook.sh is not executable" on NTFS). It does not block the WSL steps.
- Re-runs skip finished steps. If an older WSL clone exists, move it aside first (for example to `~/app-configs.old-<timestamp>`) and copy its `home/.chezmoidata/personal.yaml` over with mode 600.

## 3. Personal data

The first install seeds `home/.chezmoidata/personal.yaml` with `hostProfile: wsl` and `gui: false`. Fill in your git name and email there, then run `chezmoi --source="$HOME/app-configs" apply` (on WSL always pass --source: `chezmoi init --source` does not persist the source dir). The file is not committed; never paste its contents into issues or logs.

## 4. Verify (inside WSL)

```bash
id utmostcreator                          # the user from nix/vars/default.nix
bash ops/detect-host.sh                   # wsl
bash ops/detect-host.sh --hm-attr         # wsl-nixos
systemctl --failed                        # no failed units
bash ops/doctor.sh                        # exit 0 (a missing `code` is only a warning)
bash ops/install-git-hooks.sh --check     # exit 0 in WSL
sys-readiness                             # includes the WSL2 section from ops/wsl-check.sh
```

`sys-readiness` is a fish function wrapping `bash $DOTFILES_DIR/ops/readiness.sh`. From bash (for example `wsl -d NixOS --exec bash -lc '...'`) use `bash ~/app-configs/ops/readiness.sh` or `fish -c sys-readiness`.

Seen on the verified PC (full table: [evidence](../../work/active/T-0047-nixos-wsl/evidence/final-run-2026-11-16.md)): doctor exit 0; sys-readiness exit 0 (43 OK, 2 TODO: chezmoi pending, no Docker daemon); selection diff IN SYNC; Europe/London; clone clean at the pulled commit. On Windows, `install-git-hooks.sh --check` from Git Bash exits 0 with 8f6b4eb; a real test commit from the Windows clone is still to do.

Known false positive: on WSL the readiness TODO "chezmoi pending" appears because no chezmoi source dir is persisted. Fixed on origin/main (ca3b67b, 70bb32b); a clone from before them still shows it. Check with `chezmoi --source="$HOME/app-configs" verify`.

Known issue (clones from before d03a095): the user unit codebase-memory-mcp-ui restart-loops on a fresh WSL home ("daemon session context was rejected") until `~/Projects` exists (section 5). d03a095 (on origin/main) makes the unit create the directory (T-0047 open item (c)); it applies after a pull plus a Home Manager switch. On WSL, run `sys-install` (`bash ~/app-configs/ops/install.sh`) or re-run `ops/windows/bootstrap.ps1`, which runs it in step 12. Note: install.sh snapshots `$HOME`, then runs `chezmoi apply --force`, so it overwrites hand edits to managed files.

Known issue (clones from before adedbb2): `sys-update --apply`, `ops/audit.sh` and `ops/bootstrap.sh` called chezmoi without `--source`, so on WSL they could not apply dotfiles and the whole apply stopped, including the Home Manager switch. origin/main now passes `--source` automatically in sys-update, readiness, audit and bootstrap (adedbb2, 5617787, 70bb32b); not re-run on WSL: unknown. Plain `chezmoi` commands still need it on WSL: `chezmoi --source="$HOME/app-configs" apply` for dotfiles; `sys-install` for a Home Manager switch.


Known issue: interactive fish prints an ssh-agent.fish error until you pull origin/main (9e6cb03 or later) and run `chezmoi --source="$HOME/app-configs" apply`.

## 5. After the bootstrap: WSL git over SSH and ~/Projects

Run wsl commands from PowerShell as `wsl -d NixOS --exec bash -lc '...'`: the default login shell is fish and it rejects `$?`.

1. WSL has no SSH key of its own; your key is in the Windows ssh-agent (section 1). Point the repo's git at the Windows ssh.exe:
   ```powershell
   wsl -d NixOS --exec bash -lc 'git -C ~/app-configs config --local core.sshCommand /mnt/c/Windows/System32/OpenSSH/ssh.exe'
   wsl -d NixOS --exec bash -lc '/mnt/c/Windows/System32/OpenSSH/ssh.exe -o BatchMode=yes -T git@github.com'
   ```
   The second command should greet you by your GitHub user name. On a first connection, check that GitHub's ED25519 fingerprint is `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU` before accepting. Then `git fetch origin && git merge --ff-only origin/main` works over SSH (verified: 8316e94..8f6b4eb; lefthook's post-merge drift-hints hook ran). This is a per-clone manual setting for now; making it permanent for fresh installs is a follow-up (chezmoi / Home Manager).
2. Only for a clone from before d03a095 (see the known issue above): until a pull and a Home Manager switch bring the fix, create the directory the codebase-memory-mcp-ui wrapper needs and restart the unit:
   ```bash
   mkdir -p ~/Projects && systemctl --user restart codebase-memory-mcp-ui
   ```
   Verified: active (running), NRestarts=0.

The WSL2 section of sys-readiness checks:

| Check | Fix |
| --- | --- |
| systemd is PID 1 | `[boot] systemd=true`, then `wsl --shutdown` |
| repo on the Linux filesystem | re-clone under `~` |
| `node`/`npm`/`npx`/`pnpm` not resolving to Windows copies | run `sys-update`; or uninstall Windows Node |
| WSL2, not WSL1 (`ops/detect-host.sh --wsl-version`) | `wsl --set-version <distro> 2` (install refuses WSL1) |
| Docker daemon reachable | Off by default. Enable the one engine: `sudo ENABLE_DOCKER=1 sys-setup --apply` (unverified on WSL; see [`windows-and-wsl.md`](windows-and-wsl.md#docker) for `DOCKER_GROUP=1` and `DOCKER_ROOTLESS=1`; export first: `bootstrap.ps1 -Export before-docker`). Docker Desktop's WSL integration is a second daemon and is not supported |
| `clip.exe` reachable | `[interop] appendWindowsPath=true` |

User timers run only while the WSL VM is up. A missed run catches up at the next WSL start (`Persistent=true`).

## Alternative: Ubuntu

Per ADR-0015, for a machine where an employer requires a standard distro. Install only the distro the machine needs; the two can coexist (pick one with `wsl -d <name>`; run `wsl --set-default NixOS` if Ubuntu was registered first). The Windows bootstrap never touches Ubuntu, and `ops/system-setup.sh` refuses a non-NixOS host: never run it here. On a corporate machine, WSL, the distro, Nix and any proxy or certificate setup need employer approval; Ubuntu does not remove a ban on Nix.

```powershell
wsl --install -d Ubuntu
wsl --update
wsl --list --verbose   # VERSION must be 2
```

When Ubuntu asks for a user name, use the `username` from `nix/vars/default.nix` (currently `utmostcreator`). Home Manager builds for that name and home directory; `ops/install.sh` stops early if they differ.

`/etc/wsl.conf`:

```ini
[boot]
systemd=true            # runs the Home Manager user timers (AI CLI, MCP updates)

[user]
default=utmostcreator   # same as nix/vars/default.nix

[interop]
enabled=true
appendWindowsPath=true  # keeps clip.exe (tmux copy) and `code .` working
```

Apply with `wsl --shutdown` from PowerShell, reopen Ubuntu, and check `systemctl is-system-running` ("running" or "degraded" is fine). Then:

```bash
sudo apt update && sudo apt install -y git curl ca-certificates
git clone https://github.com/UtmostCreator/app-configs.git ~/app-configs
cd ~/app-configs
bash ops/detect-host.sh             # prints: wsl
bash ops/detect-host.sh --hm-attr   # prints: wsl
DRY_RUN=1 bash ops/install.sh       # preview
bash ops/install.sh                 # apply (snapshots $HOME first)
```

Add your SSH key to GitHub (`gh ssh-key add ~/.ssh/id_ed25519.pub`) before the first `nvim` launch (lazy.nvim clones plugins) or the first `sys-update` (`git pull`), or switch the clone to SSH: `git remote set-url origin git@github.com:UtmostCreator/app-configs.git`.

The Ubuntu path is untested on a real distro. It is covered only by detect-host, hm-switch and eval tests until these six checks pass on one: (1) detect-host prints `wsl` and `--hm-attr` prints `wsl`; (2) install dry-run, then real; (3) XDG_DATA_DIRS includes /usr/share; (4) sys-readiness and sys-update; (5) sys-setup refuses "not NixOS"; (6) the NixOS distro is unaffected.

## What matches macOS

Shared: fish (default) and zsh configs, starship, atuin, fzf, zoxide, tmux, git config and aliases, neovim, yazi, every tool in `nix/modules/home/{cli,dev}.nix`, same versions from one `flake.lock`. CLIs that macOS gets from Homebrew come from Nix on WSL2: 1Password `op` (so `NPM_TOKEN`, the composer token wrapper and `op-refresh` work), GitHub Copilot `copilot`, `mysql` (MariaDB client), `docker compose`.

## What differs from macOS

| Area | macOS | WSL2 |
| --- | --- | --- |
| Clipboard (tmux copy) | `pbcopy` | `clip.exe` via `clipcopy` |
| SSH key passphrase | Keychain (`ssh-add --apple-use-keychain`) | one agent per boot via `keychain` (Nix), passphrase asked about once per 8 hours (`APP_CONFIGS_SSH_KEY_LIFETIME`) |
| Docker daemon | Colima VM | One engine: NixOS `virtualisation.docker`, enabled with `sudo ENABLE_DOCKER=1 sys-setup --apply` (unverified on WSL; [`windows-and-wsl.md`](windows-and-wsl.md#docker)). Docker Desktop's WSL integration is a second daemon: not supported. |
| Opening URLs and files (`gh auth login`, `open .`) | `open` | `wsl-open` (Windows `explorer.exe`); fish sets `BROWSER=wsl-open` and `open` on WSL2. Replaces `wslview`, which nixpkgs dropped |
| VS Code | macOS app | Windows app + Remote WSL; `code .` from the WSL shell. User settings live on the Windows side (`%APPDATA%\Code\User`) and sync via Settings Sync; chezmoi does not write `~/.config/Code` on WSL because nothing reads it |
| PHP / Composer | Nix, but Laravel Herd may shadow them | Nix |
| Laravel Herd (`.test` sites, Valet CA) | Herd app | no equivalent; `ws` launchers skip Herd. Use `php artisan serve` or Sail |
| AI login-expiry alert | desktop notification | Windows toast via `powershell.exe`, and logged to the journal |
| Nix store optimisation | user `nix.conf` | not set per user (WSL2 user is not a trusted Nix user); add `auto-optimise-store = true` to `/etc/nix/nix.conf` if wanted |

Do not run Colima inside WSL (a VM inside the WSL VM). NixOS-WSL: use the engine above (take a `bootstrap.ps1 -Export before-docker` restore point first). Ubuntu: no repo-managed Docker yet (sys-setup refuses non-NixOS).

## Verification status

- NixOS-WSL: verified on a real PC, 2026-11-16 (evidence above).
- T-0047 acceptance: pending the personal git identity (ticket item (b)). The Windows test commit (item (a)) is a follow-up.
- Ubuntu: untested on a real distro.
- Other open items: `docs/plans/migration/followups.md` ("WSL validation").

## Install selection

Optional tool groups (media, security, Go) can be left out; see "Choose what to install" in `docs/getting-started/install.md`.
The selection file is under `$HOME/.config` by default; an `XDG_CONFIG_HOME` elsewhere on the Linux filesystem is honoured, and one on a Windows drive (`/mnt/<letter>`) is ignored.
