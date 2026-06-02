# Source-of-truth matrix (final)

Reviewed copy of `docs/migration-source-of-truth.draft.md`. Phase 2 reads only
this file. Regenerate the draft via `bash scripts/check-source-of-truth.sh`.

Branch: `feat/dotfiles-migration`
Decision date: 2026-05-24

## Duplicate / overlapping config pairs

| Target | Candidate sources | Chosen | Reason |
|--------|-------------------|--------|--------|
| `~/.zshrc` | `configs/shell/.zshrc`, `backup-sanitized/home/.zshrc` | **`backup-sanitized/home/.zshrc`** | Already sanitized with `<HOME>` placeholders; git history shows it is the newer copy. |
| `~/.zprofile` | only `backup-sanitized/home/.zprofile` | **`backup-sanitized/home/.zprofile`** | Single source. |
| `~/.bashrc` | only `backup-sanitized/home/.bashrc` | **`backup-sanitized/home/.bashrc`** | Single source. Bash fallback retained per Phase 0 decision. |
| `~/.gitconfig` | `configs/shell/.gitconfig`, `backup-sanitized/home/.gitconfig` | **`backup-sanitized/home/.gitconfig`** | Sanitized `<HOME>` placeholders; newer. |
| `~/.config/starship/starship.toml` | `configs/shell/starship.toml`, `backup-sanitized/home/.config/starship/starship.toml` | **`backup-sanitized/home/.config/starship/starship.toml`** | Only diff is a stale comment removed; newer. |
| `~/.config/ghostty/config` | `configs/ghostty/config`, `configs/ghostty/config-ghostyy`, `backup-sanitized/home/.config/ghostty/config` | **`configs/ghostty/config-ghostyy`** (renamed) | The `config-ghostyy` file is the actually-modern Ghostty config (theme + font + shell integration + clipboard safety + macOS QoL). The other two are an older Catppuccin palette and the same palette + 3 extra lines. Migrate the "-ghostyy" body as `home/dot_config/ghostty/config.tmpl` and delete the older two during Phase 2. |
| `~/.config/atuin/config.toml` | only `backup-sanitized/home/.config/atuin/config.toml` | **`backup-sanitized/...`** | Single source. |
| `~/.config/btop/btop.conf` | only `backup-sanitized/home/.config/btop/btop.conf` | **`backup-sanitized/...`** | Single source. |
| `~/.config/mise/config.toml` | only `backup-sanitized/home/.config/mise/config.toml` | **`backup-sanitized/...`** | Single source. Renames to `home/dot_config/mise/config.toml.tmpl`. |
| `~/.config/nvim/` | only `configs/nvim/` | **`configs/nvim/`** | Single source. Whole tree migrates. |
| `~/.config/karabiner/karabiner.json` | only `configs/karabiner/karabiner.json` | **`configs/karabiner/karabiner.json`** | Single source. macOS-gated by `.chezmoiignore` in Phase 4. |
| VS Code `settings.json` | `configs/vscode/user/settings.json` + `configs/vscode/user/settings.minimal.json` | **merge full + minimal via template** | Fold `settings.minimal.json` into a single `settings.json.tmpl` with `{{ if .minimal }}…{{ else }}…{{ end }}`. |
| VS Code `keybindings.json` | only `configs/vscode/keybindings.json` | **`configs/vscode/keybindings.json`** | Single source. |
| `~/.local/bin/git-branch-origin` | `scripts/git-branch-origin.sh`, `backup-sanitized/home/.local/bin/git-branch-origin` | **`scripts/git-branch-origin.sh`** | Repo copy is 424 lines vs 161 in backup; has more flags, --guess mode, exit codes, and is newer in git. Copy into `home/dot_local/bin/executable_git-branch-origin` for chezmoi to deploy with 0755. |

## SSH-agent helper disposition

| Path | Disposition | Reason |
|------|-------------|--------|
| `configs/shell/ssh-agent/ssh-agent.sh` | **migrate to `home/dot_config/app-configs/ssh-agent.sh`** | Sourced from `~/.bashrc` / `~/.zshrc`. chezmoi-owned. |
| `configs/shell/ssh-agent/ssh-agent.fish` | **migrate to `home/dot_config/fish/conf.d/ssh-agent.fish`** | Fish auto-loads everything in `conf.d/`. chezmoi-owned. |
| `configs/shell/ssh-agent/README.md` | **migrate to `docs/unix/ssh-agent-snippets.md`** | Keep as reference docs. |
| `scripts/unix/ssh-agent-setup.sh` | **keep in place as bootstrap helper** | Bootstrap.sh + docs/unix/QUICKSTART.md call it. Update its source paths in Phase 4 to point at `home/dot_config/app-configs/` and `home/dot_config/fish/conf.d/`. |

## Files with no duplicates (migrate directly)

```
backup-sanitized/home/.zprofile
backup-sanitized/home/.bashrc
backup-sanitized/home/.config/atuin/config.toml
backup-sanitized/home/.config/btop/btop.conf
backup-sanitized/home/.config/mise/config.toml
configs/karabiner/karabiner.json
configs/vscode/keybindings.json
configs/vscode/user/settings.json
configs/vscode/user/settings.minimal.json
```

## Whole-tree migrations

```
configs/nvim/              -> home/dot_config/nvim/
configs/vscode/             -> see VS Code rows above; templates fold; workspace templates move to docs/templates/vscode/
```

## Phase 2 delete list (executed in Phase 2 only)

After source selection above, the **losing** copies + project-scoped files
become deletes:

- `configs/shell/.zshrc`
- `configs/shell/.gitconfig`
- `configs/shell/starship.toml`
- `configs/ghostty/config` (old palette; superseded by `-ghostyy` body)
- `backup-sanitized/home/.config/ghostty/config` (old palette + 3 extra lines)
- `configs/ghostty/config-ghostyy` (after its body is renamed/migrated to `home/dot_config/ghostty/config.tmpl`)
- `configs/php/php.ini` (system-volatile)
- `configs/php/pint.json` (project-scoped)
- `configs/vscode/launch.json` (project-scoped)
- `backup-sanitized/home/.local/bin/git-branch-origin` (loser of the pair)

## Explicit non-deletes in Phase 2

- Native Windows files (`docs/windows/`, `*.ps1`, `verify-dev-tools-gitbash.sh`): out of scope, untouched.
- `.husky/`: deferred until Lefthook is confirmed installed and hook ownership is approved separately.
- `docs/install-dev-tools.sh`: retained as macOS reference until Phase 6 matrix parity is proven.

## Validation

- [x] `scripts/check-source-of-truth.sh` ran cleanly and emitted the draft.
- [x] Every TBD row from the draft is resolved.
- [x] Every `configs/` file has a disposition (migrate / merge / delete).
- [x] Every `backup-sanitized/` file has a disposition.
- [x] SSH-agent files all have an explicit owner.
- [x] `scripts/git-branch-origin.sh` compared against backup copy before choosing.
