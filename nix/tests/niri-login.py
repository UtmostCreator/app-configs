def exercise_first_login(machine, user, password):
    machine.wait_until_succeeds("pidof tuigreet")
    machine.send_chars(f"{user}\n")
    machine.wait_until_tty_matches("1", "(?i)password")
    machine.send_chars("wrongpass\n")
    machine.wait_until_tty_matches("1", "(?i)authentication failed", timeout=30)
    machine.fail("pidof niri")
    # Escape clears the failed login and returns to the username field.
    machine.send_key("esc")
    machine.send_chars(f"{user}\n")
    machine.wait_until_tty_matches("1", "(?i)password", timeout=30)
    machine.send_chars(f"{password}\n")
    uid = machine.succeed(f"id -u {user}").strip()
    user_services = f"systemctl --user -M {user}@.host is-active "
    for unit in ("niri", "swayidle", "vicinae", "polkit-soteria"):
        machine.wait_until_succeeds(user_services + unit + ".service")
    machine.wait_until_succeeds(f"test -S /run/user/{uid}/niri.*.sock")
    sock = machine.succeed(f"echo /run/user/{uid}/niri.*.sock").strip()
    msg = f"su - {user} -c 'NIRI_SOCKET={sock} niri msg "
    machine.succeed(msg + "keyboard-layouts' | grep -q Russian")
    machine.wait_until_succeeds(
        "journalctl -b _SYSTEMD_USER_UNIT=vicinae.service | grep -Fq 'Activated clipboard server'"
    )
    machine.send_key("meta_l-t")
    machine.wait_until_succeeds(msg + "windows' | grep -iq ghostty", timeout=30)
    machine.send_key("alt-spc")
    machine.wait_until_succeeds(msg + "windows' | grep -iq vicinae", timeout=30)
    cli = f"su - {user} -c 'XDG_RUNTIME_DIR=/run/user/{uid} vicinae "
    machine.succeed(cli + "cmd ls' | grep -Fxq @ShyAssassin/vicinae-extension-vscode-recents-0:open-recents")
    machine.succeed(cli + "deeplink vicinae://launch/clipboard/history'")
    machine.succeed(cli + "deeplink vicinae://launch/@ShyAssassin/vicinae-extension-vscode-recents-0/open-recents'")
    # Quit can close IPC before the client receives its reply. Assert
    # that the compositor acknowledged the request and the login returned.
    machine.execute(msg + "action quit --skip-confirmation'")
    machine.wait_until_succeeds("journalctl -b _SYSTEMD_USER_UNIT=niri.service -g 'quitting as requested' | grep -q 'quitting as requested'")
    machine.wait_until_succeeds("pidof tuigreet")
    machine.fail(f"test -S {sock}")
