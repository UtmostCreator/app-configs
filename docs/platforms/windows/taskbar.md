# Windows taskbar pins (manual checklist)

Owner request 2026-11-16: "also add yaml and if we can setup this task panel pinned". The pin list is in [taskbar-pins.yaml](taskbar-pins.yaml). Nothing in this repo applies it.

## Why it is manual
There is no supported way to pin apps on an existing account on Windows 11 Home:
- The documented mechanisms (the Taskbar layout policy, the CSP, a provisioning package or OEM start layout XML) apply at first sign-in or need Pro, Enterprise or MDM; they do not re-pin for an account that already exists. See [Configure pinned apps on the taskbar](https://learn.microsoft.com/en-us/windows/configuration/taskbar/pinned-apps).
- Writing the binary Taskband registry value is undocumented and fragile; ruled out.
- Both fall under ADR-0019 (no general Windows layer) and ADR-0011 (no registry tweaks outside the ADR-0020 catalogue).

## How to pin
1. Install the app (see the app list; installs stay manual or follow the tool-selection ADRs 0021 to 0033).
2. Start it, right-click its taskbar icon, choose "Pin to taskbar" (or search for it in Start, right-click, "Pin to taskbar").
3. Drag icons into the order of `taskbar-pins.yaml` (`position`, left to right). Skip `pending tool decision` and `unknown` rows until they are settled.
4. Skip rows whose `profiles` do not match this PC (proposed: `personal` rows on a work PC).

## Notes
- Items under `not_pinned` are deliberately not on the taskbar.
- `aumid` is the AppUserModelID where known; a `{PF}` or `%APPDATA%` value is the executable path to pin when the id is not known.
- `pending tool decision` means the tool-selection ADRs 0021 to 0033 (in progress) decide the app.
- HeidiSQL is a permanent Windows exception kept by the owner.
