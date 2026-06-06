# treefmt-nix configuration. Drives `nix fmt` (format the tree) and
# `nix flake check` (the `formatting` check fails if anything is unformatted).
#
# Scope is intentionally the Nix tree only for now: nixfmt-rfc-style is already
# this repo's canonical Nix formatter (see nix/modules/home/dev.nix). Shell
# formatting stays owned by the existing shfmt/lefthook path to avoid
# double-ownership; add programs.shfmt here later if you want treefmt to own it.
{ ... }:
{
  # Use the flake's own marker so treefmt finds the project root.
  projectRootFile = "flake.nix";

  programs.nixfmt = {
    enable = true;
  };
}
