# nix/modules/nixos/wsl.nix
#
# NixOS-WSL system settings that ops/system-setup.sh adds on a `wsl` host. The
# script copies this file next to /etc/nixos/configuration.nix as
# app-configs-wsl.nix and imports it from app-configs-extra.nix (a pure-eval
# flake forbids importing an absolute path outside /etc/nixos). It is NOT in
# nix/modules/nixos/default.nix: it needs the NixOS-WSL `wsl.*` options, which
# only exist on a NixOS-WSL system.
#
# The stock NixOS-WSL configuration.nix sets `wsl.defaultUser = "nixos"`. That
# is a plain definition, so lib.mkForce wins and no wsl.* line is ever edited.
# The copy is standalone and cannot import nix/vars: the username below is a
# literal kept equal to nix/vars/default.nix by tests/bash/nix-identity.bats.
#
# nix-ld (prebuilt binaries such as the claude and codex CLIs) is NOT here:
# ops/validate-config.sh forbids programs.<x>.enable under nix/modules, so
# ops/system-setup.sh emits `programs.nix-ld.enable = true;` in its generated
# module for a wsl host, like programs.fish.enable.

{ lib, ... }:
{
  wsl.defaultUser = lib.mkForce "utmostcreator";
}
