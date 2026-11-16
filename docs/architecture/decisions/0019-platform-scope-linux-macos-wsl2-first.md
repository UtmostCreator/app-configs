# ADR-0019: Platform scope: Linux, macOS and WSL2 first; Windows stays bounded
Status: decided (owner decision 2026-11-16) · Date: 2026-11-16 · Amends: ADR-0002, ADR-0010, ADR-0011, ADR-0018 · Sources: owner decision 2026-11-16, [project scope](../project-scope.md)

## Decision
- The project targets Linux (NixOS, linux-cli), macOS and WSL2. It is not for tailoring Windows 11.
- The Windows host gets only the surface already decided: the ADR-0002 bootstrap and winget for commit tooling, the ADR-0007 safety net, ADR-0016 if accepted, and manual docs and app list (ADR-0011).
- Windows app automation and `winget configure` are not planned (ADR-0011 and ADR-0002 had them open). Applying Windows settings needs its own ADR (ADR-0010 left it open). A Windows frontend for the configuration manager is out of scope (ADR-0018 said "unknown").
- WSL never runs winget or PowerShell to change Windows. Runtime interop (clip.exe, explorer.exe, toast) is allowed.
- Tailscale on the host (ADR-0004) is a manual install. The Milestone-2 items in ADR-0003 (docker.cmd shim) and ADR-0006 (native Claude install) each need their own ADR under this rule.
- Anything the repo installs, writes or automates on the Windows host (a bootstrap step, a winget id it installs, a key or file it writes) needs a new ADR tagged windows citing ADR-0019 and an owner decision. Manual docs and the manual app list stay under ADR-0011.

## Why
- Windows work is high-complexity and low-parity: bats does not run there, and ADR-0016 shows how one status line needed a bounded surface and its own guards.
- Before this record, README and tool-ownership said native Windows was unsupported while three ADRs and a bootstrap script implemented, and one proposed ADR extends, a bounded host bootstrap. There was no single statement.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Full Windows support (chezmoi, DSC, app automation) | The open-ended maintenance burden T-0041 and ADR-0016 already discard. |
| No Windows at all, WSL docs only | The bootstrap and safety net already exist and are used to reach WSL. |

## Discarded
A general Windows configuration layer; Windows app automation; applying Windows settings without a separate ADR.

## Consequences
- ADR-0002, ADR-0010, ADR-0011 and ADR-0018 carry an "Amended by ADR-0019" note.
- README.md and docs/architecture/tool-ownership.md now say "only a bounded WSL bootstrap" instead of "not supported" and "out of scope".
