Source: local

# T-0009: install.sh safety and preflight

Status: open
Wave: 3
Depends on: T-0008, T-0017

## Summary
ops/install.sh has inconsistent chezmoi source handling, weak preflight and unsafe advice.

## Owned files (write boundary)
- ops/install.sh
- tests/bash/install-preflight.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- chezmoi init uses --source but apply/managed do not (persist sourceDir or pass --source everywhere).
- Snapshot before apply --force must be fail-closed (T-0003).
- mise install runs from the caller cwd.
- `curl | sh` without pipefail hides download failure.
- DRY_RUN only honours exact 1 (validate 0|1).
- If any base tool is missing, all four are reinstalled (profile conflicts).
- Repeat HM switch fails on an existing hm-bak (verify).
- External failures bypass [install:error].
- nix-command/flakes not verified on existing Nix.
- Recommends adding the user to trusted-users (privilege escalation: remove the advice).
- Username parsed from nix/vars/default.nix via sed (use nix eval; failure is an error).
- Bats HOME guard prefix compare accepts outside paths.
- Linux-personal helper runs on macOS.
- Repo path interpolated in `sh -c`.
- trusted-users check ignores @group.
- GC timer check accepts nix-optimise.timer alone.
- "Install complete" printed before readiness.
- macOS darwin-rebuild bootstrap/sudo: same as T-0008.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.
- Write boundary extended (orchestrator, 2026-11-14): tests/bash/bootstrap-safety.bats and install-vscode-extensions.bats (hermetic nix stubs), nix/vars/default.nix (comment), docs/getting-started/install.md (installer checks paragraph). Finding 18 fixed here, not in T-0008.
- bootstrap.sh darwin-rebuild call (F6) fixed here as the same defect.

## Progress

- 2026-11-14: Landed on main (integration tip 2f93e0f). ~~Item #7 is decided as "rotate the hm-bak safely, never overwrite, stop if rotation cannot preserve the original"~~ (superseded, see the corrected #7 decision below); still to be implemented.
- 2026-11-14: Decisions recorded.
  - ~~#7 (hm-bak): rotate safely, never overwrite, stop if rotation cannot preserve the original. Priority P2, to fix before repeat-install acceptance.~~ Superseded by the corrected decision below.
  - trusted-users (new follow-up, noted here instead of a new ticket): audit dependencies, then remove unnecessary privileges (`ops/system-setup.sh`, `ops/readiness.sh`, docs). Priority P2.
  - **#7 decision (corrected by the user, 2026-11-14):** preserve existing `.hm-bak` backups and provide a manual resolution path, meaning a clear message naming the file to move. No automatic overwrite or rotation without a separately justified change. This supersedes the earlier "rotate safely" line above. Priority P2, to fix before repeat-install acceptance: the correction changed the approach, not the priority. The `trusted-users` audit stays as recorded.
- 2026-11-16 (branch fix/chezmoi-source-everywhere): first finding fixed by passing `--source=<repo>` everywhere, not by persisting sourceDir. On NixOS-WSL `chezmoi init --source` leaves no sourceDir and `~/.local/share/chezmoi` does not exist, so every plain chezmoi call failed. One decision now lives in `ops/lib/chezmoi-source.sh` (`chezmoi_source_set`, `chezmoi_source_hint`): no `--source` when `chezmoi source-path` already resolves (readlink -f) to `<repo>/<.chezmoiroot>`, else `--source=<repo>`; a failing readlink or source-path means "not configured". It is the logic of `_sel_chezmoi_is_configured_source`, which now calls it. Consumers: `ops/lib/selection-facts.sh`, `ops/readiness.sh` (inline copy removed; drift advice prints `chezmoi --source=<repo> apply` when needed; a CBM unit `activating` with 0 restarts says "starting" with no TODO), `ops/update-all.sh` (status, target-path, source-path, diff, apply, verify and the conflict advice), `ops/audit.sh`, `ops/bootstrap.sh` (diff, apply), `ops/snapshot-home.sh` (`chezmoi managed`, which update-all and bootstrap call), `ops/unix/ssh-agent-setup.sh` (`source-path`). Tests: `tests/bash/chezmoi-source.bats` (new), plus T-0009 cases and unconfigured-chezmoi stubs in update-all-apply, audit, bootstrap-safety and readiness. Not changed: `ops/install.sh` (already passes `--source` and a shim), `mise.toml` tasks and `nix/modules/home/scripts/*.sh` (plain `chezmoi diff|apply|source-path`; they are not in ops/), `ops/uninstall.sh` (`chezmoi forget`). Ticket stays open: the other findings and the independent review are still pending.
- 2026-11-16 (review follow-up, same branch): the lib also reports `CHEZMOI_SOURCE_STATE` (`configured`, `unconfigured`, `other`) and `CHEZMOI_SOURCE_PATH`. `other` means `chezmoi source-path` names an existing directory that is not this repo (a worktree on a host configured for another checkout). Read-only callers (status, diff, verify, readiness, audit) keep `--source=<repo>`, but `ops/update-all.sh --apply` refuses before changing anything ("chezmoi is configured for <path>; run sys-update from that checkout"), because templates bake `.chezmoi.sourceDir` into what an apply writes. Real chezmoi prints its default `~/.local/share/chezmoi` with rc 0 even when it is missing, so the directory is tested with `-d`: a missing path is `unconfigured` and applies with `--source=<repo>` (the NixOS-WSL case). The advice hint is shell-quoted (`%q`). Tests: `chezmoi-source.bats` (state, quoting), `update-all-apply.bats` (refusal, report mode, missing default path), `snapshot-home.bats` (unconfigured chezmoi); the unconfigured stubs now model real chezmoi.
