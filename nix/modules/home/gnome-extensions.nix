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
  #   - appindicatorsupport@rgcjonas.gmail.com
  #     (gnomeExtensions.appindicator) — GNOME Shell has NO native status/tray
  #     area. This extension restores the top-bar tray (notification area) so
  #     Flameshot's tray icon (and other AppIndicator/StatusNotifier apps) show
  #     up. Required for the Flameshot resident service's icon. Package in gui.nix.
  #
  # NOTE: GNOME loads newly enabled extensions at the start of a Shell
  # session. On Wayland (this host), the Shell cannot be hot-reloaded, so a
  # log out / log back in is required after the first `home-manager switch`
  # that adds an extension. (On X11, Alt+F2 -> `r` would suffice.)
  #
  # LONG-TERM-STABILITY GUARDRAIL (vicinae@dagimg-dot): this extension is the
  # backbone of Vicinae's window-management + clipboard integration AND of the
  # `vicinae-resize` keybinding (Alt+Shift+F; see gui.nix + gnome-keybindings.nix).
  # GNOME hard-gates extensions by `shell-version` in their metadata.json; the
  # packaged extension currently supports GNOME shell 46–50. On a GNOME *major*
  # upgrade (51+), GNOME will REFUSE to load it until upstream republishes and
  # nixpkgs ships the new build — which would break Vicinae window/clipboard +
  # the resize hotkey together. Before bumping GNOME major versions, confirm the
  # extension's shell-version list includes the target release:
  #   nix eval --raw nixpkgs#gnomeExtensions.vicinae.passthru ... (or inspect
  #   metadata.json under the extension's store path).
  # The `vicinae-resize` script degrades gracefully if the D-Bus service is gone,
  # so a stale extension never wedges the keybinding — it just no-ops.
  # The longer-term alternative (Hyprland, native resize, no extension) is
  # evaluated in repo-docs/future-upgrade-plan.md item #12.
  #
  # Linux-desktop only (imported by nix/hosts/linux-desktop/home.nix) and
  # guarded on isLinux so an accidental Darwin import is a no-op.
  dconf.settings = lib.mkIf pkgs.stdenv.isLinux {
    "org/gnome/shell" = {
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "vicinae@dagimg-dot"
      ];
    };
  };
}
