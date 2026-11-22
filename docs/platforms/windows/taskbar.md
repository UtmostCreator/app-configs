# Windows taskbar pins

Owner requests: 2026-11-16 "also add yaml and if we can setup this task panel pinned"; 2026-11-21 pins for the
installed apps and a script to unpin Copilot, Edge and Outlook. The pin list, order and unpin list are in
[taskbar-pins.yaml](taskbar-pins.yaml). `ops/windows/taskbar.ps1` applies them when you run it
([ADR-0044](../../architecture/decisions/0044-windows-taskbar-pins-script.md)); nothing else in the repo does.

## Run it
In Windows PowerShell from the repo root, after `winget import` ([apps.md](apps.md)):

```powershell
# 1. Report: what would be pinned for this profile, what is not installed, what would be unpinned. Changes nothing.
powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Manifest home      # or: -Manifest work

# 2. Unpin Edge, Copilot and Outlook now (no admin needed).
powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Unpin

# 3. Pin the profile's apps in order. Needs an elevated PowerShell on the same account; applies at the next sign-in.
powershell -ExecutionPolicy Bypass -File ops\windows\taskbar.ps1 -Manifest home -Pin
```

- `-Pin` replaces the taskbar's default pins (Edge, Store, Copilot, Outlook) with the list. You can still unpin or
  add icons afterwards; pins you remove stay removed. Install more apps later and run `-Pin` again to add them.
- `-Undo` (elevated) removes the pin policy and its XML. Pins already on the taskbar stay.
- `-Unpin` matches the English "Unpin from taskbar" verb; on another display language unpin those three by hand.

## Which apps are pinned
- `chosen` rows whose `winget` id is in the profile's manifest (`ops/windows/winget/<profile>.json`) and that are
  installed, plus `system` rows (File Explorer, Control Panel).
- Not pinned: `pending tool decision` and `unknown` rows, the Edge PDF row, and everything under `not_pinned`.
- Not installed yet: the report lists it as `skip`; install it, then run `-Pin` again.

## If it does not work
Unverified on Windows 11 Home (ADR-0044): Microsoft documents the layout policy for GPO, CSP, provisioning and
Intune; the script writes the same per-user values the GPO writes. If the pins do not appear after you sign out and
back in, run `-Undo` and pin by hand:

1. Start the app, right-click its taskbar icon, choose "Pin to taskbar" (or right-click it in Start).
2. Drag icons into the `position` order of `taskbar-pins.yaml`, left to right.
3. Skip rows whose `profiles` do not match this PC (`personal` rows on a work PC).

On a corporate PC IT usually owns the Start layout policy; the script then refuses to pin.

## Notes
- Writing the binary Taskband registry value is undocumented and fragile; still ruled out.
- `aumid` is the AppID that `Get-StartApps` prints. An empty value means the app is looked up by its Start menu name.
- HeidiSQL is a permanent Windows exception kept by the owner. Notepad++ is the Windows second editor (2026-11-21).
