{
  config,
  lib,
  pkgs,
  ...
}:
# Weekly read-only audit of this machine: `ops/audit.sh --live` (chezmoi drift,
# failed user units, nix-profile collisions, last sys-update run, dirty main
# checkout, stale codebase-memory projects). The output lands in the journal
# (`journalctl --user -u repo-audit`); a FAIL also raises a desktop
# notification, or a Windows toast on WSL2. Logic lives in
# scripts/repo-audit.sh, tested by tests/bash/repo-audit-timer.bats.
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  systemd.user.services.repo-audit = {
    Unit.Description = "Read-only audit of this machine (ops/audit.sh --live)";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.diffutils
          pkgs.findutils
          pkgs.gawk
          pkgs.git
          pkgs.gnugrep
          pkgs.gnused
          pkgs.jq
          pkgs.libnotify
          pkgs.nix
          pkgs.systemd
          pkgs.util-linux
        ]
      }:${config.home.profileDirectory}/bin";
      # The repo is found through chezmoi's source dir (on PATH via the profile
      # bin dir above), as in the codebase-memory-mcp-update unit.
      ExecStart = "${pkgs.writeShellScript "repo-audit" (builtins.readFile ./scripts/repo-audit.sh)}";
      TimeoutStartSec = "10min";
    };
  };
  systemd.user.timers.repo-audit = {
    Unit.Description = "Weekly read-only audit of this machine";
    Timer = {
      OnCalendar = "Sun *-*-* 18:30:00";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
