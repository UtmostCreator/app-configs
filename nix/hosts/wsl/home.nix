{
  # WSL2 (not WSL1): the shared CLI/dev modules, same as macOS minus GUI.
  # Never imports the GUI module. Windows-side tooling is out of scope.
  # Setup and checks: docs/platforms/wsl/setup.md, ops/wsl-check.sh.
  imports = [
    ../../modules/common
    ../../modules/home
  ];

  # Ubuntu (non-NixOS): XDG_DATA_DIRS, locale archive and Nix profile paths
  # for Nix-built programs.
  targets.genericLinux.enable = true;
  # CLI-only host: skip the GPU driver hook, which would warn on every switch
  # until `sudo non-nixos-gpu-setup` is run.
  targets.genericLinux.gpu.enable = false;
}
