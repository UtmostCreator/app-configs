Source: local

# T-0010: update-all lifecycle, locking and rollback

Status: open
Wave: 2
Depends on: T-0002, T-0003, T-0011, T-0012, T-0013; architect design first

## Summary
ops/update-all.sh has rollback, locking and ordering defects. An architect decides scope (prepare/activate/maintain split) before implementation.

## Owned files (write boundary)
- ops/update-all.sh
- tests/bash/update-all-*.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Rollback runs the old generation's activate instead of an HM generation switch (profile pointer disagrees); no nix-darwin rollback.
- No exclusive lock (flock; mkdir lock for macOS).
- Run id has 1-second resolution.
- Last-run pointer overwritten before success.
- meta_put always succeeds; metadata write failures hidden.
- Second `nix build --print-out-paths` exit unchecked: empty result skips profile_hm_conflicts.
- chezmoi status errors read as no conflicts.
- flake.lock committed before verification.
- git pull after prechecks invalidates them (re-check after pull, or pull first).
- Failed host detection falls back to linux-desktop; HOST_PROFILE unvalidated.
- HM profile path ignores XDG_STATE_HOME.
- `sh -c "cd '$REPO_ROOT' ..."` quoting.
- Partial failures leave flake.lock modified.
- GC (--gc via cleanup KEEP_DAYS) can expire the rollback generation (interface with T-0012).
- Rollback leaves a dirty worktree.
- Brave default-browser check too rigid (P2).
- Verification warnings vs failures (document).

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Architect design recorded before implementation.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Progress

- 2026-11-14: Gate B is being replayed; the release audit is pending.
