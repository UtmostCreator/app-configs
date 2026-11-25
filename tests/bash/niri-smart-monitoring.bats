#!/usr/bin/env bats

@test "Niri has persistent journaling and enables SMART only for an explicit whole-disk identity" {
    repo_nix="$(cd "$BATS_TEST_DIRNAME/../../nix" && pwd)"
    run env REPO_NIX="$repo_nix" nix eval --offline --impure --json --expr '
      let
        root = builtins.getEnv "REPO_NIX";
        flake = builtins.getFlake ("path:" + root);
        base = flake.nixosConfigurations.linux-niri;
        device = "/dev/disk/by-id/ata-MODEL_fixture";
        selected = (base.extendModules {
          modules = [ { myConfig.desktopStability.smartDevice = device; } ];
        }).config;
        desktop = (base.extendModules {
          modules = [ { myConfig.desktopStability.enable = true; } ];
        }).config;
        checkDevice = base.options.myConfig.desktopStability.smartDevice.type.check;
      in {
        generic = base.config.services.smartd.enable;
        journal = base.config.services.journald.settings.Journal.Storage;
        single = {
          inherit (selected.services.smartd) enable autodetect devices extraOptions;
          stateMode = selected.systemd.services.smartd.serviceConfig.StateDirectoryMode;
          fwupd = selected.services.fwupd.enable;
        };
        existing = {
          inherit (desktop.services.smartd) enable autodetect devices extraOptions;
          fwupd = desktop.services.fwupd.enable;
        };
        accepted = checkDevice device;
        refused = builtins.map checkDevice [ "/dev/sda" (device + "-part1") "/dev/disk/by-id/../sda" ];
      }'
    [ "$status" -eq 0 ]
    jq -e '.generic == false and .journal == "persistent" and .accepted and
       .refused == [false,false,false] and
       (.single | .enable and (.autodetect|not) and (.fwupd|not) and
         (.devices|length) == 1 and .devices[0].device == "/dev/disk/by-id/ata-MODEL_fixture" and
         (.devices[0].options | contains("-R 192")) and .stateMode == "0700" and
         (.extraOptions | index("/var/lib/smartmontools/smartd.")) != null) and
       (.existing | .enable and .autodetect and .fwupd and
         .devices == [] and .extraOptions == ["-q","nodev0"])' <<<"$output"
}
