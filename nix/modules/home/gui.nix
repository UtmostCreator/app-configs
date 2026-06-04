{ pkgs, ... }:
{
  # GUI packages for Linux desktops. macOS gets GUI apps via nix-darwin
  # Homebrew casks (see nix/modules/darwin/homebrew.nix); this module is
  # imported only by linux-desktop (nix/hosts/linux-desktop/home.nix).
  #
  # Cross-platform mapping for these apps lives in
  # repo-docs/software-and-cli-tools.md ("Cross-platform install matrix").
  #
  # Guarded on isLinux so an accidental import on a Darwin build is a no-op
  # rather than pulling Linux GUI builds onto macOS.
  #
  # Keep conservative. Only add a package after confirming it exists for the
  # target platform with `nix search nixpkgs <name>`.
  home.packages =
    with pkgs;
    lib.optionals stdenv.isLinux [
      firefox # primary browser (macOS: Homebrew cask)
      brave # privacy browser; nixpkgs ships STABLE only (no brave-beta attr).
      #       macOS gets the beta channel via the brave-browser@beta cask in
      #       nix/modules/darwin/homebrew.nix.
      #       Local dev note: Brave Shields can block local servers. If a
      #       localhost / *.test / *.localhost dev URL misbehaves, allow it via
      #       brave://settings/content/siteDetails (per-site permissions).
      #       See repo-docs/default-apps.md ("Brave + local dev servers").
      ghostty # GPU terminal (macOS: Homebrew cask)
      vscode # VS Code (unfree; allowUnfree set in nix/lib/mkhome.nix)
      flameshot # screenshots with annotation
      bruno # open-source API client (Linux + macOS; macOS also via cask)
      # IDE: VS Code is the single IDE shipped on all systems (see vscode above).
      # IntelliJ IDEA intentionally excluded for now (was jetbrains.idea on Linux
      # / intellij-idea-ce cask on macOS). Re-add in a future slice if needed.
      # raycast / aerospace are macOS-only (meta.platforms = darwin); they are
      # declared in nix/modules/darwin/homebrew.nix and must NOT be added here.
      # Nerd fonts: add via fonts.fontconfig + a nerd-fonts.* package in a
      # separate slice if you want JetBrains Mono / Meslo managed by Nix.
    ];
}
