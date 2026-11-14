Source: local

# T-0004: Git hook marker and scanner detection (P0 false success)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
Hooks can pass bad commits because of SIGPIPE under pipefail and over-broad marker regex.

## Owned files (write boundary)
- ops/hooks/pre-push.sh
- ops/hooks/pre-commit.sh
- tests/bash/git-hooks.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- pre-push `git show | grep -q` under pipefail gives SIGPIPE 141, making the conflict check false; a commit containing `<<<<<<< HEAD` passed (reported as reproduced).
- pre-commit marker regex rejects legitimate `=======` lines (e.g. Markdown headings) and has the same SIGPIPE weakness.
- Secret scan passes if no scanner is installed. Verify against the claim that the hook already fails closed with a bootstrap escape hatch.
- trufflehog fallback scans history since HEAD, not the staged snapshot.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- A large commit with real conflict markers is rejected.
- Legitimate `=======` text is accepted.
- Scanner-missing behaviour is explicit and tested.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed. Never bypass hooks with --no-verify.

## Closure

- **Commits:**
  - f9d3f6e fix(hooks): harden pre-commit marker scan, name handling and trufflehog fallback
  - 58f71e1 fix(hooks): make pre-push conflict-marker check fail closed and see merges
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
