{ config, ... }:
{
  # macOS Homebrew package declarations.
  #
  # Ownership:
  # - Nix / Home Manager: cross-platform CLI tools and runtimes.
  # - Homebrew: macOS GUI apps and fonts, plus CLIs that have no usable
  #   darwin nixpkgs build or need macOS integration. Each CLI below states
  #   its reason.
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

    # Homebrew-owned CLIs. Prefer Home Manager for cross-platform CLIs.
    brews = [
      # Compose plugin for the Docker CLI (macOS Docker integration). Not
      # configured here: `docker compose` only finds it once ~/.docker/config.json lists
      # "$HOMEBREW_PREFIX/lib/docker/cli-plugins" under cliPluginsExtraDirs.
      # That file is user-owned (docker login writes to it), so this module
      # does not write it. Follow-up: manage it via chezmoi (modify_ script).
      # Check with `docker compose version`.
      "docker-compose"
      # Provides the macOS `mysql` client. Nix mariadb is Linux-only (dev.nix).
      # Keg-only (conflicts with `mysql`), so brew does not link it. Interactive
      # shells already add its bin (fish config.fish.tmpl, zshrc);
      # environment.systemPath below covers GUI and non-interactive use.
      "mysql-client"
      # Installs the `duti` tool only. Setting default app handlers is done
      # elsewhere (nix/modules/home/default-browser-macos.nix), not by
      # installing it.
      "duti"
    ];
  };

  # mysql-client is keg-only: brew does not link it into the Homebrew bin.
  environment.systemPath = [ "${config.homebrew.prefix}/opt/mysql-client/bin" ];
}
