Source: local

# T-0020: mise.toml task safety

Status: in progress (4 findings fixed 2026-11-21, 1 false positive; 8 open, see Progress)
Wave: 3
Depends on: T-0003, T-0010

## Summary
mise tasks mutate before checking prerequisites and hide failures.

## Owned files (write boundary)
- mise.toml

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- sync:apply mutates (chezmoi apply) before checking home-manager/darwin-rebuild presence.
- apply and sync:apply use `read` without interactive = true.
- sync dry-run prints "missing: X" and succeeds.
- repo:check silently skips nix validation.
- nix:lint `|| true` (keep advisory, add a strict task).
- `git diff --check` misses staged changes (add --cached).
- `nix flake check` without --no-update-lock-file in read-only tasks.
- darwin-rebuild check needs root (use nix build of darwinConfigurations.macos.system for preview).
- `mise run` auto-installs tools before dry-run (settings.task.run_auto_install=false or --skip-tools).
- Optional installers float versions while claiming pins.
- Hard-coded ~/.config/mise (respect MISE_CONFIG_DIR/XDG).
- sync:apply duplicates the update-all lifecycle (delegate to the shared implementation per T-0010 design).
- No post-sync verification.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Progress

- 2026-11-14: Not started.

- 2026-11-21: tests/bash/mise-tasks.bats (6 tests, 5 failed on the old mise.toml). Fixed: `git diff --check` now also checks staged changes (lint:check, repo:check); nix:check and repo:check pass --no-update-lock-file; sync:dry-run counts missing tools and exits 1 after the full preview; the macOS preview uses `nix build --no-link --dry-run ...#darwinConfigurations.macos.system` instead of the root-only `darwin-rebuild check`. False positive: repo:check already exits 1 when nix is missing. Open: `read` without interactive (mise support unverified), nix:lint strict variant, run_auto_install before dry runs, floating optional installers, hard-coded ~/.config/mise, sync:apply prerequisite order and delegation to update-all (T-0010), post-sync verification.
