# Shell setup

## Stack

Primary interactive shell is **fish**; zsh and bash configs are still shipped.

- **fish** — primary interactive shell. Uses fish's **built-in**
  autosuggestions + syntax highlighting (no extra plugins). Config:
  `home/dot_config/fish/config.fish.tmpl`.
- **Starship** prompt ([starship.rs](https://starship.rs/)) — initialised in
  every shell.
- **Atuin** — searchable shell history (owns Ctrl-R).
- **bash** — `~/.bashrc` auto-`exec`s into fish for interactive terminals
  (escape hatch: `NO_FISH=1 bash`); also the fallback when fish is absent.
- **zsh** — still managed (`~/.zshrc`, Oh My Zsh + the zsh-autosuggestions /
  zsh-syntax-highlighting plugins from `nix/modules/home/shell-packages.nix`)
  for hosts/users who prefer it. Not the default on this setup.

On **NixOS**, making fish the *login* shell is a system-level change — see
"Login shell on NixOS" below.

## Files (chezmoi-managed)

Source files live in `home/` under the chezmoi tree.

| Source | Deploys to |
| --- | --- |
| `home/dot_config/fish/config.fish.tmpl` | `~/.config/fish/config.fish` (primary) |
| `home/dot_config/fish/conf.d/ssh-agent.fish` | `~/.config/fish/conf.d/ssh-agent.fish` |
| `home/dot_config/fish/conf.d/dotfiles.fish.tmpl` | `~/.config/fish/conf.d/dotfiles.fish` (sys-* functions) |
| `home/dot_bashrc.tmpl` | `~/.bashrc` (exec-into-fish + fallback) |
| `home/dot_zshrc.tmpl` | `~/.zshrc` (zsh, still supported) |
| `home/dot_zprofile.tmpl` | `~/.zprofile` |
| `home/dot_gitconfig.tmpl` | `~/.gitconfig` (templated identity + 62 aliases) |
| `home/dot_config/starship/starship.toml` | `~/.config/starship/starship.toml` |
| `home/dot_config/atuin/config.toml` | `~/.config/atuin/config.toml` |
| `home/dot_local/bin/executable_*` | `~/.local/bin/*` (sys-update/cleanup/install/readiness/setup, git-branch-origin) |

## Deploy

```bash
# Cold start (first time on this host) — unattended:
bash ops/install.sh            # or: sys-install

# Ongoing:
sys-update                         # update apps + CLI + dotfiles (brewup)
chezmoi apply                      # dotfiles only
mise run sync                      # preview full sync
mise run sync:apply                # apply full sync
```

## Login shell on NixOS

fish is installed and is the interactive shell via the `.bashrc` exec, but the
persistent *login* shell is set at the system level:

```bash
sudo sys-setup --apply             # adds fish login shell + trusted-users + GC + Europe/London time zone, then nixos-rebuild
```

See `repo-docs/nixos-rebuild.md` for what this does and `repo-docs/install-nixos.md` for
NixOS specifics.

## Prerequisites

`fish`, `starship`, `atuin`, and (for zsh users) `zsh-autosuggestions` /
`zsh-syntax-highlighting` all come from Home Manager — see
`repo-docs/migration-package-ownership.md`. Only zsh users need Oh My Zsh, installed
once per host outside the dotfiles tree:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## Secrets

Real `home/.chezmoidata/personal.yaml` (name, email, signing key, host profile)
is gitignored; only `personal.yaml.example` is committed. The macOS-only NPM
token is loaded from 1Password in `config.fish` when signed in (no startup
prompt); see the `darwin`-gated block in `home/dot_config/fish/config.fish.tmpl`.
