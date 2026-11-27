{ pkgs }:
let
  settings = pkgs.writeText "dux-trial-settings.json" (
    builtins.toJSON {
      loginctlLockIntegration = false;
      customPowerActionLock = ''${pkgs.systemd}/bin/loginctl lock-session "$XDG_SESSION_ID"'';
      syncModeWithPortal = false;
      dockConfigs = [ ];
      barConfigs = [
        {
          id = "default";
          name = "Taskbar";
          enabled = true;
          position = 1; # Bottom in Dux 2.1.2.
          screenPreferences = [ "all" ];
          leftWidgets = [
            "workspaceSwitcher"
            "runningApps"
          ];
          centerWidgets = [ "clock" ];
          rightWidgets = [
            "systemTray"
            "notificationButton"
            "battery"
            "controlCenterButton"
          ];
        }
      ];
    }
  );
  clipboard = pkgs.writeText "dux-trial-clsettings.json" (builtins.toJSON { disabled = true; });
  session = pkgs.writeShellApplication {
    name = "niri-dux-trial-session";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dux-shell
      pkgs.quickshell
    ];
    text = ''
      umask 077
      export HOME="''${RUNTIME_DIRECTORY:?Run via niri-dux-trial}"
      export XDG_CONFIG_HOME="$HOME/config" XDG_CACHE_HOME="$HOME/cache"
      export XDG_DATA_HOME="$HOME/data" XDG_STATE_HOME="$HOME/state"
      export DMS_DISABLE_POLKIT=1 DMS_DISABLE_MATUGEN=1 GSETTINGS_BACKEND=memory
      mkdir -p "$XDG_CONFIG_HOME/dms" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
      install -m 600 ${settings} "$XDG_CONFIG_HOME/dms/settings.json"
      install -m 600 ${clipboard} "$XDG_CONFIG_HOME/dms/clsettings.json"
      exec dms run
    '';
  };
in
pkgs.writeShellApplication {
  name = "niri-dux-trial";
  runtimeInputs = [ pkgs.systemd ];
  text = ''
    case "''${1:-}" in
      --version) exec ${pkgs.dux-shell}/bin/dms version ;;
      -h|--help) printf '%s\n' 'Usage: niri-dux-trial [--version]' 'Stop: systemctl --user stop niri-dux-trial.service'; exit 0 ;;
      "") ;;
      *) printf '%s\n' 'Usage: niri-dux-trial [--version]' >&2; exit 2 ;;
    esac

    if [[ ''${XDG_CURRENT_DESKTOP:-} != niri || ! -S ''${NIRI_SOCKET:-} ||
          -z ''${WAYLAND_DISPLAY:-} || -z ''${XDG_SESSION_ID:-} ]]; then
      printf '%s\n' 'Start the trial from a terminal inside the installed Niri session.' >&2
      exit 1
    fi
    notification_owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
      org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
    if [[ $notification_owner != 'b false' ]]; then
      printf '%s\n' 'The session already has a notification provider.' >&2
      exit 1
    fi

    exec systemd-run --user --collect --unit=niri-dux-trial --property=Type=exec \
      --property=RuntimeDirectory=niri-dux-trial --property=RuntimeDirectoryMode=0700 \
      --setenv="PATH=$PATH" --setenv="XDG_SESSION_ID=$XDG_SESSION_ID" \
      --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" --setenv="NIRI_SOCKET=$NIRI_SOCKET" \
      --setenv=XDG_CURRENT_DESKTOP=niri --setenv=XDG_SESSION_TYPE=wayland \
      --setenv="XDG_DATA_DIRS=''${XDG_DATA_HOME:-$HOME/.local/share}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
      ${session}/bin/niri-dux-trial-session
  '';
}
