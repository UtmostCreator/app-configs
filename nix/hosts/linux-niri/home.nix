{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  lock = "${pkgs.swaylock}/bin/swaylock -f";
  h = config.home.homeDirectory;
  seedShell = pkgs.writeShellApplication {
    name = "app-configs-seed-shell";
    runtimeInputs = [
      pkgs.chezmoi
      pkgs.coreutils
      pkgs.gitMinimal
    ];
    text = builtins.readFile ./scripts/seed-shell.sh;
  };
  folders = [
    "Projects"
    "Documents"
    "Downloads"
    "Pictures"
    "Pictures/Screenshots"
    "Scratch"
    "Scratch/temp"
    "Scratch/logs"
    "Scratch/benchmarks"
    "Scratch/reports"
    "Scratch/screenshots"
    "Archive"
    "Archive/projects"
    "Archive/snapshots"
    "Archive/imports"
    ".ssh"
  ];
in
{
  imports = [
    inputs.vicinae.homeManagerModules.default
    ../../modules/home/profile.nix
    ../../modules/home/cli.nix
    ../../modules/home/default-apps.nix
  ];
  home.stateVersion = "26.11";
  home.sessionVariables = {
    DEV_ROOT = "${h}/Projects";
    SCRATCH_ROOT = "${h}/Scratch";
    ARCHIVE_ROOT = "${h}/Archive";
  };
  # Fontconfig is supplied by the graphical NixOS system.
  fonts.fontconfig.enable = false;
  home.packages =
    (with pkgs; [
      brave
      brightnessctl
      ghostty
      keepassxc
      kopia
      playerctl
      swaylock
      vscode
      wireplumber
      # Daily developer tools from the shared dev profile. Its standalone Home
      # Manager update timers do not apply to the integrated system generation.
      php84
      php84.packages.composer
      nodejs_22
      pnpm
      python3
      uv
      gh
      keychain
      openssh
      seedShell
    ])
    ++ lib.optional config.myConfig.groups.go pkgs.go;

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
    if [[ -L "$HOME" || ! -d "$HOME" ]]; then
      echo "Expected a directory at the configured home" >&2
      exit 1
    fi
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
