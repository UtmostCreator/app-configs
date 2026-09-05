# Linux / macOS / WSL SSH Agent — QUICKSTART

Copy-paste runbook to make `git@github.com:...` (and any other SSH host)
work from any shell with the passphrase prompted **at most once per boot**
on Linux/WSL, and **at most once ever** on macOS (stored in Keychain).

Works on:

- macOS (zsh, bash, fish) — uses the built-in launchd ssh-agent + Keychain
- Linux desktop / server / WSL (bash, zsh, fish) — uses `keychain` if
  installed, otherwise a persistent shared `ssh-agent` socket

## TL;DR — one command

From a clone of this repo:

```bash
bash ops/unix/ssh-agent-setup.sh
```

Then open a new terminal. Done.

To load multiple keys, pass them via `APP_CONFIGS_SSH_KEYS` (space-
separated, basenames under `~/.ssh/` or absolute paths):

```bash
APP_CONFIGS_SSH_KEYS="github.uc.ll5 work_ed25519" \
    bash ops/unix/ssh-agent-setup.sh
```

To uninstall:

```bash
bash ops/unix/ssh-agent-setup.sh --remove
```

---

## What it sets up

| Component             | macOS                                | Linux / WSL                              |
| --------------------- | ------------------------------------ | ---------------------------------------- |
| Agent                 | launchd-managed `ssh-agent`           | `keychain` (preferred) or persistent shared `ssh-agent` |
| Passphrase storage    | macOS Keychain (asked once ever)      | In-memory, asked once per boot           |
| `~/.ssh/config` edits | Adds `UseKeychain yes` / `AddKeysToAgent yes` for `Host *` | none                                     |
| Shell wiring          | Sources snippet from `~/.bashrc`, `~/.zshrc`, or fish `conf.d` | same |

Files deployed:

| Deploy path                                  | Source in repo                                              |
| -------------------------------------------- | ----------------------------------------------------------- |
| `~/.config/app-configs/ssh-agent.sh`          | `home/dot_config/app-configs/ssh-agent.sh` (chezmoi-managed) |
| `~/.config/fish/conf.d/ssh-agent.fish`        | `home/dot_config/fish/conf.d/ssh-agent.fish` (chezmoi-managed) |

The bash/zsh rc is edited inside a marker-delimited block:

```bash
# >>> app-configs ssh-agent >>>
[ -f "$HOME/.config/app-configs/ssh-agent.sh" ] && . "$HOME/.config/app-configs/ssh-agent.sh"
# <<< app-configs ssh-agent <<<
```

Re-running the installer refreshes the block in place.

---

## Manual setup (without the installer)

### Linux / WSL — bash / zsh

```bash
# 1. Install keychain (recommended).
sudo apt-get install -y keychain        # Debian/Ubuntu/WSL
sudo dnf install -y keychain            # Fedora/RHEL
sudo pacman -S --needed keychain        # Arch
brew install keychain                   # Homebrew on Linux

# 2. Deploy the snippet (or let chezmoi do it via `mise run sync:apply`).
mkdir -p ~/.config/app-configs
cp home/dot_config/app-configs/ssh-agent.sh ~/.config/app-configs/

# 3. Add to ~/.bashrc or ~/.zshrc (idempotent — only add once):
cat >> ~/.bashrc <<'EOF'

# >>> app-configs ssh-agent >>>
export APP_CONFIGS_SSH_KEYS="github.uc.ll5"
[ -f "$HOME/.config/app-configs/ssh-agent.sh" ] && . "$HOME/.config/app-configs/ssh-agent.sh"
# <<< app-configs ssh-agent <<<
EOF
```

### Linux / WSL — fish

```fish
# Install keychain as above, then:
mkdir -p ~/.config/fish/conf.d
cp home/dot_config/fish/conf.d/ssh-agent.fish ~/.config/fish/conf.d/

# Configure keys (universal var, persists across all fish sessions):
set -Ux APP_CONFIGS_SSH_KEYS github.uc.ll5
```

### macOS

```bash
# 1. Ensure ~/.ssh/config has the Keychain directives. Add this block:
cat >> ~/.ssh/config <<'EOF'

Host *
    AddKeysToAgent yes
    UseKeychain yes
    IgnoreUnknown UseKeychain
EOF
chmod 600 ~/.ssh/config

# 2. Deploy the snippet exactly as for Linux. macOS detection is
#    automatic — the snippet uses `ssh-add --apple-use-keychain`.

# 3. The very first `ssh-add --apple-use-keychain ~/.ssh/<key>` will
#    prompt once for the passphrase and store it in your login keychain.
#    Subsequent sessions reuse it silently — even across reboots.
```

---

## Verify

```bash
# In a fresh terminal:
echo "$SHELL"
ssh-add -l          # should list at least one fingerprint
ssh -T git@github.com   # GitHub auth check (exit 1 is normal)
```

For fish:

```fish
set -S APP_CONFIGS_SSH_KEYS    # confirm keys are set
ssh-add -l
```

---

## Troubleshooting

| Symptom                                                          | Cause                                          | Fix                                                                                            |
| ---------------------------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Passphrase prompt every new shell on Linux                       | `keychain` not installed; fallback agent died  | `which keychain`; install it, then open a new shell                                            |
| `ssh-add -l` says "Could not open a connection to your authentication agent" | Agent socket stale (after WSL/PC reboot)       | Open a new shell — the snippet will start a fresh agent and re-prompt once                     |
| macOS prompts every reboot                                       | `UseKeychain yes` missing from `~/.ssh/config`  | Re-run the installer; check the `Host *` block exists                                          |
| WSL shell shows passphrase prompt twice                          | Both bash AND fish snippets active             | Pick one shell as default (`chsh -s /usr/bin/fish`); remove the other rc block                 |
| `keychain` prints a banner on every shell                        | `--quiet` flag missing                         | Re-run the installer; or edit `~/.config/app-configs/ssh-agent.sh`                             |
| Key isn't loaded                                                 | Filename mismatch                              | `ls ~/.ssh/`; update `APP_CONFIGS_SSH_KEYS` to match exact basenames                           |

---

## Security notes

- The snippet **only runs in interactive shells** (`case $- in *i*`). Scripts,
  rsync targets, `scp`, and CI invocations never trigger a passphrase prompt.
- Keys are loaded by **basename only** by default — no absolute paths in
  shell history.
- On macOS the passphrase lives in your login Keychain; on Linux it lives
  in agent memory and is wiped on reboot. Neither writes the passphrase
  to disk.
- The shared agent socket on the Linux fallback path is created under
  `~/.ssh/agent.env` with `umask 077`.

## Why not just `eval $(ssh-agent)` in `.bashrc`?

That starts a **new** agent in every shell, so each terminal asks for the
passphrase separately and you accumulate dangling `ssh-agent` processes.
`keychain` (Linux) and the launchd-managed agent (macOS) both solve this
by ensuring a single agent per user, shared across every shell.
