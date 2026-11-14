{
  # CLI / headless Linux: no GUI module.
  imports = [
    ../../modules/common
    ../../modules/home
  ];

  # Non-NixOS Linux target: XDG_DATA_DIRS, locale archive and Nix profile
  # paths for Nix-built programs.
  targets.genericLinux.enable = true;
  # CLI-only host: skip the GPU driver hook, which would warn on every switch
  # until `sudo non-nixos-gpu-setup` is run.
  targets.genericLinux.gpu.enable = false;
}
