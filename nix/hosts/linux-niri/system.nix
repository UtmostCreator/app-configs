{
  config,
  inputs,
  lib,
  pkgs,
  self,
  vars,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./first-login.nix
    ./maintenance.nix
  ];

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    overlays = [ (import ../../overlays { inherit inputs; }) ];
    config.allowUnfreePredicate =
      package:
      builtins.elem (lib.getName package) [
        "android-studio"
        "brave"
        "claude-code"
        "obsidian"
        "vscode"
      ];
  };

  specialisation.nvidia-open.configuration = import ./nvidia-open.nix;

  networking.hostName = "linux-niri";
  networking.networkmanager.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  environment.etc."app-configs/linux-niri".text = "linux-niri\n";

  programs.niri = {
    enable = true;
    useNautilus = false;
  };
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${config.programs.niri.package}/bin/niri-session";
  };

  security.soteria.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  xdg.portal.config.niri."org.freedesktop.impl.portal.ScreenCast" = "gnome";

  # The installer sets the password interactively in the target root.
  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
  environment.systemPackages = with pkgs; [
    claude-code
    codex
    git
    pciutils
    usbutils
    smartmontools
    nvme-cli
    jq
    xwayland-satellite
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.${vars.username} = import ./home.nix;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Enforce the GNOME boundary on indirect runtime dependencies too.
  system.forbiddenDependenciesRegexes = [
    "/[a-z0-9]+-gdm-[0-9]"
    "/[a-z0-9]+-gnome-session-[0-9]"
    "/[a-z0-9]+-gnome-shell-[0-9]"
    "/[a-z0-9]+-gnome-shell-extension"
    "/[a-z0-9]+-nautilus-[0-9]"
  ];
  system.configurationRevision = self.rev or self.dirtyRev or "dirty";
  system.stateVersion = "26.11";
}
