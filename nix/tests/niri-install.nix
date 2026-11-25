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
  # Bundle just the allowlisted, synthetic first-login inputs. The target
  # starts without a project checkout and uses its own home and Nix store.
  fixtureReceipt =
    pkgs.runCommand "niri-install-fixture-receipt" { nativeBuildInputs = [ pkgs.gitMinimal ]; }
      ''
        export HOME=$TMPDIR
        export GIT_AUTHOR_DATE=2001-01-01T00:00:00Z GIT_COMMITTER_DATE=2001-01-01T00:00:00Z
        git init -q -b main repo
        cd repo
        mkdir -p home/dot_config/{app-configs,fish/conf.d}
        echo '# VM client loader' > home/dot_config/app-configs/ssh-agent.sh
        echo '# VM fish client loader' > home/dot_config/fish/conf.d/ssh-agent.fish
        echo '# VM user shell for {{ .chezmoi.os }}' > home/dot_bashrc.tmpl
        git add home
        git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm fixture
        mkdir -p "$out"
        git rev-parse HEAD > "$out/install-revision"
        git bundle create "$out/install.bundle" refs/heads/main
      '';
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
      additionalPaths = [
        system
        fixtureReceipt
      ];
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
        installer.succeed("install -d -m 0755 /mnt/var/lib/app-configs")
        installer.succeed("install -m 0444 ${fixtureReceipt}/install* /mnt/var/lib/app-configs/")
        installer.succeed("echo virtio-root > /mnt/var/lib/app-configs/install-disk-id")
        installer.succeed("echo ${system} > /mnt/var/lib/app-configs/install-system")
        installer.succeed("chmod 0444 /mnt/var/lib/app-configs/install-system")
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
        good = target.succeed("readlink -f /run/booted-system").strip()
        assert good == "${system}"
        good_link = target.succeed(f"basename $(readlink {profile})").strip()
        good_generation = good_link.removeprefix("system-").removesuffix("-link")
        assert good_generation.isdigit()

    with subtest("prepare the ordinary user's workspace on first login while offline"):
        user = "${vars.username}"
        home = "/home/" + user
        repo = home + "/Projects/app-configs"
        reports = home + "/Documents/app-configs-setup"
        latest = reports + "/Latest"
        ssh_loader = home + "/.config/app-configs/ssh-agent.sh"
        target.succeed(f"test ! -e {repo} && test ! -e {reports} && test ! -e {ssh_loader}")
        target.succeed("nmcli networking off")
        target.wait_until_succeeds("test -z \"$(ip -4 route show default; ip -6 route show default)\"", timeout=30)
        target.send_key("ctrl-alt-f2")
        target.wait_until_tty_matches("2", "login:", timeout=60)
        target.send_chars(user + "\n")
        target.wait_until_tty_matches("2", "(?i)password:", timeout=30)
        target.send_chars("test-login\n")
        ctl = f"systemctl --user -M {user}@.host"
        target.succeed("su - ${vars.username} -c 'claude --version && codex --version && codex login --help && niri validate'")
        target.wait_until_succeeds(f"{ctl} is-active app-configs-first-login.timer", timeout=60)
        target.wait_until_succeeds(f"test -s {latest}/Summary.txt", timeout=300)
        target.succeed(f"grep -Fx 'RESULT  Automatic steps passed' {latest}/Summary.txt")
        target.succeed(f"grep -Fx 'RESULT  Required checks passed' {latest}/Details.log")
        target.succeed(f"grep -Fx 'SKIP  Offline; no default route' {latest}/Details.log")
        target.succeed(f"test $(stat -c %U:%a {reports}) = {user}:700")
        for file in ("Summary.txt", "Details.log"):
            target.succeed(f"test $(stat -c %U:%a {latest}/{file}) = {user}:600")
        target.succeed(f"su - {user} -c 'git -C {repo} rev-parse HEAD' | cmp - /var/lib/app-configs/install-revision")
        target.succeed(f"su - {user} -c 'command -v chezmoi && command -v mise && command -v lefthook'")
        target.succeed(f"grep -Fx '# VM client loader' {ssh_loader}")
        target.succeed(f"test $(stat -c %U:%a {home}/.ssh) = {user}:700")
        target.succeed(f"test $(stat -c %U:%a {ssh_loader}) = {user}:600")

        # Existing shell changes and untracked project files survive a second run.
        first_report = target.succeed(f"readlink {latest}").strip()
        target.succeed(f"su - {user} -c 'echo local-edit >> {ssh_loader} && echo work-in-progress > {repo}/local-notes'")
        target.succeed(f"{ctl} start app-configs-first-login.service", timeout=300)
        assert target.succeed(f"readlink {latest}").strip() != first_report
        target.succeed(f"test -s {reports}/{first_report}/Summary.txt")
        target.succeed(f"grep -Fx 'RESULT  Automatic steps passed' {latest}/Summary.txt")
        target.succeed(f"grep -Fx local-edit {ssh_loader} && grep -Fx work-in-progress {repo}/local-notes")
        target.send_chars("exit\n")
        target.wait_until_tty_matches("2", r"(?m)^.*login: *$", timeout=30)
        target.send_key("ctrl-alt-f1")
        target.succeed("nmcli networking on")

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
        # multi-user.target can precede the first interactive console prompt.
        target.wait_until_tty_matches("1", "login:", timeout=60)
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
        # Run the shipped maintenance wrapper in the same authenticated TTY.
        # The preserved user edit must block staging before the loader changes.
        target.send_chars("sys-update --apply > /tmp/apply-report 2>&1; echo $? > /tmp/apply-status\n")
        target.wait_until_succeeds("test -s /tmp/apply-status", timeout=30)
        target.succeed("test $(cat /tmp/apply-status) = 1")
        target.succeed("grep -Fx 'Review and commit checkout changes before staging.' /tmp/apply-report")
        target.send_chars(f"sys-update rollback {good_generation} && touch /tmp/oneshot-ready\n")
        target.wait_until_succeeds("test -e /tmp/oneshot-ready", timeout=45)
        esp_entry = target.succeed(f"grep -Fl 'init={good}/init ' /boot/loader/entries/*.conf").strip()
        assert len(esp_entry.splitlines()) == 1
        oneshot = "/sys/firmware/efi/efivars/LoaderEntryOneShot-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"
        raw = bytes.fromhex(target.succeed(f"od -An -v -t x1 {oneshot}"))
        assert raw[4:].decode("utf-16-le").rstrip("\0") == esp_entry.rsplit("/", 1)[-1]
        target.succeed(f"test $(readlink -f {profile}) = {candidate}")
        # Clear the proven single-use override so the original persistent
        # generation rollback and subsequent offline rescue stand on their own.
        target.succeed("bootctl --esp-path=/boot set-oneshot \"\"")
        target.fail(f"test -e {oneshot}")
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
