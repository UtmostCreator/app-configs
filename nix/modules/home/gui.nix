{ pkgs, config, ... }:
{
  # GUI packages for Linux desktops. macOS gets GUI apps via nix-darwin
  # Homebrew casks (see nix/modules/darwin/homebrew.nix); this module is
  # imported only by linux-desktop (nix/hosts/linux-desktop/home.nix).
  #
  # Cross-platform mapping for these apps lives in
  # repo-docs/software-and-cli-tools.md ("Cross-platform install matrix").
  #
  # Guarded on isLinux so an accidental import on a Darwin build is a no-op
  # rather than pulling Linux GUI builds onto macOS.
  #
  # Keep conservative. Only add a package after confirming it exists for the
  # target platform with `nix search nixpkgs <name>`.
  home.packages =
    with pkgs;
    lib.optionals stdenv.isLinux [
      firefox # primary browser (macOS: Homebrew cask)
      brave # privacy browser; nixpkgs ships STABLE only (no brave-beta attr).
      #       macOS gets the beta channel via the brave-browser@beta cask in
      #       nix/modules/darwin/homebrew.nix.
      #       Local dev note: Brave Shields can block local servers. If a
      #       localhost / *.test / *.localhost dev URL misbehaves, allow it via
      #       brave://settings/content/siteDetails (per-site permissions).
      #       See repo-docs/default-apps.md ("Brave + local dev servers").
      ghostty # GPU terminal (macOS: Homebrew cask)
      vscode # VS Code (unfree; allowUnfree set in nix/lib/mkhome.nix)
      flameshot # screenshots with annotation
      bruno # open-source API client (Linux + macOS; macOS also via cask)
      # The Vicinae launcher is provided by services.vicinae in
      # nix/modules/home/vicinae.nix (CLI on PATH, autostart, extensions).
      # The GNOME Shell integration extension below stays a package here.
      #
      # Vicinae's GNOME Shell integration. WITHOUT this extension, Vicinae on
      # GNOME Wayland cannot drive window management or read the system
      # clipboard: its server logs "vicinae@dagimg-dot extension not installed"
      # and "Falling back to dummy clipboard server", and the launcher window
      # fails to render (shows only a placeholder icon). The extension is also
      # enabled via dconf in nix/modules/home/gnome-extensions.nix; installing
      # the package alone is not enough — GNOME must be told to load it.
      gnomeExtensions.vicinae # UUID: vicinae@dagimg-dot
      # Wayland clipboard CLI (wl-copy / wl-paste). Makes the system clipboard
      # scriptable and gives copy-on-select a reliable backing on GNOME
      # Wayland; also what most clipboard-managers/tools expect to be present.
      wl-clipboard
      # Provides `pactl` (PulseAudio/PipeWire control CLI). Vicinae logs
      # "pactl not found, audio control will not work" without it; this is the
      # CLI only — PipeWire itself is the system audio server.
      pulseaudio
      # `gdbus` (from glib) — used by the vicinae-resize script below to call
      # the Vicinae GNOME extension's window-management D-Bus interface.
      glib
      # Window resize helper bound to a GNOME keybinding (Alt+Shift+F, see
      # nix/modules/home/gnome-keybindings.nix). Resizes the focused window to a
      # percentage of the work area at full height, centered. Implemented on top
      # of the Vicinae GNOME extension's D-Bus interface
      # (org.gnome.Shell.Extensions.Windows: GetFocusedWindowSync, Maximize,
      # MoveResize) which is the same Wayland-native (Mutter) path Vicinae itself
      # uses — so it works on GNOME Wayland where wmctrl/xdotool do not. The
      # extension is enabled in gnome-extensions.nix.
      #
      # Long-term-stability note: this depends on the vicinae@dagimg-dot
      # extension being loaded (GNOME shell-version gated; see the guardrail note
      # in gnome-extensions.nix). The script degrades gracefully (exits 0 with a
      # message) if the D-Bus service is absent, so a broken/disabled extension
      # never wedges the keybinding. Hyprland would replace this with a native
      # dispatcher — tracked in repo-docs/future-upgrade-plan.md item #12.
      (writeShellScriptBin "vicinae-resize" ''
        # Usage: vicinae-resize [WIDTH_PERCENT]   (default 75)
        # Intentionally NOT using `set -e`/`pipefail`: the script guards every
        # step explicitly and uses `grep | head` pipelines (head closing early
        # would trip pipefail). Errors are handled by the empty-string checks
        # below so a missing D-Bus service exits cleanly rather than aborting.
        set -u
        pct="''${1:-75}"

        dest="org.gnome.Shell"
        obj="/org/gnome/Shell/Extensions/Windows"
        iface="org.gnome.Shell.Extensions.Windows"

        gcall() {
          ${glib}/bin/gdbus call --session --dest "$dest" \
            --object-path "$obj" --method "$iface.$1" "''${@:2}"
        }

        # Graceful degradation: if the Vicinae extension D-Bus service is not on
        # the bus (extension disabled or incompatible with the running GNOME),
        # do nothing instead of erroring out the keybinding.
        json="$(gcall GetFocusedWindowSync 2>/dev/null || true)"
        if [ -z "$json" ]; then
          echo "vicinae-resize: window D-Bus service unavailable (is the Vicinae GNOME extension enabled?)" >&2
          exit 0
        fi

        id="$(printf '%s' "$json" | ${pkgs.gnugrep}/bin/grep -oE '"id":[0-9]+' | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+' | head -1)"
        [ -n "$id" ] || { echo "vicinae-resize: no focused window" >&2; exit 0; }

        # Maximize to measure the monitor work area, then read it back.
        gcall Maximize "$id" >/dev/null 2>&1 || true
        sleep 0.35
        mjson="$(gcall GetFocusedWindowSync 2>/dev/null || printf '%s' "$json")"

        field() { printf '%s' "$mjson" | ${pkgs.gnugrep}/bin/grep -oE "\"$1\":[0-9]+" | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+' | head -1; }
        wa_w="$(field width)"; wa_h="$(field height)"
        wa_x="$(field x)";     wa_y="$(field y)"
        : "''${wa_x:=0}"; : "''${wa_y:=0}"
        [ -n "$wa_w" ] && [ -n "$wa_h" ] || { echo "vicinae-resize: could not read work area" >&2; exit 0; }

        new_w=$(( wa_w * pct / 100 ))
        new_x=$(( wa_x + (wa_w - new_w) / 2 ))   # centered

        gcall MoveResize "$id" "$new_x" "$wa_y" "$new_w" "$wa_h" >/dev/null 2>&1 || true
      '')
      # Per-app TOGGLE helper bound to the app keybindings (see
      # nix/modules/home/gnome-keybindings.nix). Behavior:
      #   - if a window of the app is FOCUSED (foreground)  -> minimize it (hide)
      #   - else if a window of the app exists              -> activate/focus it
      #   - else                                            -> launch it
      # This gives a true toggle (press to show, press again to hide) and never
      # spawns a duplicate instance.
      #
      # Usage: vicinae-toggle-app <app_id> [wm_class]
      #   app_id   = desktop-entry id (used to launch), e.g. brave-browser
      #   wm_class = window class to match running windows; defaults to app_id.
      #              VS Code / Telegram report a different wm_class than their
      #              app_id, so the keybinding passes it explicitly.
      #
      # Built on the Vicinae GNOME extension D-Bus interface
      # (org.gnome.Shell.Extensions.Windows: List, Activate, Minimize) — the same
      # Wayland-native (Mutter) path used elsewhere; falls back to
      # `vicinae app launch` if the D-Bus service is unavailable.
      (writeShellScriptBin "vicinae-toggle-app" ''
        set -u
        app_id="''${1:-}"
        wm_class="''${2:-$app_id}"
        if [ -z "$app_id" ]; then
          echo "usage: vicinae-toggle-app <app_id> [wm_class]" >&2
          exit 2
        fi

        dest="org.gnome.Shell"
        obj="/org/gnome/Shell/Extensions/Windows"
        iface="org.gnome.Shell.Extensions.Windows"

        gcall() {
          ${glib}/bin/gdbus call --session --dest "$dest" \
            --object-path "$obj" --method "$iface.$1" "''${@:2}"
        }

        launch() { exec vicinae app launch "$app_id"; }

        # Raw List() returns a gdbus tuple: ('[ ... json ... ]',). Strip the
        # tuple wrapper to get the inner JSON array, then query with jq.
        raw="$(gcall List 2>/dev/null || true)"
        if [ -z "$raw" ]; then
          # D-Bus unavailable — fall back to plain raise-or-launch.
          launch
        fi
        json="$(printf '%s' "$raw" | ${pkgs.gnused}/bin/sed -e "s/^(['\"]//" -e "s/['\"],)\$//")"

        # Case-insensitive match on wm_class. Prefer a focused window; otherwise
        # any window of the app. jq emits the chosen window id (or empty).
        focused_id="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg c "$wm_class" '
          [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
          | (map(select(.has_focus == true)) | .[0].id) // empty' 2>/dev/null)"

        any_id="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg c "$wm_class" '
          [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
          | (.[0].id) // empty' 2>/dev/null)"

        if [ -n "$focused_id" ]; then
          # App is in the foreground -> send it to the background.
          gcall Minimize "$focused_id" >/dev/null 2>&1 || true
          exit 0
        elif [ -n "$any_id" ]; then
          # App is running but not focused -> bring it forward.
          gcall Activate "$any_id" >/dev/null 2>&1 && exit 0
          # If Activate failed for some reason, fall back to launch/focus.
          launch
        else
          # Not running -> launch a fresh instance.
          launch
        fi
      '')
      # IDE: VS Code is the single IDE shipped on all systems (see vscode above).
      # IntelliJ IDEA intentionally excluded for now (was jetbrains.idea on Linux
      # / intellij-idea-ce cask on macOS). Re-add in a future slice if needed.
      # raycast / aerospace are macOS-only (meta.platforms = darwin); they are
      # declared in nix/modules/darwin/homebrew.nix and must NOT be added here.
      # Nerd fonts: add via fonts.fontconfig + a nerd-fonts.* package in a
      # separate slice if you want JetBrains Mono / Meslo managed by Nix.
    ]
    # Personal-only GUI apps. Installed ONLY when the host sets
    # `myConfig.profile = "personal";` (see nix/modules/home/profile.nix) AND on
    # Linux. Vesktop = Discord with Vencord built-in (the supported way to ship
    # Vencord; the bare `vencord` attr is just a client-mod bundle, not an app).
    ++ lib.optionals (stdenv.isLinux && config.myConfig.profile == "personal") [
      vesktop # Discord + Vencord (https://github.com/Vendicated/Vencord)
      telegram-desktop # Telegram
      syncthing # continuous file sync (https://syncthing.net). Ships the CLI +
      #           Web UI (http://localhost:8384). Running it as a background
      #           service is a system/user-service concern; see
      #           repo-docs/future-upgrade-plan.md to enable services.syncthing.
    ];

  # Flameshot configuration, managed declaratively so the screenshot keybindings
  # (F4 area-select, Alt+Shift+S repeat-last-region, Alt+P pin — see
  # nix/modules/home/gnome-keybindings.nix) behave consistently on every machine.
  # Flameshot reads ~/.config/flameshot/flameshot.ini. Key choices:
  #   - copyAndCloseAfterUpload / copy-to-clipboard: captures go to the clipboard
  #     (the keybindings also pass `-c`, this aligns the GUI buttons with it).
  #   - disabledTrayIcon=true: we drive Flameshot purely via hotkeys, no tray.
  #   - showStartupLaunchMessage=false: no first-run popup.
  #   - contrastOpacity / uiColor: readable selection UI.
  # Linux-only; flameshot is in the Linux GUI package list above.
  xdg.configFile."flameshot/flameshot.ini" = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      [General]
      disabledTrayIcon=true
      showStartupLaunchMessage=false
      showHelp=false
      saveAfterCopy=false
      copyPathAfterSave=false
      uiColor=#740096
      contrastUiColor=#2d2d2d
      contrastOpacity=128
      showSidePanelButton=true
      showDesktopNotification=true
    '';
  };
}
