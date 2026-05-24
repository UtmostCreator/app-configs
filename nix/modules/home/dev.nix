{ pkgs, ... }:
{
  # Developer tooling. Per Phase 3 matrix.
  #
  # Never include:
  #   direnv (DROPPED — mise per-project env replaces it)
  #   mise, chezmoi, home-manager, lefthook (bootstrap-installed via nix profile)
  home.packages = with pkgs; [
    actionlint
    ast-grep
    bats             # bats-core formula -> bats in nixpkgs
    delta            # git-delta formula -> delta in nixpkgs
    difftastic
    docker           # CLI only; daemon source is host-specific
    gh
    gitleaks
    just
    lazygit
    lnav
    lychee
    mariadb          # provides the `mysql` client; lighter than full mysql-client formula
    neovim
    p7zip
    scc
    semgrep
    shellcheck
    shfmt
    watchexec
  ];
}
