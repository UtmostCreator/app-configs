{
  config,
  pkgs,
  lib,
  ...
}:
let
  # One binding for php and composer so the interpreter and the composer
  # package (which embeds its php) cannot diverge.
  phpPkg = pkgs.php84;
  codebaseMemoryMcp = pkgs.callPackage ../../packages/codebase-memory-mcp { };
  codebaseMemoryMcpUi = pkgs.writeShellScript "codebase-memory-mcp-ui-service" ''
    set -euo pipefail
    export CBM_ALLOWED_ROOT=${lib.escapeShellArg "${config.home.homeDirectory}/Projects"}

    # The MCP transport is stdio and exits on EOF. Keep stdin open so the
    # optional loopback-only graph UI remains available independently of an
    # editor session. Clients must not pass --ui=false: it disables the shared UI.
    ${pkgs.coreutils}/bin/sleep infinity \
      | ${codebaseMemoryMcp}/bin/codebase-memory-mcp --ui=true --port=9749
  '';

  gremlinsVersion = "0.6.0";
  gremlinsArtifact =
    {
      x86_64-linux = {
        platform = "linux_amd64";
        hash = "sha256-sCpC5Hk1+JHJpBHWjAfiEccIJgnnnCQ1tnyF7pZYxTg=";
      };
      aarch64-darwin = {
        platform = "darwin_arm64";
        hash = "sha256-kN6Fj/rT7qUBjkHN8odHtwA5ZmhLlCD0YF6xC9rQwwE=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system};
  gremlins = pkgs.stdenvNoCC.mkDerivation {
    pname = "gremlins";
    version = gremlinsVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/go-gremlins/gremlins/releases/download/v${gremlinsVersion}/gremlins_${gremlinsVersion}_${gremlinsArtifact.platform}.tar.gz";
      inherit (gremlinsArtifact) hash;
    };
    sourceRoot = ".";
    # Mutants such as `i++` -> `i--` turn loops into unbounded allocators that
    # grow for the whole timeout (5-9 GB each, several at once), which OOM-killed
    # pushes and the desktop. A per-process address-space cap makes such a mutant
    # die within seconds as "fatal error: out of memory" (reported KILLED); the
    # full unmutated ya-under-control suite passes under it.
    # GREMLINS_MAX_VMEM_KB overrides the cap for one run.
    installPhase = ''
      runHook preInstall
      install -Dm755 gremlins "$out/libexec/gremlins"
      mkdir -p "$out/bin"
      cat > "$out/bin/gremlins" <<EOF
      #!${pkgs.runtimeShell}
      ulimit -v \''${GREMLINS_MAX_VMEM_KB:-4194304}
      exec "$out/libexec/gremlins" "\$@"
      EOF
      chmod 755 "$out/bin/gremlins"
      runHook postInstall
    '';
  };
in
{
  # Developer tooling. Per Phase 3 matrix.
  #
  # Never include:
  #   direnv (DROPPED — mise per-project env replaces it)
  #   mise, chezmoi, home-manager, lefthook (bootstrap-installed via nix profile)
  home.packages =
    (with pkgs; [
      act # run GitHub Actions workflows locally
      actionlint
      ast-grep
      tree-sitter # parser generator/CLI for grammar development
      bats # bats-core formula -> bats in nixpkgs
      bun # JavaScript runtime and package manager
      uv # Python package/project manager (see mise for pinned runtimes)
      delta # git-delta formula -> delta in nixpkgs
      difftastic
      code2prompt # template-driven prompt/context generation (AI)
      codebaseMemoryMcp # structural code graph MCP + embedded browser UI
      colima # lightweight container runtime (Docker daemon via VM)
      docker # CLI only; daemon source is host-specific
      docker-buildx # docker buildx plugin (multi-arch builds)
      files-to-prompt # concatenate file sets with path headers (AI)
      opencode
      # AI coding agent CLI (Linux + aarch64-darwin). Shipped here
      # so it is reproducible instead of a hand-edited /etc/nixos line.
      gh
      gitleaks
      just
      lazygit
      onefetch # git repository summary (languages, churn); binary: onefetch
      lnav
      lychee
      markdownlint-cli # Markdown style linter; binary: markdownlint
      # ── Security / vulnerability scanning (opt-in via VERIFY_SECURITY=1 or
      #    AI_VERIFY_SCOPE=all in the AI verify scripts; not run by default) ──
      trivy # filesystem/container/IaC vulnerability scanning
      osv-scanner # dependency vulnerability scanning against the OSV database
      composer-require-checker # verify composer.json declares every used symbol (VERIFY_FULL gate)
      # ── Nix config maintenance toolchain (keeps this flake disciplined) ──
      deadnix # find unused Nix bindings
      nh # friendlier home-manager/nixos-rebuild + GC wrapper
      nix-index # nix-locate: which package provides a missing command
      nix-output-monitor # `nom`: readable, structured build output (use with nh)
      nvd # nix version diff: shows what packages changed on rebuild
      nixfmt # canonical Nix formatter (RFC 166 style)
      statix # Nix linter (anti-patterns, suggestions)
      neovim
      nodejs_22
      # node 22 runtime. On NixOS the mise core:node backend cannot
      # use nodejs.org prebuilt binaries (stub ld-linux loader) and
      # would compile from source; Nix supplies the same 22.x instead.
      p7zip
      phpPkg
      # PHP 8.4 (with extensions). Enables the AI workflow
      # validators in ops/doctor.sh.
      phpPkg.packages.composer # Composer 2.x built for the same PHP as above; on PATH on every host.
      # macOS keeps a Herd+1Password `composer` shell function
      # (fish/zsh) that shadows this binary; on Linux this IS
      # the active composer for project-local PHP work.
      pnpm # fast Node.js package manager (was: brew/corepack)
      promptfoo # LLM prompt/eval harness; golden-task CI gate + local eval runs (AI)
      # Wrapper scripts elsewhere call `npx promptfoo@latest`; this Nix copy
      # makes the CLI available offline/deterministically. The npm-only Phoenix
      # CLIs (@arizeai/phoenix-cli, @arizeai/phoenix-mcp) are not in nixpkgs —
      # install those via `mise run tools:observability:install`.
      repomix # package repository context for LLM prompts (AI)
      python3Packages.lizard # per-function cyclomatic complexity analyzer (terryyin/lizard); binary: lizard
      python3Packages.pytest # Python test runner
      scc
      semgrep
      shellcheck
      shfmt
      stripe-cli # Stripe CLI for local webhook testing (binary: stripe)
      watchexec # rerun on file change (fish `patw` for focused artisan tests)
      xh # readable HTTP client for manual API calls; keep curl for scripts
      hyperfine # benchmark commands (warmups + runs) before claiming a speedup
      # ── Go development toolchain (for the ya-under-control Go rewrite) ──
      #    Installed here so `home-manager switch` provisions the full stack
      #    reproducibly across hosts. golangci-lint bundles staticcheck, govet,
      #    errcheck, ineffassign and unused, so no standalone staticcheck is
      #    listed. Enforced by ya-under-control/.lefthook.yml + CI.
      go # Go toolchain: compiler, gofmt, go vet, go test, go mod, go fix
      gopls # official Go language server (IDE intelligence, renames, code actions)
      golangci-lint # unified lint runner (staticcheck/govet/errcheck/ineffassign/unused/...)
      gofumpt # stricter, opinionated gofmt superset
      gotools # goimports (import management) + other golang.org/x/tools binaries
      govulncheck # reachability-aware vulnerability scanning (govulncheck ./...)
      go-arch-lint # architecture dependency linter driven by .go-arch-lint.yml
      delve # dlv: source-level Go debugger
      gotestsum # readable test output + JUnit for CI
      gremlins # pinned diff-scoped Go mutation testing (pre-commit quality gate)
      goreleaser # single static cross-platform binary release pipeline
      mockgen # go.uber.org/mock generator (typed interface mocks)
    ])
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.bubblewrap # bwrap: preferred Codex CLI Linux sandbox helper
      pkgs.mariadb # provides the `mysql` client; lighter than full mysql-client formula
      # CLIs that macOS gets from Homebrew casks (darwin/homebrew.nix), so
      # Linux and WSL2 match: `op` (NPM_TOKEN, composer wrapper, op-refresh in
      # fish/zsh) and the GitHub Copilot CLI (`copilot`). Both unfree.
      pkgs._1password-cli
      pkgs.github-copilot-cli
      # One ssh-agent per boot, passphrase asked once (conf.d/ssh-agent.fish
      # prefers keychain; macOS uses the system Keychain instead).
      pkgs.keychain
    ]
  # On macOS the `mysql` client comes from Homebrew `mysql-client`
  # (nix/modules/darwin/homebrew.nix), so skip mariadb there to avoid two
  # `mysql` binaries competing on PATH.
  ;

  # Gremlins defaults to one worker per CPU; with a runaway mutant per worker the
  # memory cap above still multiplies. Half the cores leaves the desktop usable.
  # Read from $XDG_CONFIG_HOME/gremlins/gremlins/.gremlins.yaml (the doubled
  # directory is intentional: gremlins v0.6.0 defaultConfigPaths() joins
  # "gremlins","gremlins" under $XDG_CONFIG_HOME; internal/configuration/
  # configuration.go). A repo-level .gremlins.yaml still overrides it.
  xdg.configFile."gremlins/gremlins/.gremlins.yaml".text = ''
    unleash:
      workers: 8
  '';

  # Keep the graph browser available at http://127.0.0.1:9749 even when no
  # editor is open. MCP clients still use their own stdio worker and the shared
  # ~/.cache/codebase-memory-mcp indexes and inherit the daemon UI setting.
  systemd.user.services.codebase-memory-mcp-ui = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Codebase Memory MCP graph UI";
    };
    Service = {
      ExecStart = codebaseMemoryMcpUi;
      ExecStartPost = "${pkgs.curl}/bin/curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 --max-time 30 http://127.0.0.1:9749/ --output /dev/null";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # UI flags mutate shared daemon configuration. Recover if an older client
  # disables it or the listener disappears while the stdio process stays alive.
  systemd.user.services.codebase-memory-mcp-health = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Check Codebase Memory MCP dashboard";
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "codebase-memory-mcp-health" ''
        ${pkgs.curl}/bin/curl --fail --silent --max-time 10 http://127.0.0.1:9749/ --output /dev/null \
          || ${pkgs.systemd}/bin/systemctl --user restart codebase-memory-mcp-ui.service
      '';
    };
  };
  systemd.user.timers.codebase-memory-mcp-health = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Keep Codebase Memory MCP dashboard available";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.codebase-memory-mcp-update = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Update Codebase Memory MCP from the latest verified stable release";
      # No network-online.target ordering: it is a system-manager target and has
      # no effect in `systemd --user`. The script retries its downloads (curl
      # --retry) and the unit is timer-driven (Persistent), so a missed network
      # fails this run and the next timer fire retries.
    };
    Service = {
      Type = "oneshot";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.curl
          pkgs.diffutils
          pkgs.git
          pkgs.gnugrep
          pkgs.jq
          pkgs.nix
          pkgs.systemd
          pkgs.util-linux
        ]
      }:${config.home.profileDirectory}/bin";
      # Find the repo through chezmoi's source dir (the sys-* helpers do the
      # same), not a fixed ~/Projects/app-configs: README installs to
      # ~/app-configs. chezmoi is on PATH via the profile bin dir above.
      # Logic in scripts/codebase-memory-mcp-update.sh (tested by
      # tests/bash/bootstrap-safety.bats).
      # NOTE: with --apply the script runs `home-manager switch` when a new
      # release lock is found, i.e. a full Home Manager activation from a
      # background timer. Accepted by design (it is what installs the update);
      # it only runs for a changed, verified release.
      ExecStart = "${pkgs.writeShellScript "codebase-memory-mcp-update" (
        builtins.readFile ./scripts/codebase-memory-mcp-update.sh
      )}";
      TimeoutStartSec = "30min";
    };
  };
  systemd.user.timers.codebase-memory-mcp-update = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Weekly Codebase Memory MCP stable updates";
    Timer = {
      OnCalendar = "Mon *-*-* 10:00:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
