Source: local

# T-0012: cleanup.sh exit status (P1)

Status: closed (2026-11-14)
Wave: 1
Depends on: none (interface with T-0010)

## Summary
ops/cleanup.sh always exits 0 even when steps fail.

## Owned files (write boundary)
- ops/cleanup.sh
- tests/bash/cleanup.bats (new)

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- `"$@" || warn` makes the script always exit 0 (reported reproduced: 3 failing tools gave 0).
- `mise cache clear` should be `mise cache prune`.
- KEEP_DAYS=14 vs nix-settings GC 7d mismatch (align or document).
- Must not expire the generation recorded for rollback (coordinate with T-0010, e.g. honour a protected-generation / GC-root input).

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 62f2c79 fix(cleanup): exit non-zero on failed steps, protect HM generations
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
