# ssh-agent shell snippets (Linux + macOS)

Drop-in shell config that makes ssh-agent persistent and prompts for the
passphrase at most once per boot (Linux) or at most once ever (macOS, via
Keychain).

| File                | Target shell  | Deploy path                                |
| ------------------- | ------------- | ------------------------------------------ |
| `ssh-agent.sh`      | bash, zsh     | `~/.config/app-configs/ssh-agent.sh` (sourced from `~/.bashrc`/`~/.zshrc`) |
| `ssh-agent.fish`    | fish          | `~/.config/fish/conf.d/ssh-agent.fish`     |

Use `ops/unix/ssh-agent-setup.sh` to install them idempotently. See
`docs/getting-started/unix-quickstart.md` for the runbook.

## Configuring which keys to load

Default: `~/.ssh/id_ed25519`.

Override before the snippet runs:

```bash
# bash / zsh — put this in ~/.bashrc or ~/.zshrc above the source line
export APP_CONFIGS_SSH_KEYS="<github-key> <work-key>"
```

```fish
# fish — universal var, set once, persists forever
set -Ux APP_CONFIGS_SSH_KEYS <github-key> <work-key>
```

Bare names are resolved under `~/.ssh/`. Absolute paths are used as-is.
Missing keys are silently skipped — safe to list keys that only exist on
some machines.
