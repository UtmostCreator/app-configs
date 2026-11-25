{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The installed system supplies sudo, nixos-rebuild and the verifier.
  maintenance = pkgs.writeShellScript "linux-niri-maintenance" (builtins.readFile ./maintenance.sh);
  command =
    name:
    pkgs.writeShellScriptBin "sys-${name}" ''
      export PATH=/run/wrappers/bin:/run/current-system/sw/bin:${lib.makeBinPath [ pkgs.jq ]}:"$PATH"
      exec ${maintenance} ${name} "$@"
    '';
in
{
  imports = [ ../../modules/nixos/desktop-stability.nix ];
  # Installed systems retain earlier boots even on a freshly created /var.
  # journald's disk-space limits still follow the size of the root filesystem.
  services.journald.settings.Journal.Storage = lib.mkDefault "persistent";
  assertions = [
    {
      assertion =
        config.boot.loader.systemd-boot.configurationLimit == null
        || config.boot.loader.systemd-boot.configurationLimit >= 2;
      message = "The Niri update command needs room for the working and staged boot entries.";
    }
  ];
  environment.systemPackages = map command [
    "install"
    "update"
    "readiness"
    "cleanup"
  ];
}
