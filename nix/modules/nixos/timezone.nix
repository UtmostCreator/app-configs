# nix/modules/nixos/timezone.nix
#
# Shippable, reproducible system time zone for NixOS hosts.
#
# Sets the system time zone to Europe/London by default. This is a SYSTEM
# setting (time.timeZone), so it only takes effect when this module is imported
# by a NixOS configuration and applied with `sudo nixos-rebuild switch`.
#
# This repo is primarily Home Manager + nix-darwin; the live NixOS system config
# lives in /etc/nixos. To ship this default to the live host, import this module
# from /etc/nixos (e.g. via app-configs-extra.nix). See
# repo-docs/system-timezone.md for the exact wiring + apply steps.
#
# Reproducible: contains zero host-specific values. Fully overridable per host
# via `myConfig.timezone.name`.

{ config, lib, ... }:

let
  cfg = config.myConfig.timezone;
in
{
  options.myConfig.timezone = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether this module sets the system time zone. Enabled by default so
        importing the module is enough to ship the Europe/London default.
        Set to false on a host that manages time.timeZone elsewhere.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "Europe/London";
      example = "America/New_York";
      description = ''
        IANA time zone name applied to time.timeZone. Defaults to Europe/London.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.name;
  };
}
