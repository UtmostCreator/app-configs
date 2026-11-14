Source: local

# T-0001: Audit remediation program (umbrella)

Status: open
Wave: n/a (umbrella)
Depends on: none

## Summary
Triage and remediate the Nov-2026 external audits of app-configs (ops scripts,
nix modules, bootstrap/install/update, hooks, docs), plus feature proposals
(failure-prevention registry, repo-guardian agent draft, statusline upgrade).
plan.md is written alongside by another agent.

## Owned files (write boundary)
- docs/work/active/T-0001-audit-remediation/ only. Each child owns the files listed in its own ticket.

## Findings
Every audit finding is an external audit claim — unverified until reproduced.
Children reproduce first and reject false positives with evidence.

## Child tickets
| Wave | ID | Title |
|---|---|---|
| 1 | T-0002 | Syncthing conflict-file preservation (P0 data loss) |
| 1 | T-0003 | snapshot-home fail-closed (P1) |
| 1 | T-0004 | Git hook marker and scanner detection (P0) |
| 1 | T-0005 | projects/lib.sh injection and masking (P1) |
| 1 | T-0006 | projects scripts correctness (P1) |
| 1 | T-0007 | health runner exit status and test gaps (P1) |
| 2 | T-0008 | bootstrap.sh safety and dry-run contract |
| 3 | T-0009 | install.sh safety and preflight |
| 2 | T-0010 | update-all lifecycle, locking and rollback |
| 1 | T-0011 | update-* helper libraries (P1) |
| 1 | T-0012 | cleanup.sh exit status (P1) |
| 1 | T-0013 | detect-host validation (P0) |
| 2 | T-0014 | validate-config rule enforcement |
| 1 | T-0015 | doctor/readiness preflight (P1) |
| 1 | T-0016 | flake checks, CI levels, pinned darwin-rebuild |
| 2 | T-0017 | nix identity: username and homeDirectory |
| 1 | T-0018 | Home Manager dev/gui module runtime issues |
| 2 | T-0019 | nix settings, hosts and darwin modules |
| 3 | T-0020 | mise.toml task safety |
| 1 | T-0021 | ssh-agent installer injection and data safety (P0) |
| 2 | T-0022 | tool ownership policy docs |
| 1 | T-0023 | codebase-memory-mcp updater test quality (P2) |
| 1 | T-0024 | ops reporting accuracy (P2) |
| 3 | T-0025 | failure-prevention registry (feature) |
| 3 | T-0026 | repo-guardian agent draft, inactive (feature) |
| 1 | T-0027 | Claude statusline upgrade (feature) |

## Acceptance criteria
- Every child ticket closed with evidence, or rejected as a false positive with evidence.
- Child acceptance (bug tickets): reproduce each finding with a failing bats/unit test or record why it is a false positive; fix; regression test fails on old code and passes on new; affected `bats` + `bash ops/lint-shell.sh` + `nix flake check ./nix` (nix changes) pass; independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Wave dependencies respected (see each child's "Depends on").

## Out of scope / notes
- Do not edit .gitignore or Glyphbrace-managed files. Never commit from a ticket-authoring stage.
- CI-definition edits need explicit user authorisation.

## Progress

- 2026-11-14: Umbrella. Closed children T-0002 to T-0008, T-0012 to T-0019, T-0021 to T-0024, T-0027, T-0028 are in archive/2026/. Still open: T-0009, T-0010, T-0011, T-0020, T-0025, T-0026. WSL2 follow-ups are tracked as T-0034 to T-0041.
