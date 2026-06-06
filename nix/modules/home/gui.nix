{ pkgs, config, ... }:
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
      vicinae # native, fast, extensible desktop launcher (Linux-only;
      #         meta.platforms = *-linux). The Linux counterpart to the
      #         macOS-only raycast launcher below.
      # Vicinae's GNOME Shell integration. WITHOUT this extension, Vicinae on
      # GNOME Wayland cannot drive window management or read the system
      # clipboard: its server logs "vicinae@dagimg-dot extension not installed"
      # and "Falling back to dummy clipboard server", and the launcher window
      # fails to render (shows only a placeholder icon). The extension is also
      # enabled via dconf in nix/modules/home/gnome-extensions.nix; installing
      # the package alone is not enough — GNOME must be told to load it.
      gnomeExtensions.vicinae # UUID: vicinae@dagimg-dot
      # Wayland clipboard CLI (wl-copy / wl-paste). Makes the system clipboard
      # scriptable and gives copy-on-select a reliable backing on GNOME
      # Wayland; also what most clipboard-managers/tools expect to be present.
      wl-clipboard
      # Provides `pactl` (PulseAudio/PipeWire control CLI). Vicinae logs
      # "pactl not found, audio control will not work" without it; this is the
      # CLI only — PipeWire itself is the system audio server.
      pulseaudio
      # IDE: VS Code is the single IDE shipped on all systems (see vscode above).
      # IntelliJ IDEA intentionally excluded for now (was jetbrains.idea on Linux
      # / intellij-idea-ce cask on macOS). Re-add in a future slice if needed.
      # raycast / aerospace are macOS-only (meta.platforms = darwin); they are
      # declared in nix/modules/darwin/homebrew.nix and must NOT be added here.
      # Nerd fonts: add via fonts.fontconfig + a nerd-fonts.* package in a
      # separate slice if you want JetBrains Mono / Meslo managed by Nix.
    ]
    # Personal-only GUI apps. Installed ONLY when the host sets
    # `myConfig.profile = "personal";` (see nix/modules/home/profile.nix) AND on
    # Linux. Vesktop = Discord with Vencord built-in (the supported way to ship
    # Vencord; the bare `vencord` attr is just a client-mod bundle, not an app).
    ++ lib.optionals (stdenv.isLinux && config.myConfig.profile == "personal") [
      vesktop # Discord + Vencord (https://github.com/Vendicated/Vencord)
      telegram-desktop # Telegram
      syncthing # continuous file sync (https://syncthing.net). Ships the CLI +
      #           Web UI (http://localhost:8384). Running it as a background
      #           service is a system/user-service concern; see
      #           repo-docs/future-upgrade-plan.md to enable services.syncthing.
    ];

  # Start Vicinae's background server at login so `vicinae toggle` (or a GNOME
  # keyboard shortcut bound to it) works immediately. The upstream desktop entry
  # runs `vicinae server --replace`; it does not open the launcher window.
  xdg.configFile."autostart/vicinae.desktop" = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.vicinae}/share/applications/vicinae.desktop";
  };
}
