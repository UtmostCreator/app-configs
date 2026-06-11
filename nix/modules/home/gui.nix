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
      flameshot # screenshots with annotation; runs as a resident systemd user
      #           service (see systemd.user.services.flameshot below) so global
      #           hotkeys (F4 / Alt+Shift+S / Alt+P) capture reliably on Wayland.
      bruno # open-source API client (Linux + macOS; macOS also via cask)
      obsidian # notes/knowledge base (unfree; macOS: Homebrew cask)
      keepassxc # offline password manager. Toggled by Alt+1 (see
      #           nix/modules/home/gnome-keybindings.nix). StartupWMClass is
      #           `keepassxc` (lowercase), so the keybinding passes it explicitly.
      #           macOS: add the keepassxc-org/tap or cask in a future slice.
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
      # GNOME Shell has no native tray/status area. AppIndicator/StatusNotifier
      # support restores the top-bar tray so Flameshot's resident-service icon
      # (and other tray apps) appear. Enabled via dconf in gnome-extensions.nix;
      # installing the package alone is not enough — GNOME must load it.
      gnomeExtensions.appindicator # UUID: appindicatorsupport@rgcjonas.gmail.com
      # Wayland clipboard CLI (wl-copy / wl-paste). Makes the system clipboard
      # scriptable and gives copy-on-select a reliable backing on GNOME
      # Wayland; also what most clipboard-managers/tools expect to be present.
      wl-clipboard
      # Provides `pactl` (PulseAudio/PipeWire control CLI). Vicinae logs
      # "pactl not found, audio control will not work" without it; this is the
      # CLI only — PipeWire itself is the system audio server.
      pulseaudio
      # USB speaker / PipeWire diagnostics for devices like Kanto ORA4:
      #   usbutils    -> lsusb (prove USB audio device enumerates)
      #   alsa-utils  -> aplay / speaker-test (ALSA card + sound test)
      #   wireplumber -> wpctl (PipeWire default sink / mute / volume)
      #   pavucontrol -> GUI mixer for moving app streams to the USB sink
      usbutils
      alsa-utils
      wireplumber
      pavucontrol
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

        # MoveResize is ignored while Mutter still considers the window maximized.
        gcall Unmaximize "$id" >/dev/null 2>&1 || true
        sleep 0.15
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
      # `vicinae app launch` if the D-Bus service is unavailable. Ghostty also
      # has a direct executable fallback because its desktop entry can be absent
      # from the active XDG application dirs even when the Nix package is on PATH.
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

        launch() {
          vicinae app launch "$app_id" && exit 0
          if [ "$app_id" = "com.mitchellh.ghostty" ]; then
            exec ${ghostty}/bin/ghostty --gtk-single-instance=true
          fi
          exit 1
        }

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
      # Tray icon ON: gives Flameshot a top-bar (notification-area) entry and,
      # crucially, keeps the Flameshot capture daemon resident. On GNOME Wayland
      # a COLD `flameshot gui` launched from a global hotkey gets its screen-grab
      # portal request denied ("Only the focused app is allowed to show a system
      # access dialog"). Running Flameshot as a resident service (see the
      # systemd user service below) + tray icon avoids that cold-start path, so
      # F4 / Alt+Shift+S / Alt+P all capture and copy reliably.
      disabledTrayIcon=false
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

  # Run Flameshot as a resident systemd user service so its capture daemon is
  # already alive when a global screenshot hotkey fires. This is what makes
  # `flameshot gui` reliable on GNOME Wayland from F4 / Alt+Shift+S / Alt+P:
  # a cold launch from a hotkey is denied the screen-grab portal, but the
  # already-running daemon owns the capture surface and copies to the clipboard.
  # The service also provides the top-bar tray icon (disabledTrayIcon=false).
  # Linux-only; flameshot is in the Linux GUI package list above.
  systemd.user.services.flameshot = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Flameshot screenshot daemon (resident for Wayland hotkey capture)";
      # Start after the graphical session + tray are up so the icon attaches.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      # `flameshot` with no subcommand runs the background daemon + tray.
      ExecStart = "${pkgs.flameshot}/bin/flameshot";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Kanto ORA4 high-quality audio, shipped declaratively so every Linux-desktop
  # PC built from this repo gets the same best-real-world setup for the speaker.
  #
  # Hardware scan (cat /proc/asound/card<N>/stream0) shows the ORA4 enumerates as
  # a USB AUDIO device on a FULL-SPEED (12 Mbit/s) link supporting 16/24-bit at
  # 44.1/48/96 kHz, 2ch. On a full-speed link 24-bit/96kHz (~4.6 Mbit/s payload)
  # sits at the edge of the bus and risks dropouts for NO audible gain on this
  # DAC/driver pair, so the safe high-quality target is 24-bit / 48 kHz.
  #
  # This is a WirePlumber 0.5+ drop-in (SPA-JSON in wireplumber.conf.d/). It is
  # MATCHED TO THE ORA4 BY NAME (node.name prefix), so machines without the
  # speaker — and other audio devices on this machine — are unaffected.
  #
  # What it locks in:
  #   - audio.format  = S24_3LE  -> stay 24-bit, don't silently drop to 16-bit
  #   - audio.rate    = 48000    -> sweet spot for the full-speed link
  #   - allowed-rates = 48000    -> avoid pointless 96k rate-switching/dropouts
  #   - node.pause-on-idle = false -> don't clip the first moment of playback
  #   - api.alsa.soft-mixer = true -> SOFTWARE volume (see below)
  # Global resampler quality is left at the PipeWire default (already high); we
  # intentionally keep this device-scoped rather than changing global audio.
  #
  # Why soft-mixer: the ORA4's hardware volume (PCM Playback Volume in
  # /proc/asound/card<N>/usbmixer) is GAIN-ONLY, range 0..+16 dB, with
  # Base Volume = 0 dB landing at ~54% on the PipeWire slider. Below ~54% the
  # device has no attenuation headroom left, so the control collapses toward its
  # min and the output falls off a cliff to silence — that is the "stops working
  # below 50%" behaviour. Setting soft-mixer makes PipeWire attenuate digitally
  # instead, giving smooth, linear, granular volume across the full 0-100% range
  # with no dead zone. Tradeoff: digital attenuation at very low levels trims a
  # few bits of headroom, but on a 24-bit stream this is inaudible.
  #
  # Verify after a rebuild + relog (or `systemctl --user restart wireplumber`):
  #   pactl list sinks | grep -A6 -i kanto   # Sample Spec should read s24le 48000Hz
  #   pw-metadata -n settings | grep -i ora   # rule presence
  # See repo-docs/ora4-audio.md.
  xdg.configFile."wireplumber/wireplumber.conf.d/51-kanto-ora4.conf" =
    pkgs.lib.mkIf pkgs.stdenv.isLinux
      {
        text = ''
          monitor.alsa.rules = [
            {
              # DEVICE-level: disable ACP for the ORA4. With api.alsa.use-acp =
              # true (the default), ALSA Card Profile owns the mixer and re-exposes
              # the gain-only HARDWARE volume, which OVERRIDES node-level
              # soft-mixer (verified via pw-dump: device use-acp=true beat the
              # node's soft-mixer=true and the sink kept HW_VOLUME_CTRL). Turning
              # ACP off makes PipeWire use the plain ALSA path so soft-mixer wins.
              matches = [
                { device.name = "~alsa_card.usb-Kanto_Audio_ORA4_by_Kanto.*" }
              ]
              actions = {
                update-props = {
                  api.alsa.use-acp = false
                }
              }
            }
            {
              # NODE-level: lock format and force SOFTWARE volume so granular
              # volume below ~54% no longer falls off a cliff to silence.
              matches = [
                { node.name = "~alsa_output.usb-Kanto_Audio_ORA4_by_Kanto.*" }
              ]
              actions = {
                update-props = {
                  audio.format       = "S24_3LE"
                  audio.rate         = 48000
                  audio.allowed-rates = [ 48000 ]
                  node.pause-on-idle = false
                  api.alsa.soft-mixer = true
                }
              }
            }
          ]
        '';
      };
}
