Source: local

# T-0048: Cross-OS settings inventory, baseline and per-host overrides (feature)

Status: open
Depends on: none to start (phase 1 is read-only).
Blocks: none.
Relation to T-0047: independent. Apply and automation wait until the WSL2 milestone (T-0047) is done. Inventory only now.

Written 2026-11-15 against main c644dd6.

## Summary
One inventory YAML per system, compared, then a "middle ground" baseline, per-host overrides and an optional apply command.

| Phase | Work | State |
| --- | --- | --- |
| 1 | Windows inventory ([windows.yaml](windows.yaml)) | this ticket, now |
| 2 | NixOS desktop and macOS inventories (read-only commands) | later |
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
- [ ] AC-3: NixOS desktop and macOS inventories exist (phase 2).
- [ ] AC-4: baseline chosen and recorded (phase 3).
- [ ] AC-5: override mechanism with tests (phase 4).
- [ ] AC-6: apply command with `--dry-run` (phase 5).

## Safety
- Phase 1: no setting is changed. Every probe is read-only.
- Later apply steps need a restore point (`powercfg /export`) and `--dry-run` first.

## Open questions
- Where should per-host override data live long-term: chezmoi data, nix vars, or a new config dir?
- May the apply command change Windows power settings (needs admin)? Later decision.
- Which baseline values to choose?
