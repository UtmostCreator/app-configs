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

## 5. Optional: GitHub CLI

```powershell
winget install -e --id GitHub.cli
gh auth login        # choose GitHub.com, SSH, and the existing key
```

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
