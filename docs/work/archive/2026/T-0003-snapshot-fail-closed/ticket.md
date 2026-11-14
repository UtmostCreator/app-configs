Source: local

# T-0003: snapshot-home fail-closed (P1 fail-open)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
ops/snapshot-home.sh can report success with zero files and loses data in edge cases; update-all parses its output fragilely.

## Owned files (write boundary)
- ops/snapshot-home.sh
- tests/bash/snapshot-home.bats (new, or the existing file if present)
- ops/update-all.sh snapshot hunk only if needed for machine-readable path

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- `chezmoi managed ... 2>/dev/null || true` hides enumeration failure: success with zero files.
- Dangling symlinks skipped (`[[ ! -e ]]` without `-L`).
- Same-second snapshots share a dir and overwrite the manifest.
- update-all parses the snapshot dir from human log output (breaks with custom root or spaces).
- update-all silently skips a missing or non-executable snapshot script (~344-353).

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- chezmoi managed exit != 0 makes the snapshot exit non-zero.
- Dangling symlinks are captured.
- Snapshot dir is collision-safe.
- Snapshot path is emitted in a machine-readable form that update-all consumes.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 2f21a95 fix(update): stop apply when the snapshot is missing or fails
  - 10a6834 fix(snapshot): fail closed, collision-safe dirs, add --print-dir
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
