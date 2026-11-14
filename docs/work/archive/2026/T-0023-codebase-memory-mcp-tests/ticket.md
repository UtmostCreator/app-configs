Source: local

# T-0023: codebase-memory-mcp updater test quality (P2)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
Tests for the codebase-memory updater do not exercise real version changes or per-URL behaviour.

## Owned files (write boundary)
- ops/update-codebase-memory-mcp.sh
- tests/bash/update-codebase-memory-mcp.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Release-refresh test regenerates the already-installed lock (no real version change).
- curl stub returns the release fixture for every URL, including the 127.0.0.1:9749 dashboard.
- release.json updated before activation, no rollback on activation failure.
- --apply assumes HM + Linux systemd despite a macOS artifact.
- HTTP 200 does not mean the correct daemon.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
NOT nix/modules/home/dev.nix (see T-0018). Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 9b4ad9b docs(guides): describe codebase-memory updater rollback and macOS path
  - 3cdf966 fix(ops): roll back codebase-memory release lock when activation fails
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
