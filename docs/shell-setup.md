# Shell Setup

## Stack

- **zsh** via [Oh My Zsh](https://ohmyz.sh/)
- **Starship** prompt ([starship.rs](https://starship.rs/))
- **zsh-autosuggestions** + **zsh-syntax-highlighting** plugins

## Files

| Repo path             | Deploy to                          |
| --------------------- | ---------------------------------- |
| `shell/.zshrc`        | `~/.zshrc`                         |
| `shell/starship.toml` | `~/.config/starship/starship.toml` |

## Optional Local Workflow Helpers

If you keep this repo checked out locally, `shell/.zshrc` also exposes small helpers for jumping into the repo and running health checks.

- Set `APP_CONFIGS_HOME` if your clone is not at the default path.
- Use `acfg` to jump to the repo.
- Use `acfg-doctor` to run the local repo health check.
- Use `acfg-ai-check` to run the bundled AI workflow validation commands.

## Prerequisites

```bash
# Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Starship
brew install starship

# zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# zsh-syntax-highlighting
brew install zsh-syntax-highlighting
```

## Secrets

Sensitive tokens (e.g. `NPM_TOKEN`) must be set in `~/.secrets` and sourced from `.zshrc`.
That file is gitignored and never committed.

```bash
# ~/.secrets  (create manually, never commit)
export NPM_TOKEN="ghp_your_token_here"
```

## Optional Workflow Commands

If you install [`just`](https://github.com/casey/just), the repo includes:

- `just doctor`
- `just bootstrap`
- `just ai-check`
- `just hook-run-precommit`
