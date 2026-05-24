{
  # Default home aggregate (no GUI). Linux-cli and wsl import this directly.
  # linux-desktop and macos import ./gui.nix on top.
  imports = [
    ./cli.nix
    ./dev.nix
    ./shell-packages.nix
  ];
}
