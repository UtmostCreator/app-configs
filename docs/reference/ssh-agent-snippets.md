# ssh-agent shell snippets (Linux + macOS)

Drop-in shell config that makes ssh-agent persistent and prompts for the
passphrase about once per `APP_CONFIGS_SSH_KEY_LIFETIME` hours (Linux/WSL,
default 8) or at most once ever (macOS, via Keychain).

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

## Key lifetime

Linux/WSL keys are forgotten after 8 hours by default (`keychain --timeout`,
or `ssh-add -t` in the plain-agent fallback). Change it, in hours:

```bash
export APP_CONFIGS_SSH_KEY_LIFETIME=24   # bash / zsh, above the source line
```

```fish
set -Ux APP_CONFIGS_SSH_KEY_LIFETIME 24  # fish
```

`0` or empty keeps keys until the agent dies; an invalid value (`abc`, `-1`)
is ignored and the default kept. Not used on macOS (the Keychain stores the
passphrase). Keys already in a running agent keep their old lifetime until
the agent restarts (`keychain --clear`, or log out). Keys added by ssh's own
`AddKeysToAgent yes` get no lifetime whatever this variable says; use
`AddKeysToAgent 8h` in `~/.ssh/config` to match.

Bare names are resolved under `~/.ssh/`. Absolute paths are used as-is.
Missing keys are silently skipped — safe to list keys that only exist on
some machines.
