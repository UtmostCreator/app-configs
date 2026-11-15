# Windows and WSL2: choices

The WSL distro = NixOS-WSL, the same path as the NixOS desktop (sys-setup + standalone HM). Plan: T-0047. Items marked (planned) are not built.

## Windows edition

- WSL2 runs on Windows 11 Home.
- Needs Virtual Machine Platform and firmware virtualization. Hyper-V not needed.
- Pro adds Hyper-V Manager, Windows Sandbox, BitLocker, Group Policy. None used here.

## Where to run Claude Code

| Where | Use for |
|-------|---------|
| Inside WSL2 | Daily development |
| Windows | PowerShell bootstrap, winget, Windows apps/settings, repairing WSL |

- WSL2: repos under `~`, fast filesystem, LF.
- WSL2: Linux tools, repo hooks, Nix, bats, Docker, the sandbox.
- WSL2: same chezmoi-managed config and statusline as Linux/macOS.
- Avoid: editing WSL files from Windows via `\wsl$` or `\wsl.localhost`. Also avoid `/mnt/c` repos from WSL.
- `~/.claude` config and login are separate on each side.

## Docker

- One engine: NixOS `virtualisation.docker` (planned).
- Enable: `sudo ENABLE_DOCKER=1 sys-setup --apply` (planned). Not `docker.io`, not `wsl-docker.sh`.
- Windows `docker` (planned, Milestone 2): `docker.cmd` shim to the WSL docker CLI.
- Shim: no daemon or binary on Windows, no TCP listener.
- Shim: bind-mount and `-f` paths must be WSL paths.

| Access in WSL | Windows shim |
|---------------|--------------|
| `DOCKER_GROUP=1` (root-equivalent; new session: `wsl --terminate NixOS`) | works |
| `DOCKER_ROOTLESS=1` (unverified on WSL) | works |
| `sudo` only | none |

Rejected:

- `docker.exe` + ssh context: needs sshd in WSL.
- Docker Desktop: second daemon.
- Daemon on TCP 2375: unauthenticated root.

## Tailscale

- Windows only.
- WSL reaches the tailnet through Windows.
- WSL-native only for an inbound need: its own IP, Tailscale SSH into WSL.

## Reboot points

- R1: Finish Windows edition upgrade or pending update reboot first.
  - Restart from Settings -> Windows Update -> Restart now. A plain Start-menu restart can leave the pending-reboot marker set (seen 2026-11-15); a shutdown with Fast Startup on does not finish servicing either.
  - Check: the bootstrap's dry run stops at step 0 while the marker is set.
- R2: After the elevated bootstrap run installs WSL.

- Bootstrap refuses while a reboot is pending.
- `wsl --shutdown` restarts WSL only, not Windows.

## Restore points

- Before installing WSL: Windows System Restore point.
- Needs admin, System Protection on for C:. One per 24h by default.
- `wsl --export` of NixOS: before setup and before Docker. Restore: `wsl --import`.
- No export after install (size, secrets).
- `wsl --unregister`: manual decision, never scripted.
- Export tars can hold keys and tokens. Keep private.
