# Base requirements (all systems)

## Order

Base first, before any platform step. Then [your platform](index.md).

## Git and SSH

| Need | How |
|------|-----|
| Git | Per platform doc |
| SSH key on GitHub | Create it per [`windows`](windows/setup.md) or [`wsl`](wsl/setup.md). macOS / NixOS: `ssh-keygen -t ed25519`, add at github.com/settings/keys |

## Commit tooling first

Before the first commit on any machine.

| Tool | Used by |
|------|---------|
| lefthook | Installs the hooks (`.lefthook.yml`) |
| gitleaks | Secret scan (`ops/hooks/pre-commit.sh`); blocks if missing |
| chezmoi | `ops/validate-config.sh` checks |
| bash | Runs every hook script |

Hooks:

| Hook | Runs |
|------|------|
| pre-commit | `ops/hooks/no-personal-yaml.sh`, then `ops/hooks/pre-commit.sh` |
| commit-msg | `ops/hooks/commit-msg.sh` |
| pre-push | `ops/validate-config.sh`, then `ops/hooks/pre-push.sh` |
| post-merge | `ops/hooks/post-merge.sh` (drift hints) |

| Host | Setup |
|------|-------|
| Linux / macOS | Automatic: `ops/install.sh` installs chezmoi and lefthook (step 3), gitleaks comes from `nix/modules/home/dev.nix`, step 9 runs `lefthook install` |
| Windows | `winget install -e --id twpayne.chezmoi`, `-e --id Gitleaks.Gitleaks`, `-e --id evilmartians.lefthook` (ids verified 2026-11-15; winget installs the latest). Still by hand until T-0047 T2 automates it |

Then, in the clone:

```bash
command -v chezmoi gitleaks lefthook
lefthook install
```

## Rules

| Rule | Detail |
|------|--------|
| No bypass | Never `--no-verify` (AGENTS.md) |
| Commit subject | `type(scope): summary`, e.g. `docs(setup): add index` |
| Line endings | The index stores LF. `.gitattributes` forces LF for sh/bash/zsh/php/md/json/yml/yaml (CRLF for bat/cmd). With `core.autocrlf=true` Windows checks other files out as CRLF. Do not commit CRLF |
| Secrets | Never commit them or `home/.chezmoidata/personal.yaml` |
| Sync | Humans: `git pull --ff-only` before work, push after. Agents: push, rebase or force-push only when explicitly authorised for the task (AGENTS.md). Never stash (shared stash) |

## Verify

```bash
bash ops/validate-config.sh
bats tests/bash          # Linux / macOS
nix flake check ./nix    # Linux / macOS
```
