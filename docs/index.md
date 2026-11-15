# Repo Docs

Repository-owned setup guides for the chezmoi + mise + Nix / Home Manager +
nix-darwin + Lefthook stack. Start with the bootstrap runbook, then read only
the topic you need.

## Where to start

| When | Read |
|------|------|
| Setting up a clean machine | [`bootstrap.md`](getting-started/bootstrap.md) |
| Understanding who owns what tool | [`architecture/tool-ownership.md`](architecture/tool-ownership.md) |
| Listing every dev CLI tool | [`software-and-cli-tools.md`](../repo-docs/software-and-cli-tools.md) |
| Shell prompt / zsh / starship | [`shell-setup.md`](guides/shell-setup.md) |
| 1Password vault secrets: `op` references and the composer wrapper | [`1password-vault-secrets.md`](guides/1password-vault-secrets.md) |
| Neovim | [`nvim-setup.md`](reference/nvim/setup.md) |
| Karabiner / keyboard remapping (macOS) | [`keyboard.md`](reference/keyboard.md) |
| Microsoft Teams not sending or reactions reverting (macOS) | [`teams-troubleshooting.md`](guides/teams-troubleshooting.md) |
| macOS disk cleanup: what is safe to clear and how to check | [`macos-cleanup.md`](guides/macos-cleanup.md) |
| OpenClaw Telegram bot: secrets, pairing, service (Linux desktop) | [`openclaw-telegram.md`](guides/openclaw-telegram.md) |
| Kanto ORA4 / USB audio validation | [`ora4-audio.md`](reference/ora4-audio.md) |
| VS Code extensions | [`vscode-extensions.md`](../repo-docs/vscode-extensions.md) |
| CLI shortcuts: abbreviations, git aliases, ports/logs/process helpers | [`cli-shortcuts.md`](reference/cli-shortcuts.md) |
| How bugs are found: every check, the bug types it catches, where it runs (`mise run audit`) | [`bug-detection.md`](reference/bug-detection.md) |
| Setup index: base requirements, then your platform | [`platforms/index.md`](platforms/index.md) |
| Windows 11 fresh setup: local account, Brave, Git, SSH key, Claude Code | [`windows/setup.md`](platforms/windows/setup.md) |
| WSL2 setup: wsl.conf, install, readiness checks, macOS differences | [`wsl/setup.md`](platforms/wsl/setup.md) |
| Windows vs WSL2 choices: edition, where to run Claude, Docker, reboots, restore points | [`wsl/windows-and-wsl.md`](platforms/wsl/windows-and-wsl.md) |
| Persistent SSH agent (Linux / macOS / WSL) | [`unix/QUICKSTART.md`](getting-started/unix-quickstart.md) and [`unix/ssh-agent-setup.md`](guides/ssh-agent-setup.md) |
| Per-project VS Code workspace template | [`templates/vscode/`](../repo-docs/templates/vscode) |

## Convention

Setup docs assume you ran `bash ops/bootstrap.sh --yes` once on the
host. Day-to-day, use `mise run sync` (preview) and `mise run sync:apply`
(apply). See [`bootstrap.md`](getting-started/bootstrap.md) for the full runbook.

## Rules for every script and agent

- Feedback before waiting: any operation that makes the user wait says what it is doing before it waits, and reports progress on long waits (T-0050). See T-0050 in docs/work/active.
