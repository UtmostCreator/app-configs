Source: local

# T-0048: Cross-OS settings inventory, baseline and per-host overrides (feature)

Status: in progress (Windows and macOS inventories done; NixOS desktop capture, baseline, overrides and apply open)
Depends on: none to start (phase 1 is read-only).
Blocks: none.
Relation to T-0047: independent. Apply and automation wait until the WSL2 milestone (T-0047) is done. Inventory only now.

Written 2026-11-15 against main c644dd6.

## Summary
One inventory YAML per system, compared, then a "middle ground" baseline, per-host overrides and an optional apply command.

| Phase | Work | State |
| --- | --- | --- |
| 1 | Windows inventory ([windows.yaml](windows.yaml)) | this ticket, now |
| 2 | NixOS desktop and macOS inventories (read-only commands) | macOS done ([macos.yaml](macos.yaml), 2026-11-20); NixOS desktop pending |
| 3 | Compare, choose the baseline | later |
| 4 | Per-host override mechanism | later |
| 5 | Apply/change command (e.g. `screen-off <min>`) | later, after T-0047 |

NixOS-WSL has no display or power settings: it inherits Windows. No inventory for it.

## Scope
Class: align / platform-specific / skip. Skip (per-device): brightness, scaling, audio, fonts.

| Setting | Windows source | NixOS source | macOS source | Class |
| --- | --- | --- | --- | --- |
| display off AC/DC | powercfg SUB_VIDEO VIDEOIDLE | unknown (compositor idle config) | pmset displaysleep | align |
| sleep AC/DC | powercfg SUB_SLEEP STANDBYIDLE | unknown (logind, idle daemon) | pmset sleep | align |
| hibernate after AC/DC | powercfg SUB_SLEEP HIBERNATEIDLE | unknown | pmset standbydelay | platform-specific |
| lock on wake | powercfg /qh SUB_NONE CONSOLELOCK | unknown (locker config) | defaults askForPassword | align |
| lid close AC/DC | powercfg /qh SUB_BUTTONS LIDACTION | logind HandleLidSwitch | none direct | platform-specific |
| power button AC/DC | powercfg /qh SUB_BUTTONS PBUTTONACTION | logind HandlePowerKey | none | platform-specific |
| sleep button | powercfg /qh SUB_BUTTONS SBUTTONACTION | logind HandleSuspendKey | none | skip |
| hibernation enabled | powercfg /a | unknown | pmset hibernatemode | platform-specific |
| fast startup | HKLM Power HiberbootEnabled | n/a | n/a | skip |
| theme light/dark | HKCU Personalize AppsUseLightTheme | unknown (gsettings or none) | defaults AppleInterfaceStyle | align |
| night light | manual | manual | manual | skip |
| keyboard layout | Get-WinUserLanguageList | unknown | defaults HIToolbox | align |
| key repeat delay/speed | HKCU Control Panel Keyboard | unknown | defaults KeyRepeat, InitialKeyRepeat | align |
| mouse/touchpad scroll | HKCU PrecisionTouchPad ScrollDirection | unknown | defaults swipescrolldirection | align |
| timezone | Get-TimeZone | timedatectl | systemsetup -gettimezone | align |
| locale | Get-Culture, Get-WinSystemLocale | locale | defaults AppleLocale | align |
| default browser | HKCU UrlAssociations http UserChoice ProgId | xdg-settings get default-web-browser | LaunchServices (read-only check) | align |

NixOS and macOS sources are unverified research input until phase 2.

### Shared defaults and intentional differences

| Setting | macOS | Native NixOS desktop | Windows host / WSL |
| --- | --- | --- | --- |
| Time zone | nix-darwin defaults to `Europe/London` | NixOS time zone module defaults to `Europe/London` where imported | `GMT Standard Time` observed on Windows; `Europe/London` observed in NixOS-WSL; Windows configuration stays manual |
| Clock display | nix-darwin enables 24-hour time | GNOME Home Manager profile uses `24h` | `HH:mm` observed on Windows; WSL has no desktop clock |
| Browser | Stable Brave via Homebrew and Launch Services | Stable Brave via Nix and desktop associations | Brave observed on Windows; install and default selection stay manual |
| PDF viewer | Preview (ADR-0036) | Brave | Keep the platform's separate PDF choice; not a shared MIME policy |
| Desktop and power | Finder, Dock, and input defaults stay in nix-darwin; power and other host preferences are not copied | GNOME preferences stay in dconf; physical power settings require a native-host inventory | See the Windows inventory. WSL inherits the host's display and power behavior |

These are selected defaults, not a complete baseline. Do not copy raw repeat,
power, or scroll values between operating systems: the units and semantics
differ. Use the [Mac checks](../../../platforms/macos/setup.md#cross-platform-checks)
and the [Windows inventory](windows.yaml); a live NixOS desktop capture and
end-to-end Mac activation are still pending.

## Owner proposals under AC-4 (2026-11-20, not a baseline)
- GNOME follows the work Mac: idle blank after 10 min, lock 60 s after blanking, natural scrolling off, tap to click, light theme, launcher Alt+Space on every OS.
- Key repeat is converted, not copied: macOS `InitialKeyRepeat` 30 and `KeyRepeat` 2 are 15 ms ticks, so 450 ms and 30 ms; GNOME `delay` 450 and `repeat-interval` 30 are milliseconds; Windows `KeyboardDelay` 1 is 500 ms.
- The Mac is MDM-managed. A setting enforced by policy is preserved, and the Mac values stay unchanged where management status is unknown (the ADR-0020 work-profile rule).

## macOS drift decisions and settings still to record (2026-11-20)
- Key repeat: the declared value now matches the live Mac (resolved).
- 24-hour clock: declared on, live not set and the menu-bar clock shows AM/PM. Open: choose which side wins; do not fix it silently during activation.
- JSON files open in a browser while other development files open in the editor: open decision.
- Still to record before anything is applied (record first; apply only when approved and not MDM-managed): Focus and notifications, clipboard history and sync, Spotlight exclusions, display and external monitors (device-specific), mouse against built-in trackpad, and the Dock's pinned set (the 19-app Dock lists overlapping database clients; a smaller everyday Dock is a possible follow-up, the full catalogue stays separate).

## YAML schema
```yaml
system: windows            # windows | nixos | macos
captured: 2026-11-15       # UTC date
source: {os, edition_id, display_version, build, form_factor, power_scheme: {name, guid}, reboot_pending, note}
settings:                  # keys sorted, cross-OS neutral names
  display_off: {ac: 300, dc: 180, unit: s, raw: SUB_VIDEO VIDEOIDLE, how: <read command>}
  theme: {value: {}, unit: enum, raw: <registry path>, how: <read command>}
  lid_close: {ac: sleep, dc: sleep, unit: enum, raw: SUB_BUTTONS LIDACTION, how: powercfg /qh ...}
```
- `ac`/`dc` only where the setting has both; else `value`.
- `unit`: s, min, enum, bool or manual (read by hand, no command).
- `unknown` or `unavailable: <reason>` when a value cannot be read (e.g. needs elevation). Never guess.

## Windows capture notes (2026-11-15)
- `powercfg /query` hides lid, power button, sleep button and CONSOLELOCK. `powercfg /qh` (query hidden) reads them non-elevated: all four are 1 on AC and DC (sleep; require sign-in).
- Machine is mid-upgrade Home to Pro, reboot pending: `reboot_pending: true`.
- Touchpad ScrollDirection is stored raw; its meaning is not machine-verified.

## Acceptance criteria
- [ ] AC-1: the Windows YAML exists, parses, and every value was read on this PC by the stated command (no guesses). Parse check pending: no YAML parser on this PC.
- [ ] AC-2: a re-capture reproduces it (deterministic ordering).
- [ ] AC-3: NixOS desktop and macOS inventories exist (phase 2). macOS done; the NixOS desktop capture is outstanding.
- [ ] AC-4: baseline chosen and recorded (phase 3).
- [ ] AC-5: override mechanism with tests (phase 4).
- [ ] AC-6: apply command with `--dry-run` (phase 5).

## Safety
- Phase 1: no setting is changed. Every probe is read-only.
- Later apply steps need a restore point (`powercfg /export`) and `--dry-run` first.

## Open questions
- Where should per-host override data live long-term: chezmoi data, nix vars, or a new config dir?
- May the apply command change Windows power settings (needs admin)? Later decision.
- 2026-11-16 note: ADR-0020 amends ADR-0010 for step W's scope only: apply may run before T-0047 completes, replacing the restore point and powercfg requirement with a committed snapshot, undo.json and `-DryRun` (non-elevated scope). The step-W snapshot is not phase 3 (baseline); windows.yaml stays the read-only inventory. See T-0055. ADR-0034 and ADR-0035 also amend ADR-0010: the NVIDIA profile step and `-MachineWide` may apply before T-0047 completes (owner 2026-11-16, "Yes, allow now").
- Which baseline values to choose?
