# OpenClaw Telegram bot (Linux desktop)

[OpenClaw](https://github.com/openclaw/openclaw) runs as a local gateway and
answers you in Telegram. This repo installs it through the official
[nix-openclaw](https://github.com/openclaw/nix-openclaw) Home Manager module.

- Module: `nix/modules/home/openclaw.nix` (linux-desktop, `personal` profile)
- Service: `openclaw-gateway` (systemd user unit)
- Models: GPT-6.1 Sol (`openai/gpt-6.1-sol`, ChatGPT subscription) first, then
  Claude Sonnet 5.5 (`anthropic/claude-sonnet-5-5`) through your local Claude
  Code login. Both default to medium thinking. Five more models can be picked
  per chat; see [Models](#models).
- Access: Telegram DMs use pairing, and groups are disabled

## What lives where

| Item | Location | In git? |
|------|----------|---------|
| Gateway config | `~/.openclaw/openclaw.json` → Nix store symlink | Yes, as Nix in `openclaw.nix` |
| Telegram bot token | `~/.secrets/openclaw/telegram-bot-token` | **No** |
| Gateway auth token | `~/.secrets/openclaw/gateway-token` | **No** |
| ChatGPT OAuth login, sessions, pairing approvals, memory | `~/.openclaw/` | **No** |
| Claude login | Claude Code's own store (`claude auth status`) | **No** |
| Logs | `/tmp/openclaw/openclaw-gateway.log` | No |

The repo stores only the secret **paths**. No tokens or Telegram user IDs are
committed. The bot asks for its identity on the first chat and saves it to
`~/.openclaw/workspace`.

## One-time setup

### 1. Create the bot

In Telegram, open [@BotFather](https://t.me/BotFather), send `/newbot`, and
copy the token it gives you.

### 2. Store the secrets (mode 600, outside the repo)

```sh
install -d -m 700 ~/.secrets ~/.secrets/openclaw

# Gateway auth token: random, nobody needs to type it.
bash -c 'umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d " \n" > ~/.secrets/openclaw/gateway-token'

# Telegram bot token: run this line, then at the hidden "Bot token:" prompt
# paste ONLY the token (looks like 123456789:AA...). Input stays out of history.
bash -c 'read -rsp "Bot token: " t; echo; umask 077; printf %s "$t" > ~/.secrets/openclaw/telegram-bot-token'
```

These must be regular files. OpenClaw rejects a symlinked `tokenFile`.

### 3. Apply

```sh
home-manager switch --flake ~/Projects/app-configs/nix#linux-desktop
systemctl --user status openclaw-gateway
```

### 4. Sign in to the models

The GPT models use your ChatGPT subscription. Sign in with a device code. If you
are already logged in to the Codex CLI, it imports that login:

```sh
openclaw models auth login --provider openai --device-code
```

At the end, it reports "provider settings could not be applied" because Nix
owns the config. That is expected: the credentials are still saved, and the
model settings are already in `openclaw.nix`.

Claude has no separate login. It reuses the Claude Code login on this machine.
Check it with:

```sh
claude auth status --text
```

Then confirm that both defaults answer:

```sh
openclaw models list
openclaw agent --agent main --session-id smoke --model openai/gpt-6.1-sol --message "Reply: pong"
openclaw agent --agent main --session-id smoke --model anthropic/claude-sonnet-5-5 --message "Reply: pong"
```

The GPT models run on OpenClaw's own runtime, not the Codex harness. OpenClaw
2026.10.7 rejects a Nix-loaded Codex plugin; details are in `openclaw.nix`.

### 5. Pair your Telegram account

Send any message to your bot. It replies with a pairing code. Approve it on
this machine:

```sh
openclaw pairing list telegram
openclaw pairing approve telegram <code>
```

Only approved senders can talk to the bot.

## Daily use

| Task | Command |
|------|---------|
| Status | `systemctl --user status openclaw-gateway` |
| Logs | `journalctl --user -u openclaw-gateway -f` or `tail -f /tmp/openclaw/openclaw-gateway.log` |
| Restart (for example after rotating a token) | `systemctl --user restart openclaw-gateway` |
| Health | `openclaw gateway status` / `openclaw doctor` |
| Switch this chat's model | `/gpt`, `/claude` and the others under [Models](#models) |
| Full model guide in Telegram | `/model_guide` |
| Check which model is answering | `/status`, or `openclaw sessions` on the desktop |
| Web control UI | `openclaw dashboard` |

## Models

Send a model command on its own to switch the current chat. The choice stays
until you switch again; `/model default` returns to the bot default. `/think
<level>` changes thinking for the chat.

| Command | Model | Notes |
|---------|-------|-------|
| `/gpt` | `openai/gpt-6.1-sol` | Bot default, thinking medium |
| `/luna` | `openai/gpt-6-luna` | Lighter and faster GPT |
| `/astra` | `openai/gpt-6-astra` | Previous default |
| `/claude` | `anthropic/claude-sonnet-5-5` | Claude default and bot fallback, thinking medium |
| `/opus` | `anthropic/claude-opus-5-5` | Deeper reasoning |
| `/fable` | `anthropic/claude-fable-5-1` | Top tier |
| `/haiku` | `anthropic/claude-haiku-5-5` | Fastest and cheapest |

The list follows the Codex and Claude routes in glyphbrace
`assets/models.yaml`. Copilot-only models are left out because the bot has no
Copilot login. To add or change a model, edit `chatModels` in `openclaw.nix`
and the matching entry in
`nix/modules/home/openclaw-skills/model-guide/SKILL.md`, which is the text
`/model_guide` sends.

Changing the default does not move a chat that already has a model selected.
If `/status` says the chat is pinned, send `/model default`.

## Changing config

Nix owns `openclaw.json`, and OpenClaw runs with `OPENCLAW_NIX_MODE=1`. That
means `openclaw config set` and `openclaw plugins install` refuse to change
it. To change the config, edit `nix/modules/home/openclaw.nix` and run
`home-manager switch` again. Options use the upstream config shape under
`programs.openclaw.config`. For details, see the
[nix-openclaw README](https://github.com/openclaw/nix-openclaw#configuration).

## Rotating or removing secrets

- **Telegram token:** use `/revoke` in @BotFather, overwrite the file with the
  step 2 command, then restart the service.
- **Gateway token:** run the gateway-token line from step 2 again, then
  restart the service.
- **Uninstall:** remove the import from `nix/hosts/linux-desktop/home.nix` and
  switch. Then delete `~/.secrets/openclaw` and `~/.openclaw` if you no longer
  want the state.
