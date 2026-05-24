{ pkgs, ... }:
{
  # GUI-only packages. macOS gets GUI apps via nix-darwin Homebrew casks
  # (see nix/modules/darwin/homebrew.nix in Phase 8); this module is for
  # Linux desktops that want a few terminal/font extras alongside CLI.
  #
  # Keep conservative. Only add a package after confirming it exists for
  # the target platform with `nix search nixpkgs <name>`.
  home.packages = with pkgs; [
    # ghostty           # uncomment after verifying the channel ships ghostty
  ];
}
