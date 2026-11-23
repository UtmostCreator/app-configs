{ lib, ... }:
{
  # Normal system evaluations only need GPT labels and the LUKS mapper.
  # Disko's format script has no usable target until the installer maps one.
  imports = [
    (import ./layout.nix (
      lib.mkDefault (throw "Map the verified linux-niri installation disk by /dev/disk/by-id.")
    ))
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  zramSwap.enable = true;
  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
}
