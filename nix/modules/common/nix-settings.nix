{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.myConfig.nixClientAutoOptimise = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Write auto-optimise-store into the user's nix.conf. It is a restricted
      setting: the daemon ignores it, with a warning on every nix command,
      unless the user is in trusted-users. NixOS gets trusted-users from
      sys-setup; standalone hosts such as WSL2 Ubuntu do not, so they turn
      this off and set it in /etc/nix/nix.conf instead if wanted.
    '';
  };

  config.nix = {
    package = lib.mkDefault pkgs.nix;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    }
    // lib.optionalAttrs config.myConfig.nixClientAutoOptimise {
      auto-optimise-store = true;
    };

    # Scheduled garbage collection. Without this, the Nix store grows
    # unbounded over time (every Home Manager generation + every
    # impl-detail dependency is retained). Borrowed from
    # ~/projects/nix-config common/nix-settings.nix.
    #
    # NOTE: home-manager.nix module sets nix.gc on user activation; on
    # nix-darwin and NixOS hosts this runs via a system timer/launchd
    # job. On a plain Home Manager standalone install this still wires
    # the GC schedule into the user agent.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
