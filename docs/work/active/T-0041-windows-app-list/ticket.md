Source: local

# T-0041: Windows-side copy-only app list (docs)

Status: BLOCKED: awaiting user approval of the Windows-scope change
(`docs/plans/migration/implementation.md` Appendix A excludes Windows package managers).
Depends on: user approval. No WSL2 ticket depends on this one.
Sequencing: edits implementation.md; do not run in parallel with T-0039.

## Summary
Once approved, document one list of Windows apps the user installs by hand with
winget, limited to apps already used on macOS or Linux, plus a "Discarded or
deferred, and why" section. No automation: repo scripts never run winget,
wsl.exe or PowerShell.

## Owned files (write boundary)
- docs/platforms/windows/apps.md (new)
- docs/plans/migration/implementation.md (Appendix A: amend the "Windows package
  managers" bullet to "a documented copy-only list is allowed; no automation",
  with a link)

## Findings
- Flameshot kept, ShareX dropped: ShareX is Windows-only, which fails the user's
  rule (the alternative must run on Windows, Linux and macOS). Flameshot's
  official Windows page lists winget (`winget install flameshot`), Scoop,
  Chocolatey, an `.msi` and a portable `.zip` (checked 2026-11-14). The Linux
  GNOME helpers (area, last region, pin) do not exist on Windows; use Flameshot's
  own hotkey settings. Its config stays unmanaged.
- Existing toasts through `powershell.exe` (ai-auth-status.sh, repo-audit.sh)
  predate this rule and are left as is.

## List (winget ids UNVERIFIED until `winget show --id <id> --exact` confirms them)
| App | Parity source | Expected id |
| --- | --- | --- |
| Windows Terminal | WSL prerequisite (built into Windows 11; for repair) | Microsoft.WindowsTerminal |
| JetBrainsMono Nerd Font | homebrew.nix font cask | DEVCOM.JetBrainsMonoNerdFont |
| VS Code | gui.nix, homebrew cask | Microsoft.VisualStudioCode |
| Brave | homebrew `brave-browser@beta`; default-apps.nix | Brave.Brave (Brave.Brave.Beta for the same channel) |
| Firefox | gui.nix, homebrew cask | Mozilla.Firefox |
| Obsidian | gui.nix, homebrew cask | Obsidian.Obsidian |
| Bruno | gui.nix, homebrew cask | Bruno.Bruno |
| LocalSend | gui.nix, homebrew cask | LocalSend.LocalSend |
| KeePassXC | gui.nix | KeePassXCTeam.KeePassXC |
| Flameshot | gui.nix; chezmoi flameshot.ini (macOS) | Flameshot.Flameshot |
| Telegram | gui.nix telegram-desktop | Telegram.TelegramDesktop |
| Double Commander | gui.nix doublecmd | alexx2000.DoubleCommander |

How to use: in PowerShell on Windows (never from WSL), one
`winget install --id <id> --exact` at a time. Take the `winget list` before/after
from docs/platforms/wsl/test-pass.md.

## Discarded or deferred, and why
Discarded:
- ShareX: Windows-only; Flameshot covers it on all three systems.
- GlazeWM, Zebar, komorebi: a tiling WM plus a bar is a keybinding system to design and maintain.
- AutoHotkey, Kanata: hotkey and remap scripts to maintain; karabiner and keyd configs do not port.
- Raycast (Windows), Vicinae (Windows), PowerToys Run: duplicate launchers; Windows search is enough.
- HeidiSQL: Windows-only.
- System Informer: Windows-only and loads a kernel driver.
- Twinkle Tray: Windows-only and monitor-specific.
- WezTerm: a second terminal; Windows Terminal is built in, and Ghostty has no Windows build.
- A `windows/` layer (`setup.ps1`, `doctor.ps1`, DSC): repo-run PowerShell and an open-ended maintenance burden.
- Registry or DSC tweaks; auto-writing /etc/wsl.conf or Terminal settings.json;
  Git Credential Manager (GitHub already goes over SSH); a 1Password SSH-agent
  bridge; native Windows dotfiles; porting macOS-only apps.
Deferred:
- PowerToys: installs trivially but bundles a launcher and key remapper that
  overlap the discarded items; install by hand if wanted.
- Syncthing on Windows: needs autostart/service and folder-layout decisions;
  Linux runs it as a Home Manager service.
- 1Password desktop: not declared on macOS or Linux here; WSL gets `op` from Nix.
- Docker Desktop vs Docker Engine: a licence and integration choice; setup.md "pick one" stands.
- A winget configure (DSC) file: only if the plain list proves insufficient.
- Windows Terminal fragment, `.wslconfig` example, clipboard paste helper.

## Acceptance criteria
- AC1: the user's approval is recorded in this ticket before any edit.
- AC2: every listed app is declared on macOS or Linux (file cited) or is a WSL prerequisite.
- AC3: every id is confirmed by the user's `winget show` output (saved as evidence) or marked unconfirmed.
- AC4: apps.md states that nothing is automated and contains the full discarded/deferred section.
- AC5: Appendix A is amended; the diff is docs only.

## Verification
- `git diff --stat` (docs only)
- A reviewer checks each row against nix/modules/home/gui.nix and nix/modules/darwin/homebrew.nix.
- Human: `winget show` per id.

## Out of scope / notes
- Installing anything; scripts; DSC.
- docs/architecture/tool-ownership.md belongs to T-0022; if approved, one sentence
  there ("copy-only list, not managed").
