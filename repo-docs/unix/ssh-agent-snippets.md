# ssh-agent shell snippets (Linux + macOS)

Drop-in shell config that makes ssh-agent persistent and prompts for the
passphrase at most once per boot (Linux) or at most once ever (macOS, via
Keychain).

| File                | Target shell  | Deploy path                                |
| ------------------- | ------------- | ------------------------------------------ |
| `ssh-agent.sh`      | bash, zsh     | `~/.config/app-configs/ssh-agent.sh` (sourced from `~/.bashrc`/`~/.zshrc`) |
| `ssh-agent.fish`    | fish          | `~/.config/fish/conf.d/ssh-agent.fish`     |

Use `scripts/unix/ssh-agent-setup.sh` to install them idempotently. See
`repo-docs/unix/QUICKSTART.md` for the runbook.

## Configuring which keys to load

Default: `~/.ssh/github.uc.ll5`.

Override before the snippet runs:

```bash
# bash / zsh — put this in ~/.bashrc or ~/.zshrc above the source line
export APP_CONFIGS_SSH_KEYS="github.uc.ll5 work_ed25519"
```

```fish
# fish — universal var, set once, persists forever
set -Ux APP_CONFIGS_SSH_KEYS github.uc.ll5 work_ed25519
```

Bare names are resolved under `~/.ssh/`. Absolute paths are used as-is.
Missing keys are silently skipped — safe to list keys that only exist on
some machines.
