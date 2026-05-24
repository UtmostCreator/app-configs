# Migration follow-ups

Live ledger of things that **failed**, were **deferred**, or remain **open**
after the Phase 0–10 dotfiles migration on `feat/dotfiles-migration`.

Append-only. When an item is resolved, move it to the "Resolved" section
with the resolution commit hash.

The agent rule is in `AGENTS.md` ("Failure flagging is mandatory"): every
failed command/tool call/sub-agent must be flagged in the user-facing
summary and unresolved entries land here.

## Open — blocking next phase

(none)

## Open — non-blocking, before merge to `main`

### C3 — `scripts/hooks/pre-commit.sh` references missing `scripts/repo-health-check.sh`

- **Symptom:** `pre-commit` hook calls `bash scripts/repo-health-check.sh staged`; that script does not exist. After `lefthook install`, the first commit on any staged file will fail.
- **Severity:** medium. Hook only runs once lefthook is installed by bootstrap apply mode.
- **Fix options:**
  - drop the broken call (recommended, doctor + validate-config already cover it), or
  - create a thin `scripts/repo-health-check.sh` that delegates to `bash scripts/doctor.sh` and `bash scripts/validate-config.sh`.
- **Owner:** dotfiles-migration follow-up commit.

### C4 — `scripts/doctor.sh` requires `php`, but `mise.toml` no longer pins it

- **Symptom:** `scripts/doctor.sh` line 64 lists `php` as required. A fresh Ubuntu host (e.g. the `scripts/test-bootstrap-docker.sh --apply` target) has no php, no host pin, and `mise.toml` no longer pins one (per Phase 5 task-toml fix). `bash scripts/bootstrap.sh --yes` then aborts at step 9 (`scripts/doctor.sh`).
- **Severity:** high on a clean host; doctor still passes on this WSL host because system PHP is present.
- **Fix options:**
  - downgrade php to `check_optional_bin` and gate the AI validator block on `command -v php` (recommended), or
  - re-pin PHP in `mise.toml` (rejected — undoes Phase 5 design), or
  - pin PHP in `home/dot_config/mise/config.toml.tmpl` (requires per-user opt-in to land via chezmoi apply, which is already in the sync sequence).
- **Owner:** dotfiles-migration follow-up commit.

### C5 — `mise.toml` `tools:optional:install` writes `~/.config/mise/config.toml`, which chezmoi also manages

- **Symptom:** `mise use -g aqua:wagoodman/dive` (in `tools:optional:install`) writes the global pin to `~/.config/mise/config.toml`. The chezmoi template `home/dot_config/mise/config.toml.tmpl` deploys to the same path. Whichever ran last wins; the validator's "no ownership duplication" rule was specifically written to prevent this.
- **Severity:** medium. Hits only users who run both chezmoi apply and the optional-tools task.
- **Fix options:**
  - point `mise use` at a separate `~/.config/mise/config.local.toml` (mise reads it automatically), or
  - move the opt-in list into the chezmoi-managed template behind a `gui`/`devTools` flag in `personal.yaml`, or
  - drop `mise use -g` and use `mise install <tool>@<version>` + ad-hoc PATH (loses shims; not recommended).
- **Owner:** dotfiles-migration follow-up commit.

## Open — explicit deferrals (intentional, not bugs)

| Item | Why deferred | Unblock condition |
|------|--------------|-------------------|
| `nix flake check ./nix` | Nix not installed in this WSL session | Run after `bash scripts/bootstrap.sh --yes` provisions Nix. |
| `home-manager switch --flake ./nix#wsl --dry-run` | Same as above | Same. |
| `darwin-rebuild check --flake ./nix#macos` | macOS host required | Validate on a Mac before any production macOS use. |
| `bash scripts/test-bootstrap-docker.sh` | docker not installed on this WSL host | Install Docker, then re-run before legacy-cleanup of `backup-sanitized/` is merged. |
| `home/dot_config/mise/config.toml.tmpl` does not pin PHP | Per Phase 0/5 decision: keep repo-level toml task-only | Decide C4 first. |
| `.opencode/agents/implementer.md` + `.opencode/opencode.json` widening uncommitted | Reviewer flagged the diff as overbroad (every `deny` flipped to `allow`/`ask`). User instruction: "do not commit this files for now." | Either revert with `git restore`, or land a surgical narrower patch on a `chore/opencode-policy-*` branch with explicit reviewer sign-off. |
| Docker-image policy comment removed from `tools:optional:install` | Aqua backend status (`experimental = true` floor on older mise versions) not documented in mise.toml | Add a `mise --version` floor note in `docs/bootstrap.md` once the project decides a minimum. |

## Resolved

| Date | Issue | Resolution commit |
|------|-------|-------------------|
| 2026-05-24 | `scripts/doctor.sh` not executable | `72fce1d` (Phase 7 — `chmod +x scripts/doctor.sh`) |
| 2026-05-24 | `scripts/doctor.sh` required deleted `configs/shell/.zshrc` | `0e614dc` (`fix(doctor,policy): align doctor checks ...`) |
| 2026-05-24 | `scripts/doctor.sh` carried `add_winget_paths()` Windows code | `0e614dc` (function removed) |
| 2026-05-24 | `scripts/unix/ssh-agent-setup.sh` `SNIPPET_DIR` pointed at deleted `configs/shell/ssh-agent/` (would break bootstrap step 8) | `a05eb30` (staleness sweep) |
| 2026-05-24 | `README.md`, `docs/README.md`, `docs/unix/QUICKSTART.md`, `docs/unix/ssh-agent-setup.md`, `docs/templates/vscode/workspace-template.json`, `home/.chezmoitemplates/vscode/settings.minimal.json` referenced deleted `configs/` paths | `a05eb30` (staleness sweep) |
| 2026-05-24 | `CONTRIBUTING.md` referenced non-existent `scripts/repo-health-check.sh` and `just *` targets | `a05eb30` (staleness sweep, partial — see C3 above for the corresponding hook bug) |
| 2026-05-24 | `docs/vscode-extensions.md` install loop included Copilot duplicates and pointed at the wrong settings path | `a05eb30` (staleness sweep) |
| 2026-05-24 | `mise.toml` repo-level `[tools] php = "8.4"` triggered asdf-php build failure on every mise task | Removed pin in Phase-5/optional-tools commit chain — see "Tool versions" comment block in `mise.toml`. |
| 2026-05-24 | `mise.toml` task list had no convenience-tool installer | Added `tools:optional:install` + `tools:optional:list` (covers dive, fx, navi, glow, gum). |

## Process notes

When you, the reader, hit something that fails:

1. Note the literal command and the one-line failure reason.
2. Decide: **fix now** (smallest safe slice), **defer** (add row to "Open"), or **drop** (remove the broken caller).
3. If you defer, append a row under "Open" with `Symptom / Severity / Fix options / Owner`.
4. When the fix lands, move the row to "Resolved" with the commit hash.

Silent skips are not allowed. The agent rule in `AGENTS.md` ("Failure
flagging is mandatory") makes this the explicit completion criterion for
every slice.
