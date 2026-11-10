{
  config,
  lib,
  pkgs,
  ...
}:
# Hourly self-updates for the AI CLIs that ship their own installers instead
# of Nix packages: Claude Code (~/.local/share/claude) and Codex (~/.codex).
# sys-update does not touch them; these timers do. Logic lives in
# scripts/{claude,codex}-auto-update.sh, tested by
# tests/bash/ai-cli-auto-update.bats. A daily ai-auth-check timer also warns
# before either CLI needs a new interactive login.
#
# Calendar timers with Persistent=true, not OnBootSec/OnUnitActiveSec: the
# monotonic versions these replace stopped rescheduling after a reload and sat
# "elapsed" for weeks. A host without the CLI installed skips the unit.
let
  home = config.home.homeDirectory;
  path = lib.concatStringsSep ":" [
    "${home}/.local/bin"
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];

  mkUpdater =
    {
      name,
      description,
      bin,
      script,
    }:
    {
      services.${name} = {
        Unit = {
          Description = description;
          Wants = [ "network-online.target" ];
          After = [ "network-online.target" ];
          ConditionPathExists = bin;
        };
        Service = {
          Type = "oneshot";
          Environment = [ "PATH=${path}" ];
          ExecStart = "${pkgs.bash}/bin/bash ${script}";
          TimeoutStartSec = "10min";
        };
      };
      timers.${name} = {
        Unit.Description = "Hourly ${description}";
        Timer = {
          OnCalendar = "hourly";
          Persistent = true;
          RandomizedDelaySec = "5min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

  updaters = [
    (mkUpdater {
      name = "claude-auto-update";
      description = "Claude Code update and supervised session restart";
      bin = "${home}/.local/bin/claude";
      script = pkgs.writeText "claude-auto-update.sh" (builtins.readFile ./scripts/claude-auto-update.sh);
    })
    (mkUpdater {
      name = "codex-auto-update";
      description = "Codex CLI update";
      bin = "${home}/.local/bin/codex";
      script = pkgs.writeText "codex-auto-update.sh" (builtins.readFile ./scripts/codex-auto-update.sh);
    })
  ];

  # Days left before Claude Code / Codex need an interactive login, so it is
  # done at home instead of failing while away. Logic lives in
  # scripts/ai-auth-status.sh, tested by tests/bash/ai-auth-status.bats.
  # Not writeShellApplication: its forced errexit would abort on the script's
  # deliberate failing jq probes.
  aiAuthStatus = pkgs.writeShellScriptBin "ai-auth-status" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
        pkgs.libnotify
      ]
    }:$PATH
    exec ${pkgs.bash}/bin/bash ${pkgs.writeText "ai-auth-status.sh" (builtins.readFile ./scripts/ai-auth-status.sh)} "$@"
  '';

  authCheck = {
    services.ai-auth-check = {
      Unit.Description = "Warn when Claude Code or Codex needs a new login soon";
      Service = {
        Type = "oneshot";
        ExecStart = "${aiAuthStatus}/bin/ai-auth-status --notify";
      };
    };
    timers.ai-auth-check = {
      Unit.Description = "Daily AI CLI login expiry check";
      Timer = {
        OnCalendar = "*-*-* 09:00:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # These units used to be hand-made files in ~/.config/systemd/user. Let Home
  # Manager replace them instead of aborting activation on "file in the way".
  takeOver =
    lib.genAttrs
      (lib.concatMap
        (n: [
          "systemd/user/${n}.service"
          "systemd/user/${n}.timer"
          "systemd/user/timers.target.wants/${n}.timer"
        ])
        [
          "claude-auto-update"
          "codex-auto-update"
        ]
      )
      (_: {
        force = true;
      });
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = [ aiAuthStatus ];
  systemd.user = lib.mkMerge (updaters ++ [ authCheck ]);
  xdg.configFile = takeOver;
}
