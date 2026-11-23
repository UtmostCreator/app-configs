# Exercise the installed user environment on the test driver's virtual root.
# The separate blank-disk UEFI rehearsal covers Disko, the ESP and LUKS.
{
  inputs,
  pkgs,
  self,
  vars,
}:
let
  user = vars.username;
in
pkgs.testers.runNixOSTest {
  name = "linux-niri-session";
  node.specialArgs = { inherit inputs self vars; };
  node.pkgsReadOnly = false;
  nodes.machine = {
    imports = [ ../hosts/linux-niri/system.nix ];
    virtualisation.memorySize = 4096;
    users.users.${user}.initialPassword = "vmtest";
  };

  testScript = ''
    ${builtins.readFile ./niri-login.py}
    machine.start()
    machine.wait_for_unit("greetd.service")
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_unit("home-manager-${user}.service")

    with subtest("empty home received the declared session"):
        machine.succeed("test -s /etc/pam.d/swaylock")
        machine.succeed("test $(systemctl show greetd -p TTYPath --value) = /dev/tty1")
        machine.succeed("su - ${user} -c 'niri validate'")
        machine.succeed("su - ${user} -c 'test -d ~/Pictures/Screenshots'")
        machine.succeed(
            "su - ${user} -c 'for cmd in claude codex git nmtui ghostty vicinae swaylock "
            "playerctl wpctl brightnessctl xwayland-satellite; do command -v $cmd || exit 1; done'"
        )
        machine.succeed("su - ${user} -c 'claude --version && codex --version && codex login --help'")
        machine.fail("test -e /run/current-system/sw/bin/gnome-shell")
        machine.fail("test -e /run/current-system/sw/bin/nautilus")

    with subtest("ordinary user authenticates with tuigreet and starts Niri"):
        exercise_first_login(machine, "${user}", "vmtest")
  '';
}
