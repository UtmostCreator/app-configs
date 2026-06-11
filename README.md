# app-configs

Personal development environment for macOS, Linux, NixOS, and limited WSL2. It
manages dotfiles, shell configuration, CLI tools, GUI apps, runtimes, and
host-specific setup through **chezmoi** (dotfiles) + **mise** (runtimes &
tasks) + **Nix / Home Manager** (CLI packages) + **nix-darwin + Homebrew casks**
(macOS GUI) + **Lefthook** (git hooks).

A clean machine can reach a working setup with one bootstrap script.

> **Note on AI files.** The [AI Workflow Kit](https://github.com/UtmostCreator/awesome-ai-utmostcreator)
> has been removed from this repo for now (only `.opencode/` agent/skill
> definitions remain) and may be reinstalled later. It is governed separately
> and is not part of the dotfiles stack documented here — ignore it for setup,
> updates, and daily use.

## Scope

**This repo owns:** personal dotfiles, shell/Git/editor/terminal config, SSH
agent setup, CLI packages, GUI apps (where supported), the NixOS system layer
(where applicable), the macOS user/system layer via nix-darwin + Homebrew, and
the install / update / cleanup / validation commands.

**This repo does not own:** the AI Workflow Kit source (see note above) or any
downstream project code. Native Windows is not supported; WSL2 is limited to
Linux-style CLI/dev config.

## Supported systems

| System | Status | Coverage |
|--------|--------|----------|
| macOS (Apple Silicon by default) | Supported | Home Manager + nix-darwin + Homebrew casks |
| Linux desktop | Supported | Home Manager standalone + GUI module |
| Linux CLI / headless | Supported | CLI/dev only (no GUI) |
| WSL2 | Partial | CLI/dev only, no Windows-side management |
| Windows native | Not supported | Use WSL2 instead |

## Prerequisites

Required before cloning:

- Git, Bash, and internet access
- `sudo` access — only for the NixOS system layer (`sys-setup --apply`)

The installer bootstraps or verifies the rest as needed: chezmoi, mise, Nix,
Home Manager, nix-darwin (macOS), and Homebrew (macOS, if enabled).

## Quick start

Recommended (automated, NixOS-aware):

```bash
git clone <your-fork-of-this-repo> ~/dotfiles
cd ~/dotfiles
DRY_RUN=1 bash ops/install.sh     # preview only, mutates nothing
bash ops/install.sh               # install + apply
exec fish                             # start a new shell so the login shell applies
sys-readiness                         # confirm: prints ALL SET when fully configured
```

Manual mode (step-by-step with prompts) is documented in
[`repo-docs/bootstrap.md`](repo-docs/bootstrap.md):

```bash
cp home/personal.yaml.example home/.chezmoidata/personal.yaml
$EDITOR home/.chezmoidata/personal.yaml
bash ops/bootstrap.sh             # default: dry-run, no mutations
bash ops/bootstrap.sh --yes       # actually install + apply
```

## Personal configuration

Create your local personal config before the manual path (the automated
installer prompts for it if missing):

```bash
cp home/personal.yaml.example home/.chezmoidata/personal.yaml
$EDITOR home/.chezmoidata/personal.yaml
```

Example:

```yaml
name: "Your Full Name"
email: "you@example.com"
signingKey: ""          # optional git signing key
minimal: false          # true = minimal VS Code settings
useGitDelta: true       # git-delta in .gitconfig
hostProfile: "linux-desktop"
gui: true               # GUI configs (ghostty, etc.)
```

`home/.chezmoidata/personal.yaml` is gitignored and **must never be committed**.
Do not commit real names/emails not meant to be public, SSH keys, API tokens,
or machine-specific secrets — only the `home/personal.yaml.example` template is
tracked.

## Host profiles

Set `hostProfile` in `personal.yaml` to one of:

| Profile | Use case | GUI default | Nix mode |
|---------|----------|-------------|----------|
| `macos` | macOS desktop/laptop | yes (+ Karabiner) | nix-darwin + Home Manager |
| `linux-desktop` | Linux desktop (primary Linux target) | yes | Home Manager standalone |
| `linux-cli` | Headless Linux / CLI server | no | Home Manager standalone |
| `wsl` | WSL2 CLI/dev | no | Home Manager standalone |

`gui` defaults to true on `macos`/`linux-desktop` and false on `linux-cli`/`wsl`;
override it in `personal.yaml` if your machine differs.

## First-time setup flow

After `ops/install.sh` (or `sys-install`) has run once, the `sys-*` command
wrappers are deployed to `~/.local/bin` (from `home/dot_local/bin/`) and work
from any shell. They are **not** available before that first install.

```bash
sys-install              # 1. apps + CLI + dotfiles + hooks (unattended, no sudo, idempotent)
sudo sys-setup --apply   # 2. NixOS only, once: SYSTEM layer (fish login shell, trusted-users,
                         #    declarative GC) + nixos-rebuild switch. Preview without sudo: sys-setup
exec fish                # 3. start a new shell so the login shell applies
sys-readiness            # 4. confirm — done when it prints ALL SET (exit 0)
```

`sys-readiness` always tells you where you stand: `ALL SET` = done; `system
rebuild pending` = run step 2; `NOT READY` = run step 1. On non-NixOS hosts step
2 is a no-op and `sys-install` alone reaches `ALL SET`.

## Daily commands

| Command | Mutates? | Purpose |
|---------|:--------:|---------|
| `sys-readiness` | no | Check whether the host is fully configured |
| `sys-update` | yes | Update apps, CLI packages, dotfiles, and hooks |
| `sys-cleanup` | yes | De-dup Nix store + prune caches (keeps all rollbacks) |
| `sys-cleanup --gc` | yes | Also remove aged generations (keeps recent rollbacks) |
| `mise run sync` | no | Preview pending dotfile changes |
| `mise run sync:apply` | yes | Snapshot `$HOME`, then apply chezmoi + HM/darwin + mise + VS Code extensions + lefthook |
| `mise run apply` | yes | chezmoi-only apply (no Nix/mise side effects) |
| `mise run vscode:extensions:dry-run` | no | Preview missing curated VS Code extensions |
| `mise run vscode:extensions` | yes | Install curated VS Code extensions |
| `mise run doctor` | no | Local health check |
| `mise run repo:check` | no | doctor + validator + (optional) nix flake check |

Each `sys-*` is a thin wrapper over a `ops/*.sh` with `mise run` equivalents
(`install` / `update:apply` / `cleanup:apply` / `readiness`). Optional CLI extras
(dive / fx / navi / glow / gum): `mise run tools:optional:install` and
`mise run tools:optional:list`.

## Safety model

| Command | Mutates system/home? | Notes |
|---------|:--------------------:|-------|
| `DRY_RUN=1 bash ops/install.sh` | no | Preview install |
| `bash ops/install.sh` | yes | Installs and applies config |
| `bash ops/bootstrap.sh` | no | Dry-run by default |
| `bash ops/bootstrap.sh --yes` | yes | Installs and applies config |
| `sys-readiness` | no | Read-only status check |
| `sys-setup` | no | Preview NixOS system setup |
| `sudo sys-setup --apply` | yes | Applies NixOS system config |
| `sys-update` | yes | Updates configured tools and dotfiles |
| `sys-cleanup` | yes | Safe cleanup (keeps rollbacks) |
| `sys-cleanup --gc` | yes | Removes older generations |
| `bash ops/uninstall.sh` | no | Report only |
| `bash ops/uninstall.sh --apply` | yes | Applies uninstall actions |

Before applying dotfiles, the scripts snapshot your home directory under
`~/.local/state/dotfiles-snapshots/<UTC timestamp>/`. `uninstall.sh` never
removes Nix itself and never deletes those snapshots.

## Tool ownership

| Tool | Owns |
|------|------|
| chezmoi | Dotfiles and templated home-directory files |
| Nix flake | Host definitions and package modules |
| Home Manager | CLI packages, shell tools, user services |
| nix-darwin | macOS system-level configuration |
| Homebrew | macOS GUI apps and casks |
| mise | Runtime versions and repo tasks |
| Lefthook | Git hooks (no-personal-yaml guard + validate-config) |
| shell scripts | Bootstrap, setup, update, cleanup, validation |

Full rationale: [`repo-docs/architecture/tool-ownership.md`](repo-docs/architecture/tool-ownership.md).

## Repository layout

| Path | Purpose |
|------|---------|
| `home/` | chezmoi source tree for dotfiles and app configs. `home/personal.yaml.example` is committed; real `home/.chezmoidata/personal.yaml` is gitignored. |
| `nix/` | Nix flake + Home Manager modules per host profile. `nix/flake.nix` exposes `homeConfigurations.{linux-desktop,linux-cli,wsl,macos}` and `darwinConfigurations.macos`. |
| `ops/` | Repo-owned install, setup, update, cleanup, validation, hooks (`ops/hooks/`), project helpers (`ops/projects/`), and Unix setup (`ops/unix/`). |
| `repo-docs/` | Extended setup/maintenance docs. Historical migration notes under `repo-docs/migration-*.md`; completed one-off artifacts under `repo-docs/archive/`. |
| `mise.toml` | Repo task definitions. Tool versions are per-user in `home/dot_config/mise/config.toml.tmpl`. |
| `.lefthook.yml` | Git hook configuration. |

Style/reference configs that ship for downstream projects (formatting rules,
not runtime behaviour): `.editorconfig`, `.prettierrc.json`, `.eslintrc.json`,
`.stylelintrc.json`, and `.gitattributes` (LF/CRLF policy).

## Validation

```bash
sys-readiness                  # "am I all set?" (read-only)
bash ops/doctor.sh         # or: mise run doctor
bash ops/validate-config.sh
mise run repo:check
```

A healthy setup passes readiness and repo validation.

## Uninstall

```bash
bash ops/uninstall.sh             # report only
bash ops/uninstall.sh --apply     # actually run
```

## Troubleshooting

| Problem | Check |
|---------|-------|
| `sys-*` command not found | Run `bash ops/install.sh`, then open a new shell |
| Shell did not change to fish | Run `exec fish` or reopen the terminal |
| Readiness says `system rebuild pending` | Run `sudo sys-setup --apply` (NixOS) |
| Readiness says `NOT READY` | Run `sys-install`, then `sys-readiness` |
| macOS GUI apps missing | Check Homebrew / nix-darwin setup |
| WSL2 GUI missing | Expected; WSL2 is CLI/dev only |

## Extended documentation

- Install + maintenance guide: [`repo-docs/INSTALL.md`](repo-docs/INSTALL.md)
- Cold-start runbook: [`repo-docs/bootstrap.md`](repo-docs/bootstrap.md)
- NixOS specifics: [`repo-docs/install-nixos.md`](repo-docs/install-nixos.md)
- System rebuild (`nixos-rebuild`, when & how): [`repo-docs/nixos-rebuild.md`](repo-docs/nixos-rebuild.md)
- Nix-specific bits & cross-distro replacements: [`repo-docs/nix-specific-and-replacements.md`](repo-docs/nix-specific-and-replacements.md)

## Historical notes

Migration notes (`repo-docs/migration-*.md`) and archived one-off artifacts
(`repo-docs/archive/`) are retained for audit/debugging only and are not
required for normal use.
