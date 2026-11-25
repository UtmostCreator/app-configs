# nix/modules/nixos/desktop-stability.nix
#
# Stability baseline for the NixOS desktop, from the audit in
# docs/platforms/nixos/desktop-stability.md. Like docker.nix, this is a SYSTEM
# module: ops/system-setup.sh copies it next to /etc/nixos/configuration.nix
# (pure flakes cannot import paths outside /etc/nixos) and imports it by
# relative path. It is self-contained and imports nothing from the repo.
#
# The desktop baseline and single-disk SMART monitoring can be enabled
# independently. Device discovery belongs to the desktop baseline.
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
  selected = cfg.smartDevice != null;
in
{
  options.myConfig.desktopStability = {
    enable = lib.mkEnableOption "the desktop stability baseline (fwupd discovery, smartd drive health)";
    smartDevice = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.addCheck lib.types.str (
          value:
          builtins.match "/dev/disk/by-id/[a-zA-Z0-9][a-zA-Z0-9._:+-]*" value != null
          && builtins.match ".*-part[0-9]+" value == null
        )
      );
      default = null;
      description = ''
        Persistent by-id path of the verified whole disk to monitor exclusively.
        Set after confirming which physical disk backs the installed root.
      '';
    };
    zram.enable = lib.mkEnableOption ''
      zram compressed swap, used before the disk swap partition. Opt-in: it is
      an optimisation to measure, not a fix'';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Firmware update DISCOVERY via LVFS. Nothing is flashed automatically:
      # check with `fwupdmgr get-updates`, then flash explicitly with
      # `fwupdmgr update` after reading the release notes.
      services.fwupd.enable = lib.mkDefault true;

      # The desktop baseline reports to the journal and sends wall
      # messages (the module default) and as desktop notifications through
      # systembus-notify. Upstream notes that any local user could then
      # spam notifications; acceptable on a single-user desktop.
      services.smartd.notifications.systembus-notify.enable = lib.mkDefault true;
    })

    (lib.mkIf (cfg.enable || selected) {
      services.smartd = {
        enable = lib.mkDefault true;
        autodetect = lib.mkDefault (!selected);
        # smartd exits non-zero when it finds no SMART device (a VM, or a
        # disk behind a controller that hides SMART), which would fail
        # activation. `-q nodev0` makes it exit 0 instead (evaluated against
        # smartmontools 7.5; the option needs a release that knows nodev0).
        extraOptions = lib.mkDefault (
          [
            "-q"
            "nodev0"
          ]
          ++ lib.optionals selected [
            "-s"
            "/var/lib/smartmontools/smartd."
          ]
        );
      };
    })

    (lib.mkIf selected {
      services.smartd.devices = lib.mkDefault [
        {
          device = cfg.smartDevice;
          # -a includes attribute tracking. -R reports raw ATA changes
          # without elevating a lifetime count to a critical alert.
          options = lib.mkDefault "-d removable -R 5 -R 170 -R 187 -R 192 -R 196 -R 199 -R 231 -W 5";
        }
      ];
      assertions = [
        {
          assertion =
            !config.services.smartd.autodetect
            && map (d: d.device) config.services.smartd.devices == [ cfg.smartDevice ];
          message = ''
            Selected SMART monitoring must address only the reviewed disk.
            Disable device discovery and review services.smartd.devices.
          '';
        }
      ];
      systemd.services.smartd.serviceConfig = {
        StateDirectory = lib.mkDefault "smartmontools";
        StateDirectoryMode = lib.mkDefault "0700";
      };
    })

    (lib.mkIf (cfg.enable && cfg.zram.enable) {
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
  ];
}
