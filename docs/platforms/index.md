# Setup

For the fresh Niri laptop start with [Claude and install preparation](nixos/niri-install.md). For the other hosts, start with [`base.md`](base.md), then your platform. Scope: [project scope](../architecture/project-scope.md).

| Platform | Doc | Notes |
|----------|-----|-------|
| Base (all systems) | [`base.md`](base.md) | Git, SSH key, commit tooling, rules |
| Linux / macOS (generic) | [`install.md`](../getting-started/install.md), [`bootstrap.md`](../getting-started/bootstrap.md), [`unix-quickstart.md`](../getting-started/unix-quickstart.md) | `ops/install.sh` does the rest; SSH agent |
| NixOS + Niri laptop | [Install and recover linux-niri](nixos/niri-install.md) | Locked system and home, Disko, UEFI rehearsal and laptop acceptance |
| Existing NixOS desktop | [`nixos/install.md`](nixos/install.md), [`nixos/rebuild.md`](nixos/rebuild.md), [`nixos/desktop-stability.md`](nixos/desktop-stability.md) | System layer, when to rebuild, crash/OOM audit |
| macOS | [`macos/setup.md`](macos/setup.md) | nix-darwin, Homebrew |
| Windows 11 | [`windows/setup.md`](windows/setup.md) | Account, Git, SSH key, Claude Code |
| WSL2 (NixOS-WSL default, Ubuntu supported; ADR-0015) | [`wsl/setup.md`](wsl/setup.md), [`wsl/windows-and-wsl.md`](wsl/windows-and-wsl.md) | Windows vs WSL2 choices |

```mermaid
flowchart LR
  base[base.md] --> platform[Your platform doc] --> verify[validate-config]
```
