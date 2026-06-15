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
    # Raycast-style launcher toggle. Ctrl+Space stays clear of the keyboard-
    # layout switcher, which this module declares as Super+Space below.
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
      # ru layout: physical V emits Cyrillic_em (м).
      cyrillic = "<Alt>Cyrillic_em";
    };
    ghostty = {
      name = "Ghostty terminal";
      # wm_class == app_id (com.mitchellh.ghostty), so no second arg needed.
      command = "vicinae-toggle-app com.mitchellh.ghostty";
      binding = "<Alt><Shift>t";
      # ru layout: physical T emits Cyrillic_ie (е). See cyrillicTwins below.
      cyrillic = "<Alt><Shift>Cyrillic_ie";
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
      # ru layout: physical R emits Cyrillic_ka (к).
      cyrillic = "<Alt><Shift>Cyrillic_ka";
    };
    vesktop = {
      name = "Vesktop";
      # wm_class == app_id (vesktop).
      command = "vicinae-toggle-app vesktop";
      binding = "<Alt><Shift>d";
      # ru layout: physical D emits Cyrillic_ve (в).
      cyrillic = "<Alt><Shift>Cyrillic_ve";
    };
    vscode = {
      name = "VS Code";
      # VS Code's wm_class is `code` (== app_id), confirmed live; no second arg.
      command = "vicinae-toggle-app code";
      binding = "<Alt><Shift>e";
      # ru layout: physical E emits Cyrillic_u (у).
      cyrillic = "<Alt><Shift>Cyrillic_u";
    };
    obsidian = {
      name = "Obsidian";
      # wm_class == app_id (obsidian), so no second arg needed.
      command = "vicinae-toggle-app obsidian";
      binding = "<Alt><Shift>o";
      # ru layout: physical O emits Cyrillic_shcha (щ).
      cyrillic = "<Alt><Shift>Cyrillic_shcha";
    };
    keepassxc = {
      name = "KeePassXC password manager";
      # KeePassXC's StartupWMClass is `keepassxc` (lowercase) while its desktop
      # id is org.keepassxc.KeePassXC, so pass the wm_class explicitly (like VS
      # Code / Telegram). Package shipped in gui.nix.
      command = "vicinae-toggle-app org.keepassxc.KeePassXC keepassxc";
      binding = "<Alt>1";
    };
    nautilus = {
      name = "Files (Nautilus)";
      # GNOME Files: desktop id == StartupWMClass (org.gnome.Nautilus), so no
      # second arg needed. Super+E mirrors Windows' Win+E "open file explorer".
      command = "vicinae-toggle-app org.gnome.Nautilus";
      binding = "<Super>e";
    };
    # Alt+E is intentionally unbound here until the Vicinae `vscode-recents`
    # extension exposes a verified recent-projects entrypoint/deeplink. Do not
    # repurpose Alt+E to toggle VS Code; it is reserved for recent projects.
    # Resize the focused window to 75% width / full height / centered, via the
    # Vicinae GNOME extension's D-Bus API (script defined in gui.nix).
    resize = {
      name = "Resize window 75% (full height, centered)";
      command = "vicinae-resize 75";
      binding = "<Alt><Shift>f";
      # ru layout: physical F emits Cyrillic_a (а).
      cyrillic = "<Alt><Shift>Cyrillic_a";
    };
    # Screenshots via Flameshot. Flameshot runs as a resident systemd user
    # service (see gui.nix `systemd.user.services.flameshot`) so its capture
    # daemon is already alive when these global hotkeys fire — this avoids the
    # GNOME Wayland cold-start portal denial ("Only the focused app is allowed
    # to show a system access dialog") that previously forced F4 onto
    # gnome-screenshot. All shots copy to the clipboard (`-c`). F4 is a function
    # key, so it is layout-independent and needs no Cyrillic twin.
    # F4 — interactive area select, then copy to clipboard.
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
      # ru layout: physical S emits Cyrillic_yeru (ы).
      cyrillic = "<Alt><Shift>Cyrillic_yeru";
    };
    # Alt+P — select an area and pin it to the screen as a floating, movable
    # overlay (Flameshot's --pin).
    flameshot-pin = {
      name = "Screenshot: pin area to screen (Flameshot)";
      command = "flameshot gui --pin";
      binding = "<Alt>p";
      # ru layout: physical P emits Cyrillic_ze (з).
      cyrillic = "<Alt>Cyrillic_ze";
    };
  };

  # GNOME custom-keybinding entries only accept name/command/binding (and the
  # `binding` schema key is a single string `s`, NOT a list — it cannot hold two
  # accelerators). Letter shortcuts therefore fail whenever a non-Latin layout
  # (here ru) is active, because GNOME matches the produced KEYSYM, not the
  # physical key: e.g. physical O under ru emits Cyrillic_shcha (щ), so
  # `<Alt><Shift>o` never matches. To make letter shortcuts layout-independent we
  # generate a SECOND entry (`<key>-cyr`) per shortcut that declares a `cyrillic`
  # accelerator, pointing at the same command but bound to the Cyrillic keysym.
  #
  # baseEntry drops the helper-only `cyrillic` attr so the dconf entry is valid.
  baseEntry = value: builtins.removeAttrs value [ "cyrillic" ];

  # The Latin (primary) entries, one per shortcut.
  latinEntries = lib.mapAttrs (_: baseEntry) shortcuts;

  # The Cyrillic twin entries, only for shortcuts that define `cyrillic`.
  cyrillicTwins = lib.mapAttrs' (
    key: value: lib.nameValuePair "${key}-cyr" (baseEntry value // { binding = value.cyrillic; })
  ) (lib.filterAttrs (_: value: value ? cyrillic) shortcuts);

  # Every entry GNOME must render (Latin primaries + Cyrillic twins).
  allEntries = latinEntries // cyrillicTwins;

  # Build the list of fully-qualified subpaths GNOME must be told about, e.g.
  # "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghostty/".
  pathFor = key: "/${prefix}/${key}/";
  customList = map pathFor (builtins.attrNames allEntries);

  # One dconf entry per shortcut (and per Cyrillic twin) at its subpath.
  shortcutSettings = lib.mapAttrs' (
    key: value: lib.nameValuePair "${prefix}/${key}" value
  ) allEntries;
in
{
  # GNOME global keyboard shortcuts (custom media-key bindings), managed
  # declaratively so they are reproducible instead of clicked in Settings.
  #
  # Bindings (see `shortcuts` above):
  #   Super+Space  Switch keyboard layout (us <-> ru; XKB grp:win_space_toggle)
  #   Ctrl+Space   Vicinae launcher (Raycast-style)
  #   Alt+V        Vicinae clipboard history
  #   Alt+Shift+T  Ghostty terminal      (raise-or-launch)
  #   F1           Brave browser         (raise-or-launch)
  #   Alt+Shift+R  Telegram              (raise-or-launch; personal profile)
  #   Alt+Shift+D  Vesktop               (raise-or-launch; personal profile)
  #   Alt+Shift+E  VS Code               (raise-or-launch)
  #   Alt+Shift+O  Obsidian              (raise-or-launch)
  #   Alt+1        KeePassXC             (raise-or-launch)
  #   Super+E      Files (Nautilus)      (raise-or-launch; Win+E parity)
  #   Alt+Shift+F  Resize focused window to 75% width / full height / centered
  #   F4           Screenshot: select area (GNOME, -> clipboard)
  #   Alt+Shift+S  Screenshot: repeat last region (Flameshot, -> clipboard)
  #   Alt+P        Screenshot: pin selected area to screen (Flameshot)
  #
  # Letter-based app/screenshot shortcuts also generate hidden `*-cyr` twins so
  # the same physical keys work when the ru Cyrillic layout is active.
  # GNOME custom shortcuts match keysyms, not physical keys, and each custom
  # shortcut accepts only one accelerator string; see `cyrillicTwins` above.
  #
  # Linux-desktop only (imported by nix/hosts/linux-desktop/home.nix) and
  # guarded on isLinux so an accidental Darwin import is a no-op.
  dconf.settings = lib.mkIf pkgs.stdenv.isLinux (
    {
      "org/gnome/desktop/interface" = {
        # Disable all GNOME UI animations (window open/close/minimize, workspace
        # and overview transitions). The app shortcuts above (Alt+Shift+<letter>)
        # raise/minimize windows constantly; with animations on, each toggle
        # plays a transition before the window settles, which makes rapid
        # app-switching feel laggy. Off = instant, snappy focus changes.
        enable-animations = false;
      };

      "org/gnome/desktop/input-sources" = {
        # Keep English (US) as the default/current layout. GNOME uses source
        # index 0 on a fresh profile, and `current = 0` makes re-activation of
        # this declarative profile settle back on US instead of the previous MRU
        # layout. `ru` remains available as the secondary layout and can be
        # selected explicitly with Super+Space when needed.
        current = lib.hm.gvariant.mkUint32 0;
        # Keep one shared layout across all apps/windows so switching in one app
        # does not make another app unexpectedly stay on a different layout.
        per-window = false;
        #
        # Layout switching is Super+Space (`grp:win_space_toggle`), NOT Alt+Shift:
        # the app/screenshot shortcuts below use Alt+Shift+<letter>, and a bare
        # Alt+Shift group toggle collides with that prefix (GNOME cannot reliably
        # tell a lone Alt+Shift layout switch apart from an Alt+Shift+letter
        # hotkey). Super+Space keeps the toggle clear of every other binding.
        sources = [
          (lib.hm.gvariant.mkTuple [
            "xkb"
            "us"
          ])
          (lib.hm.gvariant.mkTuple [
            "xkb"
            "ru"
          ])
        ];
        xkb-options = [ "grp:win_space_toggle" ];
      };

      "org/gnome/desktop/wm/keybindings" = {
        # Disable GNOME's own Super+Space input-source shortcuts so they do not
        # double-bind against the XKB `grp:win_space_toggle` option above (which
        # owns layout switching). Leaving these empty avoids two grabs on the
        # same Super+Space chord.
        switch-input-source = [ ];
        switch-input-source-backward = [ ];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = customList;
      };
    }
    // shortcutSettings
  );
}
