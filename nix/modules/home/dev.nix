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
    bats             # bats-core formula -> bats in nixpkgs
    delta            # git-delta formula -> delta in nixpkgs
    difftastic
    code2prompt      # template-driven prompt/context generation (AI)
    colima           # lightweight container runtime (Docker daemon via VM)
    docker           # CLI only; daemon source is host-specific
    docker-buildx    # docker buildx plugin (multi-arch builds)
    files-to-prompt  # concatenate file sets with path headers (AI)
    gh
    gitleaks
    just
    lazygit
    lnav
    lychee
    mariadb          # provides the `mysql` client; lighter than full mysql-client formula
    neovim
    nodejs_22        # node 22 runtime. On NixOS the mise core:node backend cannot
                     # use nodejs.org prebuilt binaries (stub ld-linux loader) and
                     # would compile from source; Nix supplies the same 22.x instead.
    p7zip
    php              # PHP 8.4 (with extensions). Enables the AI workflow
                     # validators in scripts/doctor.sh (previously optional).
    pnpm             # fast Node.js package manager (was: brew/corepack)
    repomix          # package repository context for LLM prompts (AI)
    scc
    semgrep
    shellcheck
    shfmt
    stripe-cli       # Stripe CLI for local webhook testing (binary: stripe)
    watchexec
  ];
}
