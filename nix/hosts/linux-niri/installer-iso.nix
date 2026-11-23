{
  modulesPath,
  pkgs,
  installTools,
  targetSystem,
  ...
}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";
  # mksquashfs otherwise sizes its caches to 25% of the builder's RAM.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6 -mem 512M";
  specialisation.nvidia-recovery.configuration = {
    isoImage.configurationName = "(NVIDIA recovery - disable Nouveau)";
    boot.kernelParams = [ "module_blacklist=nouveau" ];
  };
  programs.git.enable = true;
  environment.systemPackages = [
    installTools.install-claude
    pkgs.codex
    installTools.disko
  ];
  # Nix retains the referenced system in the ISO store. nixos-install can
  # copy it straight to the mounted SSD without building in the RAM overlay.
  environment.etc."app-configs/linux-niri-toplevel".text = "${targetSystem}\n";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
