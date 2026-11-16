# nix/modules/nixos/desktop-stability.nix
#
# Stability baseline for the NixOS desktop, from the audit in
# docs/platforms/nixos/desktop-stability.md. Like docker.nix, this is a SYSTEM
# module: ops/system-setup.sh copies it next to /etc/nixos/configuration.nix
# (pure flakes cannot import paths outside /etc/nixos) and imports it by
# relative path. It is self-contained and imports nothing from the repo.
#
# Inert until `myConfig.desktopStability.enable = true;`. Every value is
# lib.mkDefault, so any definition in the host's configuration.nix wins without
# an evaluation conflict.
#
# Deliberately NOT here (see the doc):
#   - Coredump storage: systemd already caps it (MaxUse 10% / KeepFree 15% of
#     the filesystem, each at most 4 GiB; coredump.conf(5)).
#   - vm.swappiness: "10-20" advice targets disk-only swap; with zram it works
#     against compression. The kernel default stays.
#   - systemd.oomd.enableUserSlices / ManagedOOMSwap: oomd kills whole cgroups,
#     and apps started from the launcher still share one. Fix isolation first.
#   - GPU driver, Secure Boot, disk encryption, journald size: host decisions.

{ config, lib, ... }:

let
  cfg = config.myConfig.desktopStability;
in
{
  options.myConfig.desktopStability = {
    enable = lib.mkEnableOption "the desktop stability baseline (fwupd discovery, smartd drive health)";
    zram.enable = lib.mkEnableOption ''
      zram compressed swap, used before the disk swap partition. Opt-in: it is
      an optimisation to measure, not a fix'';
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Firmware update DISCOVERY via LVFS. Nothing is flashed automatically:
        # check with `fwupdmgr get-updates`, then flash explicitly with
        # `fwupdmgr update` after reading the release notes.
        services.fwupd.enable = lib.mkDefault true;

        # Drive health. smartd autodetects every SMART-capable drive (no device
        # paths here) and logs to the journal. Failures also go out as wall
        # messages (the module default) and as desktop notifications through
        # systembus-notify. Upstream notes that any local user could then
        # spam notifications; acceptable on a single-user desktop.
        services.smartd = {
          enable = lib.mkDefault true;
          autodetect = lib.mkDefault true;
          notifications.systembus-notify.enable = lib.mkDefault true;
          # smartd exits non-zero when it finds no SMART device (a VM, or a
          # disk behind a controller that hides SMART), which would fail
          # activation. `-q nodev0` makes it exit 0 instead (evaluated against
          # smartmontools 7.5; the option needs a release that knows nodev0).
          extraOptions = lib.mkDefault [
            "-q"
            "nodev0"
          ];
        };
      }

      (lib.mkIf cfg.zram.enable {
        # memoryPercent is the device's logical size, not RAM reserved up front:
        # pages use RAM only once compressed into it. Priority 100 puts zram
        # before the disk swap partition (priority -2). Per-cgroup
        # MemorySwapMax limits still count zram usage.
        zramSwap = {
          enable = lib.mkDefault true;
          memoryPercent = lib.mkDefault 25;
          priority = lib.mkDefault 100;
        };
      })
    ]
  );
}
