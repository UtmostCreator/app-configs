# Use the working PC while installing the Niri laptop

| Machine | During the rehearsal | During the laptop install |
| --- | --- | --- |
| Working NixOS/GNOME PC | Open Claude in the reviewed checkout, build `linux-niri`, host the disposable UEFI guest. Keep the runbook and recovery material accessible. | Continue using GNOME. If using the attached Kingston SSD route, require a tested disk guard before writing, protect the source ESP and firmware, and move the SSD to the laptop for its first boot. |
| Older laptop, first physical test | Boot the installer USB to identify the storage controller, GPU, firmware and network needs; retain a reviewed hardware module separate from Disko. | Prefer the USB route. Unlock the dedicated disk at cold boot, log in to Niri with an empty home and run the real-device acceptance tests. |

Use the same repository revision, lockfile, Disko layout and integrated Home Manager deployment for both routes. Keep the first authenticated login independent of SSH, a desktop shell and a second installer. If you later enrol SSH, use the PC's public key and verify password and root logins are refused before relying on it for recovery.

The existing `linux-desktop-pilot` flake output is a GNOME/GDM test fixture. The migration target is `linux-niri`. Use the [media guide](../platforms/nixos/niri-install-media.md) when the flash drive or Kingston is available. The [runbook](../platforms/nixos/niri-install.md) covers target identification, the VM rehearsal, password enrolment and recovery; the [migration plan](niri-migration.md) collects the acceptance gates.
