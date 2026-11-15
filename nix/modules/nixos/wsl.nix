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

# wsl-mnt-guard.service: WSL itself generates it (/run/systemd/generator) with
# ExecStart=/bin/true, and NixOS-WSL 2605.7.2 does not create /bin/true, so the
# unit failed with 203/EXEC and `nixos-rebuild switch` exited 4. NixOS-WSL master
# fixed it by adding true to wsl.extraBin; this does the same here, so the
# generated unit runs unchanged (its ConditionPathIsMountPoint=/mnt/wsl still
# skips it where /mnt/wsl is not a mount point). Newer releases that already add
# true make this a duplicate entry for the same symlink, which is harmless.

{ lib, pkgs, ... }:
{
  wsl.defaultUser = lib.mkForce "utmostcreator";
  wsl.extraBin = [ { src = "${pkgs.coreutils}/bin/true"; } ];
}
