# Dotfiles migration — pre-flight decisions

Branch: `feat/dotfiles-migration`
Baseline: 458 tracked files (see `/tmp/dotfiles-before.txt` for the live snapshot).

| Decision | Choice | Notes |
|----------|--------|-------|
| Bash usage | **Keep bash fallback** | Migrate `backup-sanitized/home/.bashrc` to `home/dot_bashrc`. |
| `personal.yaml` privacy | **Gitignore real file; commit `personal.yaml.example` only** | Real identity stays out of git. `personal.yaml` added to `.gitignore` in Phase 2. |
| macOS architecture | **`aarch64-darwin`** | Apple Silicon default. Phase 6 `nix/vars/default.nix` will use this. |
| Primary day-to-day host | **`wsl`** | First end-to-end validation runs on WSL2 (this machine). |

## Implications

- Phase 4 includes `home/dot_bashrc` migration.
- Phase 4 ships `home/personal.yaml.example` as the committed template (chezmoi autoloads YAML/TOML/JSON inside `home/.chezmoidata/`, so the example with the `.example` suffix lives one directory up).
- `.gitignore` will block `home/.chezmoidata/personal.yaml`.
- Phase 6 uses `aarch64-darwin` for the macos profile.
- Phase 7 `scripts/detect-host.sh` returns `wsl` on this machine; bootstrap dry-runs validate the `wsl` profile first.
- Phase 8 (nix-darwin) is deferred until a Mac is available; the macos profile must still evaluate (`nix flake check`) on Linux/WSL.

## Open carry-over from policy work

`.opencode/agents/implementer.md` and `.opencode/opencode.json` were widened to allow the migration commands. These edits are **policy/infrastructure**, not part of this migration. They will be committed separately at the end of this session under a dedicated commit on `main` or a `chore/opencode-policy` branch.
