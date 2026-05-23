I'll create this as a markdown document you can save, commit to the repo, and check off as you go. Long-form working reference rather than chat output.1,694 lines. Save it as `docs/implementation-plan.md` in the repo if you want it version-controlled alongside the migration; otherwise keep it as a working document outside the repo and delete it when the migration is done.

**What's in the file:**

- **Architecture summary** with the strict tool-ownership rules at the top so you don't have to scroll back
- **Pre-flight decisions** (4 things to resolve before you touch anything): bash usage, `personal.yaml` privacy, macOS architecture, primary host profile
- **Time estimates and risk levels** per phase
- **Eight phases** (0 through 8), each with: Goal, Prerequisites, Pre-flight checks, Actions (every step as a checkbox), Validation (concrete commands to confirm it worked), Rollback procedure, Commit message
- **Full file contents** for the non-obvious files: `.chezmoiroot`, `.chezmoiignore`, all four `.chezmoiscripts/*.sh.tmpl`, `nix/vars/default.nix`, `nix/lib/mkhome.nix`, `nix/flake.nix`, every Nix module stub, `mise.toml`, `scripts/detect-host.sh`, `scripts/bootstrap.sh`
- **Cross-OS validation matrix** — table of every check with expected pass/fail per OS, so you know when you're actually done
- **Final repo tree** in full
- **Troubleshooting section** for chezmoi, Nix, mise, WSL2, and Lefthook with the specific failure modes you're likely to hit
- **Implementation sequence** with calendar suggestions (not all on one day — each phase needs real validation between)
- **Definition of done** at the end — a checklist for "is this actually finished"

**Three things worth flagging explicitly:**

1. The four pre-flight decisions at the top are real blockers. Resolve them in writing before Phase 0 or you'll hit them mid-Phase 2 and lose flow.

2. Phase 4 (Nix flake) genuinely needs a focused weekend, not evenings. The `mkhome.nix` parameterization and the standalone-HM-vs-nix-darwin distinction will eat time the first time through.

3. Phase 8 (legacy cleanup) deliberately comes last and is gated on "tested on every machine you actually use." The `backup-sanitized/` and `configs/` folders are your safety net — don't delete them until the new setup has run on real hardware, not just throwaway VMs.

When you start Phase 0, work through the file linearly and tick boxes as you go. If something doesn't match reality (file name, path, command), update the document — it's a working artefact, not a frozen spec.

# Dotfiles Migration — Implementation Plan

A phased, checkboxed working document for migrating the dotfiles repo to a `chezmoi + mise + Nix/Home Manager + nix-darwin + Lefthook` stack targeting Linux, macOS, and WSL2.

Each phase is independently shippable. You can pause at any phase boundary and the repo remains coherent.

---

## Architecture summary

| Tool | Owns | Never owns |
|------|------|-----------|
| chezmoi | All dotfiles in `~` and `~/.config/`, run-once bootstrap scripts | Packages, services |
| mise | Language runtimes, CLI tool versions, per-project env vars, repo tasks | OS package installation |
| Nix + Home Manager | User-installed packages via `home.packages` only | Files chezmoi configures |
| nix-darwin | macOS system defaults, optional Homebrew cask bridge | Linux/WSL config |
| Lefthook | Git hooks | Anything outside git lifecycle |

**Hard rules:**
- `.chezmoiroot` at repo root, containing `home`
- Home Manager uses `home.packages = [ ... ]` only; `programs.<x>.enable` is forbidden except `programs.home-manager.enable = true`
- Windows native is NOT supported; WSL2 IS supported as a Linux-flavoured host
- Each phase commits independently and can be merged separately

---

## Pre-flight decisions (resolve before Phase 0)

- [ ] **Bash usage:** Do you launch bash on any current or future machine? If only zsh, plan to delete `backup-sanitized/home/.bashrc` in Phase 1. If yes, plan to keep `home/dot_bashrc` as a minimal fallback in Phase 2.
- [ ] **`personal.yaml` privacy:** Will real values (name, email, signing key) be committed to the repo, or kept in a gitignored `personal.yaml` with only `personal.yaml.example` committed?  Recommended: example + gitignore the real file.
- [ ] **macOS architecture:** If you have or plan to use a Mac, is it Apple Silicon (`aarch64-darwin`) or Intel (`x86_64-darwin`)? Sets the value in `nix/vars/default.nix`.
- [ ] **Primary host profile:** What's your day-to-day machine right now? (`linux` / `wsl` / `macos`). Drives the first end-to-end test target.

---

## Time estimates

| Phase | Effort | Risk |
|------:|--------|------|
| 0 — Branch & baseline | 15–30 min | Negligible |
| 1 — Cleanup | 30–60 min | Low (deletions only, git rollback) |
| 2 — chezmoi `home/` tree | 2–4 hours | Medium (need throwaway VM test) |
| 3 — `mise.toml` | 15 min | Negligible |
| 4 — Nix flake + Home Manager | Weekend (8–12 h focused) | Medium-High (Nix learning curve) |
| 5 — Bootstrap script | 1–2 hours | Low |
| 6 — nix-darwin | 2–4 hours (when on Mac) | Low (system-defaults are reversible) |
| 7 — Documentation | 1–2 hours | Negligible |
| 8 — Final cleanup | 30 min | Low (only after everything proven) |

Total: roughly 3–4 working days of focus, spread across 2–4 calendar weeks.

---

## Per-phase template

Every phase below follows this structure:

```
Goal              — one-sentence outcome
Prerequisites     — what must be done first
Pre-flight checks — verify safe to start
Actions           — concrete checkbox list
Validation        — how you know it worked
Rollback          — how to undo if it didn't
Commit            — message and what's in it
```

---

# Phase 0 — Branch & baseline

## Goal

Establish a safe, reversible baseline before any changes.

## Prerequisites

- Working repo at a known-good state on `main`
- Decisions from "Pre-flight decisions" section above resolved

## Pre-flight checks

- [ ] `git status --short` is clean (no uncommitted changes)
- [ ] `git branch --show-current` shows `main` (or your default)
- [ ] `bash scripts/doctor.sh` exits successfully
- [ ] PHP tests pass: `vendor/bin/phpunit tests/php` (or your test command)
- [ ] `php tools/ai/generate-repo-structure.php` runs without errors

## Actions

- [ ] Create the feature branch
  ```bash
  git switch -c feat/dotfiles-migration
  ```
- [ ] Capture the pre-migration file inventory
  ```bash
  git ls-files > /tmp/dotfiles-before.txt
  wc -l /tmp/dotfiles-before.txt  # should report ~129 lines
  ```
- [ ] Confirm pre-flight decisions are written down somewhere persistent (this file, a sticky note, your notes app)
- [ ] If you have a throwaway VM or fresh WSL2 distro for testing, note its name and SSH details now

## Validation

- [ ] `git branch --show-current` shows `feat/dotfiles-migration`
- [ ] `/tmp/dotfiles-before.txt` exists and lists all current files
- [ ] No untracked changes from baseline checks

## Rollback

```bash
git switch main
git branch -D feat/dotfiles-migration
```

## Commit

None this phase. The baseline is a branch creation, not a change.

---

# Phase 1 — Cleanup

## Goal

Delete everything we know we don't want (Windows artefacts, duplicates, project-scoped files), before adding anything new.

## Prerequisites

- Phase 0 complete
- Bash decision made

## Pre-flight checks

- [ ] On feature branch
- [ ] Run `diff -r configs/shell/ backup-sanitized/home/` and note which copies of `.zshrc`, `.gitconfig`, `starship.toml` to keep (most likely `backup-sanitized/` is more recent)
- [ ] Run `diff configs/ghostty/config configs/ghostty/config-ghostyy` to confirm the typo file is removable

## Actions

### Delete Husky (Lefthook wins)

- [ ] `git rm -r .husky/`

### Delete Windows-native artefacts

- [ ] `git rm -r docs/windows/`
- [ ] `git rm docs/install-dev-tools-windows.ps1`
- [ ] `git rm docs/repair-dev-tools-windows.ps1`
- [ ] `git rm docs/verify-dev-tools-powershell.ps1`
- [ ] `git rm docs/verify-dev-tools-gitbash.sh`

### Delete duplicate shell configs (kept in backup-sanitized/)

- [ ] `git rm configs/shell/.zshrc`
- [ ] `git rm configs/shell/.gitconfig`
- [ ] `git rm configs/shell/starship.toml`
- [ ] `rmdir configs/shell/` (if empty)

### Delete typo file

- [ ] `git rm configs/ghostty/config-ghostyy`

### Delete project-scoped or system-volatile files

- [ ] `git rm configs/php/php.ini` (system PHP config is too volatile across versions)
- [ ] `git rm configs/php/pint.json` (project-scoped, belongs in actual PHP project repos)
- [ ] `git rm configs/vscode/launch.json` (project-scoped)
- [ ] `rmdir configs/php/` (if empty)

### Move VS Code workspace templates to docs

- [ ] `mkdir -p docs/templates/vscode/`
- [ ] `git mv configs/vscode/workspace-example.json docs/templates/vscode/`
- [ ] `git mv configs/vscode/workspace-template.json docs/templates/vscode/`

### Optional: bash decision

- [ ] If you don't use bash anywhere: `git rm backup-sanitized/home/.bashrc`
- [ ] If you keep bash: leave `.bashrc` in place; Phase 2 migrates it as a fallback

### Update `.gitignore` (preview new entries)

- [ ] Add lines to `.gitignore`:
  ```gitignore
  # Chezmoi private state
  home/.chezmoidata/personal.yaml
  home/.chezmoidata/personal.local.yaml
  home/.chezmoistate/

  # Nix
  result
  result-*

  # direnv (in case any tooling drops it)
  .direnv/

  # mise local overrides
  mise.local.toml
  .mise.local.toml
  ```

## Validation

- [ ] `git status --short` shows only deletions and the workspace-template moves
- [ ] `git diff --check` shows no whitespace issues
- [ ] `bash scripts/doctor.sh` still exits successfully
- [ ] `lefthook run pre-commit` still passes (if you have it installed locally)
- [ ] PHP tests still pass

## Rollback

```bash
git restore --staged .
git restore .
# or to fully reset:
git reset --hard origin/main
```

## Commit

```bash
git add -A
git commit -m "chore: drop Windows native support and remove duplicates

- Delete .husky/ (Lefthook replaces it)
- Delete docs/windows/ and all *.ps1 / Git Bash scripts
- Delete duplicate shell configs in configs/shell/
- Delete configs/ghostty/config-ghostyy (typo dupe)
- Delete project-scoped configs (php.ini, pint.json, launch.json)
- Move VS Code workspace templates to docs/templates/vscode/
- Update .gitignore for upcoming chezmoi/nix/mise entries"
```

---

# Phase 2 — Build the chezmoi `home/` source tree

## Goal

All personal dotfiles live in one place, owned by chezmoi, deployable cross-OS with a single `chezmoi apply`.

## Prerequisites

- Phase 1 merged or at least committed locally
- chezmoi installed locally for testing (`brew install chezmoi`, `nix profile install nixpkgs#chezmoi`, or platform-equivalent)

## Pre-flight checks

- [ ] `which chezmoi` resolves
- [ ] Have a throwaway VM, WSL2 distro, or fresh user account available for testing without nuking your real `~`

## Actions

### Create the source root marker

- [ ] Create `.chezmoiroot` at repo root:
  ```bash
  echo home > .chezmoiroot
  ```
  This tells chezmoi to look in `<repo>/home/` for source state. Do **NOT** put a `.chezmoiroot` inside `home/`.

### Create directory skeleton

- [ ] ```bash
  mkdir -p home/.chezmoidata
  mkdir -p home/.chezmoiscripts
  mkdir -p home/dot_config/{atuin,btop,ghostty,mise,starship,nvim,karabiner}
  mkdir -p home/dot_config/Code/User
  mkdir -p "home/Library/Application Support/Code/User"
  mkdir -p home/executable_dot_local/bin
  ```

### Create personal data file

- [ ] Create `home/.chezmoidata/personal.yaml.example` (committed):
  ```yaml
  name: "Your Full Name"
  email: "you@example.com"
  signingKey: ""
  minimal: false        # true => use minimal VS Code settings
  useGitDelta: true
  hostProfile: "linux"  # one of: linux | wsl | macos
  ```
- [ ] Create your private `home/.chezmoidata/personal.yaml` (gitignored from Phase 1) with real values

### Create `.chezmoiignore`

- [ ] Create `home/.chezmoiignore`:
  ```
  README.md
  .DS_Store

  {{- if ne .chezmoi.os "darwin" }}
  # macOS-only paths excluded on Linux/WSL
  Library/Application Support/Code/User/**
  dot_config/karabiner/**
  {{- end }}

  {{- if eq .chezmoi.os "darwin" }}
  # Linux/WSL VS Code path excluded on macOS
  dot_config/Code/User/**
  {{- end }}

  {{- if eq .hostProfile "wsl" }}
  # Ghostty config not needed in WSL when using Windows-side terminal
  dot_config/ghostty/**
  {{- end }}
  ```

### Migrate from `backup-sanitized/home/`

- [ ] Shell files (templates so you can parameterize identity):
  ```bash
  cp backup-sanitized/home/.zshrc       home/dot_zshrc.tmpl
  cp backup-sanitized/home/.zprofile    home/dot_zprofile.tmpl
  cp backup-sanitized/home/.gitconfig   home/dot_gitconfig.tmpl
  ```
- [ ] Open each `.tmpl` file and replace personal identity with template variables:
  - `your.email@example.com` → `{{ .email }}`
  - `Your Name` → `{{ .name }}`
  - signing key → `{{ .signingKey }}`
- [ ] App configs:
  ```bash
  cp backup-sanitized/home/.config/atuin/config.toml         home/dot_config/atuin/config.toml
  cp backup-sanitized/home/.config/btop/btop.conf            home/dot_config/btop/btop.conf
  cp backup-sanitized/home/.config/ghostty/config            home/dot_config/ghostty/config.tmpl
  cp backup-sanitized/home/.config/mise/config.toml          home/dot_config/mise/config.toml.tmpl
  cp backup-sanitized/home/.config/starship/starship.toml    home/dot_config/starship/starship.toml
  ```
- [ ] Executable script:
  ```bash
  cp backup-sanitized/home/.local/bin/git-branch-origin \
     home/executable_dot_local/bin/git-branch-origin
  ```
  The `executable_` prefix gives it `0755` on apply.
- [ ] Bash fallback (only if you kept it in Phase 1):
  ```bash
  cp backup-sanitized/home/.bashrc home/dot_bashrc
  ```

### Migrate from `configs/`

- [ ] Neovim:
  ```bash
  cp -R configs/nvim/* home/dot_config/nvim/
  ```
- [ ] Karabiner (macOS-only — gated by `.chezmoiignore`):
  ```bash
  cp configs/karabiner/karabiner.json home/dot_config/karabiner/karabiner.json
  ```
- [ ] VS Code — Linux/WSL path:
  ```bash
  cp configs/vscode/user/settings.json   home/dot_config/Code/User/settings.json.tmpl
  cp configs/vscode/keybindings.json     home/dot_config/Code/User/keybindings.json
  ```
- [ ] VS Code — macOS path:
  ```bash
  cp configs/vscode/user/settings.json   "home/Library/Application Support/Code/User/settings.json.tmpl"
  cp configs/vscode/keybindings.json     "home/Library/Application Support/Code/User/keybindings.json"
  ```
- [ ] Merge `settings.minimal.json` into the template using `.minimal`:
  - Open both `settings.json.tmpl` files
  - Identify the keys that differ between full and minimal versions
  - Wrap them in `{{ if .minimal }}...{{ else }}...{{ end }}` blocks
  - Delete `configs/vscode/user/settings.minimal.json`

### Create chezmoi run-scripts

- [ ] `home/.chezmoiscripts/run_once_before_10-install-nix.sh.tmpl`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  if command -v nix >/dev/null 2>&1; then
    echo "Nix already installed; skipping."
    exit 0
  fi

  echo "Installing Nix via Determinate Systems installer..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | \
    sh -s -- install --no-confirm

  # Source nix profile for current shell
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  ```
  Mark executable: `chmod +x home/.chezmoiscripts/run_once_before_10-install-nix.sh.tmpl`

- [ ] `home/.chezmoiscripts/run_onchange_after_20-home-manager.sh.tmpl`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  REPO_ROOT="{{ .chezmoi.workingTree }}"
  HOST_PROFILE="{{ .hostProfile }}"

  if [ "$HOST_PROFILE" = "macos" ] && command -v darwin-rebuild >/dev/null 2>&1; then
    echo "Applying nix-darwin profile..."
    darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"
  else
    echo "Applying Home Manager profile: $HOST_PROFILE"
    home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE"
  fi
  ```

- [ ] `home/.chezmoiscripts/run_onchange_after_30-mise-install.sh.tmpl`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  if command -v mise >/dev/null 2>&1; then
    mise install || true
  fi
  ```

- [ ] `home/.chezmoiscripts/run_onchange_after_40-vscode-extensions.sh.tmpl`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  if ! command -v code >/dev/null 2>&1; then
    echo "VS Code CLI not found; skipping extension install."
    exit 0
  fi

  REPO_ROOT="{{ .chezmoi.workingTree }}"
  EXTENSIONS_FILE="$REPO_ROOT/docs/vscode-extensions.md"

  [ -f "$EXTENSIONS_FILE" ] || exit 0

  grep -E '^[a-zA-Z0-9_.-]+\.[a-zA-Z0-9_.-]+$' "$EXTENSIONS_FILE" | \
    while read -r ext; do
      code --install-extension "$ext" --force
    done
  ```

- [ ] Mark all run-scripts executable:
  ```bash
  chmod +x home/.chezmoiscripts/*.sh.tmpl
  ```

## Validation

- [ ] Run on YOUR machine in dry-run mode:
  ```bash
  chezmoi init --source="$PWD"
  chezmoi diff | less  # review every change before applying
  ```
- [ ] Confirm template rendering works:
  ```bash
  chezmoi execute-template < home/dot_gitconfig.tmpl
  # Should print your gitconfig with name/email filled in
  ```
- [ ] On a throwaway VM or WSL distro:
  ```bash
  git clone <your-repo-url> ~/dotfiles-test
  cd ~/dotfiles-test
  # Create your personal.yaml here too
  chezmoi init --apply --source="$PWD"
  ```
- [ ] Verify files landed at correct paths:
  ```bash
  test -f ~/.zshrc && echo "zshrc OK"
  test -f ~/.config/atuin/config.toml && echo "atuin OK"
  test -x ~/.local/bin/git-branch-origin && echo "executable OK"
  # macOS:
  test -f "$HOME/Library/Application Support/Code/User/settings.json" && echo "vscode macOS OK"
  # Linux/WSL:
  test -f "$HOME/.config/Code/User/settings.json" && echo "vscode linux OK"
  ```
- [ ] No unexpected files in `~` (run `chezmoi managed` to list everything chezmoi owns)

## Rollback

- On your real machine, if you ran `chezmoi apply`:
  ```bash
  chezmoi forget                # stops tracking
  # Restore original files from git or backup
  ```
- On the throwaway VM: just delete the VM.
- For the repo:
  ```bash
  git restore --staged .
  git restore .
  ```

## Commit

```bash
git add -A
git commit -m "feat: migrate dotfiles into chezmoi source tree

- Create .chezmoiroot at repo root pointing to home/
- Migrate all personal dotfiles from backup-sanitized/ and configs/
- Templates for shell configs, gitconfig, ghostty, mise, VS Code settings
- OS gating via .chezmoiignore (macOS Library vs Linux .config)
- WSL gating for ghostty (Windows terminal used instead)
- Karabiner.json macOS-only via .chezmoiignore
- Run scripts: install-nix, home-manager-switch, mise-install, vscode-extensions
- VS Code minimal settings folded into single templated file"
```

Note: `backup-sanitized/` and `configs/` remain in place until Phase 8 (only delete after the whole chain works).

---

# Phase 3 — Add repo-scoped `mise.toml`

## Goal

Single command surface for repo workflows (doctor, apply, diff, bootstrap, nix switch, PHP tests).

## Prerequisites

- Phase 2 complete or at least chezmoi tree in place
- mise installed locally

## Pre-flight checks

- [ ] `which mise` resolves
- [ ] `mise --version` reports a current version

## Actions

- [ ] Create `mise.toml` at repo root:
  ```toml
  [tools]
  php = "8.4"   # required by tools/ai/ session-logging utilities

  [tasks.doctor]
  description = "Run repo health checks"
  run = "bash scripts/doctor.sh"

  [tasks.apply]
  description = "Apply dotfiles via chezmoi"
  run = "chezmoi apply"

  [tasks.diff]
  description = "Preview pending dotfile changes"
  run = "chezmoi diff"

  [tasks.bootstrap]
  description = "Cold-start setup on a fresh machine"
  run = "bash scripts/bootstrap.sh"

  [tasks."nix:check"]
  description = "Validate Nix flake"
  run = "nix flake check ./nix"

  [tasks."nix:switch"]
  description = "Apply Home Manager (auto-detect host)"
  run = """
  HOST="${HOST_PROFILE:-$(bash scripts/detect-host.sh)}"
  if [ "$HOST" = "macos" ]; then
    darwin-rebuild switch --flake ./nix#macos
  else
    home-manager switch --flake ./nix#$HOST
  fi
  """

  [tasks."test:php"]
  description = "Run PHP tests"
  run = "vendor/bin/phpunit tests/php || phpunit tests/php"

  [tasks."session:start"]
  description = "Start an AI session log"
  run = "php tools/ai/session-start.php"

  [tasks."session:end"]
  description = "End an AI session log"
  run = "php tools/ai/session-end.php"

  [tasks."repo:structure"]
  description = "Regenerate the auto-generated repo structure doc"
  run = "php tools/ai/generate-repo-structure.php"

  [tasks."repo:check"]
  description = "Full repo consistency check"
  run = """
  git diff --check
  bash scripts/doctor.sh
  nix flake check ./nix || true
  """
  ```

## Validation

- [ ] `mise tasks` lists all the tasks above
- [ ] `mise run doctor` succeeds
- [ ] `mise install` installs PHP 8.4 (or reports already installed)
- [ ] `mise run test:php` runs the PHP test suite
- [ ] `mise run session:start --help` (or equivalent) shows the AI session-logging tool still works under mise-managed PHP

## Rollback

```bash
git rm mise.toml
```

## Commit

```bash
git add mise.toml
git commit -m "feat: add mise tasks for repo workflows

- PHP 8.4 declared as repo runtime for tools/ai/
- Tasks: doctor, apply, diff, bootstrap, nix:check, nix:switch
- Tasks: test:php, session:start, session:end
- Tasks: repo:structure, repo:check"
```

---

# Phase 4 — Nix flake + modular Home Manager

## Goal

Declarative, version-pinned package layer with host profiles for Linux, WSL, and macOS. Strict `home.packages`-only rule.

## Prerequisites

- Phase 2 + 3 complete
- Nix installed (`nix --version` resolves)
- A weekend of focused time

## Pre-flight checks

- [ ] `nix --version` reports 2.18+ (flakes-capable)
- [ ] `nix flake --help` works (flakes enabled)
- [ ] Read the package list in `docs/install-dev-tools.sh` and categorize each package into cli/dev/shell/gui — you'll translate these into Nix attribute names

## Actions

### Create directory skeleton

- [ ] ```bash
  mkdir -p nix/{vars,lib,overlays}
  mkdir -p nix/hosts/{linux,wsl,macos}
  mkdir -p nix/modules/{common,home,darwin}
  ```

### Create `nix/vars/default.nix`

- [ ] ```nix
  {
    username = "REPLACE_ME";        # your username on all hosts (assumed same)
    email    = "REPLACE_ME";

    profiles = {
      linux = {
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
        system        = "aarch64-darwin";  # or x86_64-darwin for Intel
        homeDirectory = "/Users/REPLACE_ME";
        stateVersion  = "24.11";
      };
    };
  }
  ```
  Replace `REPLACE_ME` with your actual username; fix `aarch64-darwin` vs `x86_64-darwin` per your Mac.

### Create `nix/lib/mkhome.nix`

- [ ] ```nix
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
        programs.home-manager.enable = true;   # the ONE allowed programs.<x>.enable
      }
    ];
    extraSpecialArgs = extraSpecialArgs // {
      inherit inputs username;
    };
  }
  ```

### Create overlay stub

- [ ] `nix/overlays/default.nix`:
  ```nix
  final: prev: {
    # Future package overrides go here.
  }
  ```

### Create module: `nix/modules/common/nix-settings.nix`

- [ ] ```nix
  { ... }:
  {
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
    };
  }
  ```

### Create module: `nix/modules/common/packages.nix`

- [ ] Packages every host needs:
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

### Create module: `nix/modules/common/default.nix`

- [ ] ```nix
  {
    imports = [ ./packages.nix ];
  }
  ```

### Create module: `nix/modules/home/cli.nix`

- [ ] Translate the CLI tools you currently install:
  ```nix
  { pkgs, ... }:
  {
    home.packages = with pkgs; [
      atuin
      bat
      btop
      delta
      eza
      fd
      fzf
      jq
      yq
      ripgrep
      starship
      tmux
      zoxide
    ];
  }
  ```

### Create module: `nix/modules/home/dev.nix`

- [ ] ```nix
  { pkgs, ... }:
  {
    home.packages = with pkgs; [
      gh
      lazygit
      lefthook
      neovim
      shellcheck
      shfmt
      tokei
      watchexec
      # NB: do NOT include `direnv` (mise covers it)
      # NB: do NOT include `mise` here (installed via nix profile in bootstrap)
    ];
  }
  ```

### Create module: `nix/modules/home/shell-packages.nix`

- [ ] ```nix
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

### Create module: `nix/modules/home/gui.nix`

- [ ] ```nix
  { pkgs, ... }:
  {
    home.packages = with pkgs; [
      # ghostty   # uncomment when confirmed available for your system
      # Add other GUI tools you actually use here.
    ];
  }
  ```
  Keep conservative; populate as you confirm packages are available.

### Create module: `nix/modules/home/default.nix`

- [ ] ```nix
  {
    imports = [
      ./cli.nix
      ./dev.nix
      ./shell-packages.nix
    ];
  }
  ```
  Note: `gui.nix` is NOT imported here; hosts that want GUI import it directly.

### Create host: `nix/hosts/linux/home.nix`

- [ ] ```nix
  {
    imports = [
      ../../modules/common
      ../../modules/home
      ../../modules/home/gui.nix
    ];
  }
  ```

### Create host: `nix/hosts/wsl/home.nix`

- [ ] ```nix
  {
    imports = [
      ../../modules/common
      ../../modules/home
      # No GUI module on WSL.
    ];
  }
  ```

### Create host: `nix/hosts/macos/home.nix`

- [ ] ```nix
  {
    imports = [
      ../../modules/common
      ../../modules/home
      ../../modules/home/gui.nix
    ];
  }
  ```

### Create darwin stub: `nix/hosts/macos/darwin.nix`

- [ ] Stub for Phase 6 — file exists so the flake evaluates:
  ```nix
  { pkgs, vars, ... }:
  {
    system.stateVersion = 5;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    users.users.${vars.username}.home = vars.profiles.macos.homeDirectory;
    imports = [ ../../modules/darwin ];
  }
  ```

### Create darwin module stubs

- [ ] `nix/modules/darwin/default.nix`:
  ```nix
  {
    imports = [ ./system-defaults.nix ];
  }
  ```
- [ ] `nix/modules/darwin/system-defaults.nix` (empty for now, populated in Phase 6):
  ```nix
  { ... }:
  {
    # Phase 6 populates this with dock, finder, keyboard, trackpad defaults.
  }
  ```

### Create `nix/flake.nix`

- [ ] ```nix
  {
    description = "Personal dev environment for Linux, WSL2, and macOS";

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
          let profile = vars.profiles.${name};
          in mkHome {
            inherit (profile) system homeDirectory stateVersion;
            username = vars.username;
            modules  = [ ./hosts/${name}/home.nix ];
          };
      in
      {
        homeConfigurations = {
          linux = mkProfile "linux";
          wsl   = mkProfile "wsl";
          macos = mkProfile "macos";   # standalone HM, used if not running nix-darwin
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
- [ ] `nix flake show ./nix` lists `homeConfigurations.{linux,wsl,macos}` and `darwinConfigurations.macos`
- [ ] On Linux/WSL — dry run:
  ```bash
  home-manager switch --flake ./nix#wsl --dry-run
  # or
  home-manager switch --flake ./nix#linux --dry-run
  ```
- [ ] After actual switch (`home-manager switch --flake ./nix#<host>`):
  ```bash
  which ripgrep       # should be /home/<user>/.nix-profile/bin/rg or /nix/store/...
  rg --version
  bat --version
  ```
- [ ] On macOS — check only:
  ```bash
  darwin-rebuild check --flake ./nix#macos
  ```
- [ ] `chezmoi diff` shows no conflicts with Home Manager (no files claimed by both)

## Rollback

- Home Manager: `home-manager generations` then activate a previous one
- nix-darwin: `darwin-rebuild --rollback`
- Flake itself: `git restore nix/` (the configs revert; existing packages stay until next switch)

## Commit

```bash
git add nix/
git commit -m "feat: add Nix flake with modular Home Manager configuration

- nix/vars/default.nix: per-host username, system, homeDirectory
- nix/lib/mkhome.nix: helper to build homeManagerConfiguration
- nix/hosts/{linux,wsl,macos}: thin host profiles selecting modules
- nix/modules/common: nix-settings, shared packages
- nix/modules/home: cli, dev, shell-packages, gui (gui not in default)
- nix/modules/darwin: stubs for Phase 6
- flake.nix exposes homeConfigurations + darwinConfigurations.macos
- Strict rule: home.packages only, no programs.<x>.enable (except home-manager)
- WSL profile excludes gui module
- direnv intentionally absent (mise covers it)
- mise intentionally absent from packages (installed via nix profile in bootstrap)"
```

After this commit, in a follow-up:

```bash
git rm docs/install-dev-tools.sh
git commit -m "chore: remove legacy install script, migrated to Nix Home Manager"
```

---

# Phase 5 — Unified bootstrap script

## Goal

One command turns a clean macOS, Linux, or WSL2 machine into a fully configured environment.

## Prerequisites

- Phase 4 complete and committed
- A throwaway target machine (VM, fresh WSL2 distro, or borrowed Mac) to test bootstrap end-to-end

## Pre-flight checks

- [ ] You can rebuild a target machine quickly (snapshot/reset) if bootstrap fails partway

## Actions

### Create `scripts/detect-host.sh`

- [ ] ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  case "$(uname -s)" in
    Darwin)
      echo "macos"
      ;;
    Linux)
      if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    *)
      echo "unsupported" >&2
      exit 1
      ;;
  esac
  ```
- [ ] `chmod +x scripts/detect-host.sh`

### Create `scripts/bootstrap.sh`

- [ ] ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  log()  { printf '[bootstrap] %s\n' "$*"; }
  fail() { printf '[bootstrap:error] %s\n' "$*" >&2; exit 1; }

  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/scripts/detect-host.sh")}"

  log "Repo root: $REPO_ROOT"
  log "Host profile: $HOST_PROFILE"

  # --- Preflight: required commands ---
  for cmd in git bash curl; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
  done

  # --- Install Nix if absent ---
  if ! command -v nix >/dev/null 2>&1; then
    log "Installing Nix (Determinate Systems installer)..."
    curl --proto '=https' --tlsv1.2 -sSf -L \
      https://install.determinate.systems/nix | \
      sh -s -- install --no-confirm
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh || true
  fi

  command -v nix >/dev/null 2>&1 || \
    fail "Nix install completed but 'nix' not on PATH. Open a new shell and rerun."

  # --- Install minimal base tools via nix profile ---
  log "Installing chezmoi, mise, home-manager, lefthook..."
  nix profile install \
    nixpkgs#chezmoi \
    nixpkgs#mise \
    nixpkgs#home-manager \
    nixpkgs#lefthook

  # --- Validate flake before applying anything ---
  log "Validating Nix flake..."
  nix flake check "$REPO_ROOT/nix"

  # --- Apply chezmoi (uses .chezmoiroot to find home/) ---
  log "Initializing chezmoi..."
  chezmoi init --source="$REPO_ROOT"

  log "Preview chezmoi changes:"
  chezmoi diff || true

  log "Applying chezmoi..."
  chezmoi apply

  # --- Apply Home Manager or nix-darwin ---
  if [ "$HOST_PROFILE" = "macos" ] && command -v darwin-rebuild >/dev/null 2>&1; then
    log "Applying nix-darwin profile..."
    darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"
  else
    log "Applying Home Manager profile: $HOST_PROFILE"
    home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE"
  fi

  # --- Install mise runtimes from project + global config ---
  log "Trusting and installing mise runtimes..."
  mise trust "$REPO_ROOT" || true
  mise install || true

  # --- Install Lefthook hooks ---
  if [ -d "$REPO_ROOT/.git" ]; then
    log "Installing Lefthook git hooks..."
    (cd "$REPO_ROOT" && lefthook install) || true
  fi

  # --- SSH agent setup (Unix only) ---
  if [ -x "$REPO_ROOT/scripts/unix/ssh-agent-setup.sh" ] && [ "$HOST_PROFILE" != "wsl" ]; then
    log "Running SSH agent setup..."
    bash "$REPO_ROOT/scripts/unix/ssh-agent-setup.sh" || true
  fi

  # --- Final health check ---
  log "Running doctor..."
  bash "$REPO_ROOT/scripts/doctor.sh"

  log "Bootstrap complete on $HOST_PROFILE."
  ```
- [ ] `chmod +x scripts/bootstrap.sh`

## Validation

- [ ] Linux VM (Ubuntu 24.04 or similar):
  ```bash
  HOST_PROFILE=linux bash scripts/bootstrap.sh
  ```
  Verify: ripgrep, fd, bat installed; ~/.zshrc applied; mise runs PHP 8.4
- [ ] WSL2 (fresh Ubuntu distro):
  ```bash
  HOST_PROFILE=wsl bash scripts/bootstrap.sh
  ```
  Verify: same as Linux, plus karabiner.json NOT applied, ghostty config NOT applied
- [ ] macOS (when available):
  ```bash
  HOST_PROFILE=macos bash scripts/bootstrap.sh
  ```
  Verify: VS Code settings at `~/Library/Application Support/Code/User/`, karabiner.json applied
- [ ] On each: `bash scripts/doctor.sh` exits 0

## Rollback

- Per-target: VM snapshot restore is the cleanest
- Per-tool: `home-manager generations` / `nix profile rollback`

## Commit

```bash
git add scripts/bootstrap.sh scripts/detect-host.sh
git commit -m "feat: add unified Linux/macOS/WSL bootstrap

- scripts/detect-host.sh: detect linux/wsl/macos
- scripts/bootstrap.sh: end-to-end cold-start
  - Install Nix (Determinate Systems) if absent
  - Install chezmoi, mise, home-manager, lefthook via nix profile
  - Validate Nix flake before any apply
  - chezmoi init/diff/apply
  - home-manager switch or darwin-rebuild switch per host
  - mise install (runtimes)
  - lefthook install (git hooks)
  - SSH agent setup (Unix non-WSL)
  - doctor health check"
```

---

# Phase 6 — nix-darwin (macOS only; conditional)

## Goal

Manage macOS system defaults declaratively. Skip unless you have an active Mac. The stub from Phase 4 means the flake builds; this phase only fills in the substance.

## Prerequisites

- Phase 5 complete
- Active macOS machine
- `darwin-rebuild` available (installed via `nix-darwin` after first apply)

## Pre-flight checks

- [ ] `uname -s` returns `Darwin`
- [ ] `nix flake check ./nix` still passes

## Actions

### Populate `nix/modules/darwin/system-defaults.nix`

- [ ] Replace the empty stub with actual preferences you use:
  ```nix
  { ... }:
  {
    system.defaults = {
      dock = {
        autohide      = true;
        show-recents  = false;
        tilesize      = 48;
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles      = true;
        FXPreferredViewStyle   = "Nlsv";  # list view
        ShowPathbar            = true;
        ShowStatusBar          = true;
      };

      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        KeyRepeat                = 2;
        InitialKeyRepeat         = 15;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      trackpad = {
        Clicking                  = true;
        TrackpadThreeFingerDrag   = true;
      };

      screencapture = {
        location = "~/Pictures/Screenshots";
        type     = "png";
      };
    };
  }
  ```
- [ ] Only declare defaults you've actually been setting manually. Don't try to declare every macOS preference upfront — grow this from real friction.

### Optional: Homebrew cask bridge

- [ ] If you install GUI apps via Homebrew on Mac, add a `nix/modules/darwin/homebrew.nix`:
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
        "visual-studio-code"
        "ghostty"
        "karabiner-elements"
      ];
    };
  }
  ```
- [ ] Import in `nix/modules/darwin/default.nix`:
  ```nix
  {
    imports = [
      ./system-defaults.nix
      # ./homebrew.nix       # uncomment if you added it
    ];
  }
  ```

## Validation

- [ ] `nix flake check ./nix` passes
- [ ] `darwin-rebuild check --flake ./nix#macos` passes
- [ ] `darwin-rebuild switch --flake ./nix#macos`
- [ ] Verify defaults applied:
  ```bash
  defaults read com.apple.dock autohide      # 1
  defaults read com.apple.finder ShowPathbar # 1
  ```
- [ ] Open Finder, check view style; open Dock, check auto-hide

## Rollback

```bash
darwin-rebuild --rollback
```

## Commit

```bash
git add nix/modules/darwin nix/hosts/macos/darwin.nix
git commit -m "feat: populate nix-darwin system defaults

- Dock: autohide, hide recents, tile size 48
- Finder: show extensions/hidden files, list view, path bar
- Global: disable press-and-hold, custom key repeat, disable auto-correction
- Trackpad: tap-to-click, three-finger drag
- Screenshots: ~/Pictures/Screenshots, PNG"
```

---

# Phase 7 — Documentation & regenerate inventory

## Goal

Repo is self-documenting. A future-you (or LLM agent) can rebuild from clone without help.

## Prerequisites

- Phases 1–5 complete (Phase 6 optional)

## Actions

### Create `docs/architecture/tool-ownership.md`

- [ ] Write a markdown doc covering:
  - Each tool's ownership rules (table)
  - The strict `home.packages` rule and the one exception
  - Forbidden patterns (no project-scoped configs, no `programs.<x>.enable` for chezmoi-managed files, no direnv)
  - Why these rules exist (avoid tool conflict, keep migration paths open)

### Create `docs/bootstrap.md`

- [ ] Write a markdown doc covering:
  - Supported targets: Linux, macOS, WSL2
  - Explicit non-support: Windows native
  - Cold-start steps: clone, optional `personal.yaml`, `bash scripts/bootstrap.sh`
  - Per-OS notes:
    - **Linux:** package manager note for installing Nix prerequisites
    - **macOS:** Apple Silicon vs Intel architecture in `nix/vars/default.nix`
    - **WSL2:**
      - VS Code asymmetry: Windows-side VS Code settings managed manually, WSL-side via this repo
      - Clipboard: `clip.exe` for write, `xclip`/WSLg for read
      - SSH agent: bridge to Windows OpenSSH via `npiperelay`/`wsl2-ssh-agent`, OR run native ssh-agent
      - Systemd: enable per-distro via `/etc/wsl.conf`
      - File performance: keep repos in `~/`, not `/mnt/c/`
  - Forcing a profile: `HOST_PROFILE=wsl bash scripts/bootstrap.sh`
  - Verification: which commands to run after bootstrap

### Update existing docs

- [ ] `docs/README.md` — rewrite as index pointing to architecture, bootstrap, shell-setup, nvim-setup, software-and-cli-tools
- [ ] `docs/shell-setup.md` — update for chezmoi-managed shell files
- [ ] `docs/nvim-setup.md` — update path references (now under chezmoi)
- [ ] `docs/software-and-cli-tools.md` — update; packages now in Nix
- [ ] `docs/vscode-extensions.md` — note that extensions install automatically via run-onchange script
- [ ] `docs/keyboard.md` — update karabiner reference (now in chezmoi, macOS-gated)
- [ ] Root `README.md` — rewrite to summarize new stack, list tool ownership, link to docs
- [ ] `CONTRIBUTING.md` — update with new hook flow (Lefthook only)

### Regenerate auto-generated inventory

- [ ] ```bash
  mise run repo:structure
  # or: php tools/ai/generate-repo-structure.php
  ```
- [ ] Inspect:
  ```bash
  git diff --stat
  git diff --check
  ```
- [ ] Verify AI session tooling still passes:
  ```bash
  mise run test:php
  ```

## Validation

- [ ] All linked files in `docs/README.md` exist
- [ ] Lefthook hooks still fire on commit
- [ ] PHP tests pass
- [ ] A clean clone + read of `docs/bootstrap.md` walks you through setup unambiguously

## Rollback

```bash
git restore docs/
```

## Commit

```bash
git add -A
git commit -m "docs: document tool ownership, bootstrap flow, refresh inventory

- docs/architecture/tool-ownership.md: codify chezmoi/mise/Nix/HM/Lefthook rules
- docs/bootstrap.md: cold-start procedure, per-OS notes incl. WSL specifics
- Update README, shell-setup, nvim-setup, software-and-cli-tools
- Regenerate auto-generated repo structure via tools/ai/"
```

---

# Phase 8 — Final legacy cleanup

## Goal

Delete migrated source folders once their replacement is proven on real hardware.

## Prerequisites

- Phases 1–5 complete
- Bootstrap tested end-to-end on at least one target OS (primary host)
- chezmoi tree validated on a throwaway machine

## Pre-flight checks

- [ ] Every file from `backup-sanitized/home/` has a counterpart in `home/`
- [ ] Every file from `configs/` either has a counterpart in `home/` or is deleted (Phase 1)
- [ ] `docs/install-dev-tools.sh` package list has been translated into `nix/modules/`

## Actions

- [ ] Final cross-reference:
  ```bash
  find backup-sanitized/home -type f | wc -l   # should match files migrated to home/
  find configs -type f                          # should be empty (or only README.md)
  ```
- [ ] Delete migrated legacy folders:
  ```bash
  git rm -r backup-sanitized
  git rm -r configs
  ```
- [ ] Delete the legacy install script if not already:
  ```bash
  git rm docs/install-dev-tools.sh
  ```
- [ ] If `configs/README.md` was the only file left in `configs/`, that's gone too

## Validation

- [ ] Final repo tree matches the target end-state (see "Final repo tree" section below)
- [ ] All commands from the cross-OS validation matrix still pass on the primary host
- [ ] `bash scripts/bootstrap.sh` on a fresh VM still works end-to-end
- [ ] `mise run repo:check` passes

## Rollback

```bash
git revert HEAD
```

(Files are recoverable from git history forever; nothing is destroyed.)

## Commit

```bash
git add -A
git commit -m "chore: remove migrated legacy folders

- backup-sanitized/ migrated to home/ (chezmoi) in Phase 2
- configs/ migrated to home/ (chezmoi) in Phase 2
- docs/install-dev-tools.sh translated to nix/modules in Phase 4

The repo now has a single source of truth per concern:
- home/ for dotfiles
- nix/ for packages
- mise.toml for tasks
- scripts/ for bootstrap and hooks"
```

---

# Cross-OS validation matrix

Run on each target host after Phase 5. A row that fails on Linux but passes on WSL is a real bug, not "intermittent" — track it down.

| Check | Linux | macOS | WSL2 |
|-------|:-----:|:-----:|:----:|
| `bash scripts/detect-host.sh` returns correct profile | ✅ | ✅ | ✅ |
| `nix --version` resolves | ✅ | ✅ | ✅ |
| `nix flake check ./nix` passes | ✅ | ✅ | ✅ |
| `home-manager switch --flake ./nix#<host> --dry-run` succeeds | ✅ | (use darwin-rebuild) | ✅ |
| `which ripgrep` resolves to Nix store path | ✅ | ✅ | ✅ |
| `chezmoi diff` shows zero conflicts | ✅ | ✅ | ✅ |
| `~/.zshrc` exists and has your name/email rendered | ✅ | ✅ | ✅ |
| `~/.config/Code/User/settings.json` exists | ✅ | ❌ (gated) | ✅ |
| `~/Library/Application Support/Code/User/settings.json` exists | ❌ (gated) | ✅ | ❌ (gated) |
| `~/.config/karabiner/karabiner.json` exists | ❌ (gated) | ✅ | ❌ (gated) |
| `~/.config/ghostty/config` exists | ✅ | ✅ | optional |
| `mise install` succeeds | ✅ | ✅ | ✅ |
| `php --version` reports 8.4 | ✅ | ✅ | ✅ |
| `mise run test:php` passes | ✅ | ✅ | ✅ |
| `defaults read com.apple.dock autohide` matches declaration | n/a | ✅ (Phase 6) | n/a |
| Bootstrap on fresh machine completes | ✅ | ✅ | ✅ |

---

# Final repo tree (end state)

```
.
├── .chezmoiroot                         # contains the single line: home
├── .editorconfig
├── .eslintrc.json
├── .gitattributes
├── .gitignore
├── .lefthook.yml
├── .prettierrc.json
├── .stylelintrc.json
├── .schemas/
│   └── ai-session-event.schema.json
├── CONTRIBUTING.md
├── README.md
├── SECURITY.md
├── SUPPORT.md
│
├── home/                                # chezmoi source tree
│   ├── .chezmoiignore
│   ├── .chezmoidata/
│   │   └── personal.yaml.example
│   ├── .chezmoiscripts/
│   │   ├── run_once_before_10-install-nix.sh.tmpl
│   │   ├── run_onchange_after_20-home-manager.sh.tmpl
│   │   ├── run_onchange_after_30-mise-install.sh.tmpl
│   │   └── run_onchange_after_40-vscode-extensions.sh.tmpl
│   ├── dot_bashrc                       # only if you kept bash
│   ├── dot_zshrc.tmpl
│   ├── dot_zprofile.tmpl
│   ├── dot_gitconfig.tmpl
│   ├── dot_config/
│   │   ├── atuin/config.toml
│   │   ├── btop/btop.conf
│   │   ├── ghostty/config.tmpl
│   │   ├── mise/config.toml.tmpl
│   │   ├── starship/starship.toml
│   │   ├── nvim/
│   │   │   ├── init.lua
│   │   │   └── lua/plugins/{copilot,neotest,vim-tmux-navigator}.lua
│   │   ├── karabiner/karabiner.json
│   │   └── Code/User/
│   │       ├── settings.json.tmpl
│   │       └── keybindings.json
│   ├── Library/Application Support/Code/User/
│   │   ├── settings.json.tmpl
│   │   └── keybindings.json
│   └── executable_dot_local/bin/git-branch-origin
│
├── nix/
│   ├── flake.nix
│   ├── flake.lock                       # generated; commit it
│   ├── vars/default.nix
│   ├── lib/mkhome.nix
│   ├── hosts/
│   │   ├── linux/home.nix
│   │   ├── wsl/home.nix
│   │   └── macos/
│   │       ├── home.nix
│   │       └── darwin.nix
│   ├── modules/
│   │   ├── common/{default,nix-settings,packages}.nix
│   │   ├── home/{default,cli,dev,shell-packages,gui}.nix
│   │   └── darwin/{default,system-defaults}.nix
│   └── overlays/default.nix
│
├── mise.toml                            # repo tasks + PHP 8.4
│
├── scripts/
│   ├── bootstrap.sh
│   ├── detect-host.sh
│   ├── doctor.sh
│   ├── hooks/{commit-msg,pre-commit}.sh
│   └── unix/ssh-agent-setup.sh
│
├── docs/
│   ├── README.md
│   ├── bootstrap.md
│   ├── architecture/tool-ownership.md
│   ├── shell-setup.md
│   ├── nvim-setup.md
│   ├── software-and-cli-tools.md
│   ├── vscode-extensions.md
│   ├── keyboard.md
│   ├── ai/observability.md
│   └── templates/vscode/
│       ├── workspace-example.json
│       └── workspace-template.json
│
├── tools/ai/                            # untouched
│   ├── agent-log.php
│   ├── generate-repo-structure.php
│   ├── session-end.php
│   ├── session-log-lib.php
│   ├── session-start.php
│   └── validate-session-log.php
├── tests/php/SessionLogToolsTest.php
└── reference/                           # untouched (PHP design patterns corpus)
```

---

# Common troubleshooting

## chezmoi

**"executable not found" after `chezmoi apply`**
- Verify `executable_` prefix on the file in source tree
- Verify chmod +x was applied: `ls -l home/executable_dot_local/bin/`

**"unresolved template variable"**
- Check `home/.chezmoidata/personal.yaml` exists and has all keys referenced in templates
- Run `chezmoi data` to dump current data; check missing key

**Files appear in wrong location on macOS**
- Check `.chezmoiignore` macOS gates: `Library/Application Support/Code/User/**` should NOT be ignored on Darwin
- Run `chezmoi managed | grep Code` to see what chezmoi thinks it owns

## Nix

**`nix flake check` fails with "input does not have output"**
- Run `nix flake update ./nix` to refresh inputs
- Check that `nix-darwin` input is correctly referenced

**`home-manager switch` fails with "file conflicts with chezmoi"**
- A `programs.<x>.enable = true;` is generating a config file that chezmoi also manages
- Remove the `programs.<x>.enable` line; package via `home.packages` only

**Wrong macOS architecture**
- Edit `nix/vars/default.nix`: `aarch64-darwin` (Apple Silicon) vs `x86_64-darwin` (Intel)

## mise

**`mise install` does nothing**
- Run `mise trust .` first (mise requires explicit trust per directory)
- Check `mise current` shows expected versions

**PHP not on PATH after install**
- Reload shell or run `eval "$(mise activate zsh)"`
- Verify activation in `~/.zshrc`: should include `eval "$(mise activate zsh)"`

## WSL2

**Bootstrap can't find `curl`**
- WSL2 fresh distros may be minimal: `sudo apt update && sudo apt install -y curl ca-certificates`
- Then rerun bootstrap

**Git operations slow**
- Repo lives in `/mnt/c/`? Move to `~/`. WSL2 filesystem performance on `/mnt/` is poor by design.

**SSH keys not picked up**
- Either run `ssh-agent` natively in WSL (lose keys on shell exit) or bridge to Windows OpenSSH via `wsl2-ssh-agent` (recommended; document in `docs/bootstrap.md`)

**VS Code settings not applying to Windows VS Code**
- Expected. The WSL-side `~/.config/Code/User/settings.json` doesn't affect Windows VS Code with Remote-WSL. Manage Windows-side settings on the Windows side; chezmoi-managed WSL settings cover VS Code Server only.

## Lefthook

**Hooks not firing after clone**
- Run `lefthook install` once per clone
- Bootstrap script does this automatically; manual clones need it

---

# Implementation sequence to actually follow

When you sit down to execute this:

1. **Day 1:** Phase 0 + Phase 1 (cleanup, low risk, finish in one sitting)
2. **Day 2:** Phase 2 (chezmoi source tree — half-day)
3. **Day 2 or 3:** Phase 3 (mise.toml — 15 min, slot it in)
4. **Weekend:** Phase 4 (Nix flake — the big one)
5. **Day after:** Phase 5 (bootstrap script + first end-to-end test on throwaway VM/WSL)
6. **When on Mac:** Phase 6 (nix-darwin, if applicable)
7. **Day after Phase 5 tests pass:** Phase 7 (docs)
8. **A week after all primary tests pass:** Phase 8 (legacy cleanup)

Don't compress this. Each phase needs real validation on real hardware. The legacy folders (`backup-sanitized/`, `configs/`) are your safety net until the new setup has run on every machine you actually use.

---

# Definition of done

The migration is complete when:

- [ ] Every check in the cross-OS validation matrix passes on your primary host
- [ ] A fresh clone + `bash scripts/bootstrap.sh` on a new VM produces a fully working environment
- [ ] `git ls-files | wc -l` shows the new file count; nothing from `backup-sanitized/` or `configs/` remains
- [ ] `docs/architecture/tool-ownership.md` exists and is accurate
- [ ] `docs/bootstrap.md` walks a first-time reader to a working setup without you intervening
- [ ] `chezmoi diff` returns empty (nothing pending)
- [ ] `nix flake check ./nix` passes
- [ ] `mise run repo:check` passes

When all boxes above are ticked, merge the feature branch to `main` and run `bash scripts/bootstrap.sh` on every machine you use.