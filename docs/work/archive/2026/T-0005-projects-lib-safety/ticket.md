Source: local

# T-0005: projects/lib.sh injection and masking (P1)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
ops/projects/lib.sh evaluates and interpolates untrusted values and masks read errors.

## Owned files (write boundary)
- ops/projects/lib.sh
- tests/bash/projects-lib.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- proj_expand_path uses eval: `$(touch probe)` executes.
- proj_field / proj_tmux_session / proj_layout_percent interpolate id/path/key into yq expressions (use strenv plus validated dotted paths).
- proj_yq `2>/dev/null || true` masks malformed YAML and read errors.
- `//` fallback turns boolean false into "".
- proj_field_default substitutes defaults after failures and treats string "null" as missing.
- tmux has-session/attach/switch targets are not exact (use `=name`).
- proj_tmux_attach ignores detached=1 inside $TMUX.
- Library sets `set -uo pipefail` in callers (assess; do not break callers).
- require_cmd name collision (low).

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- A path containing `$(...)` stays data.
- Boolean false is preserved.
- Malformed YAML gives non-zero.
- tmux targets are exact; detached is honoured.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 3de3f47 fix(projects): harden lib.sh against injection and error masking
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
