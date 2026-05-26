# Migration follow-ups

Live ledger of things that **failed**, were **deferred**, or remain **open**
after the Phase 0–10 dotfiles migration on `feat/dotfiles-migration`.

Also covers stacked work on `feat/project-orchestrator` (chezmoi-templated
tmux + health + GitHub orchestrator imported from
`C:\xampp\htdocs\project-scripts` and anonymised — see
`docs/projects/README.md`).

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
| `feat/project-orchestrator` history-rewrite of authoring identities | Reviewer flagged `Roman.Zakhriapa@rabbies.com` + `romazahrypa@gmail.com` in commit-author metadata on `main`. Per Q2 of the project-orchestrator brief, this slice **only** sanitises new content; existing-history rewrite is a separate later slice with explicit sign-off (because `git filter-repo` + force-push invalidates the open PR's commit shas). | Land `feat/dotfiles-migration` and `feat/project-orchestrator` first; then file a `chore/rewrite-authors` PR with the exact `git filter-repo --email-callback` invocation + coordination plan for the force-push. |
| `feat/project-orchestrator` `Herd` mention in `home/dot_gitconfig.tmpl` | The committed dotfiles `gitconfig` includes a `gitdir/i:{{ .chezmoi.homeDir }}/herd/` selector. `Herd` is a personal-machine convention (the Laravel Herd install path), not a project name — but it's a leak under a strict reading of the anonymisation contract. | Replace with a configurable selector via `personal.yaml` (e.g. `{{ .gitconfig.work_dir_pattern }}`) in a separate slice; not blocking. |

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
| 2026-05-24 | **`scripts/bootstrap.sh` `interactive_confirm` unbound `CI`** — with `set -u`, the log line `log "Non-interactive (CI=$CI or no tty); ..."` dereferenced `$CI` directly on the non-interactive auto-confirm path. In any non-TTY shell without `CI=` exported (cron, opencode, local automation) the bootstrap aborted with `unbound variable` instead of auto-confirming, breaking exactly the `--yes` path the function was meant to support. | Captured `${CI:-}` into a local `ci_flag` at the top of the function and log `CI=${ci_flag:-<unset>}` instead. Regression test: `env -i bash -c '...interactive_confirm "test"' ` now logs `CI=<unset> or no tty` and returns 0. |
| 2026-05-24 | **`.github/workflows/validate-ai-surface.yml` `test-php` job** — the job ran `composer install --no-interaction --prefer-dist` unconditionally; this repo (and any kit-only install) has no `composer.json`, so the step failed on every push and PR and kept the workflow permanently red on unrelated changes. | Added a `Detect PHP test project` step that checks for `composer.json` and gates the setup-php / composer-install / phpunit steps on `steps.detect.outputs.has_php == 'true'`. Emits a GitHub `::notice::` when skipped. Also added `--no-run-if-empty` to the `lint` job's shellcheck xargs invocation for the same parity reason. actionlint clean. |
| 2026-05-24 | **Personal project orchestrator imported from `C:\xampp\htdocs\project-scripts`** — original was 5 named projects (CMS / frontend / traverse / vue-components / stripe), hard-coded paths, 1058-line health monitor, 668-line PR watcher, project names in every script. | New `scripts/projects/` tree on `feat/project-orchestrator`. Generic over N projects via `home/.chezmoidata/projects.yaml` (gitignored). `tmux-master.sh` (~190 lines, generic), `tmux-logs.sh`, `tmux-ssh.sh`, `repo-checks.sh`, `health/run.sh` + `render.sh` + `checks.d/*`, `github/sync-main.sh`, slim `github/pr-watch.sh` (~110 lines). Zero project names in tracked code (leak grep passes). ~5k lines → ~640 lines. New mise tasks under `projects:*`. Docs: `docs/projects/README.md`. |
| 2026-05-24 | **Codex P1 — `tmux-master.sh` dropped tertiary at N=3** — the outer `if [[ -n "$BOTTOM_L_ID" || -n "$BOTTOM_R_ID" ]]` only matched the 4+ project case. With exactly 3 projects, `TERTIARY_ID` was set but the `else` branch only opened primary + secondary, silently hiding the third project. | Rewrote the pane-assignment block around explicit N=1..5 cases keyed on whether `SECONDARY_ID` / `TERTIARY_ID` / `BOTTOM_L_ID` / `BOTTOM_R_ID` are set. N=3 now splits the right column once for tertiary. Regression test in `/tmp/tmux-master-p1-test.sh` confirms all five counts open the correct project set. |
| 2026-05-24 | **Codex P2a — `pr-watch.sh` rang `pr_review_requested` for every transition and never reached `ci_failed`** — any state change (mergeable, updatedAt, anything) fired the review-requested bell; the `ci_failed` event key in the config schema was unreachable. | Per-field transition detection: read `statusCheckRollup` from `gh pr list` and roll it up to `FAILURE`/`PENDING`/`SUCCESS`/`NONE`. Compare `reviewDecision` and the rolled-up CI state separately. `pr_review_requested` only fires when review becomes `REVIEW_REQUIRED`. `ci_failed` fires on `* → FAILURE`. Generic changes (mergeable, updatedAt only) log without ringing any bell. State file now persists `{review, ci, mergeable, updatedAt}`. |
| 2026-05-24 | **Codex P2b — `health/run.sh --quiet` exited 1 on warn-only runs** — `[[ "$(jq -r '.overall.status' <<<"$AGG")" == "ok" ]]` treated `warn` as failure, contradicting the documented "exit 0 if all ok, 1 if any fail" contract and breaking warn-only automation. | Replaced the `== "ok"` guard with `final_exit()` keyed on `overall.failed > 0`. Both `--quiet` and `pretty` modes now exit 0 for ok and warn-only, 1 only when at least one check has `status: fail`. Docstring updated to spell out the contract. Regression test for the four shapes (ok / warn-only / fail / warn+fail) confirms the mapping. |

## Process notes

When you, the reader, hit something that fails:

1. Note the literal command and the one-line failure reason.
2. Decide: **fix now** (smallest safe slice), **defer** (add row to "Open"), or **drop** (remove the broken caller).
3. If you defer, append a row under "Open" with `Symptom / Severity / Fix options / Owner`.
4. When the fix lands, move the row to "Resolved" with the commit hash.

Silent skips are not allowed. The agent rule in `AGENTS.md` ("Failure
flagging is mandatory") makes this the explicit completion criterion for
every slice.
