# Setup

Start with [`base.md`](base.md), then your platform. Scope: [project scope](../architecture/project-scope.md).

| Platform | Doc | Notes |
|----------|-----|-------|
| Base (all systems) | [`base.md`](base.md) | Git, SSH key, commit tooling, rules. Always first |
| Linux / macOS (generic) | [`install.md`](../getting-started/install.md), [`bootstrap.md`](../getting-started/bootstrap.md), [`unix-quickstart.md`](../getting-started/unix-quickstart.md) | `ops/install.sh` does the rest; SSH agent |
| NixOS desktop | [`nixos/install.md`](nixos/install.md), [`nixos/rebuild.md`](nixos/rebuild.md) | System layer, when to rebuild |
| macOS | [`macos/setup.md`](macos/setup.md) | nix-darwin, Homebrew |
| Windows 11 | [`windows/setup.md`](windows/setup.md) | Account, Git, SSH key, Claude Code |
| WSL2 (NixOS-WSL default, Ubuntu supported; ADR-0015) | [`wsl/setup.md`](wsl/setup.md), [`wsl/windows-and-wsl.md`](wsl/windows-and-wsl.md) | Windows vs WSL2 choices |

```mermaid
flowchart LR
  base[base.md] --> platform[Your platform doc] --> verify[validate-config]
```
