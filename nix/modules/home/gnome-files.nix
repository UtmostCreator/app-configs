{ lib, pkgs, ... }:
{
  # Show hidden files/folders by default in the Linux file explorer.
  #
  # GNOME Files (Nautilus) and the GTK file-chooser dialogs read these from
  # dconf; home-manager's dconf.settings writes them so the preference is
  # reproducible instead of a manual Ctrl+H / per-machine toggle.
  #
  # macOS is handled separately and ALREADY enabled: Finder's
  # `AppleShowAllFiles = true` in nix/modules/darwin/system-defaults.nix.
  #
  # Linux-desktop only (imported by nix/hosts/linux-desktop/home.nix) and
  # guarded on isLinux so an accidental Darwin import is a no-op.
  dconf.settings = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    # Nautilus (GNOME Files) — show dotfiles/dotfolders in the browser view.
    "org/gnome/nautilus/preferences" = {
      show-hidden-files = true;
    };
    # GTK3 open/save file-chooser dialogs.
    "org/gtk/settings/file-chooser" = {
      show-hidden = true;
    };
    # GTK4 open/save file-chooser dialogs (separate schema path from GTK3).
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
  };
}
