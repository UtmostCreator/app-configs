Source: local

# T-0016: flake checks, CI levels, pinned darwin-rebuild

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
Flake checks are eval-only and CI coverage is unclear; macOS bootstrap needs a pinned darwin-rebuild.

## Owned files (write boundary)
- nix/flake.nix (checks and packages outputs only)
- ops/ci.sh
- .github/workflows/ci.yml
- ops/ci-local.sh if relevant

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Comment claims --all-systems needs no remote builders, but writeText sentinels create per-system derivations.
- Checks are evaluation-only (activationPackage.drvPath), not build validation.
- Default flake check on Linux skips aarch64-darwin.
- P3: regression check reporting when nixpkgs-last-good pins (Semgrep, OpenClaw) are removable (report-only).
- P3: formatting check duplicated across arches.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- CI runs `nix flake check ./nix --all-systems --no-build` plus native `nix flake check`/`nix build` of linux activation packages; eval vs build levels documented.
- Exports pinned nix-darwin `packages.aarch64-darwin.darwin-rebuild` (consumed by T-0008/T-0009).

## Out of scope / notes
CI-definition edits (.github/workflows/ci.yml) need explicit user authorisation naming the file before editing. Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - a768571 ci: evaluate all systems and build Linux activation packages
  - 8d5ed38 feat(nix): export pinned darwin-rebuild and document flake check levels
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
