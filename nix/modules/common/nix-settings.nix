{ pkgs, ... }:
{
  nix = {
    package = pkgs.nix;

    settings = {
      experimental-features = [ "nix-command" "flakes" ];
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
