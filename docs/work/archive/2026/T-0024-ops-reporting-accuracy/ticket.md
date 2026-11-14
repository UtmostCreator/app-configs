Source: local

# T-0024: ops reporting accuracy (P2)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
Reporting scripts misclassify state. Fix what is cheap and testable; record the rest.

## Owned files (write boundary)
- ops/system-setup.sh
- ops/detect-os-disks.sh
- ops/update-version-report.sh
- ops/generate-package-matrix.sh
- matching tests

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- system-setup.sh:83-129 grep matches comments, disabled and wrong-user config.
- detect-os-disks 597-625: EFI+NTFS/MSR does not prove Windows installed; LUKS/LVM Linux missed.
- update-version-report 475-477: empty package set and failed snapshot share one representation.
- generate-package-matrix 85-97: fixed tool list omits documented tools.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 72bd9a7 fix(generate-package-matrix): derive documented tools from the docs list
  - 3283af1 fix(update-version-report): distinguish empty package set from failed snapshot
  - 5854dc7 fix(detect-os-disks): require full Windows evidence, see through LUKS/LVM
  - 13751cc fix(system-setup): detect only active, target-user config
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
