# nix/hosts/linux-desktop-pilot/system.nix
#
# niri pilot host (PC 2): the smallest NixOS system that boots to GDM with
# GNOME as the default session and niri as a second, selectable session.
# Build-only for now; nothing activates it on PC 1. See
# docs/plans/niri-migration.md, ADR-0012 (niri trial, GNOME stays the default)
# and ADR-0038 (how a fresh host gets installed).
#
# Home Manager stays standalone, as on PC 1: after the first login run the
# repo's normal install, so `ops/detect-host.sh` picks linux-desktop and the
# same Home Manager profile applies. Do NOT run `ops/system-setup.sh` (or
# `ops/tailscale-setup.sh`) here, although install suggests it: both edit
# /etc/nixos and rebuild from /etc/nixos#nixos, a different system than this
# flake host (T-0029). Rebuild with
# `nixos-rebuild switch --flake <repo>/nix#linux-desktop-pilot` instead.
# niri's own config is chezmoi's (home/dot_config/niri/config.kdl, deployed to
# ~/.config/niri/config.kdl); /etc/niri is not used.
#
# Checked by tests/bash/nixos-pilot.bats (evaluation) and nix/tests/pilot-vm.nix
# (boots it in QEMU: GDM, GNOME default, niri session start with the repo's
# niri config).

{
  lib,
  pkgs,
  self,
  vars,
  ...
}:
{
  imports = [ ../../modules/nixos ];

  networking.hostName = "linux-desktop-pilot";
  networking.networkmanager.enable = true;

  # GNOME baseline, as on PC 1.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # niri as a second GDM session. The pinned module would make niri the
  # default session, so GNOME is set explicitly.
  programs.niri.enable = true;
  services.displayManager.defaultSession = "gnome";

  # What the niri session needs beyond programs.niri (which already brings the
  # session entry, the keyring, the portals and the polkit service): a polkit
  # agent for password prompts, and xwayland-satellite so X11 apps open. niri
  # finds xwayland-satellite on PATH and starts it on demand. The bar,
  # notifications, lock and idle handling wait for the shell choice (ADR-0013).
  security.soteria.enable = true;
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    # No password in the repo: set it from the installer with
    # `nixos-enter --root /mnt -c 'passwd <user>'` before the first boot.
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Shows which commit runs: `nixos-version --configuration-revision`. Build
  # through a git+file: or git checkout reference; a path: reference has no
  # revision and records "dirty".
  system.configurationRevision = self.rev or self.dirtyRev or "dirty";

  # PLACEHOLDER disks and boot, so the system evaluates before PC 2 exists.
  # Replace with the hardware-configuration.nix generated on PC 2 (never
  # copied from PC 1) or a disko layout (ADR-0038), and DELETE these two
  # fileSystems entries in the same change: a generated config overrides a
  # mount it also defines, but a leftover /boot placeholder for a layout
  # without /boot drops the boot into emergency mode. Labels, not /dev/sdX.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };
  nixpkgs.hostPlatform = "x86_64-linux";

  # The release PC 2 is installed from. Never change it after the install.
  system.stateVersion = "26.11";
}
