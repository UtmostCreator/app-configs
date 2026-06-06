# Dotfiles Migration — Implementation Plan (v2)

A phased, checkboxed working document for migrating the dotfiles repo to a `chezmoi + mise + Nix/Home Manager + nix-darwin + Lefthook` stack.

**Target support:**
- **macOS** — primary, full coverage (Home Manager + nix-darwin + Homebrew casks)
- **Linux desktop** — primary, full coverage (Home Manager standalone + GUI module)
- **Linux CLI/headless** — CLI-only coverage (Home Manager standalone; no GUI module)
- **WSL2** — best-effort CLI-only, Linux-flavoured shell/dev only. No Windows-side management.
- **Windows native** — out of scope/deferred; existing native Windows files remain untouched unless a separate cleanup is approved.

Each phase is independently shippable.

**Critical-pass score:** ~91/100 after supplement integration. This is not 95+ until the Phase 1/3 matrices are completed from real repository evidence and the helper scripts are implemented, run, and verified on throwaway/real hosts.

## Supplement critical review

Accepted into this plan:
- Helper scripts for repeatable source/package matrices: `ops/check-source-of-truth.sh` and `ops/generate-package-matrix.sh`.
- Shell syntax/lint checks via `bash -n` and ShellCheck.
- PATH refresh after Nix profile installs, followed by callable checks for `chezmoi`, `mise`, `home-manager`, and `lefthook`.
- Snapshot-before-apply via `ops/snapshot-home.sh` before any real-machine `chezmoi apply`.
- Architecture invariant validator: `ops/validate-config.sh`, exposed as `mise run repo:validate`.
- Optional Docker fresh-Ubuntu dry-run validation before legacy deletion.
- Recovery/handoff helper: `ops/uninstall.sh`.
- Secrets and dependency-update documentation.
- Lefthook guard to block staged `home/.chezmoidata/personal.yaml`.

Rejected or modified:
- Do **not** make validation fail merely because existing Windows-native files are present; Windows native management remains deferred and files remain untouched unless separately approved.
- Do **not** require PHP/AI CI for this config-only migration unless AI/PHP workflow files are edited.
- Do **not** make `mise run sync` mutating; it remains preview-only. `mise run sync:apply` is the explicit mutating command.
- Do **not** hard-drop `direnv`; Phase 3 must decide whether to retain or drop it with evidence.

---

## What changed in v2

| v1 design | v2 correction | Why |
|-----------|---------------|-----|
| WSL2 treated equal to Linux/macOS | WSL2 best-effort, no Windows-side scope | Avoid bottomless Windows complexity |
| chezmoi `.chezmoiops/` ran home-manager, mise install, vscode extensions | All orchestration moved to `bootstrap.sh` + mise tasks (`mise run sync` previews; `mise run sync:apply` applies); chezmoi renders files only | One owner per concern; `chezmoi apply` becomes safe |
| Cleanup before source-of-truth selection | New Phase 1: explicit source matrix before any deletes | Prevents losing the fresher copy of a duplicated file |
| Nix package list built inside Phase 4 | New Phase 3: package ownership matrix as a discrete deliverable | Every tool maps to an owner before any Nix file is written |
| Bootstrap silently applied everything | Bootstrap defaults to `--dry-run`; `--yes` required for mutations | Safety on real machines |
| macOS GUI via Nix | macOS GUI via nix-darwin Homebrew cask bridge | Nixpkgs macOS GUI coverage is uneven; casks are canonical |
| 3 chezmoi run-scripts | 0 chezmoi run-scripts | chezmoi = pure file rendering |

---

## Architecture summary

| Tool | Owns | Never owns |
|------|------|-----------|
| **chezmoi** | All dotfiles in `~` and `~/.config/`. File rendering only — no orchestration | Package installation, side effects beyond writing files |
| **mise** | Language runtimes, tool versions, per-project env vars, repo tasks including `sync` | OS package installation, dotfile content |
| **Nix + Home Manager** | User-installed CLI packages via `home.packages` only | Files chezmoi configures |
| **nix-darwin** | macOS system defaults, Homebrew cask bridge for GUI apps | Linux/WSL config |
| **Lefthook** | Git hooks | Anything outside git lifecycle |
| **bootstrap.sh** | Initial cold-start orchestration on new machines | Ongoing preview is `mise run sync`; mutating updates are `mise run sync:apply` |

**Hard rules:**

- `.chezmoiroot` at repo root, containing `home`
- Home Manager uses `home.packages = [ ... ]` only. The single exception is `programs.home-manager.enable = true;`. No other `programs.<x>.enable` is permitted.
- Home Manager must NOT create or manage: `~/.zshrc`, `~/.gitconfig`, `~/.config/starship/starship.toml`, `~/.config/mise/config.toml`, `~/.config/nvim`, `~/.config/ghostty`, VS Code user settings.
- chezmoi must NOT install packages, switch nix profiles, or run any orchestration.
- bootstrap.sh runs ONCE per machine. `mise run sync` previews ongoing updates; `mise run sync:apply` is the explicit mutating update command.

---

## Host profile model

```
profiles:
  macos -> Home Manager + nix-darwin + Homebrew casks
            GUI module on, karabiner on, VS Code at ~/Library/Application Support/Code/User/
  linux-desktop -> Home Manager standalone
            GUI module on, VS Code at ~/.config/Code/User/; primary Linux target
  linux-cli -> Home Manager standalone
            CLI/dev tools only, NO GUI module, NO karabiner, NO ghostty
  wsl   -> Home Manager standalone, lightweight, best-effort CLI-only
            NO GUI module, NO karabiner, NO ghostty
            Zero Windows-side management
```

WSL2 caveats (documented in `repo-docs/bootstrap.md`):
- Windows VS Code (Remote-WSL) reads settings from Windows side; not managed here
- Windows SSH agent bridge: do it manually with `wsl2-ssh-agent` if you want it
- Windows Terminal / Windows package managers: out of scope
- Clipboard: use `clip.exe` from CLI or rely on terminal
- Keep repos in `~/`, not `/mnt/c/`

---

## Pre-flight decisions

- [ ] **Bash usage:** zsh-only, or keep bash fallback?
- [ ] **`personal.yaml` privacy:** real values in git, or example + gitignore? **Recommended: gitignore real file.**
- [ ] **macOS architecture:** `aarch64-darwin` (Apple Silicon) or `x86_64-darwin` (Intel)?
- [ ] **Day-to-day primary host:** `linux-desktop` / `linux-cli` / `wsl` / `macos`?

---

## Time estimates

| Phase | Effort | Risk |
|------:|--------|------|
| 0 — Branch & baseline | 15–30 min | Negligible |
| 1 — Source-of-truth selection | 30–60 min | Negligible |
| 2 — Cleanup | 30–60 min | Low |
| 3 — Package ownership matrix | 1–2 hours | Negligible |
| 4 — chezmoi `home/` tree | 2–4 hours | Medium |
| 5 — `mise.toml` | 15 min | Negligible |
| 6 — Nix flake + Home Manager | Weekend (8–12 h) | Medium-High |
| 7 — Bootstrap with safety flags | 1–2 hours | Low |
| 8 — nix-darwin + Homebrew casks | 2–4 hours (macOS only) | Low |
| 9 — Documentation | 1–2 hours | Negligible |
| 10 — Legacy cleanup | 30 min | Low |

Total: ~4 working days, 2–4 calendar weeks.

---

# Phase 0 — Branch & baseline

## Goal
Safe, reversible baseline.

## Pre-flight checks
- [ ] `git status --short` clean
- [ ] On `main`
- [ ] `bash ops/doctor.sh` exits 0
- [ ] Dotfiles-config smoke checks pass where tools exist: `git diff --check`, shell syntax for changed shell scripts (`bash -n <script>`), and existing repo doctor if it is relevant to dotfile health
- [ ] Repo AI/PHP checks are optional and out of scope for this config architecture migration unless the phase edits AI workflow files (not planned)

## Actions
- [ ] `git switch -c feat/dotfiles-migration`
- [ ] `git ls-files > /tmp/dotfiles-before.txt && wc -l /tmp/dotfiles-before.txt`
- [ ] Write the 4 pre-flight decisions somewhere persistent
- [ ] Note throwaway target (VM/WSL distro/spare account)

## Validation
- [ ] On the feature branch
- [ ] `/tmp/dotfiles-before.txt` exists
- [ ] All decisions recorded

## Rollback
```bash
git switch main && git branch -D feat/dotfiles-migration
```

## Commit
None this phase.

---

# Phase 1 — Source-of-truth selection

## Goal
For every config that exists in multiple places, decide which copy wins. Document the decision. **No file moved or deleted in this phase.**

## Pre-flight checks
- [ ] `diff` available

## Actions

### Create/use helper: `ops/check-source-of-truth.sh`
Planned script contract, not a substitute for human review:
- Compares known duplicate/overlapping config sources and inventories `configs/` plus `backup-sanitized/`.
- Emits a draft matrix to `repo-docs/migration-source-of-truth.draft.md` with candidate paths, diff status, freshness hints where available, and unresolved `TBD` markers.
- Never deletes or moves files.
- Final human-reviewed output is `repo-docs/migration-source-of-truth.md`; Phase 2 reads only the final reviewed file.

Run after creating the script:
```bash
bash ops/check-source-of-truth.sh
```

### Run diff comparisons
```bash
diff -u configs/shell/.zshrc        backup-sanitized/home/.zshrc          | head -100
diff -u configs/shell/.gitconfig    backup-sanitized/home/.gitconfig      | head -100
diff -u configs/shell/starship.toml backup-sanitized/home/.config/starship/starship.toml | head -100
diff -u configs/ghostty/config      configs/ghostty/config-ghostyy
diff -u configs/ghostty/config      backup-sanitized/home/.config/ghostty/config
diff -u ops/git-branch-origin.sh backup-sanitized/home/.local/bin/git-branch-origin | head -100
```

### Complete this matrix (overwrite TBDs)

| Target in `~` | Candidate sources | Chosen | Reason |
|---|---|---|---|
| `~/.zshrc` | `backup-sanitized/home/.zshrc`, `configs/shell/.zshrc` | TBD | (pick newer/more complete) |
| `~/.zprofile` | `backup-sanitized/home/.zprofile` | backup-sanitized | only source |
| `~/.bashrc` | `backup-sanitized/home/.bashrc` | keep or drop per pre-flight | — |
| `~/.gitconfig` | `backup-sanitized/...`, `configs/shell/.gitconfig` | TBD | pick the one with current identity |
| `~/.config/starship/starship.toml` | `backup-sanitized/...`, `configs/shell/starship.toml` | TBD | — |
| `~/.config/ghostty/config` | 3 candidates | TBD | typo file (`config-ghostyy`) likely loses |
| `~/.config/atuin/config.toml` | `backup-sanitized/...` | backup-sanitized | only source |
| `~/.config/btop/btop.conf` | `backup-sanitized/...` | backup-sanitized | only source |
| `~/.config/mise/config.toml` | `backup-sanitized/...` | backup-sanitized | only source |
| `~/.config/nvim/*` | `configs/nvim/*` | configs/nvim | only source |
| `~/.config/karabiner/karabiner.json` | `configs/karabiner/karabiner.json` | configs/karabiner | only source, macOS-gated |
| VS Code `settings.json` | `configs/vscode/user/settings.json` + `settings.minimal.json` | merge full+minimal | fold via template `{{ if .minimal }}` |
| VS Code `keybindings.json` | `configs/vscode/keybindings.json` | only source | — |
| `~/.local/bin/git-branch-origin` | `backup-sanitized/.../git-branch-origin`, `ops/git-branch-origin.sh` | TBD | compare both; do not assume backup copy wins |
| SSH agent config/scripts | `configs/shell/ssh-agent/*`, `ops/unix/ssh-agent-setup.sh` | TBD | decide migrate / keep as bootstrap helper / drop; document ownership before Phase 2 |

### Identify Phase 2 deletes (don't do yet)
- Project-scoped (delete): `configs/vscode/launch.json`, `configs/php/pint.json`
- System-volatile (delete): `configs/php/php.ini`
- Confirmed typo dupe (delete): `configs/ghostty/config-ghostyy`
- Windows-native: out of scope/deferred; leave untouched unless a separate cleanup is approved
- `.husky/`: defer unless hook ownership is separately confirmed after Lefthook is installed and working
- Whichever side lost above

## Validation
- [ ] `repo-docs/migration-source-of-truth.draft.md` generated by the helper
- [ ] Draft has no unresolved `TBD` markers before Phase 2 begins
- [ ] Final reviewed `repo-docs/migration-source-of-truth.md` exists
- [ ] Matrix has no TBDs
- [ ] Every `configs/` file disposition documented (migrate / dupe-of-X / project-scoped / delete)
- [ ] `configs/shell/ssh-agent/*` disposition documented
- [ ] `ops/unix/ssh-agent-setup.sh` ownership documented (bootstrap helper / migrated / retained / dropped)
- [ ] `ops/git-branch-origin.sh` compared against backup copy before choosing
- [ ] Every `backup-sanitized/` file disposition documented

## Commit
```bash
git add repo-docs/migration-source-of-truth.md  # if you want the audit in git
git commit -m "docs: record source-of-truth decisions for migration"
```

---

# Phase 2 — Cleanup

## Goal
Execute Phase 1's approved delete list. No new files created except documented moves/templates. Native Windows files and `.husky/` are not deleted in this phase unless separately approved.

## Actions

### Husky (deferred by default)
```bash
# Optional separate cleanup only after Lefthook is confirmed installed and working
# and hook ownership is approved:
# git rm -r .husky/
```

### Windows artefacts (out of scope/deferred)
```bash
# Do not delete native Windows docs/scripts as part of this migration.
# "Ignore Windows" means no Windows-side management; existing files stay untouched
# unless a separate cleanup is approved.
```

### Losing duplicates (your matrix dictates which)
```bash
# If backup-sanitized won:
git rm configs/shell/.zshrc configs/shell/.gitconfig configs/shell/starship.toml
rmdir configs/shell 2>/dev/null || true
```

### Typo and project-scoped
```bash
git rm configs/ghostty/config-ghostyy
git rm configs/php/php.ini configs/php/pint.json
git rm configs/vscode/launch.json
rmdir configs/php 2>/dev/null || true
```

### VS Code workspace templates → docs
```bash
mkdir -p docs/templates/vscode/
git mv configs/vscode/workspace-example.json docs/templates/vscode/
git mv configs/vscode/workspace-template.json docs/templates/vscode/
```

### Bash decision
```bash
# Drop only if pre-flight said zsh-only:
git rm backup-sanitized/home/.bashrc
```

### Update `.gitignore`
Append:
```gitignore
# Chezmoi private state
home/.chezmoidata/personal.yaml
home/.chezmoidata/personal.local.yaml
home/.chezmoistate/

# Nix
result
result-*

# mise local
mise.local.toml
.mise.local.toml
```

## Validation
- [ ] `git status --short` shows only deletions + workspace-template moves
- [ ] `git diff --check` clean
- [ ] `bash ops/doctor.sh` still exits 0
- [ ] Dotfiles-config checks pass for touched files (for example `bash -n` on edited shell scripts, `chezmoi diff` once Phase 4 exists)
- [ ] Repo AI/PHP tests are optional/out of scope unless this phase edits those surfaces

## Rollback
```bash
git restore --staged . && git restore .
```

## Commit
```bash
git add -A
git commit -m "chore: drop duplicate and project-scoped configs"
```

---

# Phase 3 — Package ownership matrix

## Goal
Every tool from `repo-docs/install-dev-tools.sh` and `repo-docs/software-and-cli-tools.md` maps to an owner. **No Nix code written here.** Draft output is `repo-docs/migration-package-ownership.draft.md`; final reviewed output is `repo-docs/migration-package-ownership.md`.

## Actions

### Create/use helper: `ops/generate-package-matrix.sh`
Planned script contract, not a substitute for human verification:
- Extracts package/tool candidates from `repo-docs/install-dev-tools.sh`, `repo-docs/software-and-cli-tools.md`, and current config references.
- Generates `repo-docs/migration-package-ownership.draft.md` with candidate owner, package/cask lookup hints, source references, and unresolved `TBD` markers.
- May call `nix search nixpkgs <name>` and `brew search --casks <name>` when available, but search names are advisory only and must be manually verified before Nix/Homebrew code is written.
- Final human-reviewed output is `repo-docs/migration-package-ownership.md`; Phase 6 reads only the final reviewed file.

Run after creating the script:
```bash
bash ops/generate-package-matrix.sh
```

### Build the list
- [ ] Extract every package name from `repo-docs/install-dev-tools.sh`
- [ ] Cross-reference `repo-docs/software-and-cli-tools.md`
- [ ] Add any tool you actually use that's in neither doc

### Categorize each tool

Owner options: **Nix** (Home Manager package), **nix profile** (bootstrap-installed, not in HM), **mise** (runtime/tool version), **cask** (Homebrew via nix-darwin, macOS only), **manual** (per-machine install), **decision required**, **DROPPED**.

Template (populate from your actual list):

| Tool | Type | Owner | Module / Manifest | Notes |
|------|------|-------|-------------------|-------|
| `ripgrep` | CLI | Nix | `modules/home/cli.nix` | |
| `fd` | CLI | Nix | `modules/home/cli.nix` | |
| `bat` | CLI | Nix | `modules/home/cli.nix` | |
| `eza` | CLI | Nix | `modules/home/cli.nix` | |
| `jq`, `yq` | CLI | Nix | `modules/home/cli.nix` | |
| `fzf`, `zoxide` | CLI | Nix | `modules/home/cli.nix` | |
| `btop`, `atuin`, `starship`, `tmux` | CLI | Nix | `modules/home/cli.nix` | Configs in chezmoi |
| `tldr` (`tealdeer`) | CLI | Nix | `modules/home/cli.nix` | Verify package name in nixpkgs |
| `delta` / `difftastic` | CLI | Nix | `modules/home/dev.nix` | |
| `gh`, `lazygit`, `neovim` | CLI | Nix | `modules/home/dev.nix` | nvim config in chezmoi |
| `shellcheck`, `shfmt` | CLI | Nix | `modules/home/dev.nix` | |
| `actionlint`, `gitleaks`, `lychee` | CLI | Nix | `modules/home/dev.nix` | verify in nixpkgs |
| `lnav`, `yazi`, `tokei`, `watchexec`, `just` | CLI | Nix | `modules/home/dev.nix` | verify in nixpkgs |
| `bats-core` | CLI | Nix | `modules/home/dev.nix` | if you test bash |
| `ripgrep-all` (`rga`) | CLI | Nix | `modules/home/dev.nix` | verify name |
| `p7zip`, `mysql-client` | CLI | Nix | `modules/home/dev.nix` | names vary |
| `mkcert`, `semgrep` | CLI | Nix or manual | check nixpkgs | |
| `mise` | Tool | nix profile | bootstrap.sh installs | Excluded from HM (chicken-egg) |
| `chezmoi` | Tool | nix profile | bootstrap.sh installs | Excluded from HM |
| `home-manager` | Tool | nix profile | bootstrap.sh installs | Excluded from HM |
| `lefthook` | Tool | nix profile | bootstrap.sh installs | Excluded from HM |
| `direnv` | Env activation | **decision required** | — | Existing docs list direnv; drop only if mise env activation covers all current use |
| PHP runtime | Runtime | mise | `home/dot_config/mise/config.toml` | Not Nix |
| Node runtime | Runtime | mise | mise config | Not Nix |
| `pnpm` | Node mgr | mise / corepack | mise config | Not Nix |
| `composer` | Runtime tool | **Nix** (`php84Packages.composer`) | `nix/modules/home/dev.nix` | On PATH on every host via `home-manager switch`; macOS Herd+1Password shell function shadows it. (Originally planned mise-owned, but mise never installed it.) |
| Ghostty (terminal) | GUI | cask (macOS), Nix or manual (Linux), DROPPED (WSL) | `modules/darwin/homebrew.nix` / `modules/home/gui.nix` | |
| Karabiner-Elements | GUI | cask | `modules/darwin/homebrew.nix` | macOS-only |
| VS Code | GUI | cask (macOS), Nix or manual (Linux), Windows-side (WSL — not managed) | varies | |
| Docker (CLI) | CLI | Nix (Linux) | `modules/home/dev.nix` | Daemon platform-specific |
| Docker Desktop / Colima | Daemon | cask (macOS), manual (Linux) | varies | |
| `stripe-cli` | CLI | check nixpkgs, else manual/cask | — | |
| BBEdit, Bruno, IntelliJ IDEA CE, Sequel Ace, BetterDisplay, AeroSpace, Firefox | macOS GUI | cask | `modules/darwin/homebrew.nix` | Populate per what you actually use |

### Verify availability
- [ ] For every Nix row: `nix search nixpkgs <name>` (or [search.nixos.org/packages](https://search.nixos.org/packages))
- [ ] Treat `nix search` results as advisory; manually verify exact Nix attribute names against nixpkgs/search.nixos.org before use
- [ ] For every cask row on macOS: `brew search --casks <name>`
- [ ] Swap any missing Nix packages to manual or cask

### Save the matrix
- [ ] Commit reviewed `repo-docs/migration-package-ownership.md` — Phase 6 reads from this
- [ ] Cross-reference the final matrix from `repo-docs/software-and-cli-tools.md` or `repo-docs/architecture/tool-ownership.md`

## Validation
- [ ] `repo-docs/migration-package-ownership.draft.md` generated by the helper
- [ ] Draft has no unresolved `TBD` markers before Phase 6 begins
- [ ] Final reviewed `repo-docs/migration-package-ownership.md` exists
- [ ] Every tool has a non-TBD owner
- [ ] Every Nix attribute name verified
- [ ] Every cask verified (on macOS)
- [ ] `direnv` explicitly decided: retained, or dropped only with evidence that mise env activation covers all current use

## Commit
```bash
git add repo-docs/migration-package-ownership.md
git commit -m "docs: package ownership matrix for chezmoi/mise/Nix/cask split"
```

---

# Phase 4 — Build chezmoi `home/` source tree

## Goal
All personal dotfiles in `home/`, owned by chezmoi. **No `.chezmoiops/` directory** — chezmoi is pure file rendering.

## Pre-flight checks
- [ ] `chezmoi --version` resolves
- [ ] Throwaway test target ready

## Actions

### Source root marker (at repo root)
```bash
echo home > .chezmoiroot
```

### Directory skeleton
```bash
mkdir -p home/.chezmoidata
mkdir -p home/dot_config/{atuin,btop,ghostty,mise,starship,nvim,karabiner}
mkdir -p home/dot_config/Code/User
mkdir -p "home/Library/Application Support/Code/User"
mkdir -p home/dot_local/bin
```

### `home/.chezmoidata/personal.yaml.example` (committed)
```yaml
name: "Your Full Name"
email: "you@example.com"
signingKey: ""
minimal: false        # true => minimal VS Code settings
useGitDelta: true
hostProfile: "linux-desktop"  # macos | linux-desktop | linux-cli | wsl
gui: true             # false on linux-cli, WSL, or other headless hosts
```

### Private `home/.chezmoidata/personal.yaml` (gitignored)
Real values. `hostProfile` and `gui` must be correct for your machine. `linux-desktop` is the primary Linux profile; `linux-cli` and `wsl` are CLI-only.

### `home/.chezmoiignore`
```
README.md
.DS_Store

{{- $hostProfile := default "linux-desktop" .hostProfile -}}
{{- $gui := default false .gui -}}

{{- if ne .chezmoi.os "darwin" }}
Library/Application Support/Code/User/**
dot_config/karabiner/**
{{- end }}

{{- if eq .chezmoi.os "darwin" }}
dot_config/Code/User/**
{{- end }}

{{- if or (eq $hostProfile "wsl") (eq $hostProfile "linux-cli") }}
dot_config/ghostty/**
{{- end }}

{{- if not $gui }}
dot_config/ghostty/**
{{- end }}
```

### Migrate per Phase 1 matrix

Shell files (parameterize identity):
```bash
cp <chosen-zshrc>    home/dot_zshrc.tmpl
cp <chosen-zprofile> home/dot_zprofile.tmpl
cp <chosen-gitconfig> home/dot_gitconfig.tmpl
```
Then in each `.tmpl`: replace email/name/signing key with `{{ .email }}`, `{{ .name }}`, `{{ .signingKey }}`.

App configs:
```bash
cp <chosen-atuin>    home/dot_config/atuin/config.toml
cp <chosen-btop>     home/dot_config/btop/btop.conf
cp <chosen-ghostty>  home/dot_config/ghostty/config.tmpl
cp <chosen-mise>     home/dot_config/mise/config.toml.tmpl
cp <chosen-starship> home/dot_config/starship/starship.toml
```

Executable:
```bash
cp <chosen-git-branch-origin> home/dot_local/bin/executable_git-branch-origin
```

Bash fallback (only if kept):
```bash
cp <chosen-bashrc> home/dot_bashrc
```

Neovim:
```bash
cp -R configs/nvim/* home/dot_config/nvim/
```

Karabiner (macOS-gated):
```bash
cp configs/karabiner/karabiner.json home/dot_config/karabiner/karabiner.json
```

VS Code — both paths in source tree:
```bash
cp configs/vscode/user/settings.json    home/dot_config/Code/User/settings.json.tmpl
cp configs/vscode/keybindings.json      home/dot_config/Code/User/keybindings.json
cp configs/vscode/user/settings.json   "home/Library/Application Support/Code/User/settings.json.tmpl"
cp configs/vscode/keybindings.json     "home/Library/Application Support/Code/User/keybindings.json"
```
Fold `settings.minimal.json` into both `settings.json.tmpl` files with `{{ if .minimal }}...{{ else }}...{{ end }}`. Then `git rm configs/vscode/user/settings.minimal.json`.

### Explicitly DO NOT create `.chezmoiops/`
All orchestration belongs in `bootstrap.sh` (cold start) and mise tasks for ongoing work: `mise run sync` previews; `mise run sync:apply` applies.

### Create helper: `ops/snapshot-home.sh`
Planned script contract:
- Before any `chezmoi apply` on a real machine, copy existing managed destination files into a timestamped recovery directory (for example under `~/.local/state/dotfiles-snapshots/<timestamp>/`).
- Snapshot only paths that chezmoi would manage or overwrite; do not collect unrelated home files.
- Print the snapshot location and a manifest of copied files.
- In apply mode, failure to create the snapshot must fail the apply path. No opt-out is added in this plan; any future opt-out needs a separate review.

Bootstrap and `sync:apply` must call this helper immediately before `chezmoi apply` once it exists.

### Create validator: `ops/validate-config.sh`
Planned architecture invariant validator. It should fail on violations of v2's active architecture only:
- Require `.chezmoiroot` at repo root and require it to point at `home`.
- Forbid `.chezmoiops/`.
- Require `home/.chezmoidata/personal.yaml.example` to be committed/present.
- Require `home/.chezmoidata/personal.yaml` to be ignored and not staged.
- Forbid Home Manager `programs.<x>.enable` except `programs.home-manager.enable = true;`.
- Forbid bootstrap-managed tools (`chezmoi`, `mise`, `home-manager`, `lefthook`) in Home Manager package modules.

The validator must **not** fail because existing Windows-native files are present, because `.husky/` still exists before separate hook cleanup approval, or because `direnv` exists before the Phase 3 decision explicitly drops it.

## Validation
- [ ] Local dry-run:
  ```bash
  chezmoi init --source="$PWD"
  chezmoi diff | less
  ```
- [ ] Template renders:
  ```bash
  chezmoi execute-template < home/dot_gitconfig.tmpl
  ```
- [ ] Linux desktop gating works (set `hostProfile: linux-desktop` in personal.yaml):
  ```bash
  chezmoi managed | grep -E '(karabiner|Library)'   # empty
  chezmoi managed | grep '.config/Code/User'        # match
  ```
- [ ] Linux CLI/headless gating works (set `hostProfile: linux-cli`, `gui: false`):
  ```bash
  chezmoi managed | grep -E '(ghostty|karabiner|Library)'   # empty
  ```
- [ ] WSL gating (set `hostProfile: wsl`):
  ```bash
  chezmoi managed | grep ghostty   # empty
  ```
- [ ] Throwaway machine test:
  ```bash
  git clone <repo> ~/test-dotfiles
  cd ~/test-dotfiles
  # create personal.yaml with your values
  chezmoi init --source="$PWD"
  chezmoi diff | less
  # Apply only after explicit confirmation of the diff:
  # chezmoi apply
  test -f ~/.zshrc && echo OK
  test -x ~/.local/bin/git-branch-origin && echo OK
  ```
- [ ] `bash ops/validate-config.sh` passes after the validator exists

## Commit
```bash
git add -A
git commit -m "feat: migrate dotfiles into chezmoi source tree (file rendering only)

- .chezmoiroot at repo root points to home/
- Per Phase 1 source-of-truth matrix
- OS + WSL + GUI gating via .chezmoiignore
- No .chezmoiops/ — orchestration in bootstrap.sh + mise sync preview/apply"
```

---

# Phase 5 — `mise.toml` with `sync` task

## Goal
Repo task surface. The default `sync` task is the day-to-day safe preview replacing the chezmoi run-scripts we removed; `sync:apply` is the explicit update command.

## Actions

Create `mise.toml` at repo root:

```toml
[tools]
php = "8.4"

[tasks.doctor]
description = "Run repo health checks"
run = "bash ops/doctor.sh"

[tasks.diff]
description = "Preview chezmoi changes"
run = "chezmoi diff"

[tasks.apply]
description = "Apply chezmoi only (no nix/mise/lefthook side effects)"
run = "chezmoi apply"

[tasks."sync:dry-run"]
description = "Preview full sync without mutating"
run = """
set -e
chezmoi diff
HOST="${HOST_PROFILE:-$(bash ops/detect-host.sh)}"
if [ "$HOST" = "macos" ]; then
  if command -v darwin-rebuild >/dev/null 2>&1; then darwin-rebuild check --flake ./nix#macos; else echo "missing: darwin-rebuild"; fi
else
  if command -v home-manager >/dev/null 2>&1; then home-manager switch --flake ./nix#$HOST --dry-run; else echo "missing: home-manager"; fi
fi
if command -v mise >/dev/null 2>&1; then mise install --dry-run || mise install --help >/dev/null; else echo "missing: mise"; fi
echo "Would run: lefthook install"
"""

[tasks."sync:apply"]
description = "Apply full sync: chezmoi apply, home-manager/darwin switch, mise install, lefthook install"
run = """
set -e
chezmoi diff
printf 'Apply full sync? [y/N] '
read -r ans
[ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "Aborted"; exit 1; }
if [ -x ops/snapshot-home.sh ]; then bash ops/snapshot-home.sh; else echo "missing: ops/snapshot-home.sh"; exit 1; fi
chezmoi apply
HOST="${HOST_PROFILE:-$(bash ops/detect-host.sh)}"
if [ "$HOST" = "macos" ]; then
  darwin-rebuild switch --flake ./nix#macos
else
  home-manager switch --flake ./nix#$HOST
fi
mise install
lefthook install
"""

[tasks.sync]
description = "Default safe sync preview (alias for sync:dry-run)"
run = "mise run sync:dry-run"

[tasks."lint:check"]
description = "Whitespace and repository lint checks"
run = "git diff --check"

[tasks."lint:shell"]
description = "Shell syntax and ShellCheck for migration scripts"
run = """
set -e
bash -n ops/bootstrap.sh ops/detect-host.sh ops/snapshot-home.sh ops/validate-config.sh ops/check-source-of-truth.sh ops/generate-package-matrix.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck ops/bootstrap.sh ops/detect-host.sh ops/snapshot-home.sh ops/validate-config.sh ops/check-source-of-truth.sh ops/generate-package-matrix.sh
else
  echo "missing: shellcheck (skip lint; install via Nix per package matrix)"
fi
"""

[tasks."repo:validate"]
description = "Validate dotfiles architecture invariants"
run = "bash ops/validate-config.sh"

[tasks.bootstrap]
description = "Cold-start: ops/bootstrap.sh"
run = "bash ops/bootstrap.sh"

[tasks."nix:check"]
description = "Validate Nix flake"
run = "nix flake check ./nix"

[tasks."nix:show"]
description = "Show flake outputs"
run = "nix flake show ./nix"

[tasks."repo:check"]
description = "Dotfiles/config consistency check"
run = """
git diff --check
bash ops/doctor.sh
bash ops/validate-config.sh
if command -v nix >/dev/null 2>&1; then nix flake check ./nix; else echo "missing: nix (skip flake check)"; fi
"""

# Optional, out-of-scope for the config architecture migration unless AI files are edited:
# [tasks."ai:test:php"]
# description = "Run repo AI/PHP tests"
# run = "vendor/bin/phpunit tests/php || phpunit tests/php"
#
# [tasks."ai:repo:structure"]
# description = "Regenerate AI repo structure doc"
# run = "php tools/ai/generate-repo-structure.php"
```

## Validation
- [ ] `mise tasks` lists all tasks
- [ ] `mise run doctor` succeeds
- [ ] `mise run lint:check` succeeds
- [ ] `mise run lint:shell` succeeds, or records ShellCheck unavailable only before Nix package setup
- [ ] `mise run repo:validate` succeeds after `ops/validate-config.sh` exists
- [ ] `mise install` installs PHP 8.4
- [ ] `mise run sync` previews only and does not mutate
- [ ] `mise run sync:apply` asks before applying
- [ ] `mise run sync:apply` snapshots managed home files before `chezmoi apply`

## Commit
```bash
git add mise.toml
git commit -m "feat: mise tasks (incl. sync) for repo workflows"
```

---

# Phase 6 — Nix flake + modular Home Manager

## Goal
Declarative pinned package layer per host profile. Populated from Phase 3 matrix.

## Pre-flight checks
- [ ] `nix --version` ≥ 2.18
- [ ] `repo-docs/migration-package-ownership.md` complete

## Actions

### Skeleton
```bash
mkdir -p nix/{vars,lib,overlays}
mkdir -p nix/hosts/{linux-desktop,linux-cli,wsl,macos}
mkdir -p nix/modules/{common,home,darwin}
```

### `nix/vars/default.nix`
```nix
{
  username = "REPLACE_ME";
  email    = "REPLACE_ME";

  profiles = {
    linux-desktop = {
      system        = "x86_64-linux";
      homeDirectory = "/home/REPLACE_ME";
      stateVersion  = "24.11";
    };
    linux-cli = {
      system        = "x86_64-linux";
      homeDirectory = "/home/REPLACE_ME";
      stateVersion  = "24.11";
    };
    wsl = {
      system        = "x86_64-linux";
      homeDirectory = "/home/REPLACE_ME";
      stateVersion  = "24.11";
    };
    macos = {
      system        = "aarch64-darwin";  # x86_64-darwin for Intel
      homeDirectory = "/Users/REPLACE_ME";
      stateVersion  = "24.11";
    };
  };
}
```

### `nix/lib/mkhome.nix`
```nix
{ inputs }:

{ system, username, homeDirectory, stateVersion, modules, extraSpecialArgs ? {} }:

let
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ (import ../overlays) ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = modules ++ [
    {
      home = { inherit username homeDirectory stateVersion; };
      programs.home-manager.enable = true;  # ONLY allowed programs.<x>.enable
    }
  ];
  extraSpecialArgs = extraSpecialArgs // { inherit inputs username; };
}
```

### `nix/overlays/default.nix`
```nix
final: prev: { }
```

### `nix/modules/common/nix-settings.nix`
```nix
{ ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
  };
}
```

### `nix/modules/common/packages.nix`
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    curl
    wget
    git
    unzip
    xz
    cacert
  ];
}
```

### `nix/modules/common/default.nix`
```nix
{ imports = [ ./packages.nix ]; }
```

### `nix/modules/home/cli.nix`
Populate from Phase 3 matrix. Example:
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    atuin
    bat
    btop
    eza
    fd
    fzf
    jq
    yq
    ripgrep
    starship
    tmux
    zoxide
    # add per matrix
  ];
}
```

### `nix/modules/home/dev.nix`
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    delta
    gh
    lazygit
    neovim
    shellcheck
    shfmt
    # NB: direnv decision required; include only if mise activation does not cover current use
    # NB: NO mise, chezmoi, home-manager, lefthook (nix profile in bootstrap)
  ];
}
```

### `nix/modules/home/shell-packages.nix`
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
  ];
}
```

### `nix/modules/home/gui.nix`
Conservative; populate from matrix. Linux desktop / macOS hosts only.
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ghostty   # uncomment when verified for your system
  ];
}
```

### `nix/modules/home/default.nix`
```nix
{
  imports = [
    ./cli.nix
    ./dev.nix
    ./shell-packages.nix
    # gui.nix NOT here; hosts import directly
  ];
}
```

### `nix/hosts/linux-desktop/home.nix`
```nix
{
  imports = [
    ../../modules/common
    ../../modules/home
    ../../modules/home/gui.nix
  ];
}
```

### `nix/hosts/wsl/home.nix`
```nix
{
  imports = [
    ../../modules/common
    ../../modules/home
    # No GUI on WSL
  ];
}
```

### `nix/hosts/macos/home.nix`
```nix
{
  imports = [
    ../../modules/common
    ../../modules/home
    ../../modules/home/gui.nix
  ];
}
```

### `nix/hosts/linux-cli/home.nix`
```nix
{
  imports = [
    ../../modules/common
    ../../modules/home
    # No GUI on CLI/headless hosts
  ];
}
```

### `nix/hosts/macos/darwin.nix` (stub)
```nix
{ pkgs, vars, ... }:
{
  system.stateVersion = 5;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  users.users.${vars.username}.home = vars.profiles.macos.homeDirectory;
  imports = [ ../../modules/darwin ];
}
```

### Stubs for Phase 8
```nix
# nix/modules/darwin/default.nix
{ imports = [ ./system-defaults.nix ]; }
```
```nix
# nix/modules/darwin/system-defaults.nix
{ ... }: { }
```

### `nix/flake.nix`
```nix
{
  description = "Personal dev environment for macOS, Linux, and WSL2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-darwin, ... }:
    let
      vars   = import ./vars/default.nix;
      mkHome = import ./lib/mkhome.nix { inherit inputs; };

      mkProfile = name:
        let p = vars.profiles.${name};
        in mkHome {
          inherit (p) system homeDirectory stateVersion;
          username = vars.username;
          modules  = [ ./hosts/${name}/home.nix ];
        };
    in
    {
      homeConfigurations = {
        linux-desktop = mkProfile "linux-desktop";
        linux-cli     = mkProfile "linux-cli";
        wsl           = mkProfile "wsl";
        macos         = mkProfile "macos";
      };

      darwinConfigurations.macos = nix-darwin.lib.darwinSystem {
        system      = vars.profiles.macos.system;
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/macos/darwin.nix
          home-manager.darwinModules.home-manager
          {
            users.users.${vars.username}.home = vars.profiles.macos.homeDirectory;
            home-manager.useGlobalPkgs    = true;
            home-manager.useUserPackages  = true;
            home-manager.users.${vars.username} = import ./hosts/macos/home.nix;
          }
        ];
      };
    };
}
```

## Validation
- [ ] `nix flake check ./nix` passes
- [ ] `nix flake show ./nix` lists `homeConfigurations.{linux-desktop,linux-cli,wsl,macos}` + `darwinConfigurations.macos`
- [ ] Dry runs:
  ```bash
  home-manager switch --flake ./nix#linux-desktop --dry-run
  home-manager switch --flake ./nix#linux-cli     --dry-run
  home-manager switch --flake ./nix#wsl           --dry-run
  ```
- [ ] Real switch on primary host: `which ripgrep` resolves to Nix store
- [ ] `chezmoi diff` shows zero conflicts

## Rollback
```bash
home-manager generations
# pick a previous gen and activate it
```

## Commit
```bash
git add nix/
git commit -m "feat: Nix flake + modular Home Manager per host profile

- vars + lib + hosts + modules pattern
- linux-cli and WSL exclude GUI module
- home.packages only; mise/chezmoi/home-manager/lefthook excluded"
```

Follow-up:
```bash
# Defer deletion until package matrix parity and real-host validation are complete.
# Keep repo-docs/install-dev-tools.sh as a legacy/macOS reference unless deletion is approved later.
# git rm repo-docs/install-dev-tools.sh
# git commit -m "chore: remove legacy install script after Nix parity validation"
```

---

# Phase 7 — Bootstrap with safety flags

## Goal
One command cold-starts a new machine. **Default `--dry-run`. `--yes` required for mutations.**

## Actions

### `ops/detect-host.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)" in
  Darwin) echo "macos" ;;
  Linux)
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
      echo "wsl"
    else
      echo "${HOST_PROFILE_DEFAULT:-linux-desktop}"
    fi
    ;;
  *) echo "unsupported" >&2; exit 1 ;;
esac
```
```bash
chmod +x ops/detect-host.sh
```

### `ops/bootstrap.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-dry-run}"

for arg in "$@"; do
  case "$arg" in
    --dry-run)     MODE="dry-run" ;;
    --yes|--apply) MODE="apply" ;;
    --help|-h)
      cat <<EOF
Usage: ops/bootstrap.sh [--dry-run|--yes]

  --dry-run   Check only, install nothing (default)
  --yes       Actually install and apply

Env:
  HOST_PROFILE   Override host detection (macos|linux-desktop|linux-cli|wsl)
  HOST_PROFILE_DEFAULT  Linux non-WSL fallback (linux-desktop default; set linux-cli for headless)
  CI=true        Allow non-interactive apply mode
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

log()  { printf '[bootstrap:%s] %s\n' "$MODE" "$*"; }
fail() { printf '[bootstrap:error] %s\n' "$*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/ops/detect-host.sh")}"

log "Repo: $REPO_ROOT"
log "Host: $HOST_PROFILE"

case "$HOST_PROFILE" in
  macos|linux-desktop|linux-cli|wsl) ;;
  unsupported) fail "Unsupported OS" ;;
  *) fail "Unsupported HOST_PROFILE: $HOST_PROFILE" ;;
esac

for cmd in git bash curl; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
done

# --- Nix ---
if ! command -v nix >/dev/null 2>&1; then
  if [ "$MODE" = "dry-run" ]; then
    log "Would install Nix (Determinate Systems)"
  else
    log "Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L \
      https://install.determinate.systems/nix | sh -s -- install --no-confirm
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
else
  log "Nix: $(nix --version)"
fi

have_nix=false
command -v nix >/dev/null 2>&1 && have_nix=true

# --- Base tools via nix profile ---
if [ "$MODE" = "dry-run" ]; then
  if [ "$have_nix" = true ]; then
    log "Would: nix profile install chezmoi mise home-manager lefthook"
  else
    log "Missing nix: would install Nix first, then install chezmoi mise home-manager lefthook"
  fi
else
  log "Installing base tools via nix profile..."
  nix profile install \
    nixpkgs#chezmoi \
    nixpkgs#mise \
    nixpkgs#home-manager \
    nixpkgs#lefthook
  # Refresh PATH for the current process after nix profile install.
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
  [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh || true
  for cmd in chezmoi mise home-manager lefthook; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Missing after nix profile install: $cmd"
  done
fi

# --- Validate flake ---
if [ "$have_nix" = true ]; then
  log "Validating flake..."
  nix flake check "$REPO_ROOT/nix"
else
  log "Skipping flake validation: nix missing (would install in apply mode)"
fi

# --- Chezmoi ---
if command -v chezmoi >/dev/null 2>&1; then
  log "chezmoi init..."
  chezmoi init --source="$REPO_ROOT"

  log "Preview chezmoi changes:"
  chezmoi diff
else
  [ "$MODE" = "dry-run" ] && log "Missing chezmoi: would install before init/diff/apply" || fail "chezmoi missing after base tool install"
fi

if [ "$MODE" = "dry-run" ]; then
  log "Would: chezmoi apply"
else
  if [ -z "${CI:-}" ] && [ -t 0 ]; then
    read -rp "Apply chezmoi changes? [y/N] " ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || fail "Aborted"
  fi
  [ -x "$REPO_ROOT/ops/snapshot-home.sh" ] || fail "Missing executable snapshot helper: ops/snapshot-home.sh"
  bash "$REPO_ROOT/ops/snapshot-home.sh"
  chezmoi apply
fi

# --- Home Manager / nix-darwin ---
if [ "$HOST_PROFILE" = "macos" ]; then
  SWITCH_CMD="darwin-rebuild switch --flake $REPO_ROOT/nix#macos"
else
  SWITCH_CMD="home-manager switch --flake $REPO_ROOT/nix#$HOST_PROFILE"
fi

if [ "$MODE" = "dry-run" ]; then
  log "Would: $SWITCH_CMD"
  if [ "$HOST_PROFILE" = "macos" ]; then
    command -v darwin-rebuild >/dev/null 2>&1 && darwin-rebuild check --flake "$REPO_ROOT/nix#macos" || log "Missing darwin-rebuild: would install/use after Nix setup"
  else
    command -v home-manager >/dev/null 2>&1 && home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE" --dry-run || log "Missing home-manager: would install via nix profile"
  fi
else
  log "Running: $SWITCH_CMD"
  [ "$HOST_PROFILE" != "macos" ] || command -v darwin-rebuild >/dev/null 2>&1 || fail "darwin-rebuild missing; complete nix-darwin setup before macOS apply"
  $SWITCH_CMD
fi

# --- mise ---
if [ "$MODE" = "dry-run" ]; then
  command -v mise >/dev/null 2>&1 && log "Would: mise trust + install" || log "Missing mise: would install via nix profile"
else
  mise trust "$REPO_ROOT"
  mise install
fi

# --- Lefthook ---
if [ -d "$REPO_ROOT/.git" ]; then
  if [ "$MODE" = "dry-run" ]; then
    command -v lefthook >/dev/null 2>&1 && log "Would: lefthook install" || log "Missing lefthook: would install via nix profile"
  else
    (cd "$REPO_ROOT" && lefthook install)
  fi
fi

# --- SSH agent (Unix non-WSL) ---
if [ "$HOST_PROFILE" != "wsl" ] && [ -x "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" ]; then
  if [ "$MODE" = "dry-run" ]; then
    log "Would: ops/unix/ssh-agent-setup.sh"
  else
    bash "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" || true
  fi
fi

# --- Doctor ---
if [ -x "$REPO_ROOT/ops/doctor.sh" ]; then
  log "Running doctor..."
  bash "$REPO_ROOT/ops/doctor.sh"
else
  log "Doctor skipped: ops/doctor.sh missing or not executable"
fi

log "Done. Mode: $MODE"
[ "$MODE" = "dry-run" ] && log "Re-run with --yes to apply"
```
```bash
chmod +x ops/bootstrap.sh
```

## Validation
- [ ] Shell syntax passes:
  ```bash
  bash -n ops/bootstrap.sh ops/detect-host.sh ops/snapshot-home.sh ops/validate-config.sh
  ```
- [ ] ShellCheck passes once available:
  ```bash
  shellcheck ops/bootstrap.sh ops/detect-host.sh ops/snapshot-home.sh ops/validate-config.sh
  ```
- [ ] Dry-run on your current machine (default — must mutate nothing):
  ```bash
  bash ops/bootstrap.sh
  ```
- [ ] Apply on throwaway VM/WSL:
  ```bash
  HOST_PROFILE=wsl bash ops/bootstrap.sh --yes
  ```
- [ ] Verify post-apply:
  ```bash
  command -v chezmoi
  command -v mise
  command -v home-manager
  command -v lefthook
  which ripgrep
  test -f ~/.zshrc
  mise --version
  ```
- [ ] Snapshot was created before `chezmoi apply` and the apply failed if snapshot creation failed
- [ ] Idempotency dry-run after apply reports no pending mutations; run this as a validation step, not as a recursive self-call inside bootstrap:
  ```bash
  bash ops/bootstrap.sh --dry-run
  mise run sync
  ```

## Rollback
- Throwaway: trash
- Real: `home-manager generations` / `darwin-rebuild --rollback`

## Commit
```bash
git add ops/bootstrap.sh ops/detect-host.sh
git commit -m "feat: bootstrap.sh with --dry-run default and --yes opt-in

- Zero mutations without explicit --yes
- Interactive confirmation unless CI=true
- Host detection (macos|linux-desktop|linux-cli|wsl)
- SSH agent setup skipped on WSL (Windows-side concern)"
```

---

# Phase 8 — nix-darwin + Homebrew casks (macOS)

## Goal
macOS system defaults declaratively; GUI apps via Homebrew casks bridged through nix-darwin.

## Prerequisites
Phase 7 complete. Active Mac in scope. Skip if no Mac.

## Actions

### Populate `nix/modules/darwin/system-defaults.nix`
```nix
{ ... }:
{
  system.defaults = {
    dock = {
      autohide     = true;
      show-recents = false;
      tilesize     = 48;
    };
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles      = true;
      FXPreferredViewStyle   = "Nlsv";
      ShowPathbar            = true;
      ShowStatusBar          = true;
    };
    NSGlobalDomain = {
      ApplePressAndHoldEnabled              = false;
      KeyRepeat                             = 2;
      InitialKeyRepeat                      = 15;
      NSAutomaticCapitalizationEnabled      = false;
      NSAutomaticDashSubstitutionEnabled    = false;
      NSAutomaticQuoteSubstitutionEnabled   = false;
      NSAutomaticSpellingCorrectionEnabled  = false;
    };
    trackpad = {
      Clicking                = true;
      TrackpadThreeFingerDrag = true;
    };
    screencapture = {
      location = "~/Pictures/Screenshots";
      type     = "png";
    };
  };
}
```

### Create `nix/modules/darwin/homebrew.nix`
Populate cask list from Phase 3 matrix:
```nix
{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup    = "zap";
    };

    casks = [
      # Populate from your matrix. Examples:
      # "ghostty"
      # "karabiner-elements"
      # "visual-studio-code"
      # "bruno"
      # "sequel-ace"
      # "betterdisplay"
      # "aerospace"
    ];

    brews = [
      # macOS-only formulae not in Nix, e.g.:
      # "colima"
    ];
  };
}
```

### Update `nix/modules/darwin/default.nix`
```nix
{
  imports = [
    ./system-defaults.nix
    ./homebrew.nix
  ];
}
```

## Validation
- [ ] `nix flake check ./nix` passes
- [ ] `darwin-rebuild check --flake ./nix#macos` passes
- [ ] Apply: `darwin-rebuild switch --flake ./nix#macos`
- [ ] Verify:
  ```bash
  defaults read com.apple.dock autohide       # 1
  defaults read com.apple.finder ShowPathbar  # 1
  brew list --casks
  ```

## Rollback
```bash
darwin-rebuild --rollback
```

## Commit
```bash
git add nix/modules/darwin nix/hosts/macos/darwin.nix
git commit -m "feat: nix-darwin with system defaults and Homebrew cask bridge

- system defaults: dock, finder, keyboard, trackpad, screenshots
- Casks per matrix (Phase 3)
- macOS GUI via cask (not Nix)"
```

---

# Phase 9 — Documentation

## Goal
Repo self-documents. WSL2 caveats explicitly listed.

## Actions

### `repo-docs/architecture/tool-ownership.md`
Codify the rules from this plan's "Architecture summary" section. Explicitly state:
- chezmoi renders files only (no orchestration)
- Home Manager: `home.packages` only, one exception (`programs.home-manager.enable`)
- mise: runtimes + tasks; `direnv` retained or dropped only after the Phase 3 decision proves mise env activation covers current use
- nix-darwin: macOS system defaults + cask bridge
- bootstrap.sh: cold start once; `mise run sync` previews updates; `mise run sync:apply` applies updates
- Dependency update procedure: update `nix/flake.lock` separately from package-owner changes, verify exact Nix/cask names against the Phase 3 matrix, run `nix flake check ./nix`, then preview with `mise run sync` before `mise run sync:apply`.

### `repo-docs/bootstrap.md`
Cold-start procedure + per-OS notes.

**Secrets handling guidance (mandatory):**
- Real `home/.chezmoidata/personal.yaml` stays gitignored and must never be committed.
- `personal.yaml.example` documents required keys with fake values only.
- Host-specific secrets, SSH keys, signing keys, tokens, and machine-local paths are entered manually or managed by a separate approved secret workflow; this migration does not introduce secret distribution.
- Lefthook must block staged `home/.chezmoidata/personal.yaml`.

**WSL2 caveats section (mandatory):**
- Windows VS Code (Remote-WSL) reads settings from Windows side. Not managed by this repo.
- Windows SSH agent bridge: set up `wsl2-ssh-agent` manually if you want Windows-side keys. Not in scope.
- Windows Terminal config: out of scope (manage on Windows side if needed).
- Windows package managers: out of scope.
- Clipboard: use `clip.exe` from shell or rely on terminal integration. No automation here.
- Keep working repos in `~/` not `/mnt/c/` for filesystem perf.
- WSL detection in bootstrap is by `/proc/version` grep — override with `HOST_PROFILE=wsl` if needed.

### Update existing docs
- [ ] `repo-docs/README.md` — index
- [ ] `repo-docs/shell-setup.md` — chezmoi paths
- [ ] `repo-docs/nvim-setup.md` — chezmoi paths
- [ ] `repo-docs/software-and-cli-tools.md` — refer to matrix
- [ ] `repo-docs/vscode-extensions.md` — note manual install or future `mise run sync` extension
- [ ] `repo-docs/keyboard.md` — karabiner via chezmoi (macOS-gated)
- [ ] Root `README.md` — new stack summary
- [ ] `CONTRIBUTING.md` — Lefthook as intended hook runner; note `.husky/` remains until separate hook cleanup is approved, if applicable

### `ops/uninstall.sh` recovery helper
Add a small recovery/handoff utility that documents and optionally performs safe local cleanup steps:
- Print current Home Manager generations / nix-darwin rollback hints.
- Print snapshot locations created by `ops/snapshot-home.sh`.
- Offer explicit, reviewed commands for removing Lefthook hooks and local profiles if the user is abandoning the migration.
- Do not delete user data by default.

### Lefthook planned guards
- Block commits that stage `home/.chezmoidata/personal.yaml`.
- Optionally add pre-push `bash ops/validate-config.sh` after `ops/validate-config.sh` exists.
- Keep `.husky/` until separate hook cleanup is approved and Lefthook is installed/working.

### Optional/deferred CI workflow
CI is optional/deferred because this repository already has AI workflows and a config-only migration should not introduce conflicting CI without review. If enabled in a separate reviewed slice, keep it limited to:
- shell syntax/lint for migration scripts
- `bash ops/validate-config.sh`
- `nix flake check ./nix` only when `nix/` exists and Nix is available in the runner
- `bash ops/bootstrap.sh --dry-run`

PHP tests remain optional/out-of-scope unless AI/PHP workflow files are edited.

### Regenerate inventory
```bash
# Optional AI/repo inventory only; out of scope for config architecture unless AI docs are edited:
# mise run ai:repo:structure
```

## Validation
- [ ] All linked files exist
- [ ] Markdown links/commands referenced in changed dotfiles docs are accurate
- [ ] Repo AI/PHP tests are optional/out of scope unless this phase edits those surfaces
- [ ] Secrets handling and dependency update procedure are documented
- [ ] `ops/uninstall.sh` exists and defaults to non-destructive recovery guidance
- [ ] Lefthook blocks staged `home/.chezmoidata/personal.yaml`; optional pre-push validator runs only after the script exists
- [ ] Fresh-clone walkthrough of `repo-docs/bootstrap.md` succeeds on a VM (without you intervening)

## Commit
```bash
git add -A
git commit -m "docs: tool-ownership, bootstrap with WSL caveats, refresh structure"
```

---

# Phase 10 — Legacy cleanup

## Goal
Delete migrated source folders. Only after every primary host is proven. Legacy cleanup stays gated and may intentionally retain reference docs/scripts.

## Prerequisites
- Phases 1–9 complete
- Bootstrap end-to-end tested on primary host
- Phase 8 done (or explicitly deferred until Mac is available)
- Optional/final gate considered: `ops/test-bootstrap-docker.sh` fresh Ubuntu dry-run validation. Full apply in Docker/VM is opt-in only.

## Pre-flight checks
- [ ] Every `backup-sanitized/home/` file has a counterpart in `home/`
- [ ] `configs/` empty (or only README)
- [ ] `repo-docs/install-dev-tools.sh` either migrated and approved for deletion, or intentionally retained as a macOS/legacy reference
- [ ] `chezmoi diff` empty
- [ ] `nix flake check ./nix` passes
- [ ] `bash ops/test-bootstrap-docker.sh --dry-run` passes, or is explicitly skipped with a recorded reason (for example Docker unavailable)

## Optional helper: `ops/test-bootstrap-docker.sh`
Planned script contract:
- Build/run a fresh Ubuntu container, install only dry-run prerequisites, clone/mount the repo, and execute `bash ops/bootstrap.sh --dry-run`.
- Validate bootstrap safety and missing-tool messages without mutating the host.
- Full apply testing must be explicitly opt-in and is not required before deletion unless separately approved.

## Actions
```bash
git rm -r backup-sanitized
git rm -r configs
# Optional only if Phase 3 matrix parity + real-host validation prove it obsolete and deletion is approved:
# git rm repo-docs/install-dev-tools.sh
```

## Validation
- [ ] Final tree matches end-state
- [ ] Fresh-clone bootstrap on VM still works
- [ ] Docker fresh-Ubuntu dry-run passes or skip reason is recorded
- [ ] `mise run repo:check` passes

## Commit
```bash
git add -A
git commit -m "chore: remove migrated legacy source folders"
```

---

# Cross-OS validation matrix

| Check | macOS | Linux desktop | Linux CLI | WSL2 |
|-------|:-----:|:-------------:|:---------:|:----:|
| `bash ops/detect-host.sh` returns correct profile | ✅ | ✅ | override/`HOST_PROFILE_DEFAULT=linux-cli` | ✅ |
| `nix flake check ./nix` passes | ✅ | ✅ | ✅ | ✅ best-effort |
| `nix flake show ./nix` lists expected configs | ✅ | ✅ | ✅ | ✅ |
| `home-manager switch --flake ./nix#<host> --dry-run` | (use darwin-rebuild) | ✅ `linux-desktop` | ✅ `linux-cli` | ✅ `wsl` |
| `which ripgrep` resolves to Nix store | ✅ | ✅ | ✅ | ✅ |
| `chezmoi diff` zero conflicts | ✅ | ✅ | ✅ | ✅ |
| `~/.zshrc` exists, identity rendered | ✅ | ✅ | ✅ | ✅ |
| `~/Library/Application Support/Code/User/settings.json` | ✅ | ❌ gated | ❌ gated | ❌ gated |
| `~/.config/Code/User/settings.json` | ❌ gated | ✅ | optional/manual | ✅ (server only) |
| `~/.config/karabiner/karabiner.json` | ✅ | ❌ gated | ❌ gated | ❌ gated |
| `~/.config/ghostty/config` | ✅ | ✅ | ❌ gated | ❌ gated |
| `mise install` succeeds | ✅ | ✅ | ✅ | ✅ |
| `php --version` reports 8.4 | ✅ | ✅ | ✅ | ✅ |
| `defaults read com.apple.dock autohide` matches | ✅ Phase 8 | n/a | n/a | n/a |
| Homebrew casks installed | ✅ Phase 8 | n/a | n/a | n/a |
| `bash ops/bootstrap.sh` (dry-run) reports no pending changes after `--yes` already ran | ✅ | ✅ | ✅ | ✅ |
| `mise run sync` previews only; `mise run sync:apply` applies after confirmation | ✅ | ✅ | ✅ | ✅ |

---

# Common troubleshooting

## chezmoi
- **"unresolved template variable"** — check `home/.chezmoidata/personal.yaml`; run `chezmoi data` to inspect
- **macOS files on Linux** — `.chezmoiignore` gating broken; check `eq .chezmoi.os "darwin"`
- **WSL with ghostty applied** — check `hostProfile: wsl` is in personal.yaml; default in `.chezmoiignore` is `linux-desktop`

## Nix
- **`nix flake check` fails on missing input** — `nix flake update ./nix`
- **`home-manager switch` says file conflict** — a `programs.<x>.enable` is generating a chezmoi-managed file; remove the enable, use `home.packages` instead
- **Wrong macOS arch** — fix `vars/default.nix`

## mise
- **`mise install` does nothing** — `mise trust .` first
- **PHP not on PATH** — ensure `eval "$(mise activate zsh)"` in `~/.zshrc`

## WSL2
- **Bootstrap missing `curl`** — `sudo apt update && sudo apt install -y curl ca-certificates`
- **Slow git** — move repo from `/mnt/c/` to `~/`
- **Windows VS Code settings ignored** — expected; WSL repo manages WSL/server-side only
- **`detect-host.sh` returned `linux` not `wsl`** — set `HOST_PROFILE=wsl` env or update `/proc/version` detection

## Lefthook
- **Hooks not firing** — `lefthook install`; bootstrap with `--yes` does this

---

# Implementation sequence

1. **Day 1:** Phases 0, 1, 2 (audit + source selection + cleanup — same sitting)
2. **Day 2:** Phase 3 (package matrix — couple hours)
3. **Day 3:** Phases 4, 5 (chezmoi tree + mise — half day)
4. **Weekend:** Phase 6 (Nix flake — focused)
5. **Day after:** Phase 7 (bootstrap; validate on throwaway VM)
6. **When on Mac:** Phase 8
7. **Day after Phase 7 passes:** Phase 9 (docs)
8. **A week after primary host validated:** Phase 10 (legacy delete)

Don't compress. Validation between phases on real machines.

---

# Definition of done

- [ ] Cross-OS matrix passes on primary host
- [ ] Fresh clone + `bash ops/bootstrap.sh --yes` succeeds on a clean VM
- [ ] `chezmoi diff` empty
- [ ] `nix flake check ./nix` passes
- [ ] `bash ops/validate-config.sh` and `mise run repo:validate` pass
- [ ] `mise run lint:check` and `mise run lint:shell` pass
- [ ] `ops/test-bootstrap-docker.sh --dry-run` passes, or Docker validation is explicitly skipped with a recorded reason
- [ ] CI/config validation is green if optional CI was enabled
- [ ] `mise run repo:check` passes
- [ ] `mise run sync` is a clean preview and never mutates; `mise run sync:apply` is idempotent after a clean preview (running twice in a row makes no changes)
- [ ] `home/.chezmoidata/personal.yaml` is ignored and blocked by Lefthook from being staged
- [ ] `repo-docs/bootstrap.md` and/or `repo-docs/architecture/tool-ownership.md` include secrets handling and dependency update procedure
- [ ] `ops/doctor.sh` reflects the new tree and passes
- [ ] `backup-sanitized/` and `configs/` deleted
- [ ] `repo-docs/architecture/tool-ownership.md` accurate
- [ ] `repo-docs/bootstrap.md` includes WSL2 caveats section
- [ ] No `.chezmoiops/` directory exists
- [ ] `repo-docs/migration-source-of-truth.md` and `repo-docs/migration-package-ownership.md` committed as audit trail

When all boxes ticked, merge to `main` and run `bash ops/bootstrap.sh --yes` on each real machine, then run `mise run sync` as a preview and `mise run sync:apply` only if needed.

---

# Appendix A: scope explicitly excluded

Out of scope for this repo, won't be added under this architecture:

- Windows native management (PowerShell automation, Windows package managers, Windows Terminal). Existing native Windows docs/scripts are left untouched unless a separate cleanup is approved.
- Windows-side VS Code settings management
- Windows SSH agent bridging
- WSL clipboard automation beyond what shells/tmux provide natively
- Server-specific Linux management beyond the CLI-only `linux-cli` profile
- Multi-machine secret distribution (chezmoi's age/gpg integration is available if needed, kept separate)
- Project-scoped configs (Pint, ESLint, project `launch.json`, etc. — those belong in project repos)

# Appendix B: ongoing workflow (after migration)

Day-to-day, after the migration is done:

```bash
# Edit a dotfile in the repo
$EDITOR home/dot_zshrc.tmpl

# Preview
mise run diff

# Apply just the dotfile change (no nix/mise side effects)
mise run apply

# Preview everything (default safe sync)
mise run sync

# Apply everything (dotfile + nix packages + mise runtimes + hooks) after prompt
mise run sync:apply
```

When adding a new CLI tool:
```bash
$EDITOR nix/modules/home/cli.nix      # add to home.packages
mise run nix:check                    # validate flake
mise run sync                         # preview
mise run sync:apply                   # apply after confirmation
```

When adding a new macOS GUI app:
```bash
$EDITOR nix/modules/darwin/homebrew.nix   # add cask
mise run nix:check
darwin-rebuild switch --flake ./nix#macos
```

No more raw `chezmoi apply` followed by manually remembering to run `home-manager switch`. `mise run sync` is the single safe preview verb; `mise run sync:apply` is the explicit mutating verb.
