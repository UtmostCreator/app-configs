# Repo Docs

Repository-owned setup guides for the chezmoi + mise + Nix / Home Manager +
nix-darwin + Lefthook stack. Start with the bootstrap runbook, then read only
the topic you need.

> **Why `repo-docs/` and not `docs/`?** The `docs/ai/` tree is an AI workflow
> kit auto-shipped by [`UtmostCreator/awesome-ai-utmostcreator`](https://github.com/UtmostCreator/awesome-ai-utmostcreator)
> and is **not** maintained in this repo. To keep repo-owned documentation
> clearly separated from that auto-shipped content, all of this repo's own docs
> live here under `repo-docs/`; `docs/` holds only the AI kit.
>
> The kit's generated `docs/ai/repo-directory-map.json` (and
> `docs/ai/repo-required-tools.md`) may still name the old `docs/<file>` paths
> until the kit is regenerated/re-synced upstream — that staleness is expected
> and harmless; no repo tooling depends on it.

## Where to start

| When | Read |
|------|------|
| Setting up a clean machine | [`bootstrap.md`](bootstrap.md) |
| Understanding who owns what tool | [`architecture/tool-ownership.md`](architecture/tool-ownership.md) |
| Listing every dev CLI tool | [`software-and-cli-tools.md`](software-and-cli-tools.md) |
| Shell prompt / zsh / starship | [`shell-setup.md`](shell-setup.md) |
| Neovim | [`nvim-setup.md`](nvim-setup.md) |
| Karabiner / keyboard remapping (macOS) | [`keyboard.md`](keyboard.md) |
| VS Code extensions | [`vscode-extensions.md`](vscode-extensions.md) |
| Persistent SSH agent (Linux / macOS / WSL) | [`unix/QUICKSTART.md`](unix/QUICKSTART.md) and [`unix/ssh-agent-setup.md`](unix/ssh-agent-setup.md) |
| Persistent SSH agent (Windows native) | [`windows/QUICKSTART.md`](windows/QUICKSTART.md) (kept as-is; not maintained as part of this stack) |
| Per-project VS Code workspace template | [`templates/vscode/`](templates/vscode/) |
| Migration audit trail | [`migration-implementation-plan.md`](migration-implementation-plan.md) and `migration-*.md` |

## Convention

Setup docs assume you ran `bash scripts/bootstrap.sh --yes` once on the
host. Day-to-day, use `mise run sync` (preview) and `mise run sync:apply`
(apply). See [`bootstrap.md`](bootstrap.md) for the full runbook.
