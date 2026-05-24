{
  # Replace with your actual username on every host. If usernames differ per
  # machine, override `username` via specialArgs in flake.nix instead of
  # editing this default.
  username = "REPLACE_ME";

  # Public identity. Real values live in chezmoi's personal.yaml, not here.
  email = "REPLACE_ME";

  profiles = {
    linux-desktop = {
      system = "x86_64-linux";
      homeDirectory = "/home/REPLACE_ME";
      stateVersion = "24.11";
    };
    linux-cli = {
      system = "x86_64-linux";
      homeDirectory = "/home/REPLACE_ME";
      stateVersion = "24.11";
    };
    wsl = {
      system = "x86_64-linux";
      homeDirectory = "/home/REPLACE_ME";
      stateVersion = "24.11";
    };
    macos = {
      # Per Phase 0 decision: Apple Silicon default.
      # Switch to "x86_64-darwin" for Intel Macs.
      system = "aarch64-darwin";
      homeDirectory = "/Users/REPLACE_ME";
      stateVersion = "24.11";
    };
  };
}
