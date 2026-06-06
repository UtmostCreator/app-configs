# nix/modules/nixos/dual-boot.nix
#
# Reusable, OPTIONAL NixOS + Windows dual-boot module (systemd-boot).
#
# Nothing in this file does anything unless `myConfig.dualBoot.enable = true`.
# Windows-free users can import it freely; it stays fully inert.
#
# Design goals (verified against nixpkgs systemd-boot module schema):
#   - Reproducible: the same-ESP path contains ZERO hardware-specific values.
#   - Honest about non-reproducibility: the separate-disk path needs a per-host
#     EDK2 device handle discovered at runtime. That single value is isolated in
#     `windowsDeviceHandle` and guarded by an assertion.
#   - Single owner: this module only declares `boot.loader.*` (systemd-boot +
#     efi mount point + timeout) and, opt-in, the local-time RTC fix.
#
# IMPORTANT (boot-partition safety): systemd-boot only ever writes to the ESP
# named by `boot.loader.efi.efiSysMountPoint` (and the optional XBOOTLDR mount).
# It never writes to another disk's ESP. The separate-disk Windows path does not
# copy or modify the Windows bootloader; it only adds a NixOS-side menu entry
# that *chainloads* Windows read-only via the EDK2 UEFI Shell. See README/plan.
#
# Import via: imports = [ ./modules/nixos ]; then set `myConfig.dualBoot.*`.

{ config, lib, ... }:

let
  cfg = config.myConfig.dualBoot;
in
{
  options.myConfig.dualBoot = {
    enable = lib.mkEnableOption "NixOS + Windows dual-boot via systemd-boot";

    espMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/boot";
      example = "/efi";
      description = ''
        Mount point of the EFI System Partition that systemd-boot installs to.
        This is the ONLY ESP this module ever writes to. When the Windows ESP is
        too small to share (see xbootldrMountPoint), set this to the shared ESP
        (commonly "/efi") and keep NixOS kernels on the XBOOTLDR partition.

        You must also declare fileSystems."<this mount>" in
        hardware-configuration.nix; this module does not mount anything.
      '';
    };

    configurationLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = ''
        Number of newest NixOS generations kept in the boot menu. Caps how much
        space NixOS uses on the ESP/XBOOTLDR partition, which matters most when
        sharing a small ESP with Windows.
      '';
    };

    timeout = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 5;
      description = ''
        Boot-menu timeout in seconds. null waits for a keypress (menu-force).
        This sets boot.loader.timeout, which systemd-boot honors.
      '';
    };

    # --- Windows location ---------------------------------------------------

    windowsOnSeparateDisk = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        false: Windows shares NixOS's ESP. systemd-boot auto-detects the Windows
               Boot Manager already present on that ESP. Fully reproducible, no
               machine-specific values. PREFER THIS when partitioning allows it.
        true:  Windows lives on its own disk/ESP. systemd-boot cannot load EFI
               binaries from another ESP, so this enables the EDK2 UEFI Shell and
               adds a chainload entry. Requires windowsDeviceHandle (per-host).
               This does NOT touch the Windows ESP; it only reads it at boot.
      '';
    };

    windowsDeviceHandle = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "HD0c1";
      description = ''
        HARDWARE-SPECIFIC. EDK2 UEFI Shell device handle of the Windows ESP.
        Only used when windowsOnSeparateDisk = true. Keep this in PER-HOST
        config, never in a shared/portable module default.

        Discover it (matches the official nixpkgs procedure):
          1. Set windowsOnSeparateDisk = true (enables the EDK2 UEFI Shell entry)
          2. Run `nixos-rebuild boot`
          3. Reboot, select "EDK2 UEFI Shell" from the systemd-boot menu
          4. Run `map -c` to list consistent device handles (e.g. HD0c1)
          5. For each handle run `ls HD0c1:\EFI`
          6. The correct ESP contains a `Microsoft` directory
          7. Confirm with `HD0c1:\EFI\Microsoft\Boot\Bootmgfw.efi` (Windows boots)
          8. Use that handle (e.g. "HD0c1") here, then `nixos-rebuild switch`
      '';
    };

    # --- Optional: small Windows ESP workaround -----------------------------

    xbootldrMountPoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/boot";
      description = ''
        Optional XBOOTLDR partition for when a SHARED Windows ESP is too small
        (factory Windows ESPs are often ~100 MB and cannot hold several NixOS
        generations). NixOS kernels go here while espMountPoint stays the shared
        ESP. You must ALSO declare fileSystems."<this mount>" (usually in
        hardware-configuration.nix). Leave null when you have a roomy (>=512 MB)
        ESP or when Windows is on a separate disk.
      '';
    };

    # --- Optional: clock fix ------------------------------------------------

    windowsTimeFix = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Windows writes the RTC in local time by default while NixOS expects UTC,
        so the clock can jump between boots. Setting this true makes NixOS treat
        the RTC as local time to match Windows.

        Default is false because the cleaner, recommended fix is to make WINDOWS
        use UTC (set HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation\
        RealTimeIsUniversal = 1) and leave NixOS on UTC. Enable this only if you
        cannot or do not want to change the Windows side.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.windowsOnSeparateDisk || cfg.windowsDeviceHandle != null;
        message = ''
          myConfig.dualBoot: windowsOnSeparateDisk = true requires
          windowsDeviceHandle. Discover it with `map -c` in the EDK2 UEFI Shell
          (see the windowsDeviceHandle option documentation).
        '';
      }
    ];

    boot.loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = cfg.espMountPoint;
      timeout = cfg.timeout;

      systemd-boot = {
        enable = true;
        configurationLimit = cfg.configurationLimit;

        xbootldrMountPoint = lib.mkIf (cfg.xbootldrMountPoint != null) cfg.xbootldrMountPoint;

        # Separate-disk Windows: expose the EDK2 UEFI Shell so the generated
        # Windows entry can chainload Bootmgfw.efi from the other ESP.
        edk2-uefi-shell = lib.mkIf cfg.windowsOnSeparateDisk {
          enable = true;
        };

        # One menu entry that chainloads Windows read-only. The attribute name
        # ("11") is only the title/file-name key; efiDeviceHandle points the EDK2
        # shell at the Windows ESP. systemd-boot never writes to that ESP.
        windows = lib.mkIf cfg.windowsOnSeparateDisk {
          "11" = {
            title = "Windows";
            efiDeviceHandle = cfg.windowsDeviceHandle;
          };
        };
      };
    };

    time.hardwareClockInLocalTime = lib.mkIf cfg.windowsTimeFix true;
  };
}
