{ pkgs, ... }:
{
  # Developer tooling. Per Phase 3 matrix.
  #
  # Never include:
  #   direnv (DROPPED — mise per-project env replaces it)
  #   mise, chezmoi, home-manager, lefthook (bootstrap-installed via nix profile)
  home.packages = with pkgs; [
    actionlint
    ast-grep
    bats # bats-core formula -> bats in nixpkgs
    bun # JavaScript runtime and package manager
    delta # git-delta formula -> delta in nixpkgs
    difftastic
    code2prompt # template-driven prompt/context generation (AI)
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
    nixfmt-rfc-style # canonical Nix formatter (RFC 166 style)
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
    # the active composer. Required by ai-verify.sh / ai-task.sh
    # and listed in docs/ai/repo-required-tools.md.
    pnpm # fast Node.js package manager (was: brew/corepack)
    promptfoo # LLM prompt/eval harness; golden-task CI gate + local eval runs (AI)
    # Wrapper scripts elsewhere call `npx promptfoo@latest`; this Nix copy
    # makes the CLI available offline/deterministically. The npm-only Phoenix
    # CLIs (@arizeai/phoenix-cli, @arizeai/phoenix-mcp) are not in nixpkgs —
    # install those via `mise run tools:observability:install`.
    repomix # package repository context for LLM prompts (AI)
    python3Packages.lizard # per-function cyclomatic complexity analyzer (terryyin/lizard); binary: lizard
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
    goreleaser # single static cross-platform binary release pipeline
    mockgen # go.uber.org/mock generator (typed interface mocks)
  ];
}
