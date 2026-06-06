{ vars, ... }:
{
  # Top-level nix-darwin host stub. Populated in Phase 8 with system defaults
  # and Homebrew casks. This minimal form keeps the flake evaluating today.
  system.stateVersion = 5;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  users.users.${vars.username}.home = vars.profiles.macos.homeDirectory;
  imports = [ ../../modules/darwin ];
}
