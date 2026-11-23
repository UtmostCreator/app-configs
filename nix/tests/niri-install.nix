# Run Disko and nixos-install in an installer guest. The destination then
# boots only from its own encrypted QEMU disk, with its own writable store.
{ host, vars }:
let
  inherit (host) pkgs;
  installed = host.extendModules {
    modules = [
      (
        { modulesPath, ... }:
        {
          imports = [ (modulesPath + "/testing/test-instrumentation.nix") ];
          specialisation.broken-desktop.configuration.services.greetd.enable = pkgs.lib.mkForce false;
          boot.loader.timeout = 1;
        }
      )
    ];
  };
  system = installed.config.system.build.toplevel;
  # Only the installer gets a fixture file. The installed initrd must prompt.
  disk = host.extendModules {
    modules = [
      {
        disko.devices.disk.main = {
          device = pkgs.lib.mkForce "/dev/disk/by-id/virtio-root";
          content.partitions.root.content.passwordFile = "/run/test-passphrase";
        };
      }
    ];
  };
  prepare = pkgs.lib.getExe disk.config.system.build.formatMount;
  mountExisting = pkgs.lib.getExe disk.config.system.build.mount;
  common.virtualisation = {
    # As in nixpkgs' installer test, share only the virtual target disk.
    diskImage = "./linux-niri.qcow2";
    diskSize = 48 * 1024;
    memorySize = 4096;
    cores = 4;
    useDefaultFilesystems = false;
  };
in
pkgs.testers.runNixOSTest {
  name = "linux-niri-install-recovery";
  enableOCR = true;

  nodes.installer = {
    imports = [ common ];
    virtualisation = {
      emptyDiskImages = [ 2048 ];
      fileSystems."/" = {
        device = "/dev/vdb";
        fsType = "ext4";
        autoFormat = true;
      };
      writableStore = true;
      additionalPaths = [ system ];
    };
    nix.enable = true;
    nix.settings.substituters = pkgs.lib.mkForce [ ];
    environment.systemPackages = [
      pkgs.cryptsetup
      pkgs.nixos-install
      pkgs.nixos-enter
    ];
  };
  nodes.target = {
    imports = [ common ];
    virtualisation = {
      useBootLoader = true;
      useEFIBoot = true;
      efi.keepVariables = false;
      mountHostNixStore = false;
      # The VM runner requires a root declaration to build its launch
      # command. UEFI boots the installed system's on-disk configuration.
      fileSystems."/" = {
        device = "/dev/mapper/linux-niri-root";
        fsType = "ext4";
      };
    };
  };

  testScript = ''
    ${builtins.readFile ./niri-login.py}
    profile = "/nix/var/nix/profiles/system"

    def boot_target():
        target.start()
        target.wait_for_text("[Pp]assphrase", timeout=120)
        target.send_chars("test-passphrase\n")
        target.wait_for_unit("multi-user.target")

    with subtest("install the target on a blank disk and enrol the user"):
        installer.start()
        installer.wait_for_unit("multi-user.target")
        installer.succeed("test $(readlink -f /dev/disk/by-id/virtio-root) = /dev/vda")
        installer.fail("blkid /dev/vda")
        installer.succeed("echo -n test-passphrase > /run/test-passphrase")
        installer.succeed("${prepare}")
        installer.succeed("nixos-install --no-channel-copy --no-root-passwd --system ${system}", timeout=1800)
        installer.succeed("nixos-enter --root /mnt -c 'echo ${vars.username}:test-login | chpasswd'")
        installer.succeed("umount -R /mnt && cryptsetup close linux-niri-root")
        installer.shutdown()

    with subtest("cold boot the installed closure through UEFI and LUKS"):
        target.state_dir = installer.state_dir
        boot_target()
        target.succeed("test -d /sys/firmware/efi && test -s /boot/EFI/BOOT/BOOTX64.EFI")
        target.succeed("test \"$(findmnt -n -o FSTYPE /boot)\" = vfat")
        target.succeed("test \"$(findmnt -n -o FSTYPE /)\" = ext4")
        target.succeed("test \"$(findmnt -n -o FSTYPE -T /nix/store)\" = ext4")
        target.succeed("${pkgs.cryptsetup}/bin/cryptsetup isLuks --type luks2 /dev/disk/by-partlabel/linux-niri-luks")
        nvidia = target.succeed("readlink -e /run/booted-system/specialisation/nvidia-open").strip()
        entry = target.succeed("grep -Fl '(nvidia-open)' /boot/loader/entries/*.conf").strip()
        target.succeed(f"grep -F 'init={nvidia}/init' {entry}")
        target.succeed(f"grep -E '^options nvidia-drm .*modeset=1' {nvidia}/etc/modprobe.d/nixos.conf")
        target.wait_for_unit("greetd.service")
        target.wait_for_unit("home-manager-${vars.username}.service")
        target.succeed("test -s /home/${vars.username}/.config/niri/config.kdl")
        target.succeed("su - ${vars.username} -c 'claude --version && codex --version && codex login --help && niri validate'")
        good = target.succeed("readlink -f /run/booted-system").strip()
        assert good == "${system}"
        good_link = target.succeed(f"basename $(readlink {profile})").strip()
        good_generation = good_link.removeprefix("system-").removesuffix("-link")
        assert good_generation.isdigit()

    with subtest("connect the isolated virtual Ethernet interface with NetworkManager"):
        target.wait_for_unit("NetworkManager.service")
        nic = target.succeed("nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == \"ethernet\" {print $1; exit}'").strip()
        assert nic
        target.succeed(f"nmcli con add con-name rehearsal type ethernet ifname {nic} "
                       "ipv4.method manual ipv4.addresses 192.0.2.10/24 ipv6.method disabled connection.autoconnect no")
        target.succeed("nmcli --wait 30 con up rehearsal")
        target.succeed(f"nmcli -t -f DEVICE,STATE device | grep -Fx '{nic}:connected'")
        target.succeed("nmcli con delete rehearsal")

    with subtest("log into the installed Niri session and use its launch shortcuts"):
        exercise_first_login(target, "${vars.username}", "test-login")

    with subtest("boot a different generation with its greeter disabled"):
        candidate = target.succeed("readlink -f /run/current-system/specialisation/broken-desktop").strip()
        assert good != candidate
        target.succeed(f"nix-env -p {profile} --set {candidate}")
        target.succeed(f"{profile}/bin/switch-to-configuration boot")
        target.shutdown()
        boot_target()
        target.succeed(f"test $(readlink -f /run/booted-system) = {candidate}")
        target.fail("systemctl is-active greetd.service")

    with subtest("restore the working generation at an authenticated TTY"):
        target.send_key("ctrl-alt-f2")
        target.wait_until_tty_matches("2", "login:", timeout=60)
        target.send_chars("${vars.username}\n")
        target.wait_until_tty_matches("2", "(?i)password:", timeout=30)
        target.send_chars("test-login\n")
        target.wait_until_succeeds("loginctl list-sessions --no-legend | grep '${vars.username}.*tty2'", timeout=60)
        target.send_chars("sudo -p 'Recovery sudo: ' -v && touch /tmp/sudo-ready\n")
        target.wait_until_tty_matches("2", r"(?m)^Recovery sudo: *$", timeout=30)
        target.send_chars("test-login\n")
        target.wait_until_succeeds("test -e /tmp/sudo-ready", timeout=30)
        target.send_chars(
            f"sudo nix-env -p {profile} --switch-generation {good_generation} && "
            f"sudo {profile}/bin/switch-to-configuration boot && touch /tmp/rollback-complete\n"
        )
        target.wait_until_succeeds("test -e /tmp/rollback-complete", timeout=90)
        target.shutdown()
        boot_target()
        target.succeed(f"test $(readlink -f /run/booted-system) = {good}")
        target.wait_for_unit("greetd.service")

    with subtest("recover the previous generation from the offline installer"):
        target.succeed(f"nix-env -p {profile} --set {candidate}")
        target.succeed(f"{profile}/bin/switch-to-configuration boot")
        target.shutdown()
        installer.start()
        installer.wait_for_unit("multi-user.target")
        installer.succeed("echo -n test-passphrase > /run/test-passphrase")
        installer.succeed("${mountExisting}")
        installer.succeed(f"nixos-enter --root /mnt -c 'nix-env -p {profile} --switch-generation {good_generation} && {profile}/bin/switch-to-configuration boot'")
        installer.succeed("umount -R /mnt && cryptsetup close linux-niri-root")
        installer.shutdown()
        boot_target()
        target.succeed(f"test $(readlink -f /run/booted-system) = {good}")
        target.wait_for_unit("greetd.service")
  '';
}
