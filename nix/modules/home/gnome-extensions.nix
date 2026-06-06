{ lib, pkgs, ... }:
{
  # Enable the GNOME Shell extensions this config ships.
  #
  # Installing an extension package (see gui.nix) only places its files on
  # disk; GNOME does NOT load an extension until its UUID is listed in
  # `org/gnome/shell` `enabled-extensions`. home-manager's dconf.settings
  # writes that key so the preference is reproducible instead of a manual
  # `gnome-extensions enable ...` per machine.
  #
  # Currently enabled:
  #   - vicinae@dagimg-dot  (gnomeExtensions.vicinae) — required for Vicinae's
  #     window-management + clipboard integration on GNOME Wayland. Without it
  #     the Vicinae server falls back to a "dummy" clipboard server and the
  #     launcher window fails to render. Package added in gui.nix.
  #
  # NOTE: GNOME loads newly enabled extensions at the start of a Shell
  # session. On Wayland (this host), the Shell cannot be hot-reloaded, so a
  # log out / log back in is required after the first `home-manager switch`
  # that adds an extension. (On X11, Alt+F2 -> `r` would suffice.)
  #
  # Linux-desktop only (imported by nix/hosts/linux-desktop/home.nix) and
  # guarded on isLinux so an accidental Darwin import is a no-op.
  dconf.settings = lib.mkIf pkgs.stdenv.isLinux {
    "org/gnome/shell" = {
      enabled-extensions = [
        "vicinae@dagimg-dot"
      ];
    };
  };
}
