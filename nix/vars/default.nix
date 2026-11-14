let
  # Single-user design: one username for every profile and host. Change it
  # here and in the literal default in nix/modules/nixos/docker.nix (guarded by
  # tests/bash/nix-identity.bats); each homeDirectory below is derived from it.
  # Keep this a plain `username = "...";` line: ops/install.sh parses it with
  # sed until it switches to `nix eval`.
  username = "utmostcreator";
in
{
  inherit username;

  profiles = {
    linux-desktop = {
      system = "x86_64-linux";
      homeDirectory = "/home/${username}";
      stateVersion = "24.11";
    };
    linux-cli = {
      system = "x86_64-linux";
      homeDirectory = "/home/${username}";
      stateVersion = "24.11";
    };
    wsl = {
      system = "x86_64-linux";
      homeDirectory = "/home/${username}";
      stateVersion = "24.11";
    };
    macos = {
      # Per Phase 0 decision: Apple Silicon default.
      # Switch to "x86_64-darwin" for Intel Macs.
      system = "aarch64-darwin";
      homeDirectory = "/Users/${username}";
      stateVersion = "24.11";
    };
  };
}
