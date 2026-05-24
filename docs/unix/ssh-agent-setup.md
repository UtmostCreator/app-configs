# SSH Agent Setup (Linux / macOS / WSL) — Reference

Long-form reference for the persistent ssh-agent setup. For the
copy-paste runbook see [`QUICKSTART.md`](QUICKSTART.md).

## Goal

A single ssh-agent per user, shared across every interactive shell, that
holds passphrase-protected keys with minimal re-prompting:

- **macOS**: prompt for the passphrase exactly **once ever**. The
  passphrase is stored in the user's login Keychain. Survives reboots,
  upgrades, and account re-logins until the user revokes it.
- **Linux / WSL**: prompt for the passphrase exactly **once per boot**.
  Survives across every shell, tmux pane, VS Code terminal, and SSH'd
  sub-session for the lifetime of the agent process.

Non-interactive invocations (scripts, `scp`, `rsync`, CI runners that
inherit the user shell) must never block on a passphrase prompt.

## Components

```
home/dot_config/app-configs/
    ssh-agent.sh                 # bash + zsh loader (POSIX-ish, chezmoi-managed)

home/dot_config/fish/conf.d/
    ssh-agent.fish               # fish loader (chezmoi-managed; auto-sourced)

scripts/unix/
    ssh-agent-setup.sh           # idempotent installer (install / --remove);
                                 # also re-used by scripts/bootstrap.sh step 8.

docs/unix/
    QUICKSTART.md                # 1-command runbook
    ssh-agent-setup.md           # this file
    ssh-agent-snippets.md        # short reference from the original README
```

## How the loader decides what to do

`ssh-agent.sh` and `ssh-agent.fish` both run the same logic:

1. **Exit immediately for non-interactive shells.** This is the critical
   safety check — `scp`, `rsync --rsh`, and remote `ssh host cmd`
   invocations source the rc file but must not prompt.
2. **Read `APP_CONFIGS_SSH_KEYS`** (default: `github.uc.ll5`). Split on
   whitespace; resolve bare names against `~/.ssh/`; keep absolute paths.
3. **Branch on `uname -s`:**
   - `Darwin` → call `ssh-add --apple-use-keychain <key>` (falls back to
     legacy `-K` on older macOS) for each not-yet-loaded key. The agent
     is already running under launchd; we just attach keys to it and
     point the Keychain at them.
   - `Linux` (or other Unix) → prefer `keychain` if available, else fall
     back to a single shared `ssh-agent` whose env vars are persisted in
     `~/.ssh/agent.env`.
4. **Skip keys already loaded** by comparing fingerprints from
   `ssh-keygen -lf <key>` against `ssh-add -l`. Cheap and idempotent.

## Why `keychain` on Linux

`keychain` (from Funtoo) is a small wrapper around `ssh-agent` that:

- Starts one agent per user per boot.
- Caches the agent's `SSH_AUTH_SOCK` / `SSH_AGENT_PID` under
  `~/.keychain/<host>-sh` (POSIX) or `<host>-fish` (fish).
- Auto-loads named keys, prompting only when the key isn't already in
  the agent.
- Cleans up the cache when the agent dies (e.g. after reboot).

The alternative — bare `eval $(ssh-agent)` in rc — spawns a new agent
per shell, leading to N agents and N passphrase prompts per session.

## Why Keychain on macOS

macOS ships a launchd-managed `ssh-agent` user agent (defined in
`/System/Library/LaunchAgents/com.openssh.ssh-agent.plist`) that auto-
starts on login and lives as long as the user session. Adding a key
with `--apple-use-keychain` writes the passphrase to the **login
keychain** (`~/Library/Keychains/login.keychain-db`), which:

- Is unlocked automatically when the user logs in.
- Survives reboots and macOS upgrades.
- Is encrypted at rest with the user's login password.

The `Host *` block the installer adds:

```ssh
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IgnoreUnknown UseKeychain
```

- `AddKeysToAgent yes`: any time `ssh` itself loads a new key (because
  you `ssh somewhere` and it picks an `IdentityFile`), it gets added
  to the agent automatically.
- `UseKeychain yes`: when prompted for a passphrase, store it in
  Keychain after success.
- `IgnoreUnknown UseKeychain`: keeps the config valid on Linux
  (where `UseKeychain` is unknown), so the same `~/.ssh/config` is
  portable across all your machines.

## Linux fallback (no `keychain` installed)

If `keychain` is missing, the snippet uses this strategy:

1. Read `~/.ssh/agent.env` (a file containing `SSH_AUTH_SOCK=...;
   export SSH_AUTH_SOCK;`-style lines) if it exists.
2. Run `ssh-add -l`. If it succeeds, the agent is alive — done.
3. If the agent is unreachable, run `ssh-agent -s > ~/.ssh/agent.env`
   to start a fresh one, then re-source the file.
4. Add any configured keys not already loaded.

This gives almost the same UX as `keychain`, but with two caveats:

- Agent does not auto-detect a stale `~/.keychain/...-sh` after a reboot
  as cleanly as `keychain` does. The fallback handles this by checking
  socket liveness via `ssh-add -l` exit code.
- Agent isn't cleaned up on logout; processes may accumulate if you
  start many fresh agents (the snippet only starts one per stale state,
  so in practice it's fine).

Install `keychain` whenever possible — it's < 100 KB.

## Configuration knobs

| Variable                  | Default            | Effect                                                                  |
| ------------------------- | ------------------ | ----------------------------------------------------------------------- |
| `APP_CONFIGS_SSH_KEYS`    | `github.uc.ll5`    | Space-separated list of keys to auto-load. Bare names → `~/.ssh/<name>`. Absolute paths used as-is. |

Set it in three places, in order of precedence:

1. Before sourcing the snippet in `~/.bashrc` / `~/.zshrc`:
   ```bash
   export APP_CONFIGS_SSH_KEYS="github.uc.ll5 work_ed25519"
   ```
2. As a fish universal variable:
   ```fish
   set -Ux APP_CONFIGS_SSH_KEYS github.uc.ll5 work_ed25519
   ```
3. Via the installer's environment, which writes (1) for you:
   ```bash
   APP_CONFIGS_SSH_KEYS="github.uc.ll5 work" \
       bash scripts/unix/ssh-agent-setup.sh
   ```

## Idempotency rules

- The bash/zsh rc block is delimited by:
  ```
  # >>> app-configs ssh-agent >>>
  ...
  # <<< app-configs ssh-agent <<<
  ```
  The installer strips the block before re-writing it, so running the
  installer twice never duplicates lines.
- The fish snippet is a single `.fish` file in `conf.d`. Re-running the
  installer overwrites it.
- The macOS `~/.ssh/config` block uses the same `# >>> ... <<<` markers.
  Re-running the installer skips the edit if `UseKeychain yes` is
  already present anywhere in the config (e.g. you added it manually).

## Rollback

```bash
bash scripts/unix/ssh-agent-setup.sh --remove
```

Removes:

- The marker-delimited block from `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`.
- `~/.config/app-configs/ssh-agent.sh`.
- `~/.config/fish/conf.d/ssh-agent.fish`.
- The marker block in `~/.ssh/config` on macOS.

Does **not** touch:

- Keys themselves (`~/.ssh/*`).
- Existing macOS Keychain entries (use Keychain Access.app → delete
  the "SSH:" entry).
- The `keychain` apt/dnf/brew package.

To also forget the passphrase on macOS:

```bash
security delete-generic-password -l "SSH: $HOME/.ssh/github.uc.ll5"
```

To also forget on Linux (clear running agent):

```bash
ssh-add -D       # drop all keys from the running agent
keychain --clear # clear keychain cache; next shell will re-prompt
```

## Comparison with the Windows runbook

| Aspect              | Windows (`docs/windows/QUICKSTART.md`)    | Unix (this doc)                                  |
| ------------------- | ------------------------------------------ | ------------------------------------------------ |
| Agent provider      | Windows OpenSSH service (`ssh-agent.exe`)   | launchd (macOS) / keychain or ssh-agent (Linux)  |
| Re-prompt cadence   | 8 hours (emulated in PowerShell profile)    | Once per boot (Linux) / once ever (macOS)        |
| Admin required      | Yes (one time, to enable the service)       | No                                               |
| Git config tweak    | `core.sshCommand` must point at Windows ssh | None                                             |
| Key persistence     | Until `ssh-add -D` or service restart       | Until reboot (Linux) / Keychain entry deletion (macOS) |

## See also

- `docs/shell-setup.md` — Zsh/Starship/Oh-My-Zsh baseline.
- `docs/windows/QUICKSTART.md` — Windows ssh-agent runbook.
- [`man ssh_config`](https://man.openbsd.org/ssh_config) — full directive list.
- [keychain upstream](https://www.funtoo.org/Keychain) — Funtoo's
  reference page.
