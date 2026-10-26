{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;

  # Secrets live OUTSIDE this repo and outside the Nix store. The repo only
  # names the paths; create the files once per machine (chmod 600). See
  # docs/guides/openclaw-telegram.md.
  secretsDir = "${home}/.secrets/openclaw";

  # The gateway's systemd PATH does not include ~/.local/bin, where the native
  # Claude Code installer puts `claude`. A tiny shim on the gateway-only
  # runtime PATH lets the claude-cli runtime reuse the existing Claude Code
  # login without exposing anything on the user's login PATH.
  claudeShim = pkgs.writeShellScriptBin "claude" ''
    exec ${home}/.local/bin/claude "$@"
  '';
in
{
  # OpenClaw gateway (github:openclaw/openclaw) talking to Telegram, via the
  # official nix-openclaw Home-Manager module (programs.openclaw, provided by
  # the `nix-openclaw` flake input and imported in
  # nix/hosts/linux-desktop/home.nix).
  #
  # Runs as the `openclaw-gateway` systemd user service. Nix owns the config
  # (~/.openclaw/openclaw.json is a store symlink); runtime state such as
  # sessions, pairing approvals, model OAuth logins, and the agent's own
  # workspace identity stays in ~/.openclaw and never enters this repo.
  #
  # Access: Telegram DMs use pairing. Unknown senders get a code that must be
  # approved locally (`openclaw pairing approve telegram <code>`), so no
  # Telegram user IDs are committed here. Groups are disabled.
  #
  # Models: GPT-6 Astra via ChatGPT subscription OAuth (OpenClaw runtime) is
  # primary; Claude Opus via the local Claude Code login is the fallback and is
  # selectable with /models.
  #
  # Personal Linux machines only.
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.myConfig.profile == "personal") {
    programs.openclaw = {
      enable = true;

      # No `runtimePlugins = [ "codex" ]`: OpenClaw 2026.10.7 only lets a
      # bundled or `openclaw plugins install`-ed @openclaw/codex register the
      # Codex harness, so the Nix-loaded copy is rejected ("only bundled
      # plugins can claim reserved command ownership: codex"). ChatGPT OAuth
      # runs on OpenClaw's own runtime instead (agentRuntime below).
      # Telegram is built into core.
      runtimePackages = [ claudeShim ];

      # On by default upstream but needs a Google Places API key we don't set.
      bundledPlugins.goplaces.enable = false;

      config = {
        secrets.providers.gatewaytoken = {
          source = "file";
          path = "${secretsDir}/gateway-token";
          mode = "singleValue";
        };

        gateway = {
          mode = "local";
          auth = {
            mode = "token";
            # Resolved from the file above by both the service and the CLI.
            token = {
              source = "file";
              provider = "gatewaytoken";
              id = "value";
            };
          };
        };

        channels.telegram = {
          enabled = true;
          tokenFile = "${secretsDir}/telegram-bot-token";
          dmPolicy = "pairing";
          groupPolicy = "disabled";
          configWrites = false;
        };

        agents.defaults = {
          model = {
            primary = "openai/gpt-6-astra";
            fallbacks = [ "anthropic/claude-opus-5-5" ];
          };
          models = {
            "openai/gpt-6-astra".agentRuntime.id = "openclaw";
            "anthropic/claude-opus-5-5".agentRuntime.id = "claude-cli";
          };
          # Without an explicit policy, Nix mode (no doctor migration) treats
          # the `models` keys as a legacy allowlist; allow both providers.
          modelPolicy.allow = [
            "openai/*"
            "anthropic/*"
          ];
        };
      };
    };

    # Upstream's unit has no [Install] section, so it would only start on
    # `home-manager switch`. Start it with the user session too. The rest is
    # what `openclaw gateway status` recommends and nix-openclaw omits: wait
    # for the network, let active turns drain on stop, back off restarts.
    systemd.user.services.openclaw-gateway = {
      Install.WantedBy = [ "default.target" ];
      Unit = {
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        # Upstream asks for >=330s so long turns can drain, but when Telegram
        # requests hang the gateway never exits and every restart waits the
        # full budget. 60s keeps restarts snappy for a personal bot.
        TimeoutStopSec = 60;
        KillMode = "mixed";
        RestartSec = lib.mkForce "5s";
      };
    };
  };
}
