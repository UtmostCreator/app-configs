# macOS Development Environment

My daily macOS setup for full-stack development, terminal workflows, containers, APIs, databases, and CLI automation.

## Primary Development Stack

- **Terminal:** Ghostty + tmux
- **Shell:** fish (primary; native autosuggestions + highlighting) + Starship + Atuin. zsh + Oh My Zsh still supported. See `repo-docs/shell-setup.md`.
- **Navigation/Search:** fzf, fd, ripgrep, ripgrep-all, zoxide, Yazi
- **Editor:** Neovim (lazy.nvim) + BBEdit
- **Git:** lazygit + delta
- **Containers:** Colima + Docker
- **Runtime/Versioning:** mise + pnpm
- **API/DB:** Bruno, Stripe CLI, mysql-client, Sequel Ace, Medis

## Terminal And Shell

### Terminal

- **[Ghostty](https://github.com/ghostty-org/ghostty)** - fast GPU-accelerated terminal
- **[tmux](https://github.com/tmux/tmux)** - persistent sessions, split panes, and keyboard-first terminal workflows

### Shell

- **[fish](https://fishshell.com)** - primary interactive shell; ships
  autosuggestions + syntax highlighting **natively** (no extra plugins)
- **[Starship](https://starship.rs)** - active prompt setup (all shells)
- **[Atuin](https://github.com/atuinsh/atuin)** - searchable shell history with sync
- **[Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)** - Zsh framework (zsh still
  supported as an alternative shell)
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** /
  **[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)**
  - only for the zsh path; fish uses its built-ins

> Previously used: Zsh as primary, [Powerlevel10k](https://github.com/romkatv/powerlevel10k).
> Shell config + how to switch: `repo-docs/shell-setup.md`.

## Navigation And CLI Workflow

- **[Yazi](https://github.com/sxyazi/yazi)** - terminal file manager
- **[fzf](https://github.com/junegunn/fzf)** - fuzzy finder for terminal workflows
- **[ripgrep](https://github.com/BurntSushi/ripgrep)** - fast regex file search
- **[ripgrep-all](https://github.com/phiresky/ripgrep-all)** - search across PDFs, docs, and archives
- **[fd](https://github.com/sharkdp/fd)** - modern alternative to `find`
- **[zoxide](https://github.com/ajeetdsouza/zoxide)** - smarter directory navigation
- **[bat](https://github.com/sharkdp/bat)** - `cat` with syntax highlighting and Git integration
- **[eza](https://github.com/eza-community/eza)** - modern replacement for `ls`
- **[tldr](https://github.com/tldr-pages/tldr)** - simplified command cheat sheets
- **[just](https://github.com/casey/just)** - command runner for project-specific tasks
- **[lnav](https://lnav.org)** - terminal log viewer with search and filtering
- **[btop](https://github.com/aristocratos/btop)** - terminal resource monitor
- **[GitHub Copilot CLI](https://github.com/github/copilot-cli)** - terminal-native Copilot workflow entrypoint

### Optional Convenience Tools (opt-in via `mise run tools:optional:install`)

These are recommended but not installed by default. Run the mise task to install them all via [aqua](https://aquaproj.github.io/) (prebuilt binaries, no build deps required):

```bash
mise run tools:optional:install
```

- **[dive](https://github.com/wagoodman/dive)** - explore Docker image layers and content
- **[fx](https://github.com/antonmedv/fx)** - interactive JSON viewer / processor
- **[navi](https://github.com/denisidoro/navi)** - interactive cheatsheet tool for the shell
- **[glow](https://github.com/charmbracelet/glow)** - terminal Markdown reader
- **[gum](https://github.com/charmbracelet/gum)** - shell-script TUI toolkit (prompts, spinners, choosers)

### AI Workflow Critical Additions

- **[repomix](https://github.com/yamadashy/repomix)** - package repository context for LLM prompts
- **[files-to-prompt](https://github.com/simonw/files-to-prompt)** - concatenate targeted file sets with path headers
- **[code2prompt](https://github.com/mufeedvh/code2prompt)** - template-driven prompt/context generation
- **[watchexec](https://github.com/watchexec/watchexec)** - file-watch command loop for edit -> verify cycles
- **[direnv](https://direnv.net/)** - auto-load per-directory environment variables
- **[semgrep](https://semgrep.dev/)** - static analysis and security scanning
- **[difftastic](https://github.com/Wilfred/difftastic)** - syntax-aware structural diffing for review
- **[shellcheck](https://github.com/koalaman/shellcheck)** - shell linting for repo scripts and hooks
- **[shfmt](https://github.com/mvdan/sh)** - shell formatting check for tracked scripts
- **[actionlint](https://github.com/rhysd/actionlint)** - GitHub Actions workflow validation
- **[lychee](https://github.com/lycheeverse/lychee)** - Markdown and text link checking for repo docs
- **[bats-core](https://github.com/bats-core/bats-core)** - shell test runner used by `tests/shell/`
- **[yq](https://github.com/mikefarah/yq)** - YAML querying for Copilot command policy loading

## Editors And Git

- **[Neovim](https://github.com/neovim/neovim)** - extensible Vim-based editor
  Plugin manager: **[lazy.nvim](https://lazy.folke.io)** - configured in `configs/nvim/`
- **[BBEdit](https://www.barebones.com/products/bbedit/)** - lightweight macOS text editor
- **[lazygit](https://github.com/jesseduffield/lazygit)** - terminal UI for Git workflows
- **[delta](https://github.com/dandavison/delta)** - syntax-highlighted Git diff pager

## Containers, Runtime, And Package Management

- **[colima](https://github.com/abiosoft/colima)** - lightweight container runtime for macOS
- **[docker](https://docs.docker.com/engine/reference/commandline/cli/)** - Docker CLI with modern `docker compose` workflow
- **[mise](https://github.com/jdx/mise)** - polyglot tool version manager
- **[pnpm](https://github.com/pnpm/pnpm)** - fast Node.js package manager

## API And Database Tooling

- **[Bruno](https://www.usebruno.com)** - open-source API client with plain-text collections
- **[stripe](https://stripe.com/docs/stripe-cli)** - Stripe CLI for local webhook testing
- **[mysql-client](https://dev.mysql.com/doc/refman/en/programs-client.html)** - MySQL CLI client tools
- **[Sequel Ace](https://github.com/Sequel-Ace/Sequel-Ace)** - MySQL and MariaDB GUI
- **[Medis](https://github.com/luin/medis)** - Redis GUI client

## Workspace And Window Management

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** - tiling window manager
- **[IntelliJ IDEA Community](https://www.jetbrains.com/idea/)** - useful for Java work and merge conflict resolution

## Install Via Homebrew

> # Requires [Homebrew](https://brew.sh/) - install it first if not present:

## Container & Docker

- **[colima](https://github.com/abiosoft/colima)** - lightweight container runtime for macOS (runs Docker daemon via Lima VM)
- **[docker](https://docs.docker.com/engine/reference/commandline/cli/)** - Docker CLI
- **[docker-compose](https://docs.docker.com/compose/)** - multi-container orchestration

## Browser

- **[Firefox](https://www.mozilla.org/firefox/)** - primary browser

## API Client / HTTP Debugging

- **[Bruno](https://www.usebruno.com)** - open-source API client; stores collections as plain-text files in your repo

## Package Manager

- **[pnpm](https://github.com/pnpm/pnpm)** - fast Node.js package manager

## Database Tools

- **[Sequel Ace](https://github.com/Sequel-Ace/Sequel-Ace)** - MySQL/MariaDB GUI
- **[Medis](https://github.com/luin/medis)** - Redis GUI client

## Window Management

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** - tiling window manager
- **[yabai](https://github.com/asmvik/yabai)** - Tiling window management for the Mac

## Menu Bar Management

- **[Ice](https://github.com/jordanbaird/Ice)** - menu bar organiser
- **[NoTunes](https://github.com/tombonez/noTunes)** - prevents Apple Music from launching

## Screenshots

- **[Flameshot](https://github.com/flameshot-org/flameshot)** - cross-platform screenshot tool with annotation

## Mouse & Trackpad

- **[LinearMouse](https://linearmouse.app)** - mouse acceleration control
- **[Middle Click](https://middleclick.app)** - enables trackpad middle click

## App Switching

- **[AltTab](https://alt-tab-macos.netlify.app)** - Windows-style application switcher

## Image Editing

- **[Paintbrush](https://paintbrush.sourceforge.io/)** - simple Paint-like image editor

## Tool Version Manager

- **[mise](https://github.com/jdx/mise)** - polyglot tool version manager (replaces asdf / nvm / rbenv)

## Fonts

- **[JetBrains Mono Nerd Font](https://www.nerdfonts.com)** - primary coding font with Nerd Font icons
- **[Meslo LG Nerd Font](https://www.nerdfonts.com)** - fallback / terminal font

## IDE

- **[IntelliJ IDEA Community](https://www.jetbrains.com/idea/)** - free IDE, useful for Git merge conflict resolution

---

## Cross-platform install matrix (one-script goal)

This maps each tool to **who installs it** so a single
`bash ops/bootstrap.sh --yes` (plus the NixOS rule below) installs the
whole set on either OS. The owner of record is
`repo-docs/migration-package-ownership.md`; this table is the practical summary.

| Tool / app | Linux (incl. NixOS) | macOS | Where declared |
| --- | --- | --- | --- |
| CLI tools (atuin, bat, btop, eza, fd, fzf, jq, yq, ripgrep(-all), starship, tldr, tmux, yazi, zoxide) | **Nix** | **Nix** | `nix/modules/home/cli.nix` |
| fish shell | **Nix** | **Nix** | `nix/modules/home/cli.nix` |
| dev tools (gh, lazygit, delta, difftastic, neovim, semgrep, shellcheck, shfmt, actionlint, lychee, bats, scc, watchexec, lnav, ast-grep, p7zip, mariadb client) | **Nix** | **Nix** | `nix/modules/home/dev.nix` |
| node 22 runtime | **Nix** (`nodejs_22`) | mise pin OR Nix | `nix/modules/home/dev.nix` (NixOS rule) |
| pnpm | **Nix** | **Nix** | `nix/modules/home/dev.nix` |
| colima | **Nix** | **Nix**/Homebrew | `nix/modules/home/dev.nix` |
| docker CLI | **Nix** (daemon = host) | **Nix** + colima | `nix/modules/home/dev.nix` |
| stripe CLI | **Nix** (`stripe-cli`) | **Nix**/Homebrew | `nix/modules/home/dev.nix` |
| Firefox | **Nix** | Homebrew cask | `gui.nix` / `darwin/homebrew.nix` |
| Ghostty | **Nix** | Homebrew cask | `gui.nix` / `darwin/homebrew.nix` |
| VS Code | **Nix** (`vscode`) | Homebrew cask `visual-studio-code` | `gui.nix` / `darwin/homebrew.nix` — single IDE on all systems |
| Flameshot | **Nix** | Homebrew cask | `gui.nix` (Linux) |
| Brave | **Nix** (stable) | Homebrew cask `brave-browser@beta` | `gui.nix` / `darwin/homebrew.nix` |
| IntelliJ IDEA CE | **excluded** (not shipped) | **excluded** (not shipped) | intentionally dropped for now; VS Code is the IDE |
| Bruno | **Nix** | Homebrew cask | `gui.nix` / `darwin/homebrew.nix` |
| Sequel Ace, BBEdit, BetterDisplay, AeroSpace, Karabiner, Ice, AltTab, Stats, NoTunes, LinearMouse | **macOS-only** (no Linux equivalent shipped) | Homebrew cask | `nix/modules/darwin/homebrew.nix` |
| repomix, files-to-prompt, code2prompt | npm / uv / cargo (per-project, optional) | same | not in Nix; see "AI context packers" below |
| dive, fx, navi, glow, gum | `mise run tools:optional:install` (aqua) | same | `mise.toml` optional task |
| direnv | **DROPPED** (mise per-project env replaces it) | DROPPED | — |

NixOS runtime rule (see `repo-docs/install-nixos.md`): runtimes that mise would
otherwise compile from source on NixOS (e.g. node) are provided by Nix and
**re-applied with `home-manager switch`** instead of `mise install`.

GUI on Linux is installed by the same `home-manager switch` because
`nix/modules/home/gui.nix` (imported by `linux-desktop`) lists the
Linux-installable apps. macOS GUI apps come from the nix-darwin Homebrew
cask bridge. Either way it is one apply command per host.

## How to install everything

> **Preferred path on every host (macOS / Linux desktop / Linux CLI / WSL2):**
>
> ```bash
> bash ops/bootstrap.sh --yes
> ```
>
> Bootstrap installs Nix, then `nix profile install chezmoi mise home-manager
> lefthook`, validates the flake, runs chezmoi apply, runs `home-manager switch`
> (or `darwin-rebuild switch` on macOS), then `mise install` and
> `lefthook install`. Daily updates go through `mise run sync` (preview) and
> `mise run sync:apply` (mutate). See [`bootstrap.md`](bootstrap.md) and
> [`migration-package-ownership.md`](migration-package-ownership.md) for the
> per-tool owner.
>
> Optional convenience tools (`dive`, `fx`, `navi`, `glow`, `gum`) are opt-in:
>
> ```bash
> mise run tools:optional:install
> ```

## Install via Homebrew (macOS-only fallback)

> Use this only if you choose not to run the bootstrap script. Requires
> [Homebrew](https://brew.sh/):
> `sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### CLI tools (`brew install`)

```bash
brew install atuin
brew install ast-grep
brew install bat
brew install btop
brew install colima
brew install docker
brew install docker-buildx
brew install duti
brew install eza
brew install fd
brew install fzf
brew install gh
brew install git-delta
brew install difftastic
brew install direnv
brew install gitleaks
brew install jq
brew install copilot-cli
brew install just
brew install lazygit
brew install lnav
brew install lychee
brew install mise
brew install mysql-client
brew install neovim
brew install p7zip
brew install php
brew install pnpm
brew install ripgrep
brew install ripgrep-all
brew install semgrep
brew install shellcheck
brew install shfmt
brew install starship
brew install stripe/stripe-cli/stripe
brew install tldr
brew install tmux
brew install watchexec
brew install yazi
brew install yq
brew install zoxide
brew install zsh-autosuggestions
brew install zsh-syntax-highlighting
brew install bats-core
brew install actionlint
brew install asmvik/formulae/yabai
```

> `mysql-client` is often keg-only and may require adding Homebrew's bin path to your shell config.

### AI context packers (outside Homebrew core list)

```bash
brew install scc
npm install -g repomix
uv tool install files-to-prompt
cargo install code2prompt
```

### GUI apps (`brew install --cask`)

```bash
brew tap nikitabobko/tap
brew install --cask aerospace
brew install --cask bbedit
brew install --cask betterdisplay
brew install --cask bruno
brew install --cask ghostty
brew install --cask intellij-idea-ce
brew install --cask sequel-ace
```

### Installed outside Homebrew

| Tool      | Install method                                                                                    |
| --------- | ------------------------------------------------------------------------------------------------- |
| Oh My Zsh | `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` |
| lazy.nvim | Auto-installed by Neovim config on first launch                                                   |
| Medis     | [App Store](https://apps.apple.com/app/medis-gui-for-redis/id1063631769)                          |

## macOS Utilities (Non-Development)

These tools improve the daily macOS experience but are not part of the core development workflow.

- **[Stats](https://github.com/exelban/stats)** - menu bar system monitor
- **[Ice](https://github.com/jordanbaird/Ice)** - menu bar organiser
- **[NoTunes](https://github.com/tombonez/noTunes)** - prevents Apple Music from launching
- **[BetterDisplay](https://github.com/waydabber/BetterDisplay)** - display control
- **[Flameshot](https://github.com/flameshot-org/flameshot)** - screenshots with annotation
- **[LinearMouse](https://linearmouse.app)** - mouse acceleration control
- **[Middle Click](https://middleclick.app)** - trackpad middle click
- **[AltTab](https://alt-tab-macos.netlify.app)** - Windows-style application switcher
- **[Paintbrush](https://paintbrush.sourceforge.io/)** - simple Paint-like image editor
- **[Firefox](https://www.mozilla.org/firefox/)** - primary browser
- **[JetBrains Mono Nerd Font](https://www.nerdfonts.com)** - primary coding font
- **[Meslo LG Nerd Font](https://www.nerdfonts.com)** - fallback terminal font
