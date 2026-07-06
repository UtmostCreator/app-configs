# NixOS system-layer keyboard remap for laptop top-row F1.
#
# GNOME dconf shortcuts only see keys after the compositor/session stack has
# accepted them. On this Lenovo laptop, the physical F1/top-row key can arrive as
# the media mute key instead of logical F1, and GNOME logs showed it would not
# reliably let a custom shortcut grab that media keysym. `keyd` remaps it below
# GNOME, similar in spirit to a Windows registry scan-code remap, so the existing
# Home Manager GNOME shortcut can bind normal F1 to Brave.
#
# Import this from the live NixOS system config, then run nixos-rebuild.

{ ... }:

{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        # keyd key names are lower-case evdev-style names. The laptop media mute
        # keysym becomes logical F1 before GNOME handles user shortcuts.
        mute = "f1";
      };
    };
  };
}
