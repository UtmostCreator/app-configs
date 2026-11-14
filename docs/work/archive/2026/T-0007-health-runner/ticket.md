Source: local

# T-0007: health runner exit status and test gaps (P1)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
The health runner can exit 0 when jq fails, and its tests miss key paths.

## Owned files (write boundary)
- ops/projects/health/run.sh
- ops/projects/health/checks.d/30-process.sh
- their tests (locate first; python unit tests exist)

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- final_exit `failed=$(jq ...)` is empty on jq failure, giving exit 0 (use jq -e plus a numeric check).
- Test only fails jq on --slurpfile, not in final_exit.
- pgrep mock `return 0` does not assert args.
- Pretty renderer never tested (render.sh deleted in helper).
- No multi-check aggregation tests.
- Docs say checks are executable, but any *.sh is run via bash (align the contract).
- jq shim uses `#!/bin/bash` (NixOS: use `/usr/bin/env bash`) and does not verify the shim ran.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Not bugs: warn exits 0; process-name weak match is a warn. Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 509240c fix(health): fail closed when final_exit cannot read overall.failed
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
