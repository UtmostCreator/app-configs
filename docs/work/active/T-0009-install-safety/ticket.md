Source: local

# T-0009: install.sh safety and preflight

Status: open
Wave: 3
Depends on: T-0008, T-0017

## Summary
ops/install.sh has inconsistent chezmoi source handling, weak preflight and unsafe advice.

## Owned files (write boundary)
- ops/install.sh
- tests/bash/install-preflight.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- chezmoi init uses --source but apply/managed do not (persist sourceDir or pass --source everywhere).
- Snapshot before apply --force must be fail-closed (T-0003).
- mise install runs from the caller cwd.
- `curl | sh` without pipefail hides download failure.
- DRY_RUN only honours exact 1 (validate 0|1).
- If any base tool is missing, all four are reinstalled (profile conflicts).
- Repeat HM switch fails on an existing hm-bak (verify).
- External failures bypass [install:error].
- nix-command/flakes not verified on existing Nix.
- Recommends adding the user to trusted-users (privilege escalation: remove the advice).
- Username parsed from nix/vars/default.nix via sed (use nix eval; failure is an error).
- Bats HOME guard prefix compare accepts outside paths.
- Linux-personal helper runs on macOS.
- Repo path interpolated in `sh -c`.
- trusted-users check ignores @group.
- GC timer check accepts nix-optimise.timer alone.
- "Install complete" printed before readiness.
- macOS darwin-rebuild bootstrap/sudo: same as T-0008.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.
- Write boundary extended (orchestrator, 2026-11-14): tests/bash/bootstrap-safety.bats and install-vscode-extensions.bats (hermetic nix stubs), nix/vars/default.nix (comment), docs/getting-started/install.md (installer checks paragraph). Finding 18 fixed here, not in T-0008.
- bootstrap.sh darwin-rebuild call (F6) fixed here as the same defect.

## Progress

- 2026-11-14: Landed on main (integration tip 2f93e0f). Item #7 is decided as "rotate the hm-bak safely, never overwrite, stop if rotation cannot preserve the original"; still to be implemented.
