# Neovim setup

## Stack

- **Neovim** (0.9+) — installed by Home Manager (`nix/modules/home/dev.nix`)
- Plugin manager: [lazy.nvim](https://github.com/folke/lazy.nvim) (configured in `init.lua`)
- **vim-tmux-navigator** for seamless pane switching between Neovim and tmux

## Files (chezmoi-managed)

| Source                     | Deploys to        |
| -------------------------- | ----------------- |
| `home/dot_config/nvim/`    | `~/.config/nvim/` |

## Deploy

```bash
mise run sync             # preview
mise run sync:apply       # apply (snapshots ~ first)
```

On first run, lazy.nvim auto-installs plugins when you open Neovim.

## Prerequisites

`neovim`, `tmux`, and friends come from Home Manager; nothing to install by
hand. See `docs/migration-package-ownership.md` for the per-tool owner.
