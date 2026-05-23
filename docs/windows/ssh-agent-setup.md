# SSH Agent Setup on Windows (8-hour passphrase re-prompt)

This document is the long-form reference. For the copy-paste runbook see
[QUICKSTART.md](QUICKSTART.md).

It exists because PowerShell sessions on this machine cannot reach the
`ssh-agent` that Git Bash starts, so `git@github.com:...` fails with
`Permission denied (publickey)` from any PowerShell shell. We want both
shells to share working SSH auth, with at most one passphrase prompt per
8 hours.

## 1. Diagnosis (Status: completed)

Performed read-only on `C:\Users\UC-LL5S`.

| Aspect | Finding |
| --- | --- |
| Git remote | `git@github.com:UtmostCreator/app-configs.git` (SSH, not HTTPS). |
| `~/.bashrc` (Git Bash) | Installed at `C:\Users\UC-LL5S\.bashrc`, length 4141 bytes, last write 2026-05-09. Loads ssh-agent with `SSH_ADD_TTL="28800"` (8 hours). Source of truth is `C:\Users\UC-LL5S\Documents\___sync\syncthing\users\.bashrc`. |
| `~/.bash_profile` (Git Bash) | Installed, sources `.bashrc`. |
| `~/.ssh/github.uc.ll5` private key | Present, 464 bytes. |
| `~/.ssh/config` | Maps `Host github.com` to `IdentityFile ~/.ssh/github.uc.ll5`, `User git`, `IdentitiesOnly yes`. |
| `~/.ssh/agent.env` | Exists with `SSH_AGENT_PID=411` and `SSH_AUTH_SOCK=/c/Users/UC-LL5S/.ssh/agent/s.smdfzvtRtB.agent.1Tx2Es8TIP`. Likely stale (file dated 2026-05-09). |
| PowerShell profiles | `Microsoft.PowerShell_profile.ps1` and `profile.ps1` set up Starship, zoxide, atuin, direnv, alias `ll`. **No ssh-agent setup.** |
| `ssh.exe` on PATH | Two binaries: Windows OpenSSH at `C:\WINDOWS\System32\OpenSSH\ssh.exe` (9.5.5.1) and Git's bundled `C:\Program Files\Git\usr\bin\ssh.exe`. |
| `ssh-agent` Windows service | `Status: Stopped, StartType: Disabled`. |
| Current pwsh env | `SSH_AUTH_SOCK` and `SSH_AGENT_PID` are empty, `GIT_SSH` is empty. |

## 2. Root cause

- Git Bash uses its own Unix-style `ssh-agent` writing a Unix domain socket
  file under `~/.ssh/agent/`. That socket is unreachable by PowerShell, and
  by Windows-native `ssh.exe`.
- PowerShell has no agent setup at all, so `git.exe` from PowerShell cannot
  present a key when talking to `git@github.com`.
- The Windows OpenSSH `ssh-agent` Windows service - the obvious cross-shell
  agent - is disabled.

## 3. Decision criteria

Pick one of the two fixes below. They are not mutually exclusive but you
usually want only one.

| Option | Persists across reboots | Needs admin | Touches global git config | Best for |
| --- | --- | --- | --- | --- |
| A. Per-session helper | No | No | No | One-off `git fetch`/`git push` from pwsh today. |
| B. Windows agent service + profile snippet | Yes | Yes (once) | Yes (sets `core.sshCommand`) | Long-term unified setup. |

## 4. Option A - per-session helper (Status: planned, not yet executed)

Use this when you just need to unblock the current task and do not want to
touch any persistent state.

The helper [`scripts/Setup-SshAgent.ps1`](scripts/Setup-SshAgent.ps1) starts
Git's bundled `ssh-agent`, loads `~/.ssh/github.uc.ll5` with a `-t 28800`
(8 hour) TTL, and exports `SSH_AUTH_SOCK` + `SSH_AGENT_PID` into the current
shell.

### Steps

```powershell
# From this repo root, in the SAME PowerShell session you want to use for git:
pwsh -NoProfile -File docs\windows\scripts\Setup-SshAgent.ps1

# After it succeeds, verify:
ssh -T git@github.com
# Expected: "Hi UtmostCreator! You've successfully authenticated, but GitHub does not provide shell access."

# Then run the git operation that was blocked:
git fetch origin main
```

Notes:

- Run `Setup-SshAgent.ps1` with `-NoProfile` if your profile has anything
  noisy. With profile is fine too.
- The agent dies when this PowerShell session exits. That is intentional for
  Option A.
- The script is idempotent: re-running in the same shell reuses the existing
  agent if it is still alive.

## 5. Option B - Windows agent service + persistent profile snippet (Status: planned, not yet executed, requires admin)

Use this when you want PowerShell git to always have a working agent, the way
Git Bash already does.

### 5.1 Enable the Windows OpenSSH agent service (admin)

[`scripts/Enable-SshAgentService.ps1`](scripts/Enable-SshAgentService.ps1)
sets the service to start automatically and starts it.

```powershell
# Open an ELEVATED PowerShell (Run as Administrator), then:
pwsh -NoProfile -File docs\windows\scripts\Enable-SshAgentService.ps1

# Verify:
Get-Service ssh-agent | Select-Object Name, Status, StartType
# Expected: Status: Running, StartType: Automatic
```

### 5.2 Tell git.exe to use Windows OpenSSH (not Git Bash ssh)

```powershell
# Non-admin pwsh:
git config --global core.sshCommand "C:/WINDOWS/System32/OpenSSH/ssh.exe"

# Verify:
git config --global --get core.sshCommand
```

This makes `git` from any shell use the Windows agent service. Git Bash will
keep working with its own setup because `core.sshCommand` is overridden only
in the contexts that explicitly pick it up; if your Git Bash sessions break,
unset with `git config --global --unset core.sshCommand` and use the
per-shell agents instead.

### 5.3 Load the key into the Windows agent

```powershell
# One-time load. Windows OpenSSH ssh-add does NOT support -t (no TTL flag).
ssh-add "$HOME\.ssh\github.uc.ll5"

# Verify:
ssh-add -l
# Expected: a single 2048/3072/4096-bit RSA/ED25519 fingerprint matching github.uc.ll5
```

The Windows agent persists keys for the current Windows user account across
reboots, until you explicitly remove them with `ssh-add -d` or
`ssh-add -D`.

### 5.4 Install the 8-hour re-prompt snippet in your PowerShell profile

Windows OpenSSH `ssh-add` has no `-t` flag. To mimic the 8-hour TTL from
`.bashrc`, we maintain a marker file's `LastWriteTime` as the anchor and
only call `ssh-add` again after 8 hours have elapsed.

Use the helper script (idempotent, supports `-Remove`):

```powershell
# Without GIT_SSH override (git.exe in PowerShell continues to use whatever
# `core.sshCommand` resolves to):
pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1

# With GIT_SSH override (recommended; scopes Windows OpenSSH to PowerShell
# only, leaves Git Bash unaffected):
pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1 -IncludeGitSshOverride

# Remove later:
pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1 -Remove
```

The installed block, delimited by
`# --- ssh-agent 8h prompt (managed by ...) ---` and
`# --- end ssh-agent 8h prompt ---`, is safe to re-run, does nothing if
the service is stopped or the key is missing, and only invokes `ssh-add`
when more than 8 hours have passed since the last marker write.

The marker file is `$HOME\.ssh\state\pwsh-last-add.txt`. Delete it to
force a prompt on the next PowerShell session.

## 6. Verification (planned)

After Option A or Option B, the following must all succeed:

```powershell
ssh -T git@github.com                  # Greets you by name, exit 1 is normal for GitHub
ssh-add -l                             # Lists at least one key matching github.uc.ll5
git ls-remote git@github.com:UtmostCreator/app-configs.git HEAD  # Prints a SHA
```

## 7. Rollback

- Option A: just close the PowerShell session. Nothing else to undo.
- Option B:
  - Remove the profile snippet block (delimited by the comment markers above).
  - `git config --global --unset core.sshCommand`
  - `ssh-add -D` to drop all keys from the Windows agent.
  - As admin: `Stop-Service ssh-agent; Set-Service ssh-agent -StartupType Disabled`.

## 8. Approval boundaries hit by this work

Per `docs/ai/approval-boundaries.md`, the following items required your
explicit go-ahead before any agent could execute them:

- Enabling and starting the Windows `ssh-agent` service (system service +
  admin elevation).
- Adding a key to any ssh-agent (credential touch).
- Modifying `~/.gitconfig` global `core.sshCommand` (auth-adjacent config).
- Editing PowerShell profile to persist the TTL snippet.

The agent will not perform any of these without explicit re-confirmation in
the current task.

## 9. Related files in this repo

- [QUICKSTART.md](QUICKSTART.md) - copy-paste runbook (start here).
- [scripts/Enable-SshAgentService.ps1](scripts/Enable-SshAgentService.ps1) - admin service enabler.
- [scripts/Install-SshAgentProfileSnippet.ps1](scripts/Install-SshAgentProfileSnippet.ps1) - PowerShell profile snippet installer/remover.
- [scripts/Setup-SshAgent.ps1](scripts/Setup-SshAgent.ps1) - per-session fallback when admin is unavailable.
- [README.md](README.md) - index for `docs/windows/`.
