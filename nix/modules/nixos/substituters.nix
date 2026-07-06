# nix/modules/nixos/substituters.nix
#
# Extra binary caches (substituters) for NixOS hosts. Pulling prebuilt binaries
# from these caches avoids compiling large packages from source, which is the
# single biggest rebuild-speed win on NixOS.
#
# This is a SYSTEM setting (nix.settings.*), so it only takes effect when this
# module is imported by /etc/nixos and applied with `nixos-rebuild`. It is part
# of nix/modules/nixos and is opt-in via the usual import (see
# repo-docs/system-timezone.md for the wiring pattern; sys-setup can wire the
# whole nix/modules/nixos set).
#
# Caches chosen for broad, trustworthy community coverage:
#   - nix-community: huge general community cache (home-manager, many tools)
#   - garnix.io:     CI cache used by many flakes (borrowed from nix-config-pavlo)
# Add project-specific caches (e.g. hyprland) only if a host actually needs them.
#
# NOTE: vicinae.cachix.org is intentionally NOT added here. The linux-desktop
# Home-Manager config uses the nixpkgs (Hydra-cached) `pkgs.vicinae` build via
# programs.vicinae.package, so no Vicinae Cachix is needed. Only add it if you
# switch nix/modules/home/vicinae.nix to the upstream `vicinae` flake build AND
# that cache has a matching prebuilt (otherwise it still compiles from source).

{ lib, ... }:
let
  caches = [
    "https://nix-community.cachix.org"
    "https://cache.garnix.io"
  ];
in
{
  nix.settings = {
    extra-substituters = caches;

    # Also mark these as trusted-substituters so they are honored for every
    # build, not just when the requesting user is in trusted-users. Without
    # this, a non-trusted user sees "ignoring untrusted substituter" and the
    # cache is silently skipped (falling back to compiling from source).
    extra-trusted-substituters = caches;

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
}
