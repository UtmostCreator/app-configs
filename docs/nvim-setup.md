# Neovim Setup

## Stack

- **Neovim** (0.9+)
- Plugin manager: [lazy.nvim](https://github.com/folke/lazy.nvim) (configured in `init.lua`)
- **vim-tmux-navigator** for seamless pane switching between Neovim and tmux

## Files

| Repo path     | Deploy to         |
| ------------- | ----------------- |
| `configs/nvim/` | `~/.config/nvim/` |

## Deploy

```bash
# Backup existing config if present
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null

# Symlink from repo
ln -s /path/to/app-configs/configs/nvim ~/.config/
```

Then open Neovim — lazy.nvim will auto-install plugins on first launch.

## Prerequisites

```bash
brew install neovim
brew install tmux  # required for vim-tmux-navigator
```
