{ ... }:
{
  # Homebrew bridge for macOS GUI apps. nix-darwin manages the Brewfile so
  # casks become declarative without forcing every GUI app through Nix.
  #
  # Cask names below come from repo-docs/migration-package-ownership.md Phase 3
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
      "brave-browser@beta"  # Brave Beta channel (Linux gets stable pkgs.brave in gui.nix)
      "ghostty"
      "bbedit"
      "bruno"
      "visual-studio-code"  # VS Code — single IDE on all systems (Linux: vscode in gui.nix)
      # IntelliJ IDEA intentionally excluded for now. Re-add "intellij-idea-ce"
      # in a future slice if needed.
      "sequel-ace"
      "betterdisplay"
      "aerospace"
      "karabiner-elements"
      "raycast"          # macOS-only launcher (no Linux build)
      "flameshot"        # screenshots (Linux: nix gui.nix)
      "firefox"          # browser parity with Linux gui.nix (both platforms)
      # Optional — uncomment once verified with `brew search --casks <name>`:
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
