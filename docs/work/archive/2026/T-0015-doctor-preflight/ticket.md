Source: local

# T-0015: doctor/readiness preflight (P1)

Status: closed (2026-11-14)
Wave: 1
Depends on: none (T-0008 consumes --preflight)

## Summary
ops/doctor.sh checks the wrong prerequisites for a fresh machine. Define boundaries: doctor --preflight = prerequisites; readiness = installed state.

## Owned files (write boundary)
- ops/doctor.sh
- ops/readiness.sh
- related tests

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- doctor requires rg though rg comes from Home Manager (cli.nix); bootstrap dry-run runs doctor, so a fresh machine fails.
- No nix/chezmoi/mise/home-manager/lefthook check (readiness.sh has them).
- justfile/Justfile warnings though the repo uses mise.toml.
- jq/yq optional though required post-install.
- Scanner optional vs fail-closed pre-commit.
- fail() writes to stdout (use stderr, count errors).
- pre-commit comment says doctor checks tracked files but it uses -f.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- A `--preflight` mode that bootstrap can call.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 6773c14 fix(readiness): require jq/yq and a secret scanner, reject unknown args
  - 07a3717 fix(doctor): add --preflight and drop Home-Manager tools from required checks
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
