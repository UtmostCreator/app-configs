# Windows Setup Notes

Per-platform setup notes for working on this repository from a Windows host.

This folder is for reproducible Windows-specific procedures: SSH agents,
PowerShell profiles, service configuration, and similar tasks that do not
belong in the cross-platform `docs/ai/` workflow surface.

## Contents

| File | Purpose |
| --- | --- |
| [ssh-agent-setup.md](ssh-agent-setup.md) | Diagnose and persist `ssh-agent` for both PowerShell and Git Bash with an 8-hour key TTL, so `git fetch`/`git push` against `git@github.com:...` works without retyping passphrases. |
| [scripts/Setup-SshAgent.ps1](scripts/Setup-SshAgent.ps1) | Per-session PowerShell helper. Starts Git's `ssh-agent`, loads a key with 8-hour TTL, leaves env vars in the current shell. No admin required. |
| [scripts/Enable-SshAgentService.ps1](scripts/Enable-SshAgentService.ps1) | One-time admin helper that enables the Windows OpenSSH `ssh-agent` service so PowerShell git can reach it across reboots. Requires Administrator. |

## When to use what

- Need to run one `git fetch`/`git push` right now and don't want to touch
  the system: run `pwsh -File docs/windows/scripts/Setup-SshAgent.ps1`.
- Want PowerShell git to always use a single agent across reboots:
  run `Enable-SshAgentService.ps1` (admin), then follow the persistence
  section of `ssh-agent-setup.md`.
- Just using Git Bash already works via `~/.bashrc`; nothing else needed.

## Status conventions

Each procedure file uses these status markers next to every step:

- `Status: completed` - action ran on this machine and produced the stated result.
- `Status: planned (not yet executed)` - action documented for the user or
  future agent to run; not performed during the documenting session.
- `Status: requires approval` - blocked on user approval (typically admin
  elevation or credential touch).

Never treat a `planned` step as completed work.
