Source: local

# T-0022: tool ownership policy docs

Status: closed (2026-11-14)
Wave: 2
Depends on: policy research result supplied by orchestrator

## Summary
docs/architecture/tool-ownership.md disagrees with the repo; align it so there is one owner per target path.

## Owned files (write boundary)
- docs/architecture/tool-ownership.md (and other docs/architecture files it needs)

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- `nix flake update ./nix` is wrong for Nix >= 2.19 (use --flake ./nix).
- Doc forbids HM programs/services/xdg config, but the repo uses programs.vicinae/openclaw, services.syncthing, systemd.user.services, xdg.configFile (align per research).
- Runtime ownership says mise owns PHP/Node/pnpm, but dev.nix installs them.
- bootstrap "runs ONCE" vs idempotent install.sh.
- sync:apply vs update-all semantics.
- Rollback scope is partial.
- NixOS system layer and Homebrew CLI casks unassigned.
- home/.chezmoidata/projects.yaml documented as gitignored but missing from .gitignore.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Docs match the researched policy and the repo state.

## Out of scope / notes
DO NOT edit .gitignore (it holds the user's uncommitted changes). User follow-up: add home/.chezmoidata/projects.yaml to .gitignore, or correct the doc. Docs only: no code edits.

## Closure

- **Commits:**
  - 884bade fix(zsh): stop brewup upgrading tldr, glow and flameshot
  - ab03832 docs: fix guides that no longer match the scripts
  - 9966950 docs(architecture): align tool ownership with the repo
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - The projects.yaml gitignore follow-up was covered by d0e42fe (listed under T-0014).
