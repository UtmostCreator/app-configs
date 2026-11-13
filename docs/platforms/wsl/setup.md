# WSL2 setup

WSL2 uses the `wsl` host profile: the same shared CLI and dev modules as macOS
and Linux (`nix/modules/common`, `nix/modules/home`), with no GUI module and
no Windows-side management. macOS and WSL share one `flake.lock`, so both get
the same tool versions once both have pulled the same commit.

## 1. Windows side (PowerShell)

```powershell
wsl --install -d Ubuntu
wsl --update
wsl --list --verbose   # VERSION must be 2
```

When Ubuntu asks for a user name, use the `username` from
`nix/vars/default.nix` (currently `utmostcreator`). Home Manager builds for
that name and home directory. `ops/install.sh` stops early if they differ.

## 2. `/etc/wsl.conf`

```ini
[boot]
systemd=true            # runs the Home Manager user timers (AI CLI, MCP updates)

[user]
default=utmostcreator   # same as nix/vars/default.nix

[interop]
enabled=true
appendWindowsPath=true  # keeps clip.exe (tmux copy) and `code .` working
```

Apply with `wsl --shutdown` from PowerShell, then reopen Ubuntu and check:

```bash
systemctl is-system-running   # "running" or "degraded" is fine
```

User timers only run while the WSL VM is up. A missed weekly or hourly run
catches up the next time WSL starts (`Persistent=true`), but nothing runs
while WSL is stopped.

## 3. Install

Keep the repo and projects on the Linux filesystem (`~/...`), not under
`/mnt/c`. Git, Nix and package managers are many times slower across the
Windows drive bridge.

```bash
sudo apt update && sudo apt install -y git curl ca-certificates
git clone https://github.com/UtmostCreator/app-configs.git ~/app-configs
cd ~/app-configs
bash ops/detect-host.sh          # prints: wsl
DRY_RUN=1 bash ops/install.sh    # preview
bash ops/install.sh              # apply (snapshots $HOME first)
```

The first install seeds `home/.chezmoidata/personal.yaml` with
`hostProfile: wsl` and `gui: false`. Fill in your name and email there.

The managed gitconfig sends `https://github.com/` Git URLs over SSH. Add
your SSH key to GitHub (`gh ssh-key add ~/.ssh/id_ed25519.pub`) before the
first `nvim` launch (lazy.nvim clones plugins) or the first `sys-update`
(`git pull`), or switch the clone to SSH:
`git remote set-url origin git@github.com:UtmostCreator/app-configs.git`.

## 4. Verify

```bash
sys-readiness    # includes the WSL2 section from ops/wsl-check.sh
```

The WSL2 section checks:

| Check | Fix |
| --- | --- |
| systemd is PID 1 | `[boot] systemd=true`, then `wsl --shutdown` |
| repo on the Linux filesystem | re-clone under `~` |
| `node`/`npm`/`npx`/`pnpm` not resolving to Windows copies | run `sys-update`; or uninstall Windows Node |
| `clip.exe` reachable | `[interop] appendWindowsPath=true` |

## What differs from macOS

| Area | macOS | WSL2 |
| --- | --- | --- |
| Clipboard (tmux copy) | `pbcopy` | `clip.exe` via `clipcopy` |
| SSH key passphrase | Keychain (`ssh-add --apple-use-keychain`) | one shared agent per boot (`ssh-agent.fish`: `keychain` if installed, else `~/.ssh/agent.env`) |
| Docker daemon | Colima VM | Docker Engine in WSL, or Docker Desktop's WSL integration. Pick one. |
| Opening URLs (`gh auth login`) | `open` | prints the URL; `wslu`/`wslview` is gone from nixpkgs (project discontinued) |
| VS Code | macOS app | Windows app + Remote WSL; `code .` from the WSL shell. User settings live on the Windows side (`%APPDATA%\Code\User`) and sync via Settings Sync; chezmoi does not write `~/.config/Code` on WSL because nothing reads it |
| PHP / Composer | Nix, but Laravel Herd may shadow them | Nix |

Do not run Colima inside WSL. It would start a VM inside the WSL VM. Docker
Engine (`sudo apt install docker.io`, then add yourself to the `docker` group)
is the lighter choice for CLI-only use.

## Not yet verified on a real WSL host

The WSL configuration builds and the install path is tested in dry-run mode
on Linux, but nobody has activated it on real WSL yet. Open items are
tracked in `docs/plans/migration/followups.md` ("WSL validation").
