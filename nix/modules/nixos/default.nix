{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ universal-ctags ];

  imports = [
    ./dual-boot.nix
    ./timezone.nix
    ./substituters.nix
    ./browser-policies.nix
    ./docker.nix
  ];
}
