{ ... }:
{
  # Homebrew bridge for macOS GUI apps. nix-darwin manages the Brewfile so
  # casks become declarative without forcing every GUI app through Nix.
  #
  # Cask names below come from docs/migration-package-ownership.md Phase 3
  # matrix. Verify with `brew search --casks <name>` on the Mac before
  # uncommenting any optional row.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";   # removes any cask not declared here
    };

    casks = [
      # Primary macOS GUI apps already in active use:
      "ghostty"
      "bbedit"
      "bruno"
      "intellij-idea-ce"
      "sequel-ace"
      "betterdisplay"
      "aerospace"
      "karabiner-elements"
      # Optional — uncomment once verified with `brew search --casks <name>`:
      # "firefox"
      # "medis"
      # "linearmouse"
      # "notunes"
    ];

    brews = [
      # macOS-only formulae not satisfied by nixpkgs cleanly.
      # Confirm before enabling:
      # "colima"
    ];
  };
}
