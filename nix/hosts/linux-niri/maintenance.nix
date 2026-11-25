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
