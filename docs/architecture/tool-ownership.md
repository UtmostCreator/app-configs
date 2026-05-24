# Tool ownership

Canonical statement of which tool owns which concern in this repository.
Companion to `new-architecture-todo-v2.md`. Companion audit docs:
`docs/migration-source-of-truth.md`, `docs/migration-package-ownership.md`,
`docs/migration-decisions.md`.

## Targets

- **macOS** — primary, full coverage (Home Manager + nix-darwin + Homebrew casks)
- **Linux desktop** — primary, full coverage (Home Manager standalone + GUI module)
- **Linux CLI / headless** — CLI-only coverage (Home Manager standalone, no GUI)
- **WSL2** — best-effort CLI-only, Linux-flavoured shell/dev only.
  Windows-side tooling is out of scope.
- **Windows native** — explicitly not supported.

## Ownership table

| Tool | Owns | Never owns |
|------|------|-----------|
| **chezmoi** | Dotfiles in `~` and `~/.config/`. File rendering only — no orchestration. | Package installation, side effects beyond writing files. |
| **mise** | Language runtimes (PHP, Node, pnpm via corepack), tool versions, per-project env vars, repo tasks (`mise run sync`, `sync:apply`, `doctor`, `lint:*`, `repo:*`). | OS packages, dotfile content. |
| **Nix + Home Manager** | User-installed CLI packages via `home.packages` only. | Files chezmoi configures. Bootstrap-managed tools (`chezmoi`, `mise`, `home-manager`, `lefthook`). |
| **nix-darwin** | macOS system defaults + Homebrew cask bridge for GUI apps. | Linux/WSL config. |
| **Lefthook** | Git hooks. | Anything outside the git lifecycle. |
| **bootstrap.sh** | Initial cold-start orchestration on a new machine. | Day-to-day updates — that is `mise run sync` (preview) / `mise run sync:apply` (mutate). |

## Hard rules

- `.chezmoiroot` at the repo root, containing exactly `home`.
- Home Manager uses `home.packages = [ ... ]` only.  
  The **only** allowed `programs.<x>.enable` is `programs.home-manager.enable = true;`.
- Home Manager must NOT create or manage any of:
  `~/.zshrc`, `~/.gitconfig`, `~/.config/starship/starship.toml`,
  `~/.config/mise/config.toml`, `~/.config/nvim`, `~/.config/ghostty`,
  VS Code user settings.
- chezmoi must NOT install packages, switch Nix profiles, or run any
  orchestration.
- bootstrap.sh runs ONCE per machine. `mise run sync` previews ongoing
  updates; `mise run sync:apply` is the explicit mutating update command.
- `direnv` is DROPPED — mise covers per-project env activation. Re-add
  only if a specific gap is documented.

## Validation

`bash scripts/validate-config.sh` enforces the above (run automatically
via Lefthook pre-push). It does not flag native Windows files or `.husky/`
because those are deferred / out-of-scope, not forbidden.

## Secrets handling

This repo does NOT store secrets. Identity that drives templating lives in
`home/.chezmoidata/personal.yaml` which is gitignored. Only
`home/personal.yaml.example` is committed (it lives outside `.chezmoidata/` because chezmoi autoloads every YAML/TOML/JSON in that dir).

For real per-host secrets (SSH keys, API tokens), chezmoi supports
`age`, `1Password`, and `Bitwarden` integrations. Choose explicitly when
needed. Until then, do not bolt on a secrets layer.

## Dependency update procedure

Quarterly or as needed:

```bash
# Refresh Nix inputs
nix flake update ./nix
nix flake check ./nix

# Preview the impact
mise run sync         # alias for sync:dry-run

# Apply if preview looks right
mise run sync:apply
```

Per-tool version bumps:

```bash
# mise-managed runtimes (PHP, Node, pnpm)
mise outdated
mise upgrade <tool>
```

Home Manager `stateVersion` should only be bumped when Home Manager
explicitly asks you to. It's a migration anchor, not a "latest" knob.

`nixpkgs` currently follows `nixpkgs-unstable`. To pin a stable release,
edit `nix/flake.nix` and run `nix flake update`.
