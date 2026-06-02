# app-configs

Personal macOS / Linux / WSL2 development environment, packaged so a clean
machine can reach a working setup with one bootstrap script.

Stack: **chezmoi** (dotfiles) + **mise** (runtimes & tasks) + **Nix / Home
Manager** (CLI packages) + **nix-darwin + Homebrew casks** (macOS GUI) +
**Lefthook** (git hooks).

> Looking for the AI Workflow Kit? It moved to
> [awesome-ai-utmostcreator](https://github.com/UtmostCreator/awesome-ai-utmostcreator).
> Anything under `.opencode/`, `.github/`, `docs/ai/`, `tools/ai/`,
> `packages/ai-universal-rules/`, and `scripts/ai/` is the local mirror of
> that kit and is governed separately from the dotfiles stack documented
> here.

## Cold start (any supported host)

```bash
git clone <your-fork-of-this-repo> ~/dotfiles
cd ~/dotfiles

# Option A — fully automated, unattended (recommended). NixOS-aware.
bash scripts/install.sh                       # run it and walk away
DRY_RUN=1 bash scripts/install.sh             # preview, mutate nothing

# Option B — manual, step-by-step with prompts
cp home/personal.yaml.example home/.chezmoidata/personal.yaml
$EDITOR home/.chezmoidata/personal.yaml       # name, email, hostProfile, gui
bash scripts/bootstrap.sh                      # default: dry-run, no mutations
bash scripts/bootstrap.sh --yes               # actually install + apply
```

Install + maintenance guide: [`docs/INSTALL.md`](docs/INSTALL.md).
Cold-start runbook: [`docs/bootstrap.md`](docs/bootstrap.md).
NixOS specifics: [`docs/install-nixos.md`](docs/install-nixos.md).
System rebuild (`nixos-rebuild`, when & how): [`docs/nixos-rebuild.md`](docs/nixos-rebuild.md).
Nix-specific bits & cross-distro replacements: [`docs/nix-specific-and-replacements.md`](docs/nix-specific-and-replacements.md).

Keep it fresh (the `brewup` equivalent) and tidy:

```bash
mise run update:apply     # update flake inputs + HM + chezmoi + mise, then safe cleanup
mise run cleanup:apply    # reclaim disk without deleting rollback generations
```
Ownership rules and "why each tool": [`docs/architecture/tool-ownership.md`](docs/architecture/tool-ownership.md).

## Day-to-day

```bash
mise run sync           # preview pending changes (no mutation)
mise run sync:apply     # apply (snapshots $HOME first, then chezmoi + HM/darwin + mise + lefthook)
mise run apply          # chezmoi-only apply (no Nix/mise side effects)
mise run doctor         # local health check
mise run repo:validate  # architecture invariant guard
mise run repo:check     # doctor + validator + (optional) nix flake check
```

Optional CLI extras (dive / fx / navi / glow / gum):

```bash
mise run tools:optional:install
mise run tools:optional:list
```

## Supported targets

| Target | Coverage |
|--------|----------|
| macOS (Apple Silicon by default) | full (Home Manager + nix-darwin + Homebrew casks) |
| Linux desktop | full (Home Manager standalone + GUI module) |
| Linux CLI / headless | CLI-only (Home Manager standalone, no GUI) |
| WSL2 | best-effort, Linux-flavoured CLI/dev only |
| Windows native | not supported |

## Layout

| Path | Owns |
|------|------|
| `home/` | chezmoi source tree (dotfiles in `~` and `~/.config/`). Template `home/personal.yaml.example` is committed; real `home/.chezmoidata/personal.yaml` is gitignored. |
| `nix/` | Nix flake + Home Manager modules per host profile. `nix/flake.nix` exposes `homeConfigurations.{linux-desktop,linux-cli,wsl,macos}` and `darwinConfigurations.macos`. |
| `mise.toml` | repo tasks. Tool versions are per-user in `home/dot_config/mise/config.toml.tmpl`. |
| `.lefthook.yml` | git hooks: pre-commit (no-personal-yaml guard + shared-precommit) and pre-push (validate-config). |
| `scripts/` | `bootstrap.sh`, `detect-host.sh`, `doctor.sh`, `snapshot-home.sh`, `validate-config.sh`, `uninstall.sh`, `test-bootstrap-docker.sh`, `check-source-of-truth.sh`, `generate-package-matrix.sh`, hooks under `scripts/hooks/`, and `scripts/unix/ssh-agent-setup.sh`. |
| `docs/` | per-topic setup docs and the migration audit trail (`migration-*.md`). |
| `docs/architecture/tool-ownership.md` | canonical statement of who owns what. |
| `docs/bootstrap.md` | cold-start runbook + per-host notes + WSL2 caveats. |
| `docs/templates/vscode/` | reusable per-project workspace template (`workspace-template.json`). |

## Style configs (reference baseline)

These ship for downstream projects; they describe formatting rules, not
runtime behaviour:

- `.editorconfig`, `.prettierrc.json`, `.eslintrc.json`, `.stylelintrc.json`
- `.gitattributes` (LF/CRLF policy)

## Verify your install

```bash
bash scripts/doctor.sh
bash scripts/validate-config.sh
mise run repo:check
```

## Uninstall / handoff

```bash
bash scripts/uninstall.sh             # report only
bash scripts/uninstall.sh --apply     # actually run
```

`scripts/uninstall.sh` never removes Nix itself and never deletes snapshots
under `~/.local/state/dotfiles-snapshots/`.

## Migration history

See `new-architecture-todo-v2.md` and `docs/migration-*.md` for the phased
migration audit trail (source-of-truth matrix, package ownership matrix,
pre-flight decisions).
