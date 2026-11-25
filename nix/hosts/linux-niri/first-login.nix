{
  lib,
  pkgs,
  vars,
  ...
}:
let
  verifier = pkgs.writeShellScriptBin "app-configs-verify-first-boot" ''
    exec ${pkgs.bash}/bin/bash ${./scripts/verify-first-boot.sh} "$@"
  '';
  firstLogin = pkgs.writeShellScriptBin "app-configs-first-login" ''
    export PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${vars.username}/bin:"$HOME/.nix-profile/bin:$PATH"
    exec ${pkgs.bash}/bin/bash ${./scripts/first-login.sh} \
      ${lib.getBin pkgs.chezmoi} ${lib.getBin pkgs.mise} ${lib.getBin pkgs.lefthook}
  '';
in
{
  environment.systemPackages = [
    verifier
    firstLogin
  ];
  systemd.user.services.app-configs-first-login = {
    description = "Prepare the installed user's offline workspace and verification report";
    unitConfig.ConditionUser = vars.username;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${firstLogin}/bin/app-configs-first-login";
      UMask = "0077";
      TimeoutStartSec = "5min";
    };
  };
  systemd.user.timers.app-configs-first-login = {
    description = "Check the Niri installation after user login";
    wantedBy = [ "timers.target" ];
    unitConfig.ConditionUser = vars.username;
    timerConfig = {
      OnStartupSec = "30s";
      AccuracySec = "1s";
    };
  };
}
