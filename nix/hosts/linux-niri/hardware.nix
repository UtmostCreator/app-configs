{
  # Generic discovery baseline for an x86_64 laptop or a virtio rehearsal.
  # Review the destination's `nixos-generate-config --show-hardware-config
  # --no-filesystems` before installing. Disko owns the initrd LUKS device,
  # root mount and ESP. Add hardware-specific drivers here.
  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "uas"
    "usb_storage"
    "virtio_blk"
    "virtio_pci"
    "xhci_pci"
  ];
}
