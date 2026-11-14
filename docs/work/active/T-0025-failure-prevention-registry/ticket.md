Source: local

# T-0025: failure-prevention registry (feature)

Status: open
Wave: 3
Depends on: landed fixes from T-0002..T-0024

## Summary
A registry of confirmed and fixed defects, each with a prevention test, plus a project skill for the discover-to-recheck loop.

## Owned files (write boundary)
- docs/quality/taxonomy.yaml
- docs/quality/incidents/AC-NNNN.yaml (one per confirmed and fixed defect from T-0002..T-0024: prevention test path and verification state)
- docs/quality/README.md
- ops/quality/validate-incidents.(sh|py), wired into ops/validate-config.sh or ci.sh, with tests
- .claude/skills/failure-prevention/SKILL.md

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Feature proposal, not an audit finding. Records only verified facts.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Skill loop: discover, validate, classify, dedupe, prevent, verify, record, recheck.
- Status is never "prevented" without an executed guard.
- Validator enforces the schema and that referenced test paths exist.

## Out of scope / notes
Wiring into ops/validate-config.sh or CI is a build-affecting edit; CI-definition edits need explicit user authorisation. Only the files listed above. Unrelated findings are reported, not fixed.

## Progress

- 2026-11-14: Not started.

## Candidate entries

- Shared stash used across worktrees.
- Shared scratch file collisions.
- Review ran only some test suites, which missed a cross-suite regression.
- A broad `pkill -f` touched another session.
- Waiting with `pgrep -f '<pattern>'` matched the waiter itself and left 64-minute stuck loops; instead wait on a PID or a file with a timeout.
- Agent-safety rules now in AGENTS.md (commit from step 2); procedural, not enforced — add executable guards where practical.
