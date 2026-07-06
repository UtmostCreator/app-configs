# NixOS system-layer keyboard setup for laptop top-row function keys.
#
# GNOME dconf shortcuts only see keys after the compositor/session stack has
# accepted them. Prefer the firmware/EC Fn-lock switch when Linux exposes it so
# the top row emits function keys by default. On this host that control is
# `/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/fn_lock` and was observed as
# `0` (hotkey/media mode). A boot service sets it to `1`.
#
# Keep keyd fallbacks too: `keyd monitor` showed the physical F1/top-row key as
# brightnessdown and the physical F4/top-row key as dashboard when Fn-lock is
# off. `keyd` remaps below GNOME, similar in spirit to a Windows registry
# scan-code remap, so Home Manager GNOME shortcuts can bind normal F1/F4.
#
# Import this from the live NixOS system config, then run nixos-rebuild.

{ pkgs, ... }:

{
  systemd.services.ideapad-fn-lock = {
    description = "Prefer function keys on the laptop top row";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "ideapad-fn-lock" ''
        set -eu
        for path in \
          /sys/bus/platform/drivers/ideapad_acpi/*/fn_lock \
          /sys/bus/platform/devices/*/fn_lock \
          /sys/devices/platform/*/fn_lock
        do
          if [ -w "$path" ]; then
            printf '1' > "$path"
            exit 0
          fi
        done
        exit 0
      '';
    };
  };

  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        # keyd key names are lower-case evdev-style names. The physical F1 key
        # was observed as brightnessdown via `keyd monitor`; the physical F4 key
        # was observed as dashboard.
        brightnessdown = "f1";
        dashboard = "f4";
      };
    };
  };
}
