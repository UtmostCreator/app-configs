{ config, ... }:
{
  # macOS Homebrew package declarations.
  #
  # Ownership:
  # - Nix / Home Manager: cross-platform CLI tools and runtimes.
  # - Homebrew: macOS applications, fonts and selected host-specific tools.
  # - chezmoi: application configuration and user dotfiles.
  #
  # Keep one installation owner per package. Verify cask names with
  # `brew info --cask <name>` before adding new rows.
  homebrew = {
    enable = true;

    onActivation = {
      # Routine darwin-rebuild stays predictable. Homebrew upgrades run from
      # `sys-update` (ops/update-all.sh), not from every rebuild.
      autoUpdate = false;
      upgrade = false;

      # "none" keeps unlisted packages. "zap" would uninstall every undeclared
      # cask and its data. Switch only after the inventory is reconciled.
      cleanup = "none";
    };

    casks = [
      # ── Browsers ──────────────────────────────────────────
      "brave-browser@beta"
      "firefox"

      # ── Development applications ─────────────────────────
      "bruno"
      "ghostty"
      # "postman"
      "sequel-ace"
      "visual-studio-code"

      # ── AI and authentication CLIs ───────────────────────
      "1password-cli"
      "copilot-cli"

      # ── Knowledge and productivity ───────────────────────
      # Optional live call/meeting summarizer.
      "granola"
      "obsidian"
      "raycast"

      # ── Windows, keyboard and input ──────────────────────
      "aerospace"
      "alt-tab"
      "betterdisplay"
      "karabiner-elements"
      "linearmouse"

      # ── Files, storage and transfer ──────────────────────
      # Free picks from docs/reference/app-options.yaml (paid options such
      # as ForkLift and DaisyDisk are listed there, not installed).
      "grandperspective" # disk usage treemap (macOS 14+)
      "localsend" # LAN file transfer to Linux/Android/iOS
      "nimble-commander" # dual-pane file manager

      # ── Menu bar and system utilities ────────────────────
      "jordanbaird-ice@beta"
      "notunes"
      "stats"

      # ── Fonts ────────────────────────────────────────────
      "font-jetbrains-mono-nerd-font"
      "font-meslo-lg-nerd-font"
    ];

    # Homebrew-owned tools that need macOS integration. Prefer Home Manager
    # for cross-platform CLIs.
    brews = [
      # Needs cliPluginsExtraDirs in ~/.docker/config.json to find Compose.
      # Check with `docker compose version`.
      "docker-compose"
      # Provides the macOS `mysql` client. Nix mariadb is Linux-only (dev.nix).
      # Keg-only (conflicts with `mysql`), so brew does not link it. Interactive
      # shells already add its bin (fish config.fish.tmpl, zshrc);
      # environment.systemPath below covers GUI and non-interactive use.
      "mysql-client"
      # Sets default macOS app handlers.
      "duti"
    ];
  };

  # mysql-client is keg-only: brew does not link it into the Homebrew bin.
  environment.systemPath = [ "${config.homebrew.prefix}/opt/mysql-client/bin" ];
}
