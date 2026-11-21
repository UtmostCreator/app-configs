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

- One engine: NixOS `virtualisation.docker` (unverified on WSL).
- Enable: `sudo ENABLE_DOCKER=1 sys-setup --apply` (unverified on WSL). Add `DOCKER_GROUP=1` for user access, or `DOCKER_ROOTLESS=1`. Not `docker.io`, not `wsl-docker.sh`.
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

## Memory and stability

Lessons from the Linux desktop incident (see [desktop-stability](../nixos/desktop-stability.md)). Manual guidance only; automating any of these on Windows needs a new ADR (see [project scope](../../architecture/project-scope.md), ADR-0019). `.wslconfig` is deferred in T-0041 and Fast Startup is `skip` in T-0048.

| Item | Why | Suggested setting |
| --- | --- | --- |
| WSL2 memory cap | The WSL VM is one Windows process (`vmmem`) and grows to its limit | Keep WSL's default cap (50% of RAM): set no `memory=` in `%UserProfile%\.wslconfig`. Owner policy: percentages only, never a fixed size |
| Return unused WSL memory | The VM holds freed memory by default | `[experimental]` `autoMemoryReclaim=gradual`, `sparseVhd=true` |
| Limits inside WSL | Same runaway-job risk as on Linux | With `systemd=true`, cgroup v2 limits work inside WSL; keep their sizes below the WSL VM memory cap. The repo's percentage limits (the AI remote-control services' 40%/50%) resolve against the VM's RAM, so they already fit. The `app-terminals` slice is not deployed on WSL |
| Fast Startup on dual-boot | Leaves NTFS half-hibernated; Linux mounts it read-only or refuses | Turn it off: Control Panel, Power Options, "Choose what the power buttons do" |
| Memory warnings | Event 2004 names the processes using memory | Event Viewer: Resource-Exhaustion-Detector |

Apply `.wslconfig` changes with `wsl --shutdown` (it stops every WSL session).
