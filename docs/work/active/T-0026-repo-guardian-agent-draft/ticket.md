Source: local

# T-0026: repo-guardian agent draft (inactive)

Status: open
Wave: 3
Depends on: T-0025

## Summary
Draft a read-only repo-guardian agent with modes audit, triage, prevention-plan and verify. No writes; uses the failure-prevention skill.

## Owned files (write boundary)
- None in the repo. The draft is returned in the final answer, not written to an active agent path.

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Feature proposal, not an audit finding.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Drafted via agent-factory and reviewed by agent-definition-reviewer.
- Remains an inactive draft; activation requires explicit user approval.

## Out of scope / notes
Do not write under .claude/agents or .codex/agents without user approval.

## Progress

- 2026-11-14: Not started.
