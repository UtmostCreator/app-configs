# Agent rules for app-configs

## Build-affecting changes: validate, then commit when safe

`sys-update` (`ops/update-all.sh`) refuses to run on a dirty worktree or on
hand-edited managed files. A change left uncommitted blocks the next system
update, so do not leave build-affecting changes lying in the worktree.

**Build-affecting** means anything that changes what gets built or applied:

- `nix/**`: modules, packages, `flake.nix`, release locks
- `home/**`: chezmoi sources, templates, `modify_` scripts
- `ops/*.sh` scripts used by `sys-update`, bootstrap, or systemd units
- `.lefthook.yml`, `mise.toml`, `.vscode/mcp.json`, and other configs that
  tooling installs or reads

### Validate first

Run whatever covers the change, and every check that applies to it:

```bash
nix flake check ./nix                                    # what sys-update runs
nix build --no-link "path:$PWD/nix#homeConfigurations.$(bash ops/detect-host.sh).activationPackage"
bats tests/bash                                          # or the affected *.bats files
chezmoi diff                                             # managed files match the repo
bash ops/update-all.sh                                   # report mode, changes nothing
```

- `git add` new `*.nix` files before evaluating. Flakes ignore untracked
  files, and the pre-commit hook rejects them.
- If a live managed file (for example `~/.claude/settings.json`) drifted, port
  the edit into its repo source rather than discarding it, unless the user says
  the repo version should win.

### Commit when safe

Commit once every relevant check passes **and** all of these hold:

- The pre-commit hooks pass (gitleaks, `ops/validate-config.sh`). Never use
  `--no-verify`.
- No secrets, no `home/.chezmoidata/personal.yaml`, no machine-local state.
- The diff only contains work you made or verified. Other sessions may be
  editing this repo concurrently (see `.claude/worktrees/`), so leave in-progress
  work that is not yours unstaged and mention it.
- Use conventional commits (`feat(scope): …`, `fix(scope): …`), one logical
  change per commit.

Do **not** hand-commit an `nix/flake.lock` input bump. `sys-update` runs
`nix flake update` itself and only commits the lock when it matches HEAD, so a
dirty lock blocks that. Revert stale lock edits, keep a backup, and let
`sys-update` own them.

If a check fails or a change is not safe to commit, leave it uncommitted and
report exactly what failed. Do not commit a broken build, and do not push
unless asked.
