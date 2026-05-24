# Shell setup

## Stack

- **zsh** via [Oh My Zsh](https://ohmyz.sh/)
- **Starship** prompt ([starship.rs](https://starship.rs/))
- **zsh-autosuggestions** + **zsh-syntax-highlighting** plugins (installed
  by Home Manager — see `nix/modules/home/shell-packages.nix`)

## Files (chezmoi-managed)

Source files live in `home/` under the chezmoi tree.

| Source                               | Deploys to                          |
| ------------------------------------ | ----------------------------------- |
| `home/dot_zshrc.tmpl`                | `~/.zshrc` (templated identity)     |
| `home/dot_zprofile.tmpl`             | `~/.zprofile`                       |
| `home/dot_gitconfig.tmpl`            | `~/.gitconfig` (templated identity) |
| `home/dot_bashrc`                    | `~/.bashrc` (fallback shell)        |
| `home/dot_config/starship/starship.toml` | `~/.config/starship/starship.toml` |
| `home/dot_config/atuin/config.toml`  | `~/.config/atuin/config.toml`       |
| `home/dot_config/app-configs/ssh-agent.sh` | sourced from `~/.zshrc`       |

## Deploy

```bash
# Cold start (first time on this host):
bash scripts/bootstrap.sh --dry-run
bash scripts/bootstrap.sh --yes

# Ongoing:
mise run sync             # preview
mise run sync:apply       # apply
```

## Prerequisites

Oh My Zsh is installed once per host outside the dotfiles tree:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

`starship`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, etc. come from
Home Manager (see `docs/migration-package-ownership.md`).

## Secrets

Sensitive tokens (e.g. `NPM_TOKEN`) live in `~/.secrets`, sourced from
`~/.zshrc`. That file is gitignored at the user level (never in this repo).

```bash
# ~/.secrets — create manually, never commit
export NPM_TOKEN="ghp_your_token_here"
```

Real `home/.chezmoidata/personal.yaml` (name, email, signing key, host
profile) is also gitignored; only `personal.yaml.example` is committed.
