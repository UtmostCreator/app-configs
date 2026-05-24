# Package ownership matrix (final)

Reviewed copy of `docs/migration-package-ownership.draft.md`. Phase 6 reads
only this file. Regenerate the draft via
`bash scripts/generate-package-matrix.sh`.

Branch: `feat/dotfiles-migration`
Decision date: 2026-05-24

## Owner legend

| Owner | Meaning |
|-------|---------|
| **Nix** | Home Manager `home.packages`. Same nixpkgs attribute name on macOS/Linux/WSL unless noted. |
| **nix-profile** | Bootstrap-installed via `nix profile install` before Home Manager runs. Excluded from Home Manager modules to avoid the chicken-and-egg loop. |
| **mise** | Language runtime or per-project tool version. Owned by mise. Never duplicated into Nix or Homebrew. |
| **cask** | Homebrew cask, bridged through `nix-darwin`. macOS only. Never put in `home.packages`. |
| **manual** | Out-of-band install per docs (App Store, official installer, npm/cargo/uv, etc.). Not declared in this repo. |
| **DROPPED** | No longer used. |

**Probes below are advisory only.** Every Nix attribute and cask name **must be
manually verified** against <https://search.nixos.org/packages> and
`brew search --casks <name>` before Phase 6 writes Nix code.

## Formulae from `docs/install-dev-tools.sh`

| Tool | Owner | Module / Manifest | Notes |
|------|-------|-------------------|-------|
| `actionlint` | Nix | `nix/modules/home/dev.nix` | Verify `pkgs.actionlint`. |
| `atuin` | Nix | `nix/modules/home/cli.nix` | Config via chezmoi (`home/dot_config/atuin/config.toml`). |
| `bat` | Nix | `nix/modules/home/cli.nix` | |
| `bats-core` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `bats`. |
| `btop` | Nix | `nix/modules/home/cli.nix` | Config via chezmoi. |
| `colima` | cask (macOS) / DROPPED (Linux/WSL) | `nix/modules/darwin/homebrew.nix` brews | macOS-only container runtime. Linux uses native Docker if needed. |
| `difftastic` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `difftastic`. |
| `direnv` | **decision: DROPPED** | — | mise per-project env covers current `.envrc`-style use. Re-add as Nix if a specific mise gap appears. |
| `docker` | Nix (Linux) / cask Docker Desktop (macOS) | `nix/modules/home/dev.nix` (Linux); macOS uses Docker Desktop cask or colima | CLI from nixpkgs `docker`; daemon source is host-specific. |
| `eza` | Nix | `nix/modules/home/cli.nix` | |
| `fd` | Nix | `nix/modules/home/cli.nix` | nixpkgs attribute is `fd`. |
| `fzf` | Nix | `nix/modules/home/cli.nix` | |
| `git-delta` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `delta`. |
| `just` | Nix | `nix/modules/home/dev.nix` | |
| `lazygit` | Nix | `nix/modules/home/dev.nix` | |
| `lnav` | Nix | `nix/modules/home/dev.nix` | |
| `lychee` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `lychee`. |
| `mise` | nix-profile | `scripts/bootstrap.sh` | Chicken-and-egg. Not in Home Manager. |
| `mysql-client` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `mariadb-client` (provides `mysql`) or `mysql_client` per channel — verify before commit. |
| `neovim` | Nix | `nix/modules/home/dev.nix` | Config tree under chezmoi (`home/dot_config/nvim/`). |
| `pnpm` | mise | `home/dot_config/mise/config.toml.tmpl` | Per project runtime; not Nix. |
| `ripgrep` | Nix | `nix/modules/home/cli.nix` | |
| `ripgrep-all` | Nix | `nix/modules/home/cli.nix` | nixpkgs attribute is `ripgrep-all` (binary `rga`). |
| `semgrep` | Nix | `nix/modules/home/dev.nix` | Verify `pkgs.semgrep` availability per channel; fallback `pipx` if missing. |
| `shellcheck` | Nix | `nix/modules/home/dev.nix` | |
| `shfmt` | Nix | `nix/modules/home/dev.nix` | |
| `starship` | Nix | `nix/modules/home/cli.nix` | Config via chezmoi. |
| `stripe/stripe-cli/stripe` | manual | — | Stripe CLI installs via official script or `brew install stripe/stripe-cli/stripe`; not in nixpkgs at time of writing. Phase 6 documents in `docs/bootstrap.md` only. |
| `tlrc` | Nix | `nix/modules/home/cli.nix` | nixpkgs attribute is `tlrc`; alternative `tealdeer` if missing. |
| `tmux` | Nix | `nix/modules/home/cli.nix` | |
| `watchexec` | Nix | `nix/modules/home/dev.nix` | |
| `yazi` | Nix | `nix/modules/home/cli.nix` | nixpkgs attribute is `yazi`. |
| `yq` | Nix | `nix/modules/home/cli.nix` | nixpkgs attribute is `yq-go`. |
| `zoxide` | Nix | `nix/modules/home/cli.nix` | |
| `zsh-autosuggestions` | Nix | `nix/modules/home/shell-packages.nix` | |
| `zsh-syntax-highlighting` | Nix | `nix/modules/home/shell-packages.nix` | |

## Casks from `docs/install-dev-tools.sh`

No `brew install --cask` entries in the install script today. macOS GUI
apps are owned through `nix-darwin` Homebrew bridge (`nix/modules/darwin/homebrew.nix`).

## Tools mentioned in `docs/software-and-cli-tools.md` but missing from the install script

| Tool | Owner | Module / Manifest | Notes |
|------|-------|-------------------|-------|
| `ast-grep` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `ast-grep`. |
| `code2prompt` | manual | — | Cargo install, per docs. |
| `copilot` | DROPPED | — | Copilot CLI removed from install script intentionally; we use OpenCode. |
| `files-to-prompt` | manual | — | `uv tool install files-to-prompt` per docs. |
| `gh` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `gh`. |
| `gitleaks` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `gitleaks`. |
| `p7zip` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `p7zip`. |
| `repomix` | manual | — | `npm install -g repomix` per docs. |
| `scc` | Nix | `nix/modules/home/dev.nix` | nixpkgs attribute is `scc`. |
| `stripe` | manual | — | Same as `stripe/stripe-cli/stripe` row above. |
| `tldr` | Nix | `nix/modules/home/cli.nix` | nixpkgs attribute is `tealdeer` (binary `tldr`); duplicates `tlrc` row above — pick one. Final: **`tlrc`** wins (matches install script). `tldr` row resolved as DROPPED. |

## Optional convenience tools (mise aqua, opt-in)

Installed by `mise run tools:optional:install`. Aqua provides prebuilt
binaries so no host build deps are required.

| Tool | Owner | Manifest | Notes |
|------|-------|----------|-------|
| `dive` | mise (aqua:wagoodman/dive) | `mise.toml` `tools:optional:install` | Inspect Docker image layers. |
| `fx` | mise (aqua:antonmedv/fx) | `mise.toml` `tools:optional:install` | Interactive JSON viewer. |
| `navi` | mise (aqua:denisidoro/navi) | `mise.toml` `tools:optional:install` | Cheatsheet TUI. |
| `glow` | mise (aqua:charmbracelet/glow) | `mise.toml` `tools:optional:install` | Markdown reader in the terminal. |
| `gum` | mise (aqua:charmbracelet/gum) | `mise.toml` `tools:optional:install` | TUI toolkit for shell scripts. |

## macOS GUI / cask (declarative via nix-darwin in Phase 8)

Populate `nix/modules/darwin/homebrew.nix` with:

| Cask | Reason |
|------|--------|
| `ghostty` | Primary terminal on macOS. (Linux uses pkg or manual; WSL skips.) |
| `bbedit` | macOS-only editor. |
| `bruno` | API client. |
| `intellij-idea-ce` | Free IDE for Java/merge work. |
| `sequel-ace` | MySQL/MariaDB GUI. |
| `betterdisplay` | Display control. |
| `aerospace` | Tiling WM. |
| `karabiner-elements` | Required by `configs/karabiner/karabiner.json`. |

Optional add when actually used:

| Cask | Reason |
|------|--------|
| `firefox` | Primary browser per docs. |
| `medis` | Redis GUI (currently App Store per docs; cask alternative listed). |
| `linearmouse` | Mouse acceleration control. |
| `notunes` | Prevents Apple Music auto-launch. |

## Mandatory bootstrap-installed (via `nix profile`, never Home Manager)

| Tool | Reason |
|------|--------|
| `nix` | Provided by Determinate Systems installer; not a package. |
| `chezmoi` | Needed before Home Manager renders dotfiles. |
| `mise` | Needed before any mise task can run. |
| `home-manager` | Needed to apply Home Manager configuration. |
| `lefthook` | Needed to install git hooks early in bootstrap. |

## Validation

- [x] Helper `scripts/generate-package-matrix.sh` runs cleanly (no probe needed).
- [x] Every TBD row resolved.
- [x] PHP, Node, pnpm: ownership is **mise** (not Nix).
- [x] `direnv`: dropped with note above; reversible later.
- [x] macOS GUI apps: cask-only.
- [ ] Nix attribute names: must be verified against
  <https://search.nixos.org/packages> before Phase 6 writes Nix code (any
  row whose Nix attribute differs from the formula name is flagged in
  "Notes").
- [ ] Cask names: must be verified against `brew search --casks <name>` on
  the macOS host before Phase 8 writes nix-darwin Homebrew bridge.
