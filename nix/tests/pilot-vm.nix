# nix/tests/pilot-vm.nix
#
# VM smoke test for the niri pilot host (nix/hosts/linux-desktop-pilot).
# Boots the real pilot system in throwaway QEMU VMs; the host desktop is not
# touched. Two nodes:
#   gnome: the pilot as committed. GDM's greeter comes up, GNOME is the
#          default session, NetworkManager runs.
#   niri:  the same system plus test-only autologin into the niri session and
#          the repo's niri config linked into place, to prove niri starts under
#          GDM, loads that config, answers on its IPC socket, finds
#          xwayland-satellite and has a polkit agent.
# The VM has no GPU, and niri refuses software EGL renderers (niri
# src/backend/tty.rs), so niri runs and answers IPC but has no output: the
# test proves boot, GDM, the session list and niri startup, not rendering.
# Graphics drivers, monitors, lock and suspend stay native-session checks.
# The test driver's QEMU has no OpenGL, so a virgl-backed run is not possible
# here either.
#
# Run (a few minutes; needs /dev/kvm). The git+file reference carries the whole
# repository, so the test can see chezmoi's niri config under home/:
#   nix build --no-link -L "git+file://$PWD?dir=nix#packages.x86_64-linux.pilot-vm-test"
{
  pkgs,
  self,
  vars,
}:
let
  user = vars.username;
  # chezmoi's niri config lives outside nix/. A `path:.../nix` flake reference
  # copies only nix/, so the file is visible only through a reference that
  # carries the whole repository (git+file://...?dir=nix, see "Run" above).
  niriConfig = ../../home/dot_config/niri/config.kdl;
  haveNiriConfig = builtins.pathExists niriConfig;
  pilot = {
    imports = [ ../hosts/linux-desktop-pilot/system.nix ];
    virtualisation.memorySize = 3072;
    virtualisation.cores = 2;
  };
in
pkgs.testers.runNixOSTest {
  name = "linux-desktop-pilot-vm";
  node.specialArgs = { inherit self vars; };
  # The pilot sets nixpkgs.hostPlatform, as a real host must.
  node.pkgsReadOnly = false;

  nodes.gnome = pilot;
  nodes.niri = {
    imports = [ pilot ];
    services.displayManager.autoLogin = {
      enable = true;
      inherit user;
    };
    services.displayManager.defaultSession = pkgs.lib.mkForce "niri";
    # chezmoi deploys the niri config on a real host; the test links the same
    # file into place, so the VM runs exactly what the repo ships.
    systemd.tmpfiles.rules = pkgs.lib.optionals haveNiriConfig [
      "d /home/${user}/.config 0755 ${user} users -"
      "d /home/${user}/.config/niri 0755 ${user} users -"
      "L+ /home/${user}/.config/niri/config.kdl - - - - ${niriConfig}"
    ];
  };

  testScript = ''
    # Fail loudly, never skip: without the config this test proves less than
    # its name says.
    assert ${if haveNiriConfig then "True" else "False"}, (
        "the niri config is not visible to this build; use "
        "nix build \"git+file://$PWD?dir=nix#packages.x86_64-linux.pilot-vm-test\""
    )

    start_all()

    for m in (gnome, niri):
        m.wait_for_unit("display-manager.service")
        m.wait_for_unit("NetworkManager.service")

    with subtest("GDM greeter runs and GNOME is the default session"):
        # GDM runs the greeter under a dynamic greeter user, not "gdm", and
        # the wrapped binary's process name is ".gnome-shell-wr".
        gnome.wait_until_succeeds("pgrep gnome-shell", timeout=300)
        gnome.succeed("pgrep -u gdm-greeter gnome-shell")
        # NixOS's gdm preStart writes the default session into each user's
        # AccountsService record (set-session), not into custom.conf.
        gnome.succeed("grep -qE '^(Session|XSession)=gnome$' /var/lib/AccountsService/users/${user}")

    with subtest("niri session starts under GDM and answers on its socket"):
        niri.wait_until_succeeds("pgrep -u ${user} -x niri", timeout=300)
        niri.wait_until_succeeds("ls /run/user/1000/niri.*.sock", timeout=120)
        niri_msg = (
            "sock=$(ls /run/user/1000/niri.*.sock | head -n1); "
            "su ${user} -c \"NIRI_SOCKET=$sock niri msg %s\""
        )
        print(niri.succeed(niri_msg % "version"))
        # Empty without a GPU (see the header); printed for the log.
        print(niri.execute(niri_msg % "outputs")[1])
        niri.screenshot("niri-session")

    with subtest("niri runs the repo's config, with a polkit agent and X11 support"):
        niri.succeed("su ${user} -c 'niri validate'")
        # The Russian layout exists only in the repo's config, not in niri's
        # built-in default, so listing it proves the file was loaded.
        niri.succeed((niri_msg % "keyboard-layouts") + " | grep -q Russian")
        niri.fail("journalctl -b | grep -q 'error spawning xwayland-satellite'")
        niri.wait_until_succeeds(
            "su ${user} -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active polkit-soteria.service'",
            timeout=120,
        )
  '';
}
