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
- 2026-11-14: Gate B, T-0011 and R3 landed on main (23e3578, 1075fa3, 7067ba1, 4608ec0, e833b5e, eac6078, 1cc9f2a, 751528b, 95392e8, a2b6919, 016528e). Review: PASS WITH NOTES.
  - R4-01 (major, present before Gate B): on hosts that never run update-brave (linux-cli, wsl, macOS), `restore_guarded`'s no-hash fallback with `lock_was_clean=1` lets rollback revert a Brave release bump committed by another session and auto-commit it as `chore(nix): roll back flake inputs`.
    - Fix before the first rollback on linux-cli/wsl: restore a file with no recorded hash only from the EXIT handler, and only for a writer this run actually started. Add a linux-cli Brave rollback test.
    - Until then: do not run `sys-update rollback` on linux-cli or wsl.
  - Notes: R4-02 (guarded rm and clear `SNAPSHOT_ERR`), R4-03 (`nix-env` stub in `update-all-recovery.bats`), R4-04 (rollback commit subject mismatch), R4-05 (macOS rollback leaves a dirty worktree), R4-06 (the `dd80c28` `Integration:` note omits `hm_switch_raw`; landed as 23e3578).
  - The release audit is still pending and is required before the first real `--apply` or `rollback`. Checklist:
    1. Fix R4-01, or forbid rollback on linux-cli and wsl until it is fixed.
    2. One real Linux `--apply` then `rollback`: the target check passes, the GC root exists, the rollback commit passes its hooks, and the next run starts clean.
    3. The GC root survives garbage collection.
    4. The VERIFY gate works in a real graphical session.
    5. Re-exec after a real pull that moves HEAD.
    6. Ctrl-C and `kill -9` mid-step leave no ticker, the next run is not refused, and no snapshot temp file is left behind.
    7. linux-cli and wsl print "no runtime verification gate".
    8. macOS is untested.
    9. Nix 2.4 or newer is required.

- 2026-11-14: R4-01 fixed in `ae18daf` (`fix(update-all): restore only files this run wrote`); review PASS WITH NOTES; **R4-01 closed** in the release checklist.
  - New notes: R5-01 (a pre-Gate-A record rollback only switches the profile and says "never wrote it"), R5-02 (early-exit wording should be based on `ROLLBACK_RESTORED`), R5-03 (the incomplete path should print the settle hint).
  - Still open: R4-02, R4-03 and R4-05.
  - Release checklist addition: the first real rollback must target a run recorded by this code (a fresh `--apply`).
  - User priority: release audit P0, before production; destructive fault-injection in an isolated environment, not the daily-driver install.
