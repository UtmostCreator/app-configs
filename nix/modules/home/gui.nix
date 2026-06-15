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
      #   - else if a window of the app exists              -> activate/focus the
      #                                                        MOST-RECENTLY-USED
      #                                                        window of that app
      #   - else                                            -> launch it
      # This gives a true toggle (press to show, press again to hide) and never
      # spawns a duplicate instance.
      #
      # MRU stability: when an app has several windows (e.g. two VS Code projects
      # projectA + projectB, each a separate top-level window), the activate path
      # must return to the LAST one you actually used, not whichever happens to be
      # first in the compositor's window list. The Vicinae/Windows D-Bus `List`
      # method exposes no per-window last-focus timestamp, so we persist our own
      # tiny MRU record per wm_class under $XDG_RUNTIME_DIR. Every invocation
      # records the currently-focused window id (when it belongs to the target
      # app), and every Activate updates it too. So: focus projectA, switch to the
      # F1 browser, press Alt+Shift+E again -> projectA returns (not projectB).
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

        # Per-wm_class MRU state. Lives in the runtime dir (tmpfs, cleared on
        # logout) so stale window ids never survive a session. One file per app,
        # keyed by a sanitized wm_class, holding just the last-used window id.
        state_dir="''${XDG_RUNTIME_DIR:-/tmp}/vicinae-toggle-app"
        ${pkgs.coreutils}/bin/mkdir -p "$state_dir" 2>/dev/null || true
        mru_key="$(printf '%s' "$wm_class" | ${pkgs.gnused}/bin/sed 's#[^A-Za-z0-9._-]#_#g')"
        mru_file="$state_dir/$mru_key"

        mru_read() {
          [ -f "$mru_file" ] && ${pkgs.coreutils}/bin/cat "$mru_file" 2>/dev/null || true
        }
        mru_write() {
          printf '%s' "$1" > "$mru_file" 2>/dev/null || true
        }

        # Raw List() returns a gdbus tuple: ('[ ... json ... ]',). Strip the
        # tuple wrapper to get the inner JSON array, then query with jq.
        raw="$(gcall List 2>/dev/null || true)"
        if [ -z "$raw" ]; then
          # D-Bus unavailable — fall back to plain raise-or-launch.
          launch
        fi
        json="$(printf '%s' "$raw" | ${pkgs.gnused}/bin/sed -e "s/^(['\"]//" -e "s/['\"],)\$//")"

        # Case-insensitive match on wm_class. jq emits one window id per query
        # (or empty):
        #   focused_id = the app's currently-foreground window, if any
        #   any_id     = the first matching window (fallback target)
        #   ids        = newline-separated list of ALL matching window ids, used
        #                to validate a remembered MRU id is still alive
        focused_id="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg c "$wm_class" '
          [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
          | (map(select(.has_focus == true)) | .[0].id) // empty' 2>/dev/null)"

        any_id="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg c "$wm_class" '
          [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
          | (.[0].id) // empty' 2>/dev/null)"

        ids="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg c "$wm_class" '
          .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) | .id' 2>/dev/null)"

        # Record MRU: whenever a window of this app is focused (about to be
        # hidden or already in front), remember it as the one to restore next.
        if [ -n "$focused_id" ]; then
          mru_write "$focused_id"
        fi

        if [ -n "$focused_id" ]; then
          # App is in the foreground -> send it to the background. The MRU is
          # already recorded above, so re-pressing later returns to THIS window.
          gcall Minimize "$focused_id" >/dev/null 2>&1 || true
          exit 0
        elif [ -n "$any_id" ]; then
          # App is running but not focused -> bring forward the most-recently-used
          # window if it still exists, otherwise the first matching window. This
          # keeps multi-window apps (e.g. two VS Code projects) stable on the last
          # project you used instead of jumping to whichever is first in the list.
          target_id="$any_id"
          mru_id="$(mru_read)"
          if [ -n "$mru_id" ] && printf '%s\n' "$ids" | ${pkgs.gnugrep}/bin/grep -qxF "$mru_id"; then
            target_id="$mru_id"
          fi
          if gcall Activate "$target_id" >/dev/null 2>&1; then
            mru_write "$target_id"
            exit 0
          fi
          # If Activate failed for some reason, fall back to launch/focus.
          launch
        else
          # Not running -> launch a fresh instance.
          launch
        fi
      '')
      # Recent-projects popup for VS Code, bound to Alt+E (see
      # nix/modules/home/gnome-keybindings.nix). This is the NixOS/Linux stand-in
      # for the Raycast "VS Code - Project Manager" extension, which is macOS-only
      # and not reliable under Vicinae's Raycast-compat layer. Instead we read VS
      # Code's own recently-opened list and render it through Vicinae's native
      # `dmenu` list view (https://docs.vicinae.com/dmenu); selecting an entry
      # opens that folder with `code <folder>`.
      #
      # Source of truth: VS Code persists recently-opened folders/workspaces in
      # its globalStorage SQLite DB under the key
      # `history.recentlyOpenedPathsList`. Newer builds may also mirror it into a
      # shared-storage DB, so we read both (read-only) and de-duplicate, newest
      # first. We use python3's stdlib sqlite3 because the `sqlite3` CLI is not a
      # repo dependency; python3 is already on PATH via Nix.
      (writeShellScriptBin "vscode-recent-projects" ''
        set -euo pipefail

        # Extract recent folders (newest first, de-duplicated) from VS Code's
        # state DBs, then let the user pick one via Vicinae's dmenu popup.
        selected="$(
          ${pkgs.python3}/bin/python3 - <<'PY' | vicinae dmenu --navigation-title "VS Code" --placeholder "Open recent project…"
        from pathlib import Path
        import json
        import sqlite3
        import urllib.parse

        home = Path.home()

        # Read order = priority; first DB that yields an entry wins for ordering.
        dbs = [
            home / ".config/Code/User/globalStorage/state.vscdb",
            home / ".config/Code - Insiders/User/globalStorage/state.vscdb",
            home / ".config/VSCodium/User/globalStorage/state.vscdb",
            home / ".vscode-shared/sharedStorage/state.vscdb",
            home / ".vscode-insiders-shared/sharedStorage/state.vscdb",
            home / ".vscodium-shared/sharedStorage/state.vscdb",
        ]

        def file_uri_to_path(uri):
            if not uri or not uri.startswith("file://"):
                return None
            return urllib.parse.unquote(urllib.parse.urlparse(uri).path)

        seen = set()

        for db in dbs:
            if not db.exists():
                continue
            try:
                con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
                rows = con.execute(
                    "SELECT value FROM ItemTable "
                    "WHERE key = 'history.recentlyOpenedPathsList'"
                ).fetchall()
                con.close()
            except Exception:
                continue

            for (value,) in rows:
                try:
                    data = json.loads(value)
                except Exception:
                    continue
                for entry in data.get("entries", []):
                    path = None
                    if "folderUri" in entry:
                        path = file_uri_to_path(entry.get("folderUri"))
                    elif "workspace" in entry:
                        path = file_uri_to_path(entry["workspace"].get("configPath"))
                    if path and path not in seen and Path(path).exists():
                        seen.add(path)
                        print(path)
        PY
        )"

        # No selection (popup dismissed) -> do nothing.
        [ -n "''${selected:-}" ] || exit 0

        # Open the folder. `code` reuses the existing VS Code instance and opens
        # the folder INTO it, but on GNOME Wayland it does NOT raise/focus the
        # window when VS Code was already running in the background. So we open
        # the folder, then explicitly focus a VS Code window via the same
        # Vicinae/Windows D-Bus API used by vicinae-toggle-app.
        ${vscode}/bin/code "$selected" >/dev/null 2>&1 || true

        dest="org.gnome.Shell"
        obj="/org/gnome/Shell/Extensions/Windows"
        iface="org.gnome.Shell.Extensions.Windows"
        wm_class="code"
        # VS Code window titles embed the folder name, e.g.
        # "file - app-configs - Visual Studio Code". Match the selected project's
        # basename so we focus the RIGHT window when several projects are open.
        proj_name="$(${pkgs.coreutils}/bin/basename "$selected")"

        # `code` may need a moment to (re)attach the folder to a window before a
        # window of class `code` is listable/activatable. Poll briefly.
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          raw="$(${glib}/bin/gdbus call --session --dest "$dest" \
            --object-path "$obj" --method "$iface.List" 2>/dev/null || true)"
          [ -n "$raw" ] || { sleep 0.3; continue; }
          json="$(printf '%s' "$raw" | ${pkgs.gnused}/bin/sed -e "s/^(['\"]//" -e "s/['\"],)\$//")"
          # Prefer the `code` window whose title contains the project name; else a
          # focused `code` window; else the first `code` window.
          win_id="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg c "$wm_class" --arg n "$proj_name" '
            [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
            | ( (map(select((.title // "") | contains($n))) | .[0].id)
                // (map(select(.has_focus == true)) | .[0].id)
                // .[0].id ) // empty' 2>/dev/null)"
          if [ -n "$win_id" ]; then
            ${glib}/bin/gdbus call --session --dest "$dest" \
              --object-path "$obj" --method "$iface.Activate" "$win_id" \
              >/dev/null 2>&1 || true
            exit 0
          fi
          sleep 0.3
        done
        # D-Bus unavailable or no window yet -> `code` already did the open; exit
        # cleanly so the hotkey never wedges.
        exit 0
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
      syncthing # continuous file sync (https://syncthing.net). Runs as a HM
      #           user service (services.syncthing below) so the Web UI at
      #           http://127.0.0.1:8384 is live immediately on Linux. Driven via
      #           the sync-start / sync-open / sync-stop helpers below.
    ]
    # Syncthing control helpers (Linux personal profile only — they manage the
    # HM-declared `syncthing.service` user unit, see services.syncthing below).
    #   sync-start  start the Syncthing user service (idempotent)
    #   sync-open   ensure it is running, wait for the Web UI, then open it
    #   sync-stop   stop the Syncthing user service
    # The Web UI bind address is the Syncthing default 127.0.0.1:8384.
    ++ lib.optionals (stdenv.isLinux && config.myConfig.profile == "personal") [
      (writeShellScriptBin "sync-start" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl --user start syncthing.service
        echo "syncthing: started (Web UI at http://127.0.0.1:8384)"
      '')
      (writeShellScriptBin "sync-stop" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl --user stop syncthing.service
        echo "syncthing: stopped"
      '')
      (writeShellScriptBin "sync-open" ''
        set -euo pipefail
        url="http://127.0.0.1:8384/"
        # Start the service if it is not already active (idempotent).
        if ! ${pkgs.systemd}/bin/systemctl --user is-active --quiet syncthing.service; then
          ${pkgs.systemd}/bin/systemctl --user start syncthing.service
        fi
        # Wait for the Web UI to accept connections before opening it, so a
        # cold start does not open a "connection refused" tab (~15s max).
        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
          if ${pkgs.curl}/bin/curl -fsS -m 2 -o /dev/null "$url" 2>/dev/null; then
            break
          fi
          sleep 0.5
        done
        exec ${pkgs.xdg-utils}/bin/xdg-open "$url"
      '')
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

  # Syncthing as a Home Manager user service so the Web UI at
  # http://127.0.0.1:8384 is live immediately on Linux (personal profile only,
  # matching the syncthing package gate above). This declares the
  # `syncthing.service` user unit; the sync-start / sync-open / sync-stop helpers
  # (see home.packages above) drive it via `systemctl --user`.
  #
  # tray = false: we drive it via the Web UI + the sync-* commands, no tray app.
  # The bind address stays at Syncthing's default 127.0.0.1:8384 (GUI is
  # loopback-only). Folder/device config remains user-owned in the Web UI; this
  # only manages the daemon lifecycle, not the synced folders.
  services.syncthing = pkgs.lib.mkIf (pkgs.stdenv.isLinux && config.myConfig.profile == "personal") {
    enable = true;
    tray.enable = false;
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
            {
              # NODE-level: give the NVIDIA GPU's HDMI/DisplayPort audio sink a
              # friendly name. PipeWire labels HDMI sinks from the audio
              # CONTROLLER name (e.g. "AD106M High Definition Audio Controller
              # Digital Stereo (HDMI)"), NOT from the monitor's EDID. The monitor
              # name (e.g. "DELL S3425DW") only lives in the kernel ELD
              # (/proc/asound/card<N>/eld#0.0: monitor_name). Without this rule the
              # DELL monitor's built-in speakers show up under an unrecognizable
              # chipset name in GNOME Sound / pavucontrol, so they look "missing".
              #
              # Name-scoped to the NVIDIA HDMI output node prefix so other
              # machines / non-HDMI devices are unaffected. If you swap monitors,
              # update the description (read the current name from the ELD:
              #   grep monitor_name /proc/asound/card*/eld#0.0).
              matches = [
                { node.name = "~alsa_output.pci-.*\\.hdmi.*" }
              ]
              actions = {
                update-props = {
                  node.description = "DELL S3425DW"
                  node.nick        = "DELL S3425DW"
                }
              }
            }
          ]
        '';
      };
}
