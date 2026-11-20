#!/usr/bin/env bats
# The niri pilot host (PC 2): a build-only NixOS system with GNOME as the
# default GDM session and niri as a second, selectable session.
#
# Source: nix/hosts/linux-desktop-pilot/system.nix, wired in nix/flake.nix as
#         nixosConfigurations.linux-desktop-pilot.
#
# Guards the decisions that keep the pilot reversible (ADR-0012): GDM and GNOME
# stay, GNOME is the default (the pinned niri module would otherwise make niri
# the default session), and niri is only an extra session. The disk layout is a
# by-label placeholder until the real host's generated hardware config or a
# disko layout (ADR-0038) replaces it. Nothing here is activated on PC 1.
#
# Run:  bats tests/bash/nixos-pilot.bats

setup_file() {
    command -v nix >/dev/null || skip "nix not installed"
    command -v jq >/dev/null || skip "jq not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PILOT_JSON="$BATS_FILE_TMPDIR/pilot.json"
    user="$(nix eval --raw -f "$REPO_ROOT/nix/vars/default.nix" username)"
    nix eval --json "path:$REPO_ROOT/nix#nixosConfigurations.linux-desktop-pilot" \
        --apply "h: let c = h.config; u = c.users.users.\"$user\"; in {
          hostName = c.networking.hostName;
          gdm = c.services.displayManager.gdm.enable;
          gnome = c.services.desktopManager.gnome.enable;
          niri = c.programs.niri.enable;
          defaultSession = c.services.displayManager.defaultSession;
          sessions = c.services.displayManager.sessionData.sessionNames;
          userNormal = u.isNormalUser;
          userGroups = u.extraGroups;
          stateVersion = c.system.stateVersion;
          rootDevice = c.fileSystems.\"/\".device;
          bootDevice = c.fileSystems.\"/boot\".device;
          systemdBoot = c.boot.loader.systemd-boot.enable;
          flakes = c.nix.settings.experimental-features;
          revision = c.system.configurationRevision;
          toplevel = builtins.unsafeDiscardStringContext c.system.build.toplevel.drvPath;
        }" >"$PILOT_JSON"
}

field() { jq -r "$1" "$PILOT_JSON"; }

@test "pilot host: evaluates to a full NixOS system named linux-desktop-pilot" {
    [ "$(field .hostName)" = "linux-desktop-pilot" ]
    [[ "$(field .toplevel)" == /nix/store/*.drv ]]
}

@test "pilot sessions: GDM and GNOME stay, niri is a second session" {
    [ "$(field .gdm)" = "true" ]
    [ "$(field .gnome)" = "true" ]
    [ "$(field .niri)" = "true" ]
    field '.sessions[]' | grep -qx gnome
    field '.sessions[]' | grep -qx niri
}

@test "pilot sessions: GNOME is the default, not niri" {
    [ "$(field .defaultSession)" = "gnome" ]
}

@test "pilot user: the repo user is a normal user in wheel and networkmanager" {
    [ "$(field .userNormal)" = "true" ]
    field '.userGroups[]' | grep -qx wheel
    field '.userGroups[]' | grep -qx networkmanager
}

@test "pilot install basics: flakes on, systemd-boot, release stateVersion" {
    field '.flakes' | grep -q flakes
    [ "$(field .systemdBoot)" = "true" ]
    [ "$(field .stateVersion)" = "26.11" ]
    [ -n "$(field .revision)" ]
}

@test "pilot disks: placeholders name filesystems by label, never /dev/sdX or nvme paths" {
    [[ "$(field .rootDevice)" == /dev/disk/by-* ]]
    [[ "$(field .bootDevice)" == /dev/disk/by-* ]]
}
