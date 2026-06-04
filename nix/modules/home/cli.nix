{ pkgs, ... }:
{
  # CLI tools — used on every host (macOS / linux-desktop / linux-cli / wsl).
  # Per repo-docs/migration-package-ownership.md Phase 3 matrix.
  #
  # IMPORTANT: every nixpkgs attribute name below was decided based on the
  # matrix notes. Confirm with `nix search nixpkgs <name>` if you hit a
  # missing package on `nix flake check`.
  home.packages = with pkgs; [
    atuin
    bat
    btop
    eza
    fd
    fish             # interactive shell (native autosuggestions + syntax
                     # highlighting; config in ~/.config/fish/config.fish).
                     # Added as a plain package, not programs.fish.enable,
                     # to satisfy the validate-config.sh invariant.
    fzf
    jq
    lsof             # list open files/sockets (debugging, port owners)
    yq-go            # yq formula -> yq-go in nixpkgs
    ripgrep
    ripgrep-all      # binary: rga
    starship
    tealdeer         # tldr/tlrc alternative in nixpkgs (binary: tldr)
    tmux
    tree             # directory tree view (eza --tree also works)
    yazi
    zoxide
  ];
}
