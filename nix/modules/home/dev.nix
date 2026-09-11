{
  config,
  pkgs,
  lib,
  ...
}:
let
  codebaseMemoryMcpVersion = "0.9.0";
  codebaseMemoryMcpArtifact =
    {
      x86_64-linux = {
        platform = "linux-amd64";
        hash = "sha256-wwkBkhugJzjnWdmkY78gWi/jH9j+7UH7hO02TxgBXeo=";
      };
      aarch64-darwin = {
        platform = "darwin-arm64";
        hash = "sha256-WS+E5E1ejqua5xNOmbFUDOPCjoS2hCBPjznN5RYg0O4=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system};
  codebaseMemoryMcp = pkgs.stdenvNoCC.mkDerivation {
    pname = "codebase-memory-mcp-ui";
    version = codebaseMemoryMcpVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${codebaseMemoryMcpVersion}/codebase-memory-mcp-ui-${codebaseMemoryMcpArtifact.platform}.tar.gz";
      inherit (codebaseMemoryMcpArtifact) hash;
    };
    sourceRoot = ".";
    dontStrip = true; # Preserve the UI assets embedded in the release binary.
    installPhase = ''
      runHook preInstall
      install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"
      runHook postInstall
    '';
  };
  codebaseMemoryMcpUi = pkgs.writeShellScript "codebase-memory-mcp-ui-service" ''
    set -euo pipefail
    export CBM_ALLOWED_ROOT=${lib.escapeShellArg "${config.home.homeDirectory}/Projects"}

    # The MCP transport is stdio and exits on EOF. Keep stdin open so the
    # optional loopback-only graph UI remains available independently of an
    # editor session. Editor-launched workers explicitly use --ui=false.
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
    installPhase = ''
      runHook preInstall
      install -Dm755 gremlins "$out/bin/gremlins"
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
      actionlint
      ast-grep
      bats # bats-core formula -> bats in nixpkgs
      bun # JavaScript runtime and package manager
      delta # git-delta formula -> delta in nixpkgs
      difftastic
      code2prompt # template-driven prompt/context generation (AI)
      codebaseMemoryMcp # structural code graph MCP + embedded browser UI
      colima # lightweight container runtime (Docker daemon via VM)
      docker # CLI only; daemon source is host-specific
      docker-buildx # docker buildx plugin (multi-arch builds)
      files-to-prompt # concatenate file sets with path headers (AI)
      claude-code # Anthropic Claude Code CLI; managed by Nix, not curl|bash
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
      mariadb # provides the `mysql` client; lighter than full mysql-client formula
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
      php
      # PHP 8.4 (with extensions). Enables the AI workflow
      # validators in ops/doctor.sh.
      php84Packages.composer # Composer 2.x for PHP 8.4; on PATH on every host.
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
      watchexec
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
    ];

  # Keep the graph browser available at http://127.0.0.1:9749 even when no
  # editor is open. MCP clients still use their own stdio worker and the shared
  # ~/.cache/codebase-memory-mcp indexes; they disable UI to avoid port races.
  systemd.user.services.codebase-memory-mcp-ui = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Codebase Memory MCP graph UI";
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = codebaseMemoryMcpUi;
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
