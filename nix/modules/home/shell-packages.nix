{ pkgs, ... }:
{
  # Zsh plugin packages. Sourced from ~/.zshrc, which chezmoi renders from
  # home/dot_zshrc.tmpl. zsh itself is provided by the OS/distribution;
  # chezmoi does not own ~/.zshrc activation.
  home.packages = with pkgs; [
    zsh-autosuggestions
    zsh-syntax-highlighting
  ];
}
