Source: local

# T-0008: bootstrap.sh safety and dry-run contract

Status: closed (2026-11-14)
Wave: 2
Depends on: T-0003, T-0013, T-0015, T-0016

## Summary
ops/bootstrap.sh applies or mutates in situations the user did not authorise.

## Owned files (write boundary)
- ops/bootstrap.sh
- tests/bash/bootstrap-safety.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- MODE env var is honoured: MODE=apply (anything != dry-run) applies without --yes. Reject invalid values; only the CLI enables apply.
- confirm auto-approves when CI is non-empty (CI=false) or there is no TTY; --yes still prompts on a TTY.
- Dry-run runs nix flake check, chezmoi init and doctor (mutating): define a strict dry-run contract.
- `chezmoi diff || true` hides errors.
- DRY_CMD failure is only logged, then "done".
- Missing doctor.sh is silently skipped.
- mise install runs in the caller cwd (use -C / cd REPO_ROOT).
- darwin-rebuild is never installed and is run without sudo (use the pinned flake output from T-0016).
- ssh-agent failures ignored.
- Unknown args (check).
- nixpkgs# bootstrap tools unpinned (P2).
- WSL1 not rejected (use detect-host from T-0013).

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Uses doctor --preflight (T-0015) and detect-host (T-0013).

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - dd540f0 docs(bootstrap): describe the apply approval flow
  - ae3841b fix(bootstrap): require explicit approval and a read-only dry-run
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
