---
adr: 43
title: "Windows apps: one winget import manifest per profile, run by hand"
status: decided
date: 2026-11-21
platforms: [windows]
areas: [windows, apps, winget, profiles]
permits: [winget-import-manifest, per-profile-app-list, user-run-winget-import]
forbids: [scripted-winget-import, wsl-running-winget, store-only-or-unlisted-apps-in-manifest, auto-accepting-agreements]
amends: [11]
supersedes: []
superseded_by: []
related: [2, 19, 21, 22, 23, 24, 26, 28, 29, 31, 32, 33, 36, 37, 39, 44, T-0041]
---
# ADR-0043: Windows apps: one winget import manifest per profile, run by hand
Status: decided 2026-11-21 (owner: "now create those manifests for installion home/work profiles") · Date: 2026-11-21 · Cites: ADR-0019 (Windows additions need an ADR and an owner decision) · Amends: ADR-0011 (manual app list), T-0041 ("no automation") · Sources: [apps.md](../../platforms/windows/apps.md), `winget show --id <id> --exact` on this PC 2026-11-21

## Decision
- Commit two winget import files: `ops/windows/winget/home.json` and `ops/windows/winget/work.json` (the `winget export` schema). They list only the apps below, by exact id, with no version pin.
- The owner runs them by hand in a normal PowerShell: `winget import -i ops\windows\winget\<profile>.json`. Agreements are not pre-accepted; winget asks.
- No repo script runs `winget import`: not the bootstrap, not WSL, not CI. The bootstrap keeps its ADR-0002 scope (commit tooling, plus jq under ADR-0016).
- Anything winget cannot install, or that needs a person, goes in the [manual steps checklist](../../platforms/windows/setup.md#manual-steps-after-auto-setup).
- A test checks that each id in the manifests appears in apps.md with the same profile, and the other way round.

## Apps winget can install
Every id was found with `winget show --id <id> --exact` on 2026-11-21. Installer type matters: msix and portable install per user; wix, inno, nullsoft and exe usually install machine-wide and show a UAC prompt.

| App | id | Installer | home.json | work.json | ADR |
|---|---|---|:-:|:-:|---|
| Git for Windows | `Git.Git` | inno | yes | yes | 2 |
| Windows Terminal | `Microsoft.WindowsTerminal` | msix | yes | yes | 2 |
| JetBrainsMono Nerd Font | `DEVCOM.JetBrainsMonoNerdFont` | wix | yes | yes | T-0041 |
| VS Code | `Microsoft.VisualStudioCode` | inno | yes | yes | 26 |
| Notepad++ | `Notepad++.Notepad++` | wix | yes | yes | 26 (owner 2026-11-21: "include notepad++ latest version as a second editor") |
| Brave | `Brave.Brave` | exe | yes | yes | 22 |
| Firefox | `Mozilla.Firefox` | nullsoft | yes | yes | 22 |
| GitHub CLI | `GitHub.cli` | wix | yes | yes | 31 |
| Obsidian | `Obsidian.Obsidian` | nullsoft | yes | yes | 33 |
| Bruno | `Bruno.Bruno` | wix | yes | yes | 31 |
| Double Commander | `alexx2000.DoubleCommander` | wix | yes | yes | 28 |
| HeidiSQL | `HeidiSQL.HeidiSQL` | inno | yes | yes | 24 |
| WinSCP | `WinSCP.WinSCP` | inno | yes | yes | 29 |
| KeePassXC | `KeePassXCTeam.KeePassXC` | wix | yes | no (policy first) | 23, 39 |
| Flameshot | `Flameshot.Flameshot` | wix | yes | no (policy first) | 36 |
| TrafficMonitor Lite | `zhongyang219.TrafficMonitor.Lite` | portable | yes | no | T-0041 |
| Tailscale | `Tailscale.Tailscale` | wix | yes | never | 4, 29 |
| Telegram | `Telegram.TelegramDesktop` | inno | yes | never | 33 |
| LocalSend | `LocalSend.LocalSend` | inno | yes | never | 33 |
| Paint.NET | `dotPDN.PaintDotNet` | wix | yes | never | 36 |
| WizTree | `AntibodySoftware.WizTree` | inno | yes | never | 28 |
| Syncthing Tray | `Martchus.syncthingtray` | portable | not yet (added once ADR-0033 decides) | never | 33 |
| Vesktop | `Vencord.Vesktop` | nullsoft | not yet (added once ADR-0033 decides) | never | 33 |

Available in winget but kept out of the manifests (installed by hand when wanted): Bitwarden (`Bitwarden.Bitwarden`, the KeePassXC alternative), Signal (`OpenWhisperSystems.Signal`, deferred), Claude desktop (`Anthropic.Claude`) and ChatGPT (`OpenAI.ChatGPT`) (optional, ADR-0032), Logitech G HUB (`Logitech.GHUB`, only while the device is attached, ADR-0037). Installer types are as of 2026-11-21 and can change.

## Needs manual work (not in any manifest)
| Item | Why winget cannot do it |
|---|---|
| work.json on a corporate PC | IT may block winget or require its own portal; KeePassXC and Flameshot only if allowed |
| UAC prompts during the import | Machine-wide installers elevate one at a time |
| Brave installed outside winget | Not owned by winget, so `winget upgrade` skips it; reinstall with `Brave.Brave` to hand it over |
| VS Code WSL extension | `code --install-extension ms-vscode-remote.remote-wsl`, or Settings Sync after sign-in |
| Windows Terminal font and default WSL profile | Terminal settings, not a package (out of scope, T-0052) |
| Default browser and PDF app | Windows asks the user (Settings > Apps > Default apps) |
| Taskbar pins and order | Not winget; `ops/windows/taskbar.ps1` (ADR-0044), run by hand after the import |
| Sign-ins (GitHub, Brave sync, Obsidian, Tailscale, Telegram, KeePassXC database) | Personal accounts and secrets |
| Device software and drivers (NVIDIA, G HUB) | Per device; drivers are never mandatory (ADR-0034, ADR-0037) |
| Edge for PDF | Built into Windows; nothing to install (ADR-0036) |

## Why
- About 21 one-by-one installs become one command per profile, the Windows equivalent of the macOS Brewfile and the Nix package lists.
- A file the owner runs keeps ADR-0019's line: the repo does not install Windows apps by itself, and WSL never runs winget.
- Separate home and work files follow ADR-0021 P4 and keep personal-only apps (Tailscale, Telegram, LocalSend) off work PCs by construction.

## Strong alternatives
| Option | Why it lost |
|---|---|
| Keep the manual one-by-one list (today) | Works, but slow and error-prone on every new PC. |
| `winget configure` (DSC YAML) | Can also set settings and needs elevation and DSC modules; much more than apps. Revisit with T-0055. |
| A bootstrap switch `-Apps home\|work` | The repo would run installs; a bigger amendment to ADR-0002 and ADR-0019 than a file. Possible later. |
| Scoop or Chocolatey | A second package manager; ADR-0002 keeps winget the only one. |

## Consequences
- Done 2026-11-21: ADR-0011 and T-0041 got a dated line ("a user-run winget import manifest is allowed; no script runs it"); `home.json` (21 ids) and `work.json` (13 ids) and the parity test `tests/bash/windows-winget-manifests.bats` were added; apps.md points to them. Each id was re-checked with `winget show --id <id> --exact` on 2026-11-21.
- Adding an app means editing apps.md and the manifest together (the test enforces this).
- Unverified: whether `winget import` keeps going after one package fails (re-run to converge), and how it behaves without admin rights on a corporate PC.
