{ lib, ... }:
{
  # NixOS-WSL: the wsl host plus a NixOS system layer. Same modules as
  # ../wsl/home.nix, but NixOS already provides the XDG dirs, locale archive and
  # Nix profile paths that targets.genericLinux sets up for Ubuntu and other
  # non-NixOS distros. Built when the wsl host profile runs on NixOS
  # (ops/detect-host.sh --hm-attr). The system layer is ops/system-setup.sh and
  # nix/modules/nixos/wsl.nix.
  imports = [ ../wsl/home.nix ];

  targets.genericLinux.enable = lib.mkForce false;
}
