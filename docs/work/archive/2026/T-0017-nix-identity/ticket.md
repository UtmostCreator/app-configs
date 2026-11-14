Source: local

# T-0017: nix identity: username and homeDirectory

Status: closed (2026-11-14)
Wave: 2
Depends on: none (T-0009 consumes a stable vars attribute)

## Summary
Username and home directory are duplicated and can diverge; the specialArgs override is impossible.

## Owned files (write boundary)
- nix/vars/default.nix
- nix/lib/mkhome.nix
- nix/flake.nix (username wiring only)
- nix/modules/nixos/docker.nix

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- username and homeDirectory duplicated (derive homeDirectory from username).
- mkhome `extraSpecialArgs // { inherit inputs username; }` makes the documented specialArgs override impossible; comment misleading.
- docker.nix default user "utmostcreator" independent of vars despite comment.
- Unused placeholder email (remove if unused).
- install.sh sed-parses vars (T-0009 switches to nix eval: keep a stable attribute).

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Per-profile usernames only if cheap; otherwise document the single-user design. Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 97a5b6b refactor(nix): declare darwin users.users.<name>.home once
  - b128a68 refactor(nix): derive home directories from the single username
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
