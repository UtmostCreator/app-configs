{ lib, pkgs, ... }:
# Memory cap on the systemd user app.slice. Terminals, editors, browsers and
# the AI CLI sessions run there; the desktop shell runs in session.slice.
#
# Without a cap, a runaway job (nine parallel shellcheck runs holding 21 GB)
# fills RAM and swap, the kernel's global OOM killer picks a victim anywhere,
# and a kill inside the GNOME Shell unit stops the whole desktop and every
# terminal with it. With the cap, the slice hits a cgroup OOM first and the
# victim is chosen inside app.slice.
#
# MemoryMax is a share of RAM, MemorySwapMax a share of swap. Both are needed:
# a RAM cap alone lets the slice fill all swap, which is how the global OOM
# was reached. Together they leave about 10 % of RAM and 25 % of swap for the
# shell, system services and containers.
#
# A drop-in, not systemd.user.slices.app: that would replace the unit systemd
# ships. Tested by tests/bash/app-slice-memory-limit.bats.
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  xdg.configFile."systemd/user/app.slice.d/50-memory-limit.conf".text = ''
    [Slice]
    MemoryMax=90%
    MemorySwapMax=75%
  '';
}
