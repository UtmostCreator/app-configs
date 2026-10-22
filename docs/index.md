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
| Neovim | [`nvim-setup.md`](reference/nvim/setup.md) |
| Karabiner / keyboard remapping (macOS) | [`keyboard.md`](reference/keyboard.md) |
| Microsoft Teams not sending or reactions reverting (macOS) | [`teams-troubleshooting.md`](guides/teams-troubleshooting.md) |
| macOS disk cleanup: what is safe to clear and how to check | [`macos-cleanup.md`](guides/macos-cleanup.md) |
| Kanto ORA4 / USB audio validation | [`ora4-audio.md`](reference/ora4-audio.md) |
| VS Code extensions | [`vscode-extensions.md`](../repo-docs/vscode-extensions.md) |
| Persistent SSH agent (Linux / macOS / WSL) | [`unix/QUICKSTART.md`](getting-started/unix-quickstart.md) and [`unix/ssh-agent-setup.md`](guides/ssh-agent-setup.md) |
| Per-project VS Code workspace template | [`templates/vscode/`](../repo-docs/templates/vscode) |
| Incident response: Ubuntu/Apache, Netlify SSR, access-log and cache investigations | [`runbooks/`](runbooks/README.md) |

## Convention

Setup docs assume you ran `bash ops/bootstrap.sh --yes` once on the
host. Day-to-day, use `mise run sync` (preview) and `mise run sync:apply`
(apply). See [`bootstrap.md`](getting-started/bootstrap.md) for the full runbook.
