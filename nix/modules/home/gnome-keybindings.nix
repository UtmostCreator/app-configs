{ lib, pkgs, ... }:
let
  # Base dconf path GNOME uses for user-defined ("custom") media-key shortcuts.
  # Each entry is a subpath holding name/command/binding keys, and the parent
  # `custom-keybindings` list must reference every subpath or GNOME ignores it.
  prefix = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";

  # Declarative custom shortcuts. `command` is run by gnome-settings-daemon when
  # `binding` is pressed.
  #
  # App shortcuts use `vicinae-toggle-app <app_id> [wm_class]` (a helper defined
  # in gui.nix) which TOGGLES the app:
  #   - focused/foreground -> minimize it (send to background)
  #   - running but not focused -> activate/focus it
  #   - not running -> launch it (never spawns a duplicate)
  # `app_id` is the desktop-entry filename without ".desktop" (used to launch).
  # `wm_class` is the running-window match class; it defaults to app_id and is
  # only passed explicitly when the two differ (VS Code, Telegram). Built on the
  # Vicinae GNOME extension (vicinae@dagimg-dot) D-Bus window API on Wayland.
  #
  # Telegram + Vesktop come from the personal profile (see gui.nix + the host
  # home.nix `myConfig.profile`).
  shortcuts = {
    # Raycast-style launcher toggle. Ctrl+Space avoids the Super+Space conflict
    # with GNOME's input-source (keyboard-layout) switcher.
    vicinae = {
      name = "Vicinae launcher";
      command = "vicinae toggle";
      binding = "<Control>space";
    };
    # Vicinae clipboard history. Deeplink form is vicinae://launch/<provider>/
    # <entrypoint> (per https://docs.vicinae.com/deeplinks); the built-in
    # clipboard history entrypoint id is `clipboard:history`. `toggle=true` makes
    # the key close the window if it's already showing.
    vicinae-clipboard = {
      name = "Vicinae clipboard";
      command = ''vicinae deeplink "vicinae://launch/clipboard/history?toggle=true"'';
      binding = "<Alt>v";
    };
    ghostty = {
      name = "Ghostty terminal";
      # wm_class == app_id (com.mitchellh.ghostty), so no second arg needed.
      command = "vicinae-toggle-app com.mitchellh.ghostty";
      binding = "<Alt><Shift>t";
    };
    # F1 is GNOME's default "show help"; a custom media-key binding overrides it.
    brave = {
      name = "Brave browser";
      # wm_class == app_id (brave-browser).
      command = "vicinae-toggle-app brave-browser";
      binding = "F1";
    };
    telegram = {
      name = "Telegram";
      # Telegram's wm_class differs from the desktop id; pass it explicitly.
      command = "vicinae-toggle-app org.telegram.desktop org.telegram.desktop";
      binding = "<Alt><Shift>r";
    };
    vesktop = {
      name = "Vesktop";
      # wm_class == app_id (vesktop).
      command = "vicinae-toggle-app vesktop";
      binding = "<Alt><Shift>d";
    };
    vscode = {
      name = "VS Code";
      # VS Code's wm_class is `code` (== app_id), confirmed live; no second arg.
      command = "vicinae-toggle-app code";
      binding = "<Alt><Shift>e";
    };
    # Alt+E: intended to open the Vicinae "vscode-recents" extension's recent-
    # projects picker. That extension IS installed declaratively
    # (services.vicinae.extensions in nix/modules/home/vicinae.nix) and present on
    # disk, but Vicinae v0.21.3 (nixpkgs build) does NOT register it as a
    # launchable entrypoint/deeplink (likely a version skew with the newer
    # vicinae-extensions flake, or it requires store-based indexing). Until that
    # is resolved, Alt+E raise-or-launches VS Code itself so the key is useful.
    # Follow-up tracked in docs/migration-followups.md.
    # Target deeplink once registration works (verify the real entrypoint id):
    #   vicinae deeplink "vicinae://launch/<provider>/open-recents"
    vscode-recents = {
      name = "VS Code recent projects (Vicinae)";
      command = "vicinae-toggle-app code Code";
      binding = "<Alt>e";
    };
    # Resize the focused window to 75% width / full height / centered, via the
    # Vicinae GNOME extension's D-Bus API (script defined in gui.nix).
    resize = {
      name = "Resize window 75% (full height, centered)";
      command = "vicinae-resize 75";
      binding = "<Alt><Shift>f";
    };
    # Screenshots via Flameshot (config shipped in gui.nix). All copy to the
    # clipboard (`-c`). GNOME's own screenshot keys stay on Print/Shift+Print.
    # F4 — interactive area select.
    flameshot-area = {
      name = "Screenshot: select area (Flameshot)";
      command = "flameshot gui -c";
      binding = "F4";
    };
    # Alt+Shift+S — repeat the previously selected region (no new selection UI),
    # so the next shot stays within the same area.
    flameshot-last-region = {
      name = "Screenshot: repeat last region (Flameshot)";
      command = "flameshot gui --last-region -c";
      binding = "<Alt><Shift>s";
    };
    # Alt+P — select an area and pin it to the screen as a floating, movable
    # overlay (Flameshot's --pin).
    flameshot-pin = {
      name = "Screenshot: pin area to screen (Flameshot)";
      command = "flameshot gui --pin";
      binding = "<Alt>p";
    };
  };

  # Build the list of fully-qualified subpaths GNOME must be told about, e.g.
  # "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghostty/".
  pathFor = key: "/${prefix}/${key}/";
  customList = map pathFor (builtins.attrNames shortcuts);

  # One dconf entry per shortcut at its subpath.
  shortcutSettings = lib.mapAttrs' (key: value: lib.nameValuePair "${prefix}/${key}" value) shortcuts;
in
{
  # GNOME global keyboard shortcuts (custom media-key bindings), managed
  # declaratively so they are reproducible instead of clicked in Settings.
  #
  # Bindings (see `shortcuts` above):
  #   Ctrl+Space   Vicinae launcher (Raycast-style)
  #   Alt+V        Vicinae clipboard history
  #   Alt+E        VS Code recent projects (Vicinae vscode-recents extension)
  #   Alt+Shift+T  Ghostty terminal      (raise-or-launch)
  #   F1           Brave browser         (raise-or-launch)
  #   Alt+Shift+R  Telegram              (raise-or-launch; personal profile)
  #   Alt+Shift+D  Vesktop               (raise-or-launch; personal profile)
  #   Alt+Shift+E  VS Code               (raise-or-launch)
  #   Alt+Shift+F  Resize focused window to 75% width / full height / centered
  #   F4           Screenshot: select area (Flameshot, -> clipboard)
  #   Alt+Shift+S  Screenshot: repeat last region (Flameshot, -> clipboard)
  #   Alt+P        Screenshot: pin selected area to screen (Flameshot)
  #
  # Linux-desktop only (imported by nix/hosts/linux-desktop/home.nix) and
  # guarded on isLinux so an accidental Darwin import is a no-op.
  dconf.settings = lib.mkIf pkgs.stdenv.isLinux (
    {
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = customList;
      };
    }
    // shortcutSettings
  );
}
