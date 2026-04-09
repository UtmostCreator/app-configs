# Software & CLI Tools

## Terminal

- **[Ghostty](https://github.com/ghostty-org/ghostty)** — fast GPU-accelerated terminal

## Terminal Multiplexer

- **[tmux](https://github.com/tmux/tmux)** — terminal multiplexer; persistent sessions, split panes

## Shell & ZSH Framework

- **[Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)** — ZSH configuration framework
- **[Starship](https://starship.rs)** — fast, cross-shell prompt (replaces Powerlevel10k)
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** — inline command suggestions
- **[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)** — command syntax highlighting
- **[Powerlevel10k](https://github.com/romkatv/powerlevel10k)** — high-performance ZSH theme _(disabled, kept as fallback)_

## Shell History

- **[Atuin](https://github.com/atuinsh/atuin)** — searchable shell history with sync

## System Monitor

- **[Stats](https://github.com/exelban/stats)** — macOS menu bar system monitor
- **[btop](https://github.com/aristocratos/btop)** — terminal resource monitor

## File Managers

- **[Yazi](https://github.com/sxyazi/yazi)** — terminal file manager

## Search & Navigation

- **[fzf](https://github.com/junegunn/fzf)** — fuzzy finder for terminal workflows
- **[ripgrep](https://github.com/BurntSushi/ripgrep)** — fast regex file search
- **[ripgrep-all](https://github.com/phiresky/ripgrep-all)** — ripgrep extended to PDFs, docs, zip files
- **[fd](https://github.com/sharkdp/fd)** — modern alternative to `find`
- **[zoxide](https://github.com/ajeetdsouza/zoxide)** — smarter directory navigation

## CLI Utilities

- **[bat](https://github.com/sharkdp/bat)** — `cat` with syntax highlighting and Git integration
- **[eza](https://github.com/eza-community/eza)** — modern replacement for `ls`
- **[tldr](https://github.com/tldr-pages/tldr)** — simplified command cheat sheets
- **[just](https://github.com/casey/just)** — command runner / project-specific task scripts
- **[lnav](https://lnav.org)** — terminal log file viewer with search and filtering
- **[mysql-client](https://dev.mysql.com/doc/refman/en/programs-client.html)** — MySQL CLI client tools
- **[stripe](https://stripe.com/docs/stripe-cli)** — Stripe CLI for local webhook testing

## Text Editors

- **[Neovim](https://github.com/neovim/neovim)** — extensible Vim-based editor
  - Plugin manager: **[lazy.nvim](https://lazy.folke.io)** — declarative plugin manager (configured in `tools/nvim/`)

## Git Tools

- **[lazygit](https://github.com/jesseduffield/lazygit)** — terminal UI for Git
- **[delta](https://github.com/dandavison/delta)** — syntax-highlighted Git diff pager

## Container & Docker

- **[colima](https://github.com/abiosoft/colima)** — lightweight container runtime for macOS (runs Docker daemon via Lima VM)
- **[docker](https://docs.docker.com/engine/reference/commandline/cli/)** — Docker CLI
- **[docker-compose](https://docs.docker.com/compose/)** — multi-container orchestration

## Browser

- **[Firefox](https://www.mozilla.org/firefox/)** — primary browser

## API Client / HTTP Debugging

- **[Bruno](https://www.usebruno.com)** — open-source API client; stores collections as plain-text files in your repo

## Package Manager

- **[pnpm](https://github.com/pnpm/pnpm)** — fast Node.js package manager

## Database Tools

- **[Sequel Ace](https://github.com/Sequel-Ace/Sequel-Ace)** — MySQL/MariaDB GUI
- **[Medis](https://github.com/luin/medis)** — Redis GUI client

## Window Management

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** — tiling window manager

## Menu Bar Management

- **[Ice](https://github.com/jordanbaird/Ice)** — menu bar organiser
- **[NoTunes](https://github.com/tombonez/noTunes)** — prevents Apple Music from launching

## Screenshots

- **[Flameshot](https://github.com/flameshot-org/flameshot)** — cross-platform screenshot tool with annotation

## Mouse & Trackpad

- **[LinearMouse](https://linearmouse.app)** — mouse acceleration control
- **[Middle Click](https://middleclick.app)** — enables trackpad middle click

## App Switching

- **[AltTab](https://alt-tab-macos.netlify.app)** — Windows-style application switcher

## Image Editing

- **[Paintbrush](https://paintbrush.sourceforge.io/)** — simple Paint-like image editor

## Tool Version Manager

- **[mise](https://github.com/jdx/mise)** — polyglot tool version manager (replaces asdf / nvm / rbenv)

## Fonts

- **[JetBrains Mono Nerd Font](https://www.nerdfonts.com)** — primary coding font with Nerd Font icons
- **[Meslo LG Nerd Font](https://www.nerdfonts.com)** — fallback / terminal font

## IDE

- **[IntelliJ IDEA Community](https://www.jetbrains.com/idea/)** — free IDE, useful for Git merge conflict resolution

---

## Install via Homebrew

> Requires [Homebrew](https://brew.sh/) — install it first if not present:
> `sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### CLI tools (`brew install`)

```bash
brew install atuin
brew install bat
brew install btop
brew install colima
brew install docker
brew install docker-compose
brew install eza
brew install fd
brew install fzf
brew install git-delta
brew install just
brew install lazygit
brew install lnav
brew install mise
brew install mysql-client
brew install neovim
brew install pnpm
brew install ripgrep
brew install ripgrep-all
brew install starship
brew install stripe/stripe-cli/stripe
brew install tldr
brew install tmux
brew install yazi
brew install zoxide
brew install zsh-autosuggestions
brew install zsh-syntax-highlighting
```

### GUI apps (`brew install --cask`)

```bash
brew install --cask aerospace           # tap: nikitabobko/tap/aerospace
brew install --cask betterdisplay
brew install --cask bruno
brew install --cask firefox
brew install --cask flameshot
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-meslo-lg-nerd-font
brew install --cask ghostty
brew install --cask jordanbaird-ice
brew install --cask linearmouse
brew install --cask notunes
brew install --cask sequel-ace
brew install --cask stats
```

> AeroSpace requires its tap first: `brew tap nikitabobko/tap`

### Not available via Homebrew

| App              | Install method                                                                                                      |
| ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| Oh My Zsh        | `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`                   |
| lazy.nvim        | Auto-installed by Neovim config on first launch (see `tools/nvim/`)                                                 |
| Medis            | [App Store](https://apps.apple.com/app/medis-gui-for-redis/id1063631769)                                            |
| Middle Click     | [App Store](https://apps.apple.com/app/middle-click/id1387092371)                                                   |
| Paintbrush       | [App Store](https://apps.apple.com/app/paintbrush/id407963104) or [SourceForge](https://paintbrush.sourceforge.io/) |
| IntelliJ IDEA CE | [jetbrains.com](https://www.jetbrains.com/idea/download/) or `brew install --cask intellij-idea-ce`                 |
| AltTab           | [alt-tab-macos.netlify.app](https://alt-tab-macos.netlify.app) or `brew install --cask alt-tab`                     |
| LinearMouse      | [linearmouse.app](https://linearmouse.app) or `brew install --cask linearmouse`                                     |
