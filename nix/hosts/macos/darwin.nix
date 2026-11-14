{ vars, ... }:
{
  # Top-level nix-darwin host stub. Populated in Phase 8 with system defaults
  # and Homebrew casks. This minimal form keeps the flake evaluating today.
  system.stateVersion = 5;
  # Determinate Nix mode: ops/install.sh installs Determinate Nix, whose own
  # daemon owns the Nix package, /etc/nix/nix.conf and garbage collection.
  # nix-darwin must not also manage Nix, so nix.enable = false (nix-darwin then
  # rejects nix.settings/nix.gc, hence none here). Flakes are on by default in
  # Determinate Nix. Evaluated only on Linux; not run on a Mac.
  nix.enable = false;
  users.users.${vars.username}.home = vars.profiles.macos.homeDirectory;
  imports = [ ../../modules/darwin ];
}
