{
  # Default home aggregate (no GUI). Linux-cli and wsl import this directly.
  # linux-desktop and macos import ./gui.nix on top.
  imports = [
    ./cli.nix
    ./dev.nix
    ./ai-cli-updates.nix # hourly Claude Code + Codex self-updates (Linux)
    ./shell-packages.nix
    ./profile.nix # declares myConfig.profile (read by gui.nix). Option only;
    #               installs nothing unless a host sets it to "personal".
  ];
}
