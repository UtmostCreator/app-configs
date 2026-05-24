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

(none — C3, C4, C5 all resolved; see Resolved section)

## Open — explicit deferrals (intentional, not bugs)

| Item | Why deferred | Unblock condition |
|------|--------------|-------------------|
| `nix flake check ./nix` | Determinate Systems installer needs interactive `sudo`, which this opencode session does not have. Attempted 2026-05-24 — `sudo: A terminal is required to authenticate`. | Run from your own shell: `sh /tmp/nix-installer.sh install --no-confirm` (still cached) or `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \| sh -s -- install --no-confirm`. Then `nix flake check ./nix`. |
| `home-manager switch --flake ./nix#wsl --dry-run` | Needs Nix and `home-manager` first (same blocker as above) | After Nix is installed, run `nix profile install nixpkgs#home-manager` then the dry-run command. |
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
| 2026-05-24 | **C3** — `scripts/hooks/pre-commit.sh` called non-existent `scripts/repo-health-check.sh` | Delegated the staged-files health check to `scripts/doctor.sh` + `scripts/validate-config.sh`; missing-script branch downgraded to a warning so a partial clone still commits. |
| 2026-05-24 | **C4** — `scripts/doctor.sh` listed `php` as required, but `mise.toml` no longer pins a runtime | `php` moved to optional binaries; AI workflow validators gated on `command -v php` and report a `[WARN]` block instead of failing when absent. Fresh Ubuntu hosts no longer abort at bootstrap step 9. |
| 2026-05-24 | **C5** — `mise.toml` `tools:optional:install` wrote to `~/.config/mise/config.toml`, which chezmoi also owns | Pins now land in `~/.config/mise/conf.d/optional-tools.toml`. mise auto-loads that file; the chezmoi-managed `config.toml` is untouched. Verified end-to-end: dive/fx/navi/glow/gum all resolve via the shim path. |
| 2026-05-24 | **Ghostty macOS path was wrong** — `home/dot_config/ghostty/config.tmpl` deployed to `~/.config/ghostty/config` on macOS, but Ghostty on macOS prefers `~/Library/Application Support/com.mitchellh.ghostty/config` (XDG works as fallback only) | Single source of truth body moved to `home/.chezmoitemplates/ghostty/config.body.tmpl`. Two thin wrappers point at it: `home/dot_config/ghostty/config.tmpl` (Linux/WSL desktop) and `home/Library/Application Support/com.mitchellh.ghostty/config.tmpl` (macOS). `.chezmoiignore` gates so each OS deploys to exactly one path. Validated via `chezmoi diff` for linux-desktop/linux-cli/wsl + macOS gate render. |
| 2026-05-24 | **chezmoi autoload failure** — `home/.chezmoidata/personal.yaml.example` was inside the `.chezmoidata/` autoload dir; chezmoi tried to parse `.example` as a data format and failed with `unknown format` on any first run | Example moved to `home/personal.yaml.example` (outside `.chezmoidata/`). `.chezmoiignore` excludes it from deployment. Doctor + validator + every doc updated; validator gained an explicit anti-regression rule that errors if `home/.chezmoidata/personal.yaml.example` reappears. |
| 2026-05-24 | **`.chezmoiignore` rule selector** — patterns used `dot_config/...` (source-tree path) instead of `.config/...` (target path). Result: `karabiner` and `Library/...` directory entries still appeared in `chezmoi diff` on Linux even though file children were excluded | Rewrote `home/.chezmoiignore` to use target paths (`.config/karabiner`, `Library/Application Support/...`). Added explicit dir entries alongside `/**` so chezmoi excludes the parent dir as well as children. Verified for all four host profiles. |

## Process notes

When you, the reader, hit something that fails:

1. Note the literal command and the one-line failure reason.
2. Decide: **fix now** (smallest safe slice), **defer** (add row to "Open"), or **drop** (remove the broken caller).
3. If you defer, append a row under "Open" with `Symptom / Severity / Fix options / Owner`.
4. When the fix lands, move the row to "Resolved" with the commit hash.

Silent skips are not allowed. The agent rule in `AGENTS.md` ("Failure
flagging is mandatory") makes this the explicit completion criterion for
every slice.
