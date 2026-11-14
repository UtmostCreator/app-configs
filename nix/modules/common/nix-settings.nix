{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.myConfig;
in
{
  options.myConfig.nixClientAutoOptimise = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Write auto-optimise-store into the user's nix.conf. It is a restricted
      setting: the daemon ignores it, with a warning on every nix command,
      unless the user is in trusted-users. Off by default for that reason;
      set it to true only on a host whose daemon trusts this user, or set it
      in /etc/nix/nix.conf instead.
    '';
  };

  options.myConfig.nixSystemManaged = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      The host's own Nix installation owns the package and nix.conf
      (Determinate Nix on macOS). Home Manager then leaves nix.package null
      and writes no user nix.conf (it needs a non-null nix.package to
      generate one). Every other host leaves this false: Home Manager writes
      the user nix.conf with extra-experimental-features, which is harmless
      where the system already enables flakes (NixOS) and needed elsewhere.
      Home Manager never puts nix.package on PATH, so it cannot shadow the
      system Nix. Daemon settings (trusted-users, auto-optimise-store) belong
      in /etc/nix/nix.conf.
    '';
  };

  config.nix = lib.mkMerge [
    (lib.mkIf (!cfg.nixSystemManaged) {
      package = lib.mkDefault pkgs.nix;

      settings = {
        # extra-* appends to the system nix.conf value instead of replacing it.
        extra-experimental-features = [
          "nix-command"
          "flakes"
        ];
      }
      // lib.optionalAttrs cfg.nixClientAutoOptimise {
        auto-optimise-store = true;
      };
    })

    {
      # Scheduled garbage collection by a systemd user timer (activation only
      # installs the timer; it does not run GC). nix-collect-garbage
      # --delete-older-than deletes THIS user's generations older than the
      # window, then collects every unreachable store path, so it overlaps
      # the NixOS system nix-gc timer (ops/system-setup.sh) where one exists.
      # On macOS GC belongs to Determinate Nix.
      #
      # Linux only: the Home Manager launchd agent passes the whole options
      # string as ONE argv entry ("--delete-older-than 14d"), which
      # nix-collect-garbage rejects.
      #
      # 14 days matches KEEP_DAYS in ops/cleanup.sh.
      gc = {
        automatic = !pkgs.stdenv.hostPlatform.isDarwin;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
    }
  ];
}
