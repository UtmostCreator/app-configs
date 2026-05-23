# Windows SSH Agent — QUICKSTART

Copy-paste runbook to make `git@github.com:...` work from PowerShell with an
8-hour passphrase re-prompt. Tested with the configuration on this machine:

- Key: `~/.ssh/github.uc.ll5` (OpenSSH format, with passphrase).
- Git remote: `git@github.com:UtmostCreator/app-configs.git`.
- Existing Git Bash setup keeps working unchanged.

## TL;DR — three steps

1. **Run once as Administrator** (enables the Windows ssh-agent service).
2. **Run once as your normal user** (loads the key + writes the PowerShell profile snippet).
3. **Reopen PowerShell** and you're done. From now on you only re-type the passphrase every 8 hours.

---

## Step 1 — Enable the Windows ssh-agent service (Administrator)

Open **Windows Terminal -> PowerShell tab as Administrator** (right-click the
Windows Terminal icon -> "Run as administrator"), then:

```powershell
# Change to the repo path so the helper script is reachable:
cd C:\xampp\htdocs\app-configs

# Run the helper. Refuses if not elevated.
pwsh -NoProfile -File docs\windows\scripts\Enable-SshAgentService.ps1
```

Expected output:

```
Current state: Status=Stopped, StartType=Disabled
StartupType set to Automatic.
Service started.
Final state:   Status=Running, StartType=Automatic
```

Verify (still in admin shell or any shell):

```powershell
Get-Service ssh-agent | Select-Object Name, Status, StartType
# -> Status: Running, StartType: Automatic
```

Close the admin window. You will not need Administrator again for normal work.

## Step 2 — Load your key and install the 8h re-prompt (normal user PowerShell)

Open a **regular** (non-admin) PowerShell session:

```powershell
cd C:\xampp\htdocs\app-configs

# 2a. One-time: load the key into the Windows agent. You will be prompted
#     for the passphrase. The key persists across reboots until you remove
#     it with `ssh-add -d` or `ssh-add -D`.
ssh-add "$HOME\.ssh\github.uc.ll5"

# 2b. One-time: install the 8h re-prompt block into your PowerShell profile.
#     Idempotent: re-running does nothing if the block already exists.
pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1

# 2c. Scope git to use Windows OpenSSH for THIS PowerShell profile only
#     (Git Bash keeps using its own agent because Git Bash does not read
#     PowerShell profiles).
pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1 -IncludeGitSshOverride
```

Verify:

```powershell
ssh-add -l
# -> at least one fingerprint mentioning github.uc.ll5

ssh -T git@github.com
# -> "Hi UtmostCreator! You've successfully authenticated, but GitHub does not provide shell access."
#    (exit code 1 is normal for GitHub.)

git ls-remote git@github.com:UtmostCreator/app-configs.git HEAD
# -> prints a commit SHA
```

## Step 3 — Reopen PowerShell

Close all PowerShell windows and open a fresh one. The profile snippet runs
on every new session. It:

- Does nothing for 8 hours after a successful `ssh-add`.
- On the next session after 8 hours, runs `ssh-add` once, which prompts for
  the passphrase if needed.
- Persists across reboots because the underlying Windows ssh-agent service
  is set to Automatic in Step 1.

From now on, `git fetch`, `git push`, `git pull` over SSH work from any
PowerShell window with at most one passphrase prompt per 8 hours.

---

## What if I do not want to run admin commands?

Use the per-session helper instead. It starts Git's bundled ssh-agent for
just the current PowerShell process and loads the key with the standard
`ssh-add -t 28800` (8h) TTL.

```powershell
cd C:\xampp\htdocs\app-configs
pwsh -NoProfile -File docs\windows\scripts\Setup-SshAgent.ps1
# -> prompts for passphrase. Valid for 8h or until you close this window.

# Now run your git command in the SAME window:
git fetch origin main
```

Trade-off: every new PowerShell window needs to run this once. No admin
required, no persistent state.

---

## Rollback

Remove everything this runbook created:

```powershell
# 1. Remove key from agent and disable the service:
ssh-add -D                                # drop all keys

# Open admin PowerShell:
Stop-Service ssh-agent
Set-Service ssh-agent -StartupType Disabled

# 2. Remove the profile snippet:
pwsh -NoProfile -File docs\windows\scripts\Install-SshAgentProfileSnippet.ps1 -Remove

# 3. Remove the git override (only needed if you used IncludeGitSshOverride):
#    The Remove flag above also clears GIT_SSH from the snippet, so the next
#    PowerShell session falls back to Git's default ssh.exe.
```

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Permission denied (publickey)` from PowerShell | Agent has no key or `GIT_SSH` not set | Run `ssh-add -l`. If empty, re-run Step 2a. If not empty but git still fails, check `$env:GIT_SSH` and re-run Step 2c. |
| `Permission denied (publickey)` from Git Bash | Git Bash's own agent died | Open a fresh Git Bash session; `.bashrc` rebuilds the agent. |
| `Could not open a connection to your authentication agent` | Windows ssh-agent service stopped | `Get-Service ssh-agent`. If Stopped, re-run Step 1 as admin. |
| Profile snippet does not run on session start | Profile not loaded | `$PROFILE` should print a path; check the file exists and contains the `--- ssh-agent 8h prompt ---` block. |
| Passphrase prompt every shell | 8h marker not being written | Check `$HOME\.ssh\state\pwsh-last-add.txt` exists after a successful `ssh-add` from inside the snippet. |

## Files installed by this runbook

| Path | Step | What it is |
| --- | --- | --- |
| Windows service `ssh-agent` | 1 | StartType=Automatic, Status=Running |
| Key in Windows ssh-agent | 2a | `~/.ssh/github.uc.ll5` (persists until `ssh-add -d`) |
| `$PROFILE` (Microsoft.PowerShell_profile.ps1) | 2b | Block delimited by `# --- ssh-agent 8h prompt ---` ... `# --- end ssh-agent 8h prompt ---` |
| `$HOME\.ssh\state\pwsh-last-add.txt` | 2b (runtime) | Empty file. Its `LastWriteTime` is the 8h re-prompt anchor. |

## Why this design

- **Windows ssh-agent service** is the only cross-process ssh-agent on
  Windows. It persists across reboots, runs as the current user, and is
  reachable via `\\.\pipe\openssh-ssh-agent`.
- **Windows OpenSSH `ssh-add` has no `-t` flag**, so we cannot ask the
  agent itself to expire the key. We emulate the 8h prompt at the
  *profile* layer instead, using a marker file's `LastWriteTime`.
- **Git Bash is untouched** because the override is set via `$env:GIT_SSH`
  in the PowerShell profile, which Git Bash never reads.
- **Per-session helper still exists** (`Setup-SshAgent.ps1`) as a fallback
  for users who cannot or do not want to run the admin step.
