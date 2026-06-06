# Migration audit — 2026-05-24

Pre-push audit of `feat/dotfiles-migration` against `origin/main`.
Confirms (1) no critical Linux/macOS/WSL2 config was lost in the
migration, and (2) every chezmoi-source folder name is the one each
target tool actually reads on each platform.

## 1. Branch vs main — deletions audit

`feat/dotfiles-migration` is 17 commits ahead of `origin/main`.

### Files deleted on the branch

```
backup-sanitized/home/.config/ghostty/config
backup-sanitized/home/.local/bin/git-branch-origin
configs/README.md
configs/ghostty/config
configs/php/php.ini
configs/php/pint.json
configs/shell/.gitconfig
configs/shell/.zshrc
configs/shell/starship.toml
configs/vscode/launch.json
```

### Each deletion explained

| Deletion | What replaced it | Critical for any host? |
|----------|------------------|-----------------------|
| `backup-sanitized/home/.config/ghostty/config` | `home/dot_config/ghostty/config.tmpl` (renamed from `configs/ghostty/config-ghostyy` — the newer body, per Phase 1 source-of-truth matrix) | covered, content preserved |
| `backup-sanitized/home/.local/bin/git-branch-origin` | `home/executable_dot_local/bin/git-branch-origin` (the larger 424-line repo copy was kept; backup copy was the smaller 161-line dup) | covered with the **better** version |
| `configs/README.md` | nothing — Phase 10 legacy cleanup | doc-only, not user-facing config |
| `configs/ghostty/config` | superseded by `home/dot_config/ghostty/config.tmpl` (the `-ghostyy` body, which is the modern config) | covered with newer content |
| `configs/php/php.ini` | NOT replaced. Phase 2 deletion: system-volatile (php.ini varies wildly per PHP build) | not a dotfile; belongs in system or mise per-runtime config |
| `configs/php/pint.json` | NOT replaced. Phase 2 deletion: project-scoped (Pint config belongs in the project repo that uses it) | not a dotfile |
| `configs/shell/.gitconfig` | `home/dot_gitconfig.tmpl` (rename, 93% similar — only adds `{{ if .signingKey }}` template gate) | covered, **template-parameterised** for multi-host use |
| `configs/shell/.zshrc` | `home/dot_zshrc.tmpl` (rename from `backup-sanitized/home/.zshrc`, 98% similar — only `<HOME>` → `$HOME` substitutions per Phase 4) | covered with the **chosen winner** from the source-of-truth matrix |
| `configs/shell/starship.toml` | `home/dot_config/starship/starship.toml` (rename from `backup-sanitized/...`; only diff is removal of a stale top comment) | covered, **functionally identical** |
| `configs/vscode/launch.json` | NOT replaced. Phase 2 deletion: project-scoped (debug configs belong in the project repo) | not a dotfile |

### Quantified content overlap

| File pair | Before lines | After lines | Diff lines | Overlap |
|-----------|-------------:|------------:|-----------:|--------:|
| `.zshrc` | 411 | 411 | 34 (≈9 surrounding-context lines per chunk × 4 chunks) | ~99% content identical, intentional `<HOME>`→`$HOME` sanitisation |
| `starship.toml` | n/a | n/a | 1 line removed (stale top comment) | ~100% |
| `.gitconfig` | 109 | 112 | +3 lines for `{{ if .signingKey }}…{{ end }}` template gate | ~100% functional |
| `ghostty/config(.tmpl)` | older Catppuccin palette | modern config (theme + shell-integration + clipboard safety + macOS QoL) | full replacement | **intentional upgrade**, per matrix decision |
| `git-branch-origin` | 161 | 424 | full replacement | **intentional upgrade** to the more featureful copy |

**Verdict:** all deletions are intentional, documented in
`repo-docs/migration-source-of-truth.md`, and either replaced with a newer
sibling (90-99% functional overlap) or were not configuration files
appropriate for a dotfiles repo. No critical Linux/macOS/WSL2 config
was lost.

## 2. Folder-name / tool-pickup audit

| Chezmoi source | Deploy path | Tool default location | macOS | linux-desktop | linux-cli | WSL2 |
|----------------|-------------|----------------------|:---:|:---:|:---:|:---:|
| `dot_zshrc.tmpl` | `~/.zshrc` | zsh reads `~/.zshrc` | ✅ | ✅ | ✅ | ✅ |
| `dot_zprofile.tmpl` | `~/.zprofile` | login zsh reads `~/.zprofile` | ✅ | ✅ | ✅ | ✅ |
| `dot_bashrc` | `~/.bashrc` | bash reads `~/.bashrc` | ✅ | ✅ | ✅ | ✅ |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | git reads `~/.gitconfig` | ✅ | ✅ | ✅ | ✅ |
| `dot_config/atuin/config.toml` | `~/.config/atuin/config.toml` | atuin: `$XDG_CONFIG_HOME/atuin/` | ✅ | ✅ | ✅ | ✅ |
| `dot_config/btop/btop.conf` | `~/.config/btop/btop.conf` | btop: XDG | ✅ | ✅ | ✅ | ✅ |
| `dot_config/starship/starship.toml` | `~/.config/starship/starship.toml` | starship: XDG | ✅ | ✅ | ✅ | ✅ |
| `dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml` | mise: XDG (validated end-to-end on this WSL host) | ✅ | ✅ | ✅ | ✅ |
| `dot_config/nvim/...` | `~/.config/nvim/...` | neovim: XDG | ✅ | ✅ | ✅ | ✅ |
| `dot_config/ghostty/config.tmpl` | `~/.config/ghostty/config` (XDG, Linux only) | Ghostty Linux/BSD: XDG | gated off via `.chezmoiignore` | ✅ | gated off | gated off |
| `Library/Application Support/com.mitchellh.ghostty/config.tmpl` | `~/Library/Application Support/com.mitchellh.ghostty/config` (macOS only) | Ghostty macOS canonical path (loaded after XDG; if both exist macOS-specific wins) | ✅ | gated off | gated off | gated off |
| `.chezmoitemplates/ghostty/config.body.tmpl` | (not deployed — shared body) | Single source of truth; both wrappers above pull it via `{{ template "ghostty/config.body.tmpl" . }}` | n/a | n/a | n/a | n/a |
| `dot_config/karabiner/karabiner.json` | `~/.config/karabiner/karabiner.json` | karabiner-elements 14.x: `~/.config/karabiner/karabiner.json` | ✅ | n/a (gated) | n/a | n/a |
| `dot_config/Code/User/{keybindings,settings}.json` | `~/.config/Code/User/...` | VS Code: Linux/WSL/code-server | gated off | ✅ | optional | ✅ (Remote-WSL server side only) |
| `Library/Application Support/Code/User/{keybindings,settings}.json` | `~/Library/Application Support/Code/User/...` | VS Code: macOS | ✅ | gated | gated | gated |
| `dot_config/app-configs/ssh-agent.sh` | `~/.config/app-configs/ssh-agent.sh` | we own the path, sourced from rc | ✅ | ✅ | ✅ | ✅ |
| `dot_config/fish/conf.d/ssh-agent.fish` | `~/.config/fish/conf.d/ssh-agent.fish` | fish: auto-loads `conf.d/*.fish` | ✅ | ✅ | ✅ | ✅ |
| `executable_dot_local/bin/git-branch-origin` | `~/.local/bin/git-branch-origin` (0755) | needs `~/.local/bin` on PATH (the `.zshrc.tmpl` already adds it) | ✅ | ✅ | ✅ | ✅ |

**Verdict:** every folder name maps to the canonical default location
of its tool on each supported host. Ghostty now ships **two** wrapper
templates that both render from the shared body in
`home/.chezmoitemplates/ghostty/config.body.tmpl`:

- **macOS** deploys to `~/Library/Application Support/com.mitchellh.ghostty/config` (Ghostty's macOS-canonical path that overrides XDG)
- **Linux desktop** deploys to `~/.config/ghostty/config` (XDG)
- **linux-cli / WSL** skip both via `.chezmoiignore`

`.chezmoiignore` is updated so each host renders **exactly one** of the
two paths, never both. End-to-end validated locally with
`chezmoi diff --source home --destination /tmp/cm-test/test-home` for
linux-desktop, linux-cli, wsl, and macOS gates.

### Minor follow-up (non-blocking)

Once all hosts run Ghostty ≥1.2.3, rename the deploy basename from
`config` to `config.ghostty` (Ghostty's new canonical filename; legacy
`config` still works). Single edit in the body wrapper filename + both
wrapper paths; no body change. Defer until upgrade is confirmed across
all real hosts.

## 3. Verification run (this turn)

```text
bash scripts/validate-config.sh    -> all invariants pass
bash scripts/doctor.sh             -> exits 0 (gitleaks now present via mise shims)
bash scripts/bootstrap.sh --dry-run -> clean
mise run repo:validate             -> pass
mise run lint:shell                -> pass
mise run tools:optional:list       -> all 5 binaries resolve
git diff --check                   -> clean
shellcheck on all migration scripts -> clean
```

## 4. Failure ledger for this audit slice

| What | Reason | Resolution |
|------|--------|------------|
| `git push --dry-run origin feat/dotfiles-migration` | none — dry-run succeeded, branch creation reported | no failure; push allowed |
| `mkdir -p docs/research` earlier in this branch | none — completed | no failure |
| `nix flake check ./nix` | nix still not installed on this WSL host (Determinate installer needs interactive sudo) | unchanged; remains in `repo-docs/migration-followups.md` under deferred verifications |

No new failures.
