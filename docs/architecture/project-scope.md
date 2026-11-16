# Project scope: Linux, macOS and WSL2 first

This repository configures Linux (NixOS and `linux-cli`), macOS and WSL2. It is
not a way to tailor Windows 11. The owner decision is recorded in
[ADR-0019](decisions/0019-platform-scope-linux-macos-wsl2-first.md).

## What the Windows 11 host gets

Only the small, bounded surface that is already decided:

- A PowerShell bootstrap, `ops/windows/bootstrap.ps1`, that prepares WSL and
  installs commit tooling with winget ([ADR-0002](decisions/0002-windows-provisioning-bootstrap-winget.md)).
- The safety net around it: restore point, exports, pinned image
  ([ADR-0007](decisions/0007-safety-net-restore-points-and-pinned-downloads.md)).
- One opt-in Claude status line step, if ADR-0016 is accepted
  ([ADR-0016](decisions/0016-native-windows-claude-status-line.md)).
- Manual docs and a manual app list
  ([ADR-0011](decisions/0011-windows-edition-and-apps.md)).

## What is not planned

- No general Windows configuration layer (no chezmoi, DSC or registry tweaks).
- No Windows app automation and no application of Windows settings
  ([ADR-0010](decisions/0010-cross-os-settings-inventory-first.md)).
- No Windows frontend for the configuration manager
  ([ADR-0018](decisions/0018-interactive-config-manager-frontend.md)).
- WSL never runs winget or PowerShell to change Windows. Runtime interop
  (clip.exe, explorer.exe, toast notifications) is fine.
- Tailscale on the host ([ADR-0004](decisions/0004-tailscale-on-windows-only.md))
  is a manual install. The Milestone-2 items in ADR-0003 (docker.cmd shim) and
  ADR-0006 (native Claude install) each need their own ADR under the rule below.

## Adding anything for Windows

Anything the repo installs, writes or automates on the Windows host (a
bootstrap step, a winget id it installs, a key or file it writes) needs a new
ADR tagged `platforms: [windows]` that cites ADR-0019, and an explicit owner
decision. Manual docs and the manual app list stay under ADR-0011. Keep Windows
changes small. See the rule in [the ADR index](decisions/index.md).
