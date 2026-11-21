# Windows setup (shortest path)

From a fresh Windows 11 install to cloning these repos over SSH and running
Claude Code. For the Linux side under Windows, see [WSL2 setup](../wsl/setup.md).

## 1. Local account during setup (no Microsoft login)

At the first setup screen (region or network), press **Shift + F10** to open a
command prompt and run:

```cmd
start ms-cxh:localonly
```

Create the local user in the window that opens. On builds where that does
nothing, use `oobe\bypassnro` instead: the PC reboots and the network screen
offers **I don't have internet**.

## 2. Brave and Git (PowerShell)

```powershell
winget install -e --id Brave.Brave
winget install -e --id Git.Git --interactive
```

In the Git installer, on **Choose a credential helper**, select **None**. SSH is
used instead of Git Credential Manager. If Git is already installed with it (elevated):

```powershell
git config --system --unset credential.helper
```

## 3. SSH key for GitHub

```powershell
ssh-keygen -t ed25519 -C "windows11-github"            # Enter for the default path ~/.ssh/id_ed25519
ssh-keygen -lf "$HOME\.ssh\id_ed25519.pub"              # prints a fingerprint if the key is valid
(Get-Content "$HOME\.ssh\id_ed25519.pub" -Raw).Trim() | Set-Clipboard
```

Log in to GitHub in Brave, open <https://github.com/settings/keys>, choose
**New SSH key**, key type **Authentication Key**, and paste. The pasted text is
one line starting with `ssh-ed25519 AAAA`. GitHub answers `Key is invalid. You
must supply a key in OpenSSH public key format` when the paste is the private
key (`-----BEGIN OPENSSH PRIVATE KEY-----`), the `SHA256:…` fingerprint, or
cut off. Copy again with the line above.

Then check the key works and clone:

```powershell
ssh -T git@github.com                        # "Hi <user>! You've successfully authenticated"
git clone git@github.com:UtmostCreator/app-configs.git
```

The private key `~/.ssh/id_ed25519` never leaves the machine and is never
committed.

## 4. Claude Code

```powershell
irm https://claude.ai/install.ps1 | iex
```

The installer puts `claude.exe` in `%USERPROFILE%\.local\bin`, which is not on
`PATH` by default. Add it once for your user, then open a new terminal:

```powershell
[Environment]::SetEnvironmentVariable('Path',
  [Environment]::GetEnvironmentVariable('Path', 'User') + ";$env:USERPROFILE\.local\bin", 'User')
```

Run `claude` and log in through the browser. `claude doctor` confirms the
install.

## 4b. Optional: Claude status line (native Windows Claude)

Opt-in, [ADR-0016](../../architecture/decisions/0016-native-windows-claude-status-line.md). The default bootstrap run never does this. Run it non-elevated, with Git for Windows installed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1 -ClaudeStatusLine -DryRun   # prints "would ...", writes nothing
powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1 -ClaudeStatusLine
```

It does four things:

- installs `jq` (winget `jqlang.jq`) when it is missing;
- copies the repo script `home/dot_claude/executable_statusline.sh` to `%USERPROFILE%\.claude\statusline.sh` as it is in the repo at run time (LF);
- sets only the `statusLine` key in `%USERPROFILE%\.claude\settings.json`, copied from `home/.chezmoitemplates/claude/settings.json`; other keys keep their values (jq re-indents the file);
- renders the status line once under Git Bash to check it.

Backup: before it replaces anything, the run saves the current files byte for byte to `%LOCALAPPDATA%\app-configs\claude\<UTC>-<PID>\` (`settings.json`, and `statusline.sh` when one existed). A run with nothing to change keeps no backup. Backups are never deleted by the script.

Rollback, one command (the run prints it with the real paths):

```powershell
Copy-Item -LiteralPath "$env:LOCALAPPDATA\app-configs\claude\<UTC>-<PID>\settings.json" -Destination "$env:USERPROFILE\.claude\settings.json" -Force
```

If `settings.json` did not exist before, delete it instead. To restore the old script, copy `statusline.sh` back the same way; `winget uninstall --id jqlang.jq --exact` removes jq.

Update: after `git pull`, `-ClaudeStatusLine -DryRun` shows drift; re-run to apply. Close running Windows Claude sessions first, then reopen Windows Terminal (jq is on `PATH` only for new sessions).

It refuses (exit 3, nothing written) when elevated, when `CLAUDE_CONFIG_DIR` is set, when Git Bash's home differs from `%USERPROFILE%`, when jq is older than 1.7, when `settings.json` is not one UTF-8 JSON object, and for read-only or linked targets. Not done: hooks, model, theme, a Nerd Font and Windows Terminal profile changes.

Troubleshooting: accept workspace trust for the folder; `disableAllHooks: true` also disables the status line; Claude Code may pick another bash (`CLAUDE_CODE_GIT_BASH_PATH`); `claude --debug` shows the status line error.

## 5. Optional: GitHub CLI

```powershell
winget install -e --id GitHub.cli
gh auth login        # choose GitHub.com, SSH, and the existing key
```

## 6. Optional: password manager

[ADR-0039](../../architecture/decisions/0039-windows-work-password-manager.md): KeePassXC, or Bitwarden. Employer policy wins. Check each id with `winget show --id <id> --exact` first.

```powershell
winget install -e --id KeePassXCTeam.KeePassXC
# or: winget install -e --id Bitwarden.Bitwarden
```

Keep the vault and any key file out of git; back them up with your encrypted backup.

## What the bootstrap never changes (manual only)

Scope: only a bounded bootstrap, see [project scope](../../architecture/project-scope.md). `ops/windows/bootstrap.ps1 -DryRun` writes nothing on Windows but may start the WSL distro and use a temp file inside it (see the script header).

The bootstrap writes no registry values itself (wsl.exe, winget and System Restore record their own state) and does not touch the items below.
They stay manual on purpose: [ADR-0011](../../architecture/decisions/0011-windows-edition-and-apps.md)
discards registry and DSC tweaks, and [ADR-0007](../../architecture/decisions/0007-safety-net-restore-points-and-pinned-downloads.md)
keeps restore points as the safety net and `wsl --unregister` manual.

| Item | Why it stays manual |
|---|---|
| BitLocker / Device Encryption | Windows 11 24H2+ may enable Device Encryption on eligible hardware; the bootstrap neither detects nor changes it. If it is on, back up the recovery key. |
| TPM clear, Secure Boot keys | Clearing or replacing them can lock you out of encrypted drives and boot. |
| BIOS/UEFI flashing, `mbr2gpt`, CSM | Firmware and disk-layout changes can leave the PC unbootable. |
| Credential Guard, VBS, HVCI | Never enable with UEFI lock: it cannot be undone from Windows. |
| WDAC, AppLocker, Controlled Folder Access | Can block the installers and scripts the bootstrap runs. |
| Defender and firewall changes or exclusions | Security defaults stay as Windows ships them. |
| Pagefile size | System-managed is the safe default. |
| `powercfg /h off` | Turns off hibernation and Fast Startup together (deletes hiberfil.sys). If dual-booting, turn off only Fast Startup in Control Panel instead. |
| Hyper-V-All, Containers | WSL2 needs only VirtualMachinePlatform and Microsoft-Windows-Subsystem-Linux. |
| `.wslconfig` resource caps | Machine-specific; not managed by the bootstrap (deferred, [T-0041](../../work/active/T-0041-windows-app-list/ticket.md)). |
| Storage Sense auto-deletion, event-log clearing | Deletes data and evidence you may need later. |
| Scheduled chkdsk, DISM, SFC | Run on evidence; `sfc /verifyonly` is read-only. |
| Automatic driver updates | Can swap a working driver; update per device. |
| Static DNS, VPN | Can conflict with Tailscale's DNS and routes ([ADR-0004](../../architecture/decisions/0004-tailscale-on-windows-only.md)). |
| `wsl --unregister` and other destructive WSL commands | They delete the distro and its files. |

Security updates, Balanced power and WinRE also stay as Windows ships them.

## Manual steps after auto setup

The bootstrap (`ops/windows/bootstrap.ps1`) cannot do these: each needs a UAC
prompt, a reboot, a sign-in, a firmware setting or your approval. When a full
run finishes it prints a pointer to this section. Do them in order; skip a step
whose check already passes. Under [ADR-0019](../../architecture/decisions/0019-platform-scope-linux-macos-wsl2-first.md)
and [ADR-0011](../../architecture/decisions/0011-windows-edition-and-apps.md)
they stay manual.

| # | Action | Why | Verify |
|---|---|---|---|
| 1 | In BIOS/UEFI setup, turn on CPU virtualization (Intel VT-x or AMD SVM). | WSL2 runs a lightweight VM; without firmware virtualization it does not start. | Task Manager > Performance > CPU shows **Virtualization: Enabled** (before WSL is installed), or `wsl --list --verbose` shows `NixOS` with VERSION 2. |
| 2 | Finish any pending Windows Update reboot: Settings > Windows Update > **Restart now**. | The bootstrap refuses while a reboot is pending; a plain Start-menu restart can leave the marker set. | The dry run (`bootstrap.ps1 -DryRun`) does not stop with "step 0: reboot pending". |
| 3 | Elevated PowerShell (approve UAC): `Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent`. | WSL git and Windows git use your key through the Windows ssh-agent. | `Get-Service ssh-agent` shows Running, StartType Automatic. |
| 4 | First run only, elevated (Win+X > Terminal (Admin), approve UAC): `powershell -NoProfile -ExecutionPolicy Bypass -File ops\windows\bootstrap.ps1`. | Installs WSL and VirtualMachinePlatform and creates a restore point; both need admin. | Last line "step 1: WSL installed; reboot, then re-run in a normal PowerShell", exit 3. |
| 5 | Reboot (Settings > Windows Update > Restart now if offered), then re-run the bootstrap in a **normal** PowerShell. | Windows activates the new optional component only after a restart. | `wsl --version` prints a version; the run prints "step 2: WSL ... is new enough". |
| 6 | If a run exits 3 asking for winget source agreements, read the printed command and run it yourself if you accept. | The bootstrap never accepts license or source agreements for you. | The re-run passes step C ("chezmoi present", "gitleaks present", "lefthook present"). |
| 7 | Normal PowerShell: `ssh-add $HOME\.ssh\id_ed25519` (type the key passphrase). | Loads your key into the agent; only you know the passphrase. | `ssh -T git@github.com` greets you by your GitHub user name without a prompt. |
| 8 | Sign in to GitHub in Brave and add the public key at <https://github.com/settings/keys> (section 3). | Cloning, `git pull` and the first `nvim` launch use SSH. | Same check as step 7. |
| 9 | During step 12 of the run, answer the install profile and selection prompts. | Choosing optional tool groups is your decision; the run waits for you. | The run ends with "step 12b: done" and the pointer to this section, exit 0. |
| 10 | Inside WSL, fill your git name and email in `~/app-configs/home/.chezmoidata/personal.yaml`, then `chezmoi --source="$HOME/app-configs" apply` ([WSL setup, section 3](../wsl/setup.md#3-personal-data)). | Personal identity is never committed; T-0047 acceptance item (b). | `wsl -d NixOS --exec bash -lc 'git config user.name; git config user.email'` prints your values. Never paste the file's contents anywhere. |
| 11 | Point the WSL clone's git at the Windows ssh.exe and accept GitHub's host key after checking its fingerprint ([WSL setup, section 5](../wsl/setup.md#5-after-the-bootstrap-wsl-git-over-ssh-and-projects)). | WSL has no SSH key of its own; trusting a host key is your call. | `wsl -d NixOS --exec bash -lc '/mnt/c/Windows/System32/OpenSSH/ssh.exe -o BatchMode=yes -T git@github.com'` greets you. |
| 12 | Log in to the tools you use, in a browser: `claude` (inside WSL and on Windows separately), `gh auth login`, `op signin`. | Logins are per user and per side; tokens are never scripted. | `claude doctor`, `gh auth status` and `op whoami` succeed. |
| 13 | Inside WSL run `fish -c sys-readiness`. | Confirms the whole setup. | Exit 0, ALL SET. The only accepted TODOs: no Docker engine (opt-in) or `code` missing when Windows VS Code is not installed. |
| 14 | If Device Encryption or BitLocker is on, save the recovery key: Settings > Privacy & security > Device encryption, or <https://account.microsoft.com/devices/recoverykey>. | A firmware, TPM or Secure Boot change can ask for it; without it the drive is lost. | You can find the key outside this PC. |
| 15 | Leave `%UserProfile%\.wslconfig` without a `memory=` line (or do not create the file). | WSL's default cap is 50% of RAM; the owner's policy is percentages only, never a fixed size. | `Select-String -Path "$env:USERPROFILE\.wslconfig" -Pattern '^\s*memory\s*=' -ErrorAction SilentlyContinue` prints nothing. |
| 16 | Optional apps, each install approved by you: Windows Terminal, VS Code with the WSL extension, JetBrainsMono Nerd Font (`winget install -e --id <id>`, ids in [T-0041](../../work/active/T-0041-windows-app-list/ticket.md)); GitHub CLI and a password manager (sections 5 and 6). | Manual app list (ADR-0011); the bootstrap installs only commit tooling. | `winget list --id <id> --exact` shows each one; `code .` from WSL opens VS Code. |
| 17 | Optional: the Windows Claude status line (section 4b): dry run, real run, then open Claude in a new Windows Terminal. | T-0052 needs its real run (T6) and the visual check (H1), which only you can see. | The status line shows under the Claude prompt; the run printed its backup folder and rollback command. |

Not available yet, nothing to do: the Windows safe-settings step
(`-WindowsSettings`, T-0055) is not built, and the Ubuntu alternative (T-0040)
is needed only where an employer requires a standard distro.
