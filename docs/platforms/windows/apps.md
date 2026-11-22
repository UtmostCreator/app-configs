# Windows apps

Installed by the owner, in a normal PowerShell on Windows (never from WSL), with
one winget import file per profile
([ADR-0043](../../architecture/decisions/0043-windows-winget-app-manifests.md)):

```powershell
winget import -i ops\windows\winget\home.json    # Home
winget import -i ops\windows\winget\work.json    # Corporate
```

winget asks for the agreements and each machine-wide installer shows a UAC
prompt. Re-run the import if one package fails; installed apps are skipped. No
repo script runs the import ([ADR-0019](../../architecture/decisions/0019-platform-scope-linux-macos-wsl2-first.md)).
A single app still installs with `winget install --id <id> --exact`.
Tool choices come from the tool-selection ADRs 0021 to 0037. Taskbar pins and
order are in [taskbar-pins.yaml](taskbar-pins.yaml), applied by
[taskbar.md](taskbar.md). Source list: [T-0041](../../work/active/T-0041-windows-app-list/ticket.md).

Profiles: **Home** = personal PC, `home.json`. **Corporate** = employer PC,
`work.json` (ADR-0021 P4, ADR-0020 `work`). On a corporate PC, employer policy
wins: use the company portal when IT provides one, and skip anything IT does not
allow. "if allowed" apps are not in `work.json`; install them by id once IT
allows them. Without admin rights, add `--scope user` where the package supports it.

The tables and the manifests must agree: Home `yes` = in `home.json`, Corporate
`yes` = in `work.json` (checked by `tests/bash/windows-winget-manifests.bats`).
Every id in the manifests was confirmed with `winget show --id <id> --exact` on
2026-11-21.

## Base (both profiles)

| App | Why | winget id | Home | Corporate |
|---|---|---|:-:|:-:|
| Git for Windows | Clone, commit hooks (setup section 2) | `Git.Git` | yes | yes |
| Windows Terminal | WSL and Claude sessions | `Microsoft.WindowsTerminal` | yes | yes |
| JetBrainsMono Nerd Font | Glyphs for the shell prompt and status line | `DEVCOM.JetBrainsMonoNerdFont` | yes | yes |
| VS Code (+ WSL extension) | Editor; `code .` from WSL | `Microsoft.VisualStudioCode` | yes | yes |
| Notepad++ | Second editor, latest version; Windows-only owner exception 2026-11-21 (ADR-0026) | `Notepad++.Notepad++` | yes | yes |
| Brave | Default browser (ADR-0022) | `Brave.Brave` | yes | yes |
| Firefox | Second browser (ADR-0022) | `Mozilla.Firefox` | yes | yes |
| GitHub CLI | `gh auth`, PRs | `GitHub.cli` | yes | yes |
| Obsidian | Notes (ADR-0033) | `Obsidian.Obsidian` | yes | yes |
| Bruno | API client (ADR-0031) | `Bruno.Bruno` | yes | yes |
| Double Commander | Dual-pane files (ADR-0028) | `alexx2000.DoubleCommander` | yes | yes |
| KeePassXC | Password manager (ADR-0039); Bitwarden allowed instead | `KeePassXCTeam.KeePassXC` | yes | if allowed |
| HeidiSQL | DB client, permanent Windows exception (ADR-0024) | `HeidiSQL.HeidiSQL` | yes | yes |
| WinSCP | SFTP GUI, Windows exception (ADR-0029) | `WinSCP.WinSCP` | yes | yes |
| Flameshot | Screenshots (ADR-0036) | `Flameshot.Flameshot` | yes | if allowed |
| TrafficMonitor Lite | Taskbar CPU/RAM/network meter (T-0041) | `zhongyang219.TrafficMonitor.Lite` | yes | if allowed |
| PDF | Edge, built in (ADR-0036); nothing to install; not pinned on the taskbar | none | yes | yes |

The bootstrap installs chezmoi, gitleaks, lefthook and (with `-ClaudeStatusLine`) jq itself.

## Home only

| App | Why | winget id | Home |
|---|---|---|:-:|
| Tailscale | Tailnet on Windows only (ADR-0004); never on work hosts (ADR-0029) | `Tailscale.Tailscale` | yes |
| Telegram | Chat (ADR-0033) | `Telegram.TelegramDesktop` | yes |
| Vesktop | Discord client (ADR-0033, proposed) | `Vencord.Vesktop` | once ADR-0033 decides |
| LocalSend | LAN file transfer; a LAN listener, so not on work PCs | `LocalSend.LocalSend` | yes |
| Paint.NET | Images, Windows personal exception (ADR-0036) | `dotPDN.PaintDotNet` | yes |
| WizTree | Disk usage, Windows personal exception; replaces TreeSize (ADR-0028) | `AntibodySoftware.WizTree` | yes |
| Syncthing Tray | Syncthing on Windows (ADR-0033, proposed) | `Martchus.syncthingtray` | once ADR-0033 decides |
| Signal | Deferred (ADR-0033) | `OpenWhisperSystems.Signal` | no (deferred) |
| ChatGPT, Claude desktop | Optional, by hand (ADR-0032) | install from the vendor | by hand |
| Device software (Logitech G HUB, NVIDIA, ...) | Only while the device is attached; never mandatory (ADR-0037, ADR-0034) | per device | by hand |

## Not installed (decided or proposed discards)

PuTTY (OpenSSH instead, ADR-0029), PhpStorm (ADR-0026),
GitHub Desktop and Git Extensions (lazygit, gh and VS Code instead, ADR-0031),
TreeSize (WizTree, ADR-0028), Acrobat (only if an employer workflow needs it,
ADR-0036), ShareX, PowerToys Run, System Informer (T-0041).

## Verify

`winget list --id <id> --exact` shows each installed app. Apps installed outside
winget (for example Brave from its own installer) show without an id and are not
upgraded by `winget upgrade`; reinstall with the id if you want winget to own it.
