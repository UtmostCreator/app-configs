# Windows Setup Notes

Per-platform setup notes for working on this repository from a Windows host.

This folder is for reproducible Windows-specific procedures: SSH agents,
PowerShell profiles, service configuration, and similar tasks that do not
belong in the cross-platform `docs/ai/` workflow surface.

## Contents

| File | Purpose |
| --- | --- |
| [QUICKSTART.md](QUICKSTART.md) | **Start here.** Copy-paste runbook: 3 steps that get persistent ssh-agent with 8h passphrase re-prompt working on this PC. |
| [ssh-agent-setup.md](ssh-agent-setup.md) | Long-form reference: diagnosis findings, design rationale, both fix paths, rollback, and approval boundaries. |
| [scripts/Enable-SshAgentService.ps1](scripts/Enable-SshAgentService.ps1) | Admin one-shot: enables the Windows OpenSSH `ssh-agent` service so it starts automatically and is reachable from every PowerShell session. |
| [scripts/Install-SshAgentProfileSnippet.ps1](scripts/Install-SshAgentProfileSnippet.ps1) | Non-admin one-shot: installs the 8-hour re-prompt block into your PowerShell profile. Idempotent. Supports `-Remove` and `-IncludeGitSshOverride`. |
| [scripts/Setup-SshAgent.ps1](scripts/Setup-SshAgent.ps1) | Per-session fallback for when admin is unavailable. Starts Git's bundled `ssh-agent` and loads the key with `ssh-add -t 28800`. No admin, no persistent state. |

## When to use what

- **First time on this PC:** open `QUICKSTART.md` and follow steps 1-3.
- **Need one-off `git fetch`/`git push` from a borrowed shell:** run
  `pwsh -File repo-docs/windows/scripts/Setup-SshAgent.ps1` and use git in the
  same window.
- **Want to change the configured key or update the snippet:** re-run
  `Install-SshAgentProfileSnippet.ps1` (with new `-KeyPath` if needed).
  Re-run with `-Remove` to uninstall.
- **Just using Git Bash:** already works via `~/.bashrc`; nothing else needed.

## Status conventions

Each procedure file uses these status markers next to every step:

- `Status: completed` - action ran on this machine and produced the stated result.
- `Status: planned (not yet executed)` - action documented for the user or
  future agent to run; not performed during the documenting session.
- `Status: requires approval` - blocked on user approval (typically admin
  elevation or credential touch).

Never treat a `planned` step as completed work.
