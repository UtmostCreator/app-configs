{ pkgs, ... }:
{
  # Universal packages every host needs. Larger tool sets live under
  # nix/modules/home/*. Per Phase 3 matrix:
  # - direnv intentionally absent (DROPPED in Phase 3; mise per-project env covers it)
  # - mise, chezmoi, home-manager, lefthook are nix-profile installed in
  #   ops/bootstrap.sh; never added here.
  home.packages = with pkgs; [
    curl
    wget
    git
    universal-ctags
    unzip
    xz
    cacert
  ];
}
