{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  lock = "${pkgs.swaylock}/bin/swaylock -f";
  folders = [
    "Projects"
    "Documents"
    "Downloads"
    "Pictures"
    "Pictures/Screenshots"
  ];
in
{
  imports = [
    inputs.vicinae.homeManagerModules.default
    ../../modules/home/default-apps.nix
  ];
  home.stateVersion = "26.11";
  # Fontconfig is supplied by the graphical NixOS system.
  fonts.fontconfig.enable = false;
  home.packages = with pkgs; [
    brave
    btop
    brightnessctl
    ghostty
    keepassxc
    kopia
    playerctl
    ripgrep
    swaylock
    tmux
    vscode
    wireplumber
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
  programs.vicinae = {
    enable = true;
    package = pkgs.vicinae;
    extensions = [
      inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}.vscode-recents
    ];
    enableNumen = false;
    enableFirefoxIntegration = false;
    enableChromeIntegration = false;
    systemd.enable = true;
  };
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = lock;
      inherit lock;
    };
    timeouts = [
      {
        timeout = 300;
        command = lock;
      }
    ];
  };

  home.activation.checkNiriDirectories = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    for folder in ${lib.escapeShellArgs folders}; do
      if [[ -L "$HOME/$folder" || ( -e "$HOME/$folder" && ! -d "$HOME/$folder" ) ]]; then
        echo "Expected a directory at $HOME/$folder" >&2
        exit 1
      fi
    done
  '';
  home.activation.createNiriDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for folder in ${lib.escapeShellArgs folders}; do
      if [[ ! -d "$HOME/$folder" ]]; then
        run mkdir -m 0700 "$HOME/$folder"
      fi
    done
  '';
}
