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
