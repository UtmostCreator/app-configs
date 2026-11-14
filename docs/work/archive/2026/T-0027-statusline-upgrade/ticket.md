Source: local

# T-0027: Claude statusline upgrade (feature)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
Extend the statusline with more session signals while preserving the current appearance.

## Owned files (write boundary)
- home/dot_claude/executable_statusline.sh
- tests/bash/claude-statusline.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Feature, not an audit finding.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Preserve current appearance.
- Add remaining context tokens (e.g. "63k left"), rate_limits.five_hour usage, context pressure colours at 75/85/95%.
- Git staged/unstaged/untracked counts and ahead/behind (no fetch, cache ~5s).
- Conditional session cost/duration, cache health, worktree, PR state only when present.
- Adapt to $COLUMNS; hide missing fields (no fake 0%).
- Do not duplicate the native auto-mode footer.
- Works on Linux and macOS.
- `bats tests/bash/claude-statusline.bats` passes; `chezmoi diff` shows the managed file matches.

## Out of scope / notes
Bug-ticket acceptance (reproduce/fix/regression) does not apply; this is a feature. Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - f1f3fd3 feat(statusline): keep a compact model tag in narrow agent rows
  - c8ab06c feat(statusline): add context, git, session and cache segments
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
