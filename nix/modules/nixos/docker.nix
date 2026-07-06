# nix/modules/nixos/docker.nix
#
# Declarative Docker daemon (engine) for NixOS hosts.
#
# The Docker CLI is already shipped in the Home Manager layer
# (nix/modules/home/dev.nix), but the daemon is a SYSTEM service
# (virtualisation.docker.*). Home Manager cannot set it; only a NixOS system
# configuration can. So this module lives in the nixos system layer and only
# applies when imported by /etc/nixos and activated with
# `sudo nixos-rebuild switch` (wire via sys-setup, like timezone/browserPolicies).
#
# Inert until `myConfig.docker.enable = true;`. Reproducible: contains zero
# host-specific values. The user added to the "docker" group is overridable via
# `myConfig.docker.user` (defaults to this repo's username in nix/vars).
#
# NOTE: `sudo systemctl start docker` starts an already-installed daemon
# imperatively. This module is the declarative equivalent: it installs and
# enables the daemon so it starts on boot and survives rebuilds.

{ config, lib, ... }:

let
  cfg = config.myConfig.docker;
in
{
  options.myConfig.docker = {
    enable = lib.mkEnableOption "the Docker daemon (system service) and docker group membership";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "utmostcreator";
      example = "alice";
      description = ''
        User added to the "docker" group so it can talk to the daemon socket
        without sudo. Defaults to this repo's username (nix/vars/default.nix).
        Set to null to skip group management (e.g. when a host declares
        users.users.<name>.extraGroups elsewhere).
      '';
    };

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run the Docker daemon rootless instead of as root. When true, the
        system-wide (root) socket is disabled and each user gets their own
        daemon. Leave false for the conventional root daemon that
        `systemctl start docker` manages.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        virtualisation.docker = {
          enable = !cfg.rootless;

          rootless = lib.mkIf cfg.rootless {
            enable = true;
            setSocketVariable = true;
          };
        };
      }

      (lib.mkIf (cfg.user != null && !cfg.rootless) {
        users.users.${cfg.user}.extraGroups = [ "docker" ];
      })
    ]
  );
}
